use crate::lisp::LispObject;
use crate::process::LispProcessRef;
use crate::{
    multibyte::LispStringRef,
    remacs_sys::{
        build_string, encode_string_utf_8, intern_c_string, make_string_from_utf8, make_user_ptr,
        Ffuncall, Fmake_pipe_process, Fplist_get, Fplist_put, Fprocess_plist, Fset_process_plist,
        Fuser_ptrp, QCcoding, QCfilter, QCname, QCplist, QCtype, Qcall, Qdata, Qnil, Qraw_text,
        Qreturn, Qstring, Qstringp, Qt, Quser_ptr, Quser_ptrp, USER_PTRP, XUSER_PTR,
    },
};

use remacs_macros::{async_stream, lisp_fn};
use std::thread;

use std::{
    convert::TryInto,
    ffi::CString,
    fs::File,
    io::{Read, Write},
    os::unix::io::{FromRawFd, IntoRawFd},
};

#[repr(u32)]
enum PIPE_PROCESS {
    SUBPROCESS_STDIN = 0,
    WRITE_TO_SUBPROCESS = 1,
    READ_FROM_SUBPROCESS = 2,
    SUBPROCESS_STDOUT = 3,
    _READ_FROM_EXEC_MONITOR = 4,
    _EXEC_MONITOR_OUTPUT = 5,
}

#[derive(Clone)]
pub struct EmacsPipe {
    // Represents SUBPROCESS_STDOUT, used to write from a thread or
    // subprocess to the lisp thread.
    out_fd: i32,
    // Represents SUBPROCESS_STDIN, used to read from lisp messages
    in_fd: i32,
    _in_subp: i32,
    out_subp: i32,
}

const fn ptr_size() -> usize {
    core::mem::size_of::<*mut String>()
}

fn nullptr() -> usize {
    std::ptr::null() as *const i32 as usize
}

fn is_user_ptr(o: LispObject) -> bool {
    unsafe { Fuser_ptrp(o).into() }
}

impl LispObject {
    fn to_data_option(self) -> Option<PipeDataOption> {
        match self {
            Qstring => Some(String::marker()),
            Quser_ptr => Some(UserData::marker()),
            _ => None,
        }
    }

    fn from_data_option(option: PipeDataOption) -> LispObject {
        match option {
            PipeDataOption::STRING => Qstring,
            PipeDataOption::USER_DATA => Quser_ptr,
        }
    }
}

pub struct UserData {
    finalizer: Option<unsafe extern "C" fn(arg1: *mut libc::c_void)>,
    data: *mut libc::c_void,
}

// UserData will be safe to send because we will take ownership of
// the underlying data from Lisp.
unsafe impl Send for UserData {}

extern "C" fn rust_finalize<T>(raw: *mut libc::c_void) {
    unsafe { Box::from_raw(raw as *mut T) };
}

impl UserData {
    pub fn with_data_and_finalizer(
        data: *mut libc::c_void,
        finalizer: Option<unsafe extern "C" fn(arg1: *mut libc::c_void)>,
    ) -> Self {
        UserData {
            finalizer: finalizer,
            data: data,
        }
    }

    pub fn new<T: Sized>(t: T) -> UserData {
        let boxed = Box::into_raw(Box::new(t));
        let finalizer = rust_finalize::<T>;
        UserData::with_data_and_finalizer(boxed as *mut libc::c_void, Some(finalizer))
    }

    pub unsafe fn unpack<T: Sized>(self) -> T {
        *Box::from_raw(self.data as *mut T)
    }
}

impl From<UserData> for LispObject {
    fn from(ud: UserData) -> Self {
        unsafe { make_user_ptr(ud.finalizer, ud.data) }
    }
}

impl LispObject {
    pub fn is_user_ptr(self) -> bool {
        unsafe { USER_PTRP(self) }
    }

