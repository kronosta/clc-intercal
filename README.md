This is version 1.-94.-2.3. SourceHut is up now, so this repo is no longer really necessary, but I'll keep it around as a mirror. 

PLEASE NOTE that I do not plan on regularly updating this to the newest version.

Make sure to extract the .tar.gz file. Installing from the folder will not work as it has some subfolder naming issues detailed below; the folder is just here so everyone can view the code without having it installed on their system (the SourceHut repository has a few differences from the actual installation).

By [this thread](https://stackoverflow.com/questions/57478817/creating-files-with-reserved-names), it appears that WSL actually does not have a restriction on naming a folder `aux`. I think maybe the reason it didn't work for me is because I used the Windows version of 7-Zip to extract the .tar.gz file instead of Linux command line tools. The following text may apply if typing `tar -xzvf clc-intercal.tar.gz` into the shell on WSL doesn't work:

> You will need to unzip the .tar.gz file into Linux to actually use it (the `_aux` directory is supposed to be named `aux` but Windows doesn't allow that so I can't do that here; this messes up the Makefile process). Even WSL doesn't work, you'll need to use a virtual machine to build this on Windows. If your computer can't handle full Linux on a virtual machine, try running Ubuntu Server on a virtual machine, where the requirements are very low.

# No character limit version
CLC-INTERCAL unfortunately has a built-in, human-reachable limit of 65535 characters in a program. After toiling away for two days, I have the no character limit version. It doesn't work as a tar file because the default .io files aren't sufficient to compile programs.

## How to install
- Install CLC-INTERCAL 1.-94.-2.3.
- Type `perl -E 'print "@INC";'` into your shell to find a list of directories that the Language::INTERCAL files could be in.
- Look for the `Language/INTERCAL` directory with inside each of them. It should have a lot of files and several directories inside (there may be a few extra directories named Language/INTERCAL in @INC)
- Replace the directory you found with the `No Character Limit/Language/INTERCAL` directory in this repo. 
- Make sure `Language/INTERCAL.pm` is intact in @INC (it's the exact same as the INTERCAL.pm provided in this repo)

## Preparation
Before you can run this version of CLC-INTERCAL, you need to prepare a few compilers. This is because this variant changes the format used for .io files. When `iacc.io` or `postpre.io` are read from the `Language/INTERCAL/Include` directory or the current directory, they automatically get treated as the original format so that everything else can be made. This means you shouldn't create those in the current directory as that will mess things up.

- Copy `iacc.iacc` (not `iacc.io`) into your current directory and rename it (for this section, we'll name it `iaccncl.iacc`)
- Run `sick iaccncl.iacc` in your shell. This creates a compiler compiler in the new format named `iaccncl.io`. Since it read from `iacc.io` and `postpre.io` only, it doesn't throw an error.
- Copy `sick.iacc` (not `sick.io`) into your current directory and rename it (for this section, we'll name it `sickncl.iacc`)
- Run `sick -piaccncl sickncl.iacc` in your shell. This creates the sick compiler in the new format.
- You can do this same process with any other compiler, extension, assembler, etc. by copying it, renaming it, and running `sick -piaccncl whatever.iacc`
- You can now compile any program, but instead of using `sick program.i` you have to run `sick -pcompiler program.i`.
  - For example, if you have a standard CLC-INTERCAL program named `hello-world.i`, to compile it you can run `sick -psickncl hello-world.i`. You can also of course use `sick -psickncl -lRun hello-world.i` to run it immediately instead of compiling.
