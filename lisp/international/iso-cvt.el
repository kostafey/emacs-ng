;;; iso-cvt.el --- translate ISO 8859-1 from/to various encodings -*- coding: utf-8 -*-
;; This file was formerly called gm-lingo.el.

;; Copyright (C) 1993-1998, 2000-2021 Free Software Foundation, Inc.

;; Author: Michael Gschwind <mike@vlsivie.tuwien.ac.at>
;; Keywords: tex, iso, latin, i18n

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; This lisp code is a general framework for translating various
;; representations of the same data.
;; among other things it can be used to translate TeX, HTML, and compressed
;; files to ISO 8859-1.  It can also be used to translate different charsets
;; such as IBM PC, Macintosh or HP Roman8.
;; Note that many translations use the GNU recode tool to do the actual
;; conversion.  So you might want to install that tool to get the full
;; benefit of iso-cvt.el

; TO DO:
; Cover more cases for translation.  (There is an infinite number of ways to
; represent accented characters in TeX)

;; SEE ALSO:
; If you are interested in questions related to using the ISO 8859-1
; characters set (configuring emacs, Unix, etc. to use ISO), then you
; can get the ISO 8859-1 FAQ via anonymous ftp from
; ftp.vlsivie.tuwien.ac.at in /pub/8bit/FAQ-ISO-8859-1

;;; Code:

(defvar iso-spanish-trans-tab
  '(
    ("~n" "ñ")
    ("([a-zA-Z])#" "\\1ñ")
    ("~N" "Ñ")
    ("\\([-a-zA-Z\"`]\\)\"u" "\\1ü")
    ("\\([-a-zA-Z\"`]\\)\"U" "\\1Ü")
    ("\\([-a-zA-Z]\\)'o" "\\1ó")
    ("\\([-a-zA-Z]\\)'O" "\\Ó")
    ("\\([-a-zA-Z]\\)'e" "\\1é")
    ("\\([-a-zA-Z]\\)'E" "\\1É")
    ("\\([-a-zA-Z]\\)'a" "\\1á")
    ("\\([-a-zA-Z]\\)'A" "\\1A")
    ("\\([-a-zA-Z]\\)'i" "\\1í")
    ("\\([-a-zA-Z]\\)'I" "\\1Í")
    )
  "Spanish translation table.")

(defun iso-translate-conventions (from to trans-tab)
  "Translate between FROM and TO using the translation table TRANS-TAB."
  (save-excursion
    (save-restriction
      (narrow-to-region from to)
      (goto-char from)
      (let ((work-tab trans-tab)
	    (buffer-read-only nil)
	    (case-fold-search nil))
	(while work-tab
	  (save-excursion
	    (let ((trans-this (car work-tab)))
	      (while (re-search-forward (car trans-this) nil t)
		(replace-match (car (cdr trans-this)) t nil)))
	    (setq work-tab (cdr work-tab)))))
      (point-max))))

;;;###autoload
(defun iso-spanish (from to &optional buffer)
  "Translate net conventions for Spanish to ISO 8859-1.
Translate the region between FROM and TO using the table
`iso-spanish-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
  (interactive "*r")
  (iso-translate-conventions from to iso-spanish-trans-tab))

(defvar iso-aggressive-german-trans-tab
  '(
    ("\"a" "ä")
    ("\"A" "Ä")
    ("\"o" "ö")
    ("\"O" "Ö")
    ("\"u" "ü")
    ("\"U" "Ü")
    ("\"s" "ß")
    ("\\\\3" "ß")
    )
  "German translation table.
This table uses an aggressive translation approach
and may erroneously translate too much.")

(defvar iso-conservative-german-trans-tab
  '(
    ("\\([-a-zA-Z\"`]\\)\"a" "\\1ä")
    ("\\([-a-zA-Z\"`]\\)\"A" "\\1Ä")
    ("\\([-a-zA-Z\"`]\\)\"o" "\\1ö")
    ("\\([-a-zA-Z\"`]\\)\"O" "\\1Ö")
    ("\\([-a-zA-Z\"`]\\)\"u" "\\1ü")
    ("\\([-a-zA-Z\"`]\\)\"U" "\\1Ü")
    ("\\([-a-zA-Z\"`]\\)\"s" "\\1ß")
    ("\\([-a-zA-Z\"`]\\)\\\\3" "\\1ß")
    )
  "German translation table.
This table uses a conservative translation approach
and may translate too little.")