    pub unsafe fn to_user_ptr_unchecked(self) -> UserData {
        let p = XUSER_PTR(self);
        UserData::with_data_and_finalizer((*p).p, (*p).finalizer)
    }

    pub fn as_user_ptr(self) -> Option<UserData> {
        if self.is_user_ptr() {
            Some(unsafe { self.to_user_ptr_unchecked() })
        } else {
            None
        }
    }
}

impl From<LispObject> for UserData {
    fn from(o: LispObject) -> Self {
        o.as_user_ptr()
            .unwrap_or_else(|| wrong_type!(Quser_ptrp, o))
    }
}

impl Default for UserData {
    fn default() -> Self {
        UserData {
            finalizer: None,
            data: std::ptr::null_mut(),
        }
    }
}

// This enum defines the types that we will
// send through our data pipe.
// If you add a type to this enum, it should
// implement the trait 'PipeData'. This enum
// is a product of Rust's generic system
// combined with our usage pattern.
pub enum PipeDataOption {
    STRING,
    USER_DATA,
}

pub trait PipeData {
    fn marker() -> PipeDataOption;
}

impl PipeData for String {
    fn marker() -> PipeDataOption {
        PipeDataOption::STRING
    }
}

impl PipeData for UserData {
    fn marker() -> PipeDataOption {
        PipeDataOption::USER_DATA
    }
}

impl EmacsPipe {
    pub unsafe fn with_process(process: LispObject) -> EmacsPipe {
        let raw_proc: LispProcessRef = process.into();
        let out = raw_proc.open_fd[PIPE_PROCESS::SUBPROCESS_STDOUT as usize];
        let inf = raw_proc.open_fd[PIPE_PROCESS::SUBPROCESS_STDIN as usize];
        let pi = raw_proc.open_fd[PIPE_PROCESS::READ_FROM_SUBPROCESS as usize];
        let po = raw_proc.open_fd[PIPE_PROCESS::WRITE_TO_SUBPROCESS as usize];

        EmacsPipe {
            out_fd: out,
            in_fd: inf,
            _in_subp: pi,
            out_subp: po,
        }
    }

    pub fn with_handler(
        handler: LispObject,
        input: PipeDataOption,
        output: PipeDataOption,
    ) -> (EmacsPipe, LispObject) {
        EmacsPipe::create(handler, input, output)
    }

    fn create(
        handler: LispObject,
        input: PipeDataOption,
        output: PipeDataOption,
    ) -> (EmacsPipe, LispObject) {
        let proc = unsafe {
            // We panic here only because it will be a fairly exceptional
            // situation in which I cannot alloc these small strings on the heap
            let cstr =
                CString::new("async-msg-buffer").expect("Failed to create pipe for async function");
            let async_str = CString::new("async-handler")
                .expect("Failed to crate string for intern function call");
            let mut proc_args = vec![
                QCname,
                build_string(cstr.as_ptr()),
                QCfilter,
                intern_c_string(async_str.as_ptr()),
                QCplist,
                Qnil,
                QCcoding,
                Qraw_text,
            ];

            // This unwrap will never panic because proc_args size is small
            // and will never overflow.
            Fmake_pipe_process(proc_args.len().try_into().unwrap(), proc_args.as_mut_ptr())
        };

        let input_type = LispObject::from_data_option(input);
        let output_type = LispObject::from_data_option(output);
        let mut plist = unsafe { Fprocess_plist(proc) };
        plist = unsafe { Fplist_put(plist, Qcall, handler) };
        plist = unsafe { Fplist_put(plist, QCtype, input_type) };
        plist = unsafe { Fplist_put(plist, Qreturn, output_type) };
        unsafe { Fset_process_plist(proc, plist) };
        // This should be safe due to the fact that we have created the process
        // ourselves
        (unsafe { EmacsPipe::with_process(proc) }, proc)
    }

