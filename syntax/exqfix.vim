if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

" syntax highlight

syntax match ex_qf_help #^".*# contains=ex_qf_help_key
syntax match ex_qf_help_key '^" \S\+:'hs=s+2,he=e-1 contained contains=ex_qf_help_comma
syntax match ex_qf_help_comma ':' contained

syntax region ex_qf_filename start="^[^"][^:]*" end=":" oneline
syntax match ex_qf_linenr '\d\+:'

hi default link ex_qf_help Comment
hi default link ex_qf_help_key Label
hi default link ex_qf_help_comma Special
" hi default link ex_qf_filename Directory
" hi default link ex_qf_linenr Special

syn match	qfFileName	"^[^|]*" nextgroup=qfSeparator
syn match	qfSeparator	"|" nextgroup=qfLineNr contained
syn match	qfLineNr	"[^|]*" contained contains=qfError
syn match	qfError		"error" contained

" The default highlighting.
hi def link qfFileName	Directory
hi def link qfLineNr	LineNr
hi def link qfError	Error

let b:current_syntax = "exqfix"

" vim:ts=4:sw=4:sts=4 et fdm=marker:
