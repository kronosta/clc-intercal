# Installation instructions for CLC-INTERCAL 1.-94.-2.1 (bundle)

The installation of CLC-INTERCAL is a straightforward process, unlike
actually writing INTERCAL programs; the dependencies however could be
tricky in some environments.  For a successful install, first refer to
one or more of the following subsections:

* [All dependencies](#tldr)
* [Required dependency](#required-dependency)
* [Dependencies required for IPv6 support](#highly-recommended-dependencies-for-ipv6-support)
* [Optional dependency to enable the line mode interface](#runtime-dependency-for-the-line-interface)
* [Optional dependency to enable the full-screen text interface](#runtime-dependency-for-the-curses-interface)
* [Optional dependency to enable the X interface](#runtime-dependency-for-the-x-interface)

Once the dependencies are installed, just use the standard Perl sequence:

```
  perl Makefile.PL
  make
  make test
  make install
```

If running in a sandboxed build environment, or if network is not available,
expect some test failure for the INET package; these tests can be disabled
by creating two empty files first:

```
  touch CLC-INTERCAL-INET/t/.skip-network CLC-INTERCAL-INET/t/.skip-localhost
  make test
```

## TL;DR

This is the executive summary to install all required and optional
dependencies; for a separate description for mandatory, highly recommended
and optional dependencies, see the rest of this document.

### Debian, Ubuntu, etc:

```
  apt install libsocket6-perl libio-socket-inet6-perl
  apt install libterm-readline-gnu-perl libcurses-perl libgtk3-perl
```

### Gentoo:

```
  emerge -a dev-perl/{Socket6,IO-Socket-INET6,Term-ReadLine-Gnu,Curses,Gtk3}
```

### FreeBSD:

```
  pkg install p5-Socket6 p5-IO-Socket-INET6
  pkg install p5-Term-ReadLine-Gnu p5-Curses p5-Gtk3
```

### NerBSD

```
  pkg_add p5-Socket6 p5-IO-Socket-INET6 p5-Term-ReadLine-Gnu p5-Curses
```

### OpenBSD:

```
  pkg_add p5-Socket6 p5-IO-Socket-INET6 p5-Term-ReadLine-Gnu p5-Curses p5-Gtk3
```

### Other:

The Makefile.PL will indicate whether any necessary dependency is missing, and
this will need to be installed before continuing.  How to do that will depend
on the syste,

If the INET extension indicates that it could not find a module to list the
network interface, try installing Net::Interface from source: obtain these
from: [CPAN](https://metacpan.org/pod/Net::Interface) and then apply
[this small Makefile.PL
patch](https://uilebheist.srht.site/patches/Net-Interface-Makefile.patch)

Then build and install the module according to its own instructions.



## Highly recommended dependencies for IPv6 support:

The perl moduless Socket6 and IO::Socket::INET7

### Debian, Ubuntu etc:

```
  apt install libsocket6-perl libio-socket-inet6-perl
```

### Gentoo:

```
  emerge -a dev-perl/{Socket6,IO-Socket-INET6}
```

### FreeBSD:

```
  pkg install p5-Socket6 p5-IO-Socket-INET6
```

### NetBSD, OpenBSD:

```
  pkg_add p5-Socket6 p5-IO-Socket-INET6
```


## Runtime dependency for the Line interface:

The perl module Term::ReadLine::Gnu

### Debian, Ubuntu, etc:

```
  apt install libterm-readline-gnu-perl
```

### Gentoo:

```
  emerge -a dev-perl/Term-ReadLine-Gnu
```

### FreeBSD:

```
  pkg install p5-Term-ReadLine-Gnu
```

### NetBSD, OpenBSD:

```
  pkg_add p5-Term-ReadLine-Gnu
```



## Runtime dependency for the Curses interface:

The perl module Curses

### Debian, Ubuntu, etc:

```
  apt install libcurses-perl
```

### Gentoo:

```
  emerge -a dev-perl/Curses
```

### FreeBSD:

```
  pkg install p5-Curses
```

### NetBSD, OpenBSD:

```
  pkg_add p5-Curses
```

## Runtime dependency for the X interface:

The perl module Gtk3 (or Gtk2)

### Debian, Ubuntu, etc:

```
  apt install libgtk3-perl
```

### Gentoo:

```
  emerge -a dev-perl/Gtk3
```

### FreeBSD:

```
  pkg install p5-Gtk3
```

### NetBSD:

We haven't found a pre-built package, and at present we have not tested the X
interface on NetBSD.

### OpenBSD:

```
  pkg_add p5-Gtk3
```