(defvar iso-german-trans-tab iso-aggressive-german-trans-tab
  "Currently active translation table for German.")

;;;###autoload
(defun iso-german (from to &optional buffer)
 "Translate net conventions for German to ISO 8859-1.
Translate the region FROM and TO using the table
`iso-german-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-german-trans-tab))

(defvar iso-iso2tex-trans-tab
  '(
    ("ä" "{\\\\\"a}")
    ("à" "{\\\\`a}")
    ("á" "{\\\\'a}")
    ("ã" "{\\\\~a}")
    ("â" "{\\\\^a}")
    ("ë" "{\\\\\"e}")
    ("è" "{\\\\`e}")
    ("é" "{\\\\'e}")
    ("ê" "{\\\\^e}")
    ("ï" "{\\\\\"\\\\i}")
    ("ì" "{\\\\`\\\\i}")
    ("í" "{\\\\'\\\\i}")
    ("î" "{\\\\^\\\\i}")
    ("ö" "{\\\\\"o}")
    ("ò" "{\\\\`o}")
    ("ó" "{\\\\'o}")
    ("õ" "{\\\\~o}")
    ("ô" "{\\\\^o}")
    ("ü" "{\\\\\"u}")
    ("ù" "{\\\\`u}")
    ("ú" "{\\\\'u}")
    ("û" "{\\\\^u}")
    ("Ä" "{\\\\\"A}")
    ("À" "{\\\\`A}")
    ("Á" "{\\\\'A}")
    ("Ã" "{\\\\~A}")
    ("Â" "{\\\\^A}")
    ("Ë" "{\\\\\"E}")
    ("È" "{\\\\`E}")
    ("É" "{\\\\'E}")
    ("Ê" "{\\\\^E}")
    ("Ï" "{\\\\\"I}")
    ("Ì" "{\\\\`I}")
    ("Í" "{\\\\'I}")
    ("Î" "{\\\\^I}")
    ("Ö" "{\\\\\"O}")
    ("Ò" "{\\\\`O}")
    ("Ó" "{\\\\'O}")
    ("Õ" "{\\\\~O}")
    ("Ô" "{\\\\^O}")
    ("Ü" "{\\\\\"U}")
    ("Ù" "{\\\\`U}")
    ("Ú" "{\\\\'U}")
    ("Û" "{\\\\^U}")
    ("ñ" "{\\\\~n}")
    ("Ñ" "{\\\\~N}")
    ("ç" "{\\\\c c}")
    ("Ç" "{\\\\c C}")
    ("ß" "{\\\\ss}")
    ("\306" "{\\\\AE}")
    ("\346" "{\\\\ae}")
    ("\305" "{\\\\AA}")
    ("\345" "{\\\\aa}")
    ("\251" "{\\\\copyright}")
    ("£" "{\\\\pounds}")
    ("¶" "{\\\\P}")
    ("§" "{\\\\S}")
    ("¿" "{?`}")
    ("¡" "{!`}")
    )
  "Translation table for translating ISO 8859-1 characters to TeX sequences.")

;;;###autoload
(defun iso-iso2tex (from to &optional buffer)
 "Translate ISO 8859-1 characters to TeX sequences.
Translate the region between FROM and TO using the table
`iso-iso2tex-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-iso2tex-trans-tab))

(defvar iso-tex2iso-trans-tab
  '(
    ("{\\\\\"a}" "ä")
    ("{\\\\`a}" "à")
    ("{\\\\'a}" "á")
    ("{\\\\~a}" "ã")
    ("{\\\\^a}" "â")
    ("{\\\\\"e}" "ë")
    ("{\\\\`e}" "è")
    ("{\\\\'e}" "é")
    ("{\\\\^e}" "ê")
    ("{\\\\\"\\\\i}" "ï")
    ("{\\\\`\\\\i}" "ì")
    ("{\\\\'\\\\i}" "í")
    ("{\\\\^\\\\i}" "î")
    ("{\\\\\"i}" "ï")
    ("{\\\\`i}" "ì")
    ("{\\\\'i}" "í")
    ("{\\\\^i}" "î")
    ("{\\\\\"o}" "ö")
    ("{\\\\`o}" "ò")
    ("{\\\\'o}" "ó")
    ("{\\\\~o}" "õ")
    ("{\\\\^o}" "ô")
    ("{\\\\\"u}" "ü")
    ("{\\\\`u}" "ù")
    ("{\\\\'u}" "ú")
    ("{\\\\^u}" "û")
    ("{\\\\\"A}" "Ä")
    ("{\\\\`A}" "À")
    ("{\\\\'A}" "Á")
    ("{\\\\~A}" "Ã")
    ("{\\\\^A}" "Â")
    ("{\\\\\"E}" "Ë")
    ("{\\\\`E}" "È")
    ("{\\\\'E}" "É")
    ("{\\\\^E}" "Ê")
    ("{\\\\\"I}" "Ï")
    ("{\\\\`I}" "Ì")
    ("{\\\\'I}" "Í")
    ("{\\\\^I}" "Î")
    ("{\\\\\"O}" "Ö")
    ("{\\\\`O}" "Ò")
    ("{\\\\'O}" "Ó")
    ("{\\\\~O}" "Õ")
    ("{\\\\^O}" "Ô")
    ("{\\\\\"U}" "Ü")
    ("{\\\\`U}" "Ù")
    ("{\\\\'U}" "Ú")
    ("{\\\\^U}" "Û")
    ("{\\\\~n}" "ñ")
    ("{\\\\~N}" "Ñ")
    ("{\\\\c c}" "ç")
    ("{\\\\c C}" "Ç")
    ("\\\\\"a" "ä")
    ("\\\\`a" "à")
    ("\\\\'a" "á")
    ("\\\\~a" "ã")
    ("\\\\^a" "â")
    ("\\\\\"e" "ë")
    ("\\\\`e" "è")
    ("\\\\'e" "é")
    ("\\\\^e" "ê")
    ;; Discard spaces and/or one EOF after macro \i.
    ;; Converting it back will use braces.
    ("\\\\\"\\\\i *\n\n" "ï\n\n")
    ("\\\\\"\\\\i *\n?" "ï")
    ("\\\\`\\\\i *\n\n" "ì\n\n")
    ("\\\\`\\\\i *\n?" "ì")
    ("\\\\'\\\\i *\n\n" "í\n\n")
    ("\\\\'\\\\i *\n?" "í")
    ("\\\\^\\\\i *\n\n" "î\n\n")
    ("\\\\^\\\\i *\n?" "î")
    ("\\\\\"i" "ï")
    ("\\\\`i" "ì")
    ("\\\\'i" "í")
    ("\\\\^i" "î")
    ("\\\\\"o" "ö")
    ("\\\\`o" "ò")
    ("\\\\'o" "ó")
    ("\\\\~o" "õ")
    ("\\\\^o" "ô")
    ("\\\\\"u" "ü")
    ("\\\\`u" "ù")
    ("\\\\'u" "ú")
    ("\\\\^u" "û")
    ("\\\\\"A" "Ä")
    ("\\\\`A" "À")
    ("\\\\'A" "Á")
    ("\\\\~A" "Ã")
    ("\\\\^A" "Â")
    ("\\\\\"E" "Ë")
    ("\\\\`E" "È")
    ("\\\\'E" "É")
    ("\\\\^E" "Ê")
    ("\\\\\"I" "Ï")
    ("\\\\`I" "Ì")
    ("\\\\'I" "Í")
    ("\\\\^I" "Î")
    ("\\\\\"O" "Ö")
    ("\\\\`O" "Ò")
    ("\\\\'O" "Ó")
    ("\\\\~O" "Õ")
    ("\\\\^O" "Ô")
    ("\\\\\"U" "Ü")
    ("\\\\`U" "Ù")
    ("\\\\'U" "Ú")
    ("\\\\^U" "Û")
    ("\\\\~n" "ñ")
    ("\\\\~N" "Ñ")
    ("\\\\\"{a}" "ä")
    ("\\\\`{a}" "à")
    ("\\\\'{a}" "á")
    ("\\\\~{a}" "ã")
    ("\\\\^{a}" "â")
    ("\\\\\"{e}" "ë")
    ("\\\\`{e}" "è")
    ("\\\\'{e}" "é")
    ("\\\\^{e}" "ê")
    ("\\\\\"{\\\\i}" "ï")
    ("\\\\`{\\\\i}" "ì")
    ("\\\\'{\\\\i}" "í")
    ("\\\\^{\\\\i}" "î")
    ("\\\\\"{i}" "ï")
    ("\\\\`{i}" "ì")
    ("\\\\'{i}" "í")
    ("\\\\^{i}" "î")
    ("\\\\\"{o}" "ö")
    ("\\\\`{o}" "ò")
    ("\\\\'{o}" "ó")
    ("\\\\~{o}" "õ")
    ("\\\\^{o}" "ô")
    ("\\\\\"{u}" "ü")
    ("\\\\`{u}" "ù")
    ("\\\\'{u}" "ú")
    ("\\\\^{u}" "û")
    ("\\\\\"{A}" "Ä")
    ("\\\\`{A}" "À")
    ("\\\\'{A}" "Á")
    ("\\\\~{A}" "Ã")
    ("\\\\^{A}" "Â")
    ("\\\\\"{E}" "Ë")
    ("\\\\`{E}" "È")
    ("\\\\'{E}" "É")
    ("\\\\^{E}" "Ê")
    ("\\\\\"{I}" "Ï")
    ("\\\\`{I}" "Ì")
    ("\\\\'{I}" "Í")
    ("\\\\^{I}" "Î")
    ("\\\\\"{O}" "Ö")
    ("\\\\`{O}" "Ò")
    ("\\\\'{O}" "Ó")
    ("\\\\~{O}" "Õ")
    ("\\\\^{O}" "Ô")
    ("\\\\\"{U}" "Ü")
    ("\\\\`{U}" "Ù")
    ("\\\\'{U}" "Ú")
    ("\\\\^{U}" "Û")
    ("\\\\~{n}" "ñ")
    ("\\\\~{N}" "Ñ")
    ("\\\\c{c}" "ç")
    ("\\\\c{C}" "Ç")
    ("{\\\\ss}" "ß")
    ("{\\\\AE}" "\306")
    ("{\\\\ae}" "\346")
    ("{\\\\AA}" "\305")
    ("{\\\\aa}" "\345")
    ("{\\\\copyright}" "\251")
    ("\\\\copyright{}" "\251")
    ("{\\\\pounds}" "£" )
    ("{\\\\P}" "¶" )
    ("{\\\\S}" "§" )
    ("\\\\pounds{}" "£" )
    ("\\\\P{}" "¶" )
    ("\\\\S{}" "§" )
    ("{\\?`}" "¿")
    ("{!`}" "¡")
    ("\\?`" "¿")
    ("!`" "¡")
    )
  "Translation table for translating TeX sequences to ISO 8859-1 characters.
