" Vim syntax file
" Language: CLC-INTERCAL, C-INTERCAL, INTERCAL-1972
" Maintainer: Claudio Calvelli <compiler (whirlpool) intercal.org.uk>
" Last change: 2023-04-25

if exists("b:current_syntax")
  finish
endif

syn case ignore

syn match intercalLabel "([1-9]\d*)"
syn match intercalDoPlease "DO\|PLEASE"
"syn match intercalNegate "NOT\|N'T"
syn region intercalComment start="\(DO\|PLEASE\)[ \t\n]*N[O']T" skip="\(DO\|PLEASE\)[ \t\n]*N[O']T" matchgroup=intercalDoPlease end="DO\|PLEASE" matchgroup=intercalLabel end="([1-9]\d*)"

" normal statements
syn match intercalStmt "<-"
syn match intercalStmt "ABSTAIN[ \t\n]*FROM"
syn match intercalStmt "CASE"
syn match intercalStmt "CLOSE[ \t\n]*OFF[ \t\n]*BETWEEN"
    syn match intercalStmt "AND\([ \t\n]*DIVERT[ \t\n]*VIA\)\?"
syn match intercalStmt "COME[ \t\n]*FROM"
syn match intercalStmt "CONVERT"
syn match intercalStmt "CREATE"
syn match intercalStmt "DESTROY"
syn match intercalStmt "ENROL"
    syn match intercalStmt "TO\([ \n\t]*LEARN\)\?"
syn match intercalStmt "ENSLAVE"
syn match intercalStmt "FINISH[ \t\n]*LECTURE"
syn match intercalStmt "FORGET"
syn match intercalStmt "FREE"
syn match intercalStmt "GIVE[ \t\n]*UP"
syn match intercalStmt "GRADUATES"
syn match intercalStmt "IGNORE"
syn match intercalStmt "LEARNS"
syn match intercalStmt "MAKE"
    syn match intercalStmt "NO[ \t\n]*LONGER"
    syn match intercalStmt "BELONG[ \t\n]*TO"
syn match intercalStmt "NEXT"
syn match intercalStmt "READ[ \t\n]*OUT"
syn match intercalStmt "REINSTATE"
syn match intercalStmt "REMEMBER"
syn match intercalStmt "REOPEN[ \t\n]*BETWEEN"
syn match intercalStmt "RESUME"
syn match intercalStmt "RETRIEVE"
syn match intercalStmt "SMUGGLE"
syn match intercalStmt "STASH"
syn match intercalStmt "STEAL"
syn match intercalStmt "STUDY"
    syn match intercalStmt "IN\([ \t\n]*CLASS\)\?"
syn match intercalStmt "SWAP"
syn match intercalStmt "TRICKLE"
    syn match intercalStmt "AFTER"
syn match intercalStmt "TRUSS"
syn match intercalStmt "WHILE"
syn match intercalStmt "WRITE[ \t\n]IN"

" quantum modifiers
syn match intercalQuantum "WHILE[ \n\t]*\(ABSTAINING[ \n\t]*FROM\|REINSTATING\)[ \t\n]*\(IT\|THEM\)"
syn match intercalQuantum "WHILE[ \n\t]*CONTINUING[ \n\t]*\(TO[ \t\n]*RUN\|IT\)"
syn match intercalQuantum "WHILE[ \n\t]*\(IGNORING\|REMEMBERING\)[ \t\n]*\(IT\|THEM\)"
syn match intercalQuantum "WHILE[ \n\t]*LEAVING[ \n\t]*IT[ \t\n]*\(BELONGING\|CLOSED\|FREE\|IN[\ \t]*SLAVERY\|NOT[\ \t]*BELONGING\|OPEN\|TRICKLING[ \n\t]*DOWN\|TRUSSED[ \n\t]*UP\|UNCHANGED\)"
syn match intercalQuantum "WHILE[ \n\t]*LEAVING[ \n\t]*THEM[ \n\t]*UNCHANGED"
syn match intercalQuantum "WHILE[ \n\t]*NOT[ \t\n]*\(ASSIGNING[ \t\n]*TO\|CREATING\|DESTROYING\|LEARNING\|STUDYING\)[ \t\n]*IT"
syn match intercalQuantum "WHILE[ \n\t]*NOT[ \t\n]*\(COMING\|NEXTING\)\([ \n\t]*FROM[ \t\n]*THERE\)\?"
syn match intercalQuantum "WHILE[ \n\t]*NOT[ \t\n]*\(CASING\|ENROLLING\|FORGETTING\|RESUMING\)"
syn match intercalQuantum "WHILE[ \n\t]*NOT[ \t\n]*\(IGNORING\|REMEMBERING\|RETRIEVING\|SMUGGLING\|STASHING\|STEALING\)[ \t\n]*\(IT\|THEM\)"
"no quantum READ OUT yet  syn match intercalQuantum "WHILE[ \n\t]*NOT[ \n\t]*READING[ \n\t]*\(IT|THEM\)\([ \n\t]*OUT\)\?"
syn match intercalQuantum "WHILE[ \n\t]*NOT[ \n\t]*WRITING[ \n\t]*\(IT\|THEM\)\([ \n\t]*IN\)\?"
syn match intercalQuantum "WHILE[ \n\t]*REMAINING[ \n\t]*A[ \n\t]*STUDENT"
syn match intercalQuantum "WHILE[ \n\t]*REMEMBERING"

