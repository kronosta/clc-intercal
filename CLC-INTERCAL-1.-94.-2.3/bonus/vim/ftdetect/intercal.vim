" Vim filetype detection file
" Language:     CLC-INTERCAL, C-INTERCAL, INTERCAL-1972
" Author:       Claudio Calvelli <compiler (whirlpool) intercal.org.uk>
" Copyright:    Copyright (c) 2023 Claudio Calvelli
" Licence:      BSD, see details in the distribution
"
" This plugin attempts to determine if a file with suffix ending in "i"
" is an INTERCAL program; it doesn't attempt to replicate the full suffix
" detection employed by "sick", it assumes that all known extensions
" have been loaded

if &compatible || v:version < 603
    finish
endif

" all INTERCAL programs end with something like .(other letters)i
" and must contain some form of DO or PLEASE not too far from the top;
" we also recognise a single standard comment "PLEASE NOTE"
au BufNewFile,BufRead *.*i
  \ if join(getline(1, '$')) =~? 'please\s*note\|\(do\|please\).*\(do\|please\).*\(do\|please\).*\(do\|please\)' |
  \   set filetype=intercal |
  \ endif

" sickrc files are much easier to detect
au BufNewFile,BufRead *.sickrc,.sickrc,/etc/sick/*
  \ set filetype=sickrc