This table is not exhaustive (and due to TeX's power can never be).
It only contains commonly used sequences.")

;;;###autoload
(defun iso-tex2iso (from to &optional buffer)
 "Translate TeX sequences to ISO 8859-1 characters.
Translate the region between FROM and TO using the table
`iso-tex2iso-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-tex2iso-trans-tab))

(defvar iso-gtex2iso-trans-tab
  '(
    ("{\\\\\"a}" "ä")
    ("{\\\\`a}" "à")
    ("{\\\\'a}" "á")
    ("{\\\\~a}" "ã")
    ("{\\\\^a}" "â")
    ("{\\\\\"e}" "ë")
    ("{\\\\`e}" "è")
    ("{\\\\'e}" "é")
    ("{\\\\^e}" "ê")
    ("{\\\\\"\\\\i}" "ï")
    ("{\\\\`\\\\i}" "ì")
    ("{\\\\'\\\\i}" "í")
    ("{\\\\^\\\\i}" "î")
    ("{\\\\\"i}" "ï")
    ("{\\\\`i}" "ì")
    ("{\\\\'i}" "í")
    ("{\\\\^i}" "î")
    ("{\\\\\"o}" "ö")
    ("{\\\\`o}" "ò")
    ("{\\\\'o}" "ó")
    ("{\\\\~o}" "õ")
    ("{\\\\^o}" "ô")
    ("{\\\\\"u}" "ü")
    ("{\\\\`u}" "ù")
    ("{\\\\'u}" "ú")
    ("{\\\\^u}" "û")
    ("{\\\\\"A}" "Ä")
    ("{\\\\`A}" "À")
    ("{\\\\'A}" "Á")
    ("{\\\\~A}" "Ã")
    ("{\\\\^A}" "Â")
    ("{\\\\\"E}" "Ë")
    ("{\\\\`E}" "È")
    ("{\\\\'E}" "É")
    ("{\\\\^E}" "Ê")
    ("{\\\\\"I}" "Ï")
    ("{\\\\`I}" "Ì")
    ("{\\\\'I}" "Í")
    ("{\\\\^I}" "Î")
    ("{\\\\\"O}" "Ö")
    ("{\\\\`O}" "Ò")
    ("{\\\\'O}" "Ó")
    ("{\\\\~O}" "Õ")
    ("{\\\\^O}" "Ô")
    ("{\\\\\"U}" "Ü")
    ("{\\\\`U}" "Ù")
    ("{\\\\'U}" "Ú")
    ("{\\\\^U}" "Û")
    ("{\\\\~n}" "ñ")
    ("{\\\\~N}" "Ñ")
    ("{\\\\c c}" "ç")
    ("{\\\\c C}" "Ç")
    ("\\\\\"a" "ä")
    ("\\\\`a" "à")
    ("\\\\'a" "á")
    ("\\\\~a" "ã")
    ("\\\\^a" "â")
    ("\\\\\"e" "ë")
    ("\\\\`e" "è")
    ("\\\\'e" "é")
    ("\\\\^e" "ê")
    ("\\\\\"\\\\i" "ï")
    ("\\\\`\\\\i" "ì")
    ("\\\\'\\\\i" "í")
    ("\\\\^\\\\i" "î")
    ("\\\\\"i" "ï")
    ("\\\\`i" "ì")
    ("\\\\'i" "í")
    ("\\\\^i" "î")
    ("\\\\\"o" "ö")
    ("\\\\`o" "ò")
    ("\\\\'o" "ó")
    ("\\\\~o" "õ")
    ("\\\\^o" "ô")
    ("\\\\\"u" "ü")
    ("\\\\`u" "ù")
    ("\\\\'u" "ú")
    ("\\\\^u" "û")
    ("\\\\\"A" "Ä")
    ("\\\\`A" "À")
    ("\\\\'A" "Á")
    ("\\\\~A" "Ã")
    ("\\\\^A" "Â")
    ("\\\\\"E" "Ë")
    ("\\\\`E" "È")
    ("\\\\'E" "É")
    ("\\\\^E" "Ê")
    ("\\\\\"I" "Ï")
    ("\\\\`I" "Ì")
    ("\\\\'I" "Í")
    ("\\\\^I" "Î")
    ("\\\\\"O" "Ö")
    ("\\\\`O" "Ò")
    ("\\\\'O" "Ó")
    ("\\\\~O" "Õ")
    ("\\\\^O" "Ô")
    ("\\\\\"U" "Ü")
    ("\\\\`U" "Ù")
    ("\\\\'U" "Ú")
    ("\\\\^U" "Û")
    ("\\\\~n" "ñ")
    ("\\\\~N" "Ñ")
    ("\\\\\"{a}" "ä")
    ("\\\\`{a}" "à")
    ("\\\\'{a}" "á")
    ("\\\\~{a}" "ã")
    ("\\\\^{a}" "â")
    ("\\\\\"{e}" "ë")
    ("\\\\`{e}" "è")
    ("\\\\'{e}" "é")
    ("\\\\^{e}" "ê")
    ("\\\\\"{\\\\i}" "ï")
    ("\\\\`{\\\\i}" "ì")
    ("\\\\'{\\\\i}" "í")
    ("\\\\^{\\\\i}" "î")
    ("\\\\\"{i}" "ï")
    ("\\\\`{i}" "ì")
    ("\\\\'{i}" "í")
    ("\\\\^{i}" "î")
    ("\\\\\"{o}" "ö")
    ("\\\\`{o}" "ò")
    ("\\\\'{o}" "ó")
    ("\\\\~{o}" "õ")
    ("\\\\^{o}" "ô")
    ("\\\\\"{u}" "ü")
    ("\\\\`{u}" "ù")
    ("\\\\'{u}" "ú")
    ("\\\\^{u}" "û")
    ("\\\\\"{A}" "Ä")
    ("\\\\`{A}" "À")
    ("\\\\'{A}" "Á")
    ("\\\\~{A}" "Ã")
    ("\\\\^{A}" "Â")
    ("\\\\\"{E}" "Ë")
    ("\\\\`{E}" "È")
    ("\\\\'{E}" "É")
    ("\\\\^{E}" "Ê")
    ("\\\\\"{I}" "Ï")
    ("\\\\`{I}" "Ì")
    ("\\\\'{I}" "Í")
    ("\\\\^{I}" "Î")
    ("\\\\\"{O}" "Ö")
    ("\\\\`{O}" "Ò")
    ("\\\\'{O}" "Ó")
    ("\\\\~{O}" "Õ")
    ("\\\\^{O}" "Ô")
    ("\\\\\"{U}" "Ü")
    ("\\\\`{U}" "Ù")
    ("\\\\'{U}" "Ú")
    ("\\\\^{U}" "Û")
    ("\\\\~{n}" "ñ")
    ("\\\\~{N}" "Ñ")
    ("\\\\c{c}" "ç")
    ("\\\\c{C}" "Ç")
    ("{\\\\ss}" "ß")
    ("{\\\\AE}" "\306")
    ("{\\\\ae}" "\346")
    ("{\\\\AA}" "\305")
    ("{\\\\aa}" "\345")
    ("{\\\\copyright}" "\251")
    ("\\\\copyright{}" "\251")
    ("{\\\\pounds}" "£" )
    ("{\\\\P}" "¶" )
    ("{\\\\S}" "§" )
    ("\\\\pounds{}" "£" )
    ("\\\\P{}" "¶" )
    ("\\\\S{}" "§" )
    ("?`" "¿")
    ("!`" "¡")
    ("{?`}" "¿")
    ("{!`}" "¡")
    ("\"a" "ä")
    ("\"A" "Ä")
    ("\"o" "ö")
    ("\"O" "Ö")
    ("\"u" "ü")
    ("\"U" "Ü")
    ("\"s" "ß")
    ("\\\\3" "ß")
    )
  "Translation table for translating German TeX sequences to ISO 8859-1.