" gerunds
syn match intercalGerund "ABSTAINING[ \t\n]*FROM"
syn match intercalGerund "CALCULATING"
syn match intercalGerund "CASING"
syn match intercalGerund "CLOSING[ \t\n]*OFF"
syn match intercalGerund "COMING[ \t\n]*FROM"
syn match intercalGerund "COMMENTING"
syn match intercalGerund "COMMENTS"
syn match intercalGerund "COMPILER[ \t\n]*BUG"
syn match intercalGerund "CONVERTING"
syn match intercalGerund "CREATING"
syn match intercalGerund "CREATION"
syn match intercalGerund "DESTROYING"
syn match intercalGerund "DESTRUCTION"
syn match intercalGerund "DIVERTING"
syn match intercalGerund "ENROLLING"
syn match intercalGerund "ENSLAVING"
syn match intercalGerund "EVOLUTION"
syn match intercalGerund "FINISHING[ \t\n]*LECTURE"
syn match intercalGerund "FORGETTING"
syn match intercalGerund "FREEING"
syn match intercalGerund "GIVING[ \t\n]*UP"
syn match intercalGerund "GRADUATING"
syn match intercalGerund "IGNORING"
syn match intercalGerund "LEARNING"
syn match intercalGerund "LOOPING"
syn match intercalGerund "MAKING[ \n\t]*BELONG"
syn match intercalGerund "MAKING[ \n\t]*NOT[ \n\t]*BELONG"
syn match intercalGerund "NEXTING"
syn match intercalGerund "QUANTUM[ \t\n]*COMPUTING"
syn match intercalGerund "READING[ \t\n]*OUT"
syn match intercalGerund "REINSTATING"
syn match intercalGerund "REMEMBERING"
syn match intercalGerund "REOPENING"
syn match intercalGerund "RESUMING"
syn match intercalGerund "RETRIEVING"
syn match intercalGerund "SMUGGLING"
syn match intercalGerund "STASHING"
syn match intercalGerund "STEALING"
syn match intercalGerund "STUDYING"
syn match intercalGerund "SWAPPING"
syn match intercalGerund "TRICKLING[ \t\n]DOWN"
syn match intercalGerund "TRUSSING[ \t\n]UP"
syn match intercalGerund "WHILING"
syn match intercalGerund "WRITING[ \t\n]IN"

" other keywords
syn match intercalKW "AFTER"
syn match intercalKW "AS"
syn match intercalKW "AT"
syn match intercalKW "DOWN"
syn match intercalKW "ESAC"
syn match intercalKW "FROM"
syn match intercalKW "ON"
syn match intercalKW "THEN"
syn match intercalKW "UP"

syn match intercalRegister "[123456789$]*[.,:;@][1-9]\d*"
syn match intercalRegister "SUB"
syn match intercalRegister "BY"
syn match intercalConstant "#\d\d*"
syn match intercalConstant "?[_A-Z][_A-Z0-9]*"
syn match intercalConstant ",#\d\d*\([ \n\t]*#\d\d*\)*,"
" INTERCAL unary operators, being single letters, need to be distinguished
" carefully...
syn match intercalOperator "[.,:;@#'"][V¥&][V¥&]*\|[V¥&][V¥&]*[.,:;@#]\|[-+~¢'"]"
syn match intercalOperator "=\d\d*"
syn match intercalOperator "=\*"

" The default methods for highlighting.  Can be overridden later
hi def link intercalDoPlease    Type
hi def link intercalLabel       Label
hi def link intercalStmt        Statement
hi def link intercalQuantum     Statement
hi def link intercalKW          Statement
hi def link intercalRegister    Identifier
hi def link intercalConstant    Constant
hi def link intercalGerund      Constant
hi def link intercalOperator    Operator
hi def link intercalComment     Comment
hi def link intercalNegate      Type

let b:current_syntax = "intercal"

" vim: ts=2
