" Vim syntax file
" Language: sickrc configuration files
" Maintainer: Claudio Calvelli <compiler (whirlpool) intercal.org.uk>
" Last change: 2023-04-27

if exists("b:current_syntax")
  finish
endif

syn case ignore

syn match sickrcVerbStart "\<I[ \t\n]*CAN\(\s*NOT\|'\s*T\)\?"
syn match sickrcVerbStart "\<I[ \t\n]*DO\(NOT\|\s*N'\s*T\)"
syn match sickrcVerbStart "\<WHEN[ \t\n]*I[ \t\n]*IMITATE"
syn region sickrcComment start="\(DO\|PLEASE\)[ \t\n]*NOT" skip="\(DO\|PLEASE\)[ \t\n]*NOT" matchgroup=sickrcVerbStart end="I[ \t\n]*CAN\|I[ \t\n]*DON'T\|WHEN[ \t\n]*I[ \t\n]*IMITATE"
syn match sickrcStmt "\<I[ \t\n]*CAN\(\s*NOT\|'\s*T\)\?"
syn match sickrcStmt "\<I[ \t\n]*DO\(NOT\|\s*N'\s*T\)"
syn match sickrcStmt "\<WHEN[ \t\n]*I[ \t\n]*IMITATE\>"
syn match sickrcStmt "\<BLURT\>"
syn match sickrcStmt "\<CALCULATE\>"
syn match sickrcStmt "\<DIM\>"
syn match sickrcStmt "\<DRAW\>"
syn match sickrcStmt "\<EMBOLDEN\>"
syn match sickrcStmt "\<FRAME\>"
syn match sickrcStmt "\<GLUE\>"
syn match sickrcStmt "\<ITALICISE\>"
syn match sickrcStmt "\<OPERATE\>"
syn match sickrcStmt "\<PAINT\>"
syn match sickrcStmt "\<POINT\>"
syn match sickrcStmt "\<PRODUCE\>"
syn match sickrcStmt "\<READ\>"
syn match sickrcStmt "\<REVERSE\>"
syn match sickrcStmt "\<SCAN\>"
syn match sickrcStmt "\<SPEAK\>"
syn match sickrcStmt "\<THROW\>"
syn match sickrcStmt "\<UNDERLINE\>"
syn match sickrcStmt "\<UNDERSTAND\>"
syn match sickrcStmt "\<WRITE\>"
syn match sickrcOperator "\<AS\>"
syn match sickrcOperator "\<IGNORING\>"
syn match sickrcOperator "\<IN\>"
syn match sickrcOperator "\<RETRYING\>"
syn match sickrcOperator "\<THROWING\>"
syn match sickrcOperator "\<TO\>"
syn match sickrcOperator "\<WHEN\s*USING\>"
syn match sickrcOperator "\<WITH\>"
syn match sickrcOperator "\<WITH\(OUT\)\?\s*THE\s*MOUSE\>"
syn match sickrcPriority "#\d\d*\>"

" The default methods for highlighting.  Can be overridden later
hi def link sickrcVerbStart   Statement
hi def link sickrcStmt        Statement
hi def link sickrcOperator    Operator
hi def link sickrcComment     Comment
hi def link sickrcPriority    Label

let b:current_syntax = "sickrc"

" vim: ts=2