This table is not exhaustive (and due to TeX's power can never be).
It only contains commonly used sequences.")

(defvar iso-iso2gtex-trans-tab
  '(
    ("ä" "\"a")
    ("à" "{\\\\`a}")
    ("á" "{\\\\'a}")
    ("ã" "{\\\\~a}")
    ("â" "{\\\\^a}")
    ("ë" "{\\\\\"e}")
    ("è" "{\\\\`e}")
    ("é" "{\\\\'e}")
    ("ê" "{\\\\^e}")
    ("ï" "{\\\\\"\\\\i}")
    ("ì" "{\\\\`\\\\i}")
    ("í" "{\\\\'\\\\i}")
    ("î" "{\\\\^\\\\i}")
    ("ö" "\"o")
    ("ò" "{\\\\`o}")
    ("ó" "{\\\\'o}")
    ("õ" "{\\\\~o}")
    ("ô" "{\\\\^o}")
    ("ü" "\"u")
    ("ù" "{\\\\`u}")
    ("ú" "{\\\\'u}")
    ("û" "{\\\\^u}")
    ("Ä" "\"A")
    ("À" "{\\\\`A}")
    ("Á" "{\\\\'A}")
    ("Ã" "{\\\\~A}")
    ("Â" "{\\\\^A}")
    ("Ë" "{\\\\\"E}")
    ("È" "{\\\\`E}")
    ("É" "{\\\\'E}")
    ("Ê" "{\\\\^E}")
    ("Ï" "{\\\\\"I}")
    ("Ì" "{\\\\`I}")
    ("Í" "{\\\\'I}")
    ("Î" "{\\\\^I}")
    ("Ö" "\"O")
    ("Ò" "{\\\\`O}")
    ("Ó" "{\\\\'O}")
    ("Õ" "{\\\\~O}")
    ("Ô" "{\\\\^O}")
    ("Ü" "\"U")
    ("Ù" "{\\\\`U}")
    ("Ú" "{\\\\'U}")
    ("Û" "{\\\\^U}")
    ("ñ" "{\\\\~n}")
    ("Ñ" "{\\\\~N}")
    ("ç" "{\\\\c c}")
    ("Ç" "{\\\\c C}")
    ("ß" "\"s")
    ("\306" "{\\\\AE}")
    ("\346" "{\\\\ae}")
    ("\305" "{\\\\AA}")
    ("\345" "{\\\\aa}")
    ("\251" "{\\\\copyright}")
    ("£" "{\\\\pounds}")
    ("¶" "{\\\\P}")
    ("§" "{\\\\S}")
    ("¿" "{?`}")
    ("¡" "{!`}")
    )
  "Translation table for translating ISO 8859-1 characters to German TeX.")

