This directory contains bonus things which weren't originally distributed
with CLC-INTERCAL but could be of interest to somebody.  Files will be added
here as they surface, and this README will have a short description of each.

`intercal.ddsh` is a dd/sh program (i.e. a script for a restricted shell
using only "dd" as external command, and optionally "rm" to tidy up)
implementing the unary and binary INTERCAL operators.  Usage:

```
    sh intercal.ddsh
```

Then write into the program simple operations, like `#V1` or `#3~#2` - see
comments in the script for more information. EOF to stop, or just kill it.
See comments in the script for more information;

The `os` directory contains a draft design document for an INTERCAL operating
system which was written in 1999. No further information about this is available
at this time, but there is a Makefile which will generate a PDF if you have
`pdflatex` installed, or maybe a PostScript file if you have the right things.

The "game" file is the README file for a planned, but never implemented,
INTERCAL game package. Somebody may wish to implement it, so here it is.

The "vim" directory contains syntax-highlighting files for Vim. See the README
in there for further information.

