This is version 1.-94.-2.3. SourceHut is up now, so this repo is no longer really necessary, but I'll keep it around as a mirror. 

PLEASE NOTE that I do not plan on regularly updating this to the newest version.

Make sure to extract the .tar.gz file. Installing from the folder will not work as it has some subfolder naming issues detailed below; the folder is just here so everyone can view the code without having it installed on their system (the SourceHut repository has a few differences from the actual installation).

By [this thread](https://stackoverflow.com/questions/57478817/creating-files-with-reserved-names), it appears that WSL actually does not have a restriction on naming a folder `aux`. I think maybe the reason it didn't work for me is because I used the Windows version of 7-Zip to extract the .tar.gz file instead of Linux command line tools. The following text may apply if typing `tar -xzvf clc-intercal.tar.gz` into the shell on WSL doesn't work:

> You will need to unzip the .tar.gz file into Linux to actually use it (the `_aux` directory is supposed to be named `aux` but Windows doesn't allow that so I can't do that here; this messes up the Makefile process). Even WSL doesn't work, you'll need to use a virtual machine to build this on Windows. If your computer can't handle full Linux on a virtual machine, try running Ubuntu Server on a virtual machine, where the requirements are very low.