    // Called from the rust worker thread to send 'content' to the lisp
    // thread, to be processed by the users filter function
    // We don't use internal write due to the fact that in the lisp -> rust
    // direction, we write the raw data bytes to the pipe
    // In the rust -> lisp direction, we write the pointer as as string. This is
    // due to the fact that in the rust -> lisp direction, the data output will be
    // encoded as a string prior to being given to our handler.
    // An example pointer of 0xffff00ff as raw bytes will contain
    // a NULL TERMINATOR segment prior to pointer completion.
    pub fn message_lisp<T: PipeData>(&mut self, content: T) -> std::io::Result<()> {
        let mut f = unsafe { File::from_raw_fd(self.out_fd) };
        let ptr = Box::into_raw(Box::new(content));
        let bin = ptr as *mut _ as usize;
        let result = f.write(bin.to_string().as_bytes()).map(|_| ());
        f.into_raw_fd();
        result
    }

    fn internal_write(&mut self, bytes: &[u8]) -> std::io::Result<()> {
        let mut f = unsafe { File::from_raw_fd(self.out_subp) };
        let result = f.write(bytes).map(|_| ());
        f.into_raw_fd();
        result
    }

    pub fn write_ptr<T: PipeData>(&mut self, ptr: *mut T) -> std::io::Result<()> {
        let bin = ptr as *mut _ as usize;
        self.internal_write(&bin.to_be_bytes())
    }

    // Called from the lisp thread, used to enqueue a message for the
    // rust worker to execute.
    pub fn message_rust_worker<T: PipeData>(&mut self, content: T) -> std::io::Result<()> {
        self.write_ptr(Box::into_raw(Box::new(content)))
    }

    pub fn read_next_ptr(&self) -> std::io::Result<usize> {
        let mut f = unsafe { File::from_raw_fd(self.in_fd) };
        let mut buffer = [0; ptr_size()];
        f.read(&mut buffer)?;
        let raw_value = usize::from_be_bytes(buffer);
        f.into_raw_fd();

        if raw_value == nullptr() {
            Err(std::io::Error::new(
                std::io::ErrorKind::ConnectionAborted,
                "nullptr",
            ))
        } else {
            Ok(raw_value)
        }
    }

    // Used by the rust worker to receive incoming data. Messages sent from
    // calls to 'message_rust_worker' are recieved by read_pend_message
    pub fn read_pend_message<T: PipeData>(&self) -> std::io::Result<T> {
        self.read_next_ptr()
            .map(|v| unsafe { *Box::from_raw(v as *mut T) })
    }

    pub fn close_stream(&mut self) -> std::io::Result<()> {
        self.internal_write(&nullptr().to_be_bytes())
    }
}

fn eprint_if_unexpected_error(err: std::io::Error) {
    // If we explicity set "ConnectionAborted" to close the stream
    // we don't want to log, as that was expected.
    if err.kind() != std::io::ErrorKind::ConnectionAborted {
        eprintln!("Async stream closed; Reason {:?}", err);
    }
}

pub fn rust_worker<
    INPUT: Send + PipeData,
    OUTPUT: Send + PipeData,
    T: 'static + Fn(INPUT) -> OUTPUT + Send,
>(
    handler: LispObject,
    fnc: T,
) -> LispObject {
    let (mut pipe, proc) = EmacsPipe::with_handler(handler, INPUT::marker(), OUTPUT::marker());
    thread::spawn(move || loop {
        match pipe.read_pend_message() {
            Ok(message) => {
                let result = fnc(message);
                if let Err(err) = pipe.message_lisp(result) {
                    eprint_if_unexpected_error(err);
                    break;
                }
            }
            Err(err) => {
                eprint_if_unexpected_error(err);
                break;
            }
        }
    });

    proc
}