;;;###autoload
(defun iso-gtex2iso (from to &optional buffer)
 "Translate German TeX sequences to ISO 8859-1 characters.
Translate the region between FROM and TO using the table
`iso-gtex2iso-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-gtex2iso-trans-tab))

;;;###autoload
(defun iso-iso2gtex (from to &optional buffer)
 "Translate ISO 8859-1 characters to German TeX sequences.
Translate the region between FROM and TO using the table
`iso-iso2gtex-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-iso2gtex-trans-tab))

(defvar iso-iso2duden-trans-tab
  '(("ä" "ae")
    ("Ä" "Ae")
    ("ö" "oe")
    ("Ö" "Oe")
    ("ü" "ue")
    ("Ü" "Ue")
    ("ß" "ss"))
    "Translation table for translating ISO 8859-1 characters to Duden sequences.")

;;;###autoload
(defun iso-iso2duden (from to &optional buffer)
 "Translate ISO 8859-1 characters to Duden sequences.
Translate the region between FROM and TO using the table
`iso-iso2duden-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-iso2duden-trans-tab))

(defvar iso-iso2sgml-trans-tab
  '(("À" "&Agrave;")
    ("Á" "&Aacute;")
    ("Â" "&Acirc;")
    ("Ã" "&Atilde;")
    ("Ä" "&Auml;")
    ("Å" "&Aring;")
    ("Æ" "&AElig;")
    ("Ç" "&Ccedil;")
    ("È" "&Egrave;")
    ("É" "&Eacute;")
    ("Ê" "&Ecirc;")
    ("Ë" "&Euml;")
    ("Ì" "&Igrave;")
    ("Í" "&Iacute;")
    ("Î" "&Icirc;")
    ("Ï" "&Iuml;")
    ("Ð" "&ETH;")
    ("Ñ" "&Ntilde;")
    ("Ò" "&Ograve;")
    ("Ó" "&Oacute;")
    ("Ô" "&Ocirc;")
    ("Õ" "&Otilde;")
    ("Ö" "&Ouml;")
    ("Ø" "&Oslash;")
    ("Ù" "&Ugrave;")
    ("Ú" "&Uacute;")
    ("Û" "&Ucirc;")
    ("Ü" "&Uuml;")
    ("Ý" "&Yacute;")
    ("Þ" "&THORN;")
    ("ß" "&szlig;")
    ("à" "&agrave;")
    ("á" "&aacute;")
    ("â" "&acirc;")
    ("ã" "&atilde;")
    ("ä" "&auml;")
    ("å" "&aring;")
    ("æ" "&aelig;")
    ("ç" "&ccedil;")
    ("è" "&egrave;")
    ("é" "&eacute;")
    ("ê" "&ecirc;")
    ("ë" "&euml;")
    ("ì" "&igrave;")
    ("í" "&iacute;")
    ("î" "&icirc;")
    ("ï" "&iuml;")
    ("ð" "&eth;")
    ("ñ" "&ntilde;")
    ("ò" "&ograve;")
    ("ó" "&oacute;")
    ("ô" "&ocirc;")
    ("õ" "&otilde;")
    ("ö" "&ouml;")
    ("ø" "&oslash;")
    ("ù" "&ugrave;")
    ("ú" "&uacute;")
    ("û" "&ucirc;")
    ("ü" "&uuml;")
    ("ý" "&yacute;")
    ("þ" "&thorn;")
    ("ÿ" "&yuml;")))

(defvar iso-sgml2iso-trans-tab
  '(("&Agrave;" "À")
    ("&Aacute;" "Á")
    ("&Acirc;" "Â")
    ("&Atilde;" "Ã")
    ("&Auml;" "Ä")
    ("&Aring;" "Å")
    ("&AElig;" "Æ")
    ("&Ccedil;" "Ç")
    ("&Egrave;" "È")
    ("&Eacute;" "É")
    ("&Ecirc;" "Ê")
    ("&Euml;" "Ë")
    ("&Igrave;" "Ì")
    ("&Iacute;" "Í")
    ("&Icirc;" "Î")
    ("&Iuml;" "Ï")
    ("&ETH;" "Ð")
    ("&Ntilde;" "Ñ")
    ("&Ograve;" "Ò")
    ("&Oacute;" "Ó")
    ("&Ocirc;" "Ô")
    ("&Otilde;" "Õ")
    ("&Ouml;" "Ö")
    ("&Oslash;" "Ø")
    ("&Ugrave;" "Ù")
    ("&Uacute;" "Ú")
    ("&Ucirc;" "Û")
    ("&Uuml;" "Ü")
    ("&Yacute;" "Ý")
    ("&THORN;" "Þ")
    ("&szlig;" "ß")
    ("&agrave;" "à")
    ("&aacute;" "á")
    ("&acirc;" "â")
    ("&atilde;" "ã")
    ("&auml;" "ä")
    ("&aring;" "å")
    ("&aelig;" "æ")
    ("&ccedil;" "ç")
    ("&egrave;" "è")
    ("&eacute;" "é")
    ("&ecirc;" "ê")
    ("&euml;" "ë")
    ("&igrave;" "ì")
    ("&iacute;" "í")
    ("&icirc;" "î")
    ("&iuml;" "ï")
    ("&eth;" "ð")
    ("&ntilde;" "ñ")
    ("&nbsp;" " ")
    ("&ograve;" "ò")
    ("&oacute;" "ó")
    ("&ocirc;" "ô")
    ("&otilde;" "õ")
    ("&ouml;" "ö")
    ("&oslash;" "ø")
    ("&ugrave;" "ù")
    ("&uacute;" "ú")
    ("&ucirc;" "û")
    ("&uuml;" "ü")
    ("&yacute;" "ý")
    ("&thorn;" "þ")
    ("&yuml;" "ÿ")))

;;;###autoload
(defun iso-iso2sgml (from to &optional buffer)
 "Translate ISO 8859-1 characters in the region to SGML entities.
Use entities from \"ISO 8879:1986//ENTITIES Added Latin 1//EN\".
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-iso2sgml-trans-tab))

;;;###autoload
(defun iso-sgml2iso (from to &optional buffer)
 "Translate SGML entities in the region to ISO 8859-1 characters.
Use entities from \"ISO 8879:1986//ENTITIES Added Latin 1//EN\".
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-sgml2iso-trans-tab))

;;;###autoload
(defun iso-cvt-read-only (&rest ignore)
  "Warn that format is read-only."
  (interactive)
  (error "This format is read-only; specify another format for writing"))

;;;###autoload
(defun iso-cvt-write-only (&rest ignore)
  "Warn that format is write-only."
  (interactive)
  (error "This format is write-only"))

;;;###autoload
(defun iso-cvt-define-menu ()
  "Add submenus to the File menu, to convert to and from various formats."
  (interactive)

  (let ((load-as-menu-map (make-sparse-keymap "Load As..."))
	(insert-as-menu-map (make-sparse-keymap "Insert As..."))
	(write-as-menu-map (make-sparse-keymap "Write As..."))
	(translate-to-menu-map (make-sparse-keymap "Translate to..."))
	(translate-from-menu-map (make-sparse-keymap "Translate from..."))
	(menu menu-bar-file-menu))

    (define-key menu [load-as-separator] '("--"))

    (define-key menu [load-as] '("Load As..." . iso-cvt-load-as))
    (fset 'iso-cvt-load-as load-as-menu-map)

    ;;(define-key menu [insert-as] '("Insert As..." . iso-cvt-insert-as))
    (fset 'iso-cvt-insert-as insert-as-menu-map)

    (define-key menu [write-as] '("Write As..." . iso-cvt-write-as))
    (fset 'iso-cvt-write-as write-as-menu-map)

    (define-key menu [translate-separator] '("--"))

    (define-key menu [translate-to] '("Translate to..." . iso-cvt-translate-to))
    (fset 'iso-cvt-translate-to translate-to-menu-map)

    (define-key menu [translate-from] '("Translate from..." . iso-cvt-translate-from))
    (fset 'iso-cvt-translate-from translate-from-menu-map)

    (dolist (file-type (reverse format-alist))
      (let ((name (car file-type))
	    (str-name (cadr file-type)))
	(if (stringp str-name)
	    (progn
	      (define-key load-as-menu-map (vector name)
		(cons str-name
		      `(lambda (file)
			 (interactive ,(format "FFind file (as %s): " name))
			 (format-find-file file ',name))))
	      (define-key insert-as-menu-map (vector name)
		(cons str-name
		      `(lambda (file)
			 (interactive (format "FInsert file (as %s): " ,name))
			 (format-insert-file file ',name))))
	      (define-key write-as-menu-map (vector name)
		(cons str-name
		      `(lambda (file)
			 (interactive (format "FWrite file (as %s): " ,name))
			 (format-write-file file ',name))))
	      (define-key translate-to-menu-map (vector name)
		(cons str-name
		      `(lambda ()
			 (interactive)
			 (format-encode-buffer ',name))))
	      (define-key translate-from-menu-map (vector name)
		(cons str-name
		      `(lambda ()
			 (interactive)
			 (format-decode-buffer ',name))))))))))

(provide 'iso-cvt)

;;; iso-cvt.el ends here