fn make_return_value(ptrval: usize, option: PipeDataOption) -> LispObject {
    match option {
        PipeDataOption::STRING => {
            let content = unsafe { *Box::from_raw(ptrval as *mut String) };
            let nbytes = content.len();
            let c_content = CString::new(content).unwrap();
            // These unwraps should be 'safe', as we want to panic if we overflow
            unsafe { make_string_from_utf8(c_content.as_ptr(), nbytes.try_into().unwrap()) }
        }

        PipeDataOption::USER_DATA => {
            let content = unsafe { *Box::from_raw(ptrval as *mut UserData) };
            unsafe { make_user_ptr(content.finalizer, content.data) }
        }
    }
}

/// If 'data' is not a string, we have serious problems
/// as someone is writing to this pipe without knowing
/// how the data transfer functionality works. See below
/// comment.
#[lisp_fn]
pub fn async_handler(proc: LispObject, data: LispStringRef) -> bool {
    let plist = unsafe { Fprocess_plist(proc) };
    let orig_handler = unsafe { Fplist_get(plist, Qcall) };

    // This code may seem odd. Since we are in the same process space as
    // the lisp thread, our data transfer is not the string itself, but
    // a pointer to the string. We translate the pointer to a usize, and
    // write the string representation of that pointer over the pipe.
    // This code extracts that data, and gets us the acutal Rust String
    // object, that we then translate to a lisp object.
    let sslice = data.as_slice();
    let bin = String::from_utf8_lossy(sslice).parse::<usize>().unwrap();

    let qtype = unsafe { Fplist_get(plist, Qreturn) };
    if let Some(quoted_type) = qtype.to_data_option() {
        let retval = make_return_value(bin, quoted_type);
        let mut buffer = vec![orig_handler, proc, retval];
        unsafe { Ffuncall(3, buffer.as_mut_ptr()) };
    } else {
        // This means that someone has mishandled the
        // process plist and removed :type. Without this,
        // we cannot safely execute data transfer.
        wrong_type!(Qdata, qtype);
    }

    true
}

#[async_stream]
pub async fn async_echo(s: String) -> String {
    s
}

#[async_stream]
pub async fn async_data_echo(e: UserData) -> UserData {
    e
}

fn internal_send_message(
    pipe: &mut EmacsPipe,
    message: LispObject,
    option: PipeDataOption,
) -> bool {
    match option {
        PipeDataOption::STRING => {
            if !message.is_string() {
                wrong_type!(Qstringp, message);
            }

            let encoded_message = unsafe { encode_string_utf_8(message, Qnil, false, Qt, Qt) };
            let encoded_string: LispStringRef = encoded_message.into();
            let contents = String::from_utf8_lossy(encoded_string.as_slice());
            pipe.message_rust_worker(contents.into_owned()).is_ok()
        }
        PipeDataOption::USER_DATA => {
            if !is_user_ptr(message) {
                wrong_type!(Quser_ptrp, message);
            }

            let data_ptr = unsafe { XUSER_PTR(message) };
            let data = unsafe { *data_ptr };
            let ud = UserData::with_data_and_finalizer(data.p, data.finalizer);
            unsafe {
                (*data_ptr).p = std::ptr::null_mut();
                (*data_ptr).finalizer = None;
            };

            pipe.message_rust_worker(ud).is_ok()
        }
    }
}

#[lisp_fn]
pub fn async_send_message(proc: LispObject, message: LispObject) -> bool {
    let mut pipe = unsafe { EmacsPipe::with_process(proc) };
    let plist = unsafe { Fprocess_plist(proc) };
    let qtype = unsafe { Fplist_get(plist, QCtype) };
    if let Some(option) = qtype.to_data_option() {
        internal_send_message(&mut pipe, message, option)
    } else {
        // This means that someone has mishandled the
        // process plist and removed :type. Without this,
        // we cannot safely execute data transfer.
        wrong_type!(Qdata, qtype);
    }
}

#[lisp_fn]
pub fn async_close_stream(proc: LispObject) -> bool {
    let mut pipe = unsafe { EmacsPipe::with_process(proc) };
    pipe.close_stream().is_ok()
}

include!(concat!(env!("OUT_DIR"), "/ng_async_exports.rs"));