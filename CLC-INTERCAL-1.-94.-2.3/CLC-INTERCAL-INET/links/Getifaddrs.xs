/* Obtain a list of interfaces directly from the operating system
 *
 * This file is part of CLC-INTERCAL
 *
 * Copyright (C) 2023 Claudio Calvelli, all rights reserved
 *
 * CLC-INTERCAL is copyrighted software. However, permission to use, modify,
 * and distribute it is granted provided that the conditions set out in the
 * licence agreement are met. See files README and COPYING in the distribution.
 *
 * PERVERSION CLC-INTERCAL/INET links/Getifaddrs.xs 1.-94.-2.3
 */

#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <errno.h>
#include <sys/types.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <netinet/in.h>

#ifdef __cplusplus
}
#endif

#define FL_LOOPBACK   0x01
#define FL_BROADCAST  0x02
#define FL_MULTICAST  0x04
#define FL_UP         0x80

#define IT_NAME       0
#define IT_INDEX      1
#define IT_BROADCAST  2
#define IT_ADDRESS4   3
#define IT_ADDRESS6   4
#define IT_FLAGS      5

#define SC_NODE       0x01
#define SC_LINK       0x02
#define SC_SITE       0x05
#define SC_ORG        0x08
#define SC_GLOBAL     0x0e

MODULE = Language::INTERCAL::INET::Interface	PACKAGE = Language::INTERCAL::INET::Interface

int
iflags_loopback()
    PROTOTYPE:
    CODE:
	RETVAL = FL_LOOPBACK;
    OUTPUT:
	RETVAL

int
iflags_broadcast()
    PROTOTYPE:
    CODE:
	RETVAL = FL_BROADCAST;
    OUTPUT:
	RETVAL

int
iflags_multicast()
    PROTOTYPE:
    CODE:
	RETVAL = FL_MULTICAST;
    OUTPUT:
	RETVAL

int
iflags_up()
    PROTOTYPE:
    CODE:
	RETVAL = FL_UP;
    OUTPUT:
	RETVAL

int
ifitem_name()
    PROTOTYPE:
    CODE:
	RETVAL = IT_NAME;
    OUTPUT:
	RETVAL

int
ifitem_index()
    PROTOTYPE:
    CODE:
	RETVAL = IT_INDEX;
    OUTPUT:
	RETVAL

int
ifitem_broadcast()
    PROTOTYPE:
    CODE:
	RETVAL = IT_BROADCAST;
    OUTPUT:
	RETVAL

int
ifitem_address4()
    PROTOTYPE:
    CODE:
	RETVAL = IT_ADDRESS4;
    OUTPUT:
	RETVAL

int
ifitem_address6()
    PROTOTYPE:
    CODE:
	RETVAL = IT_ADDRESS6;
    OUTPUT:
	RETVAL

int
ifitem_flags()
    PROTOTYPE:
    CODE:
	RETVAL = IT_FLAGS;
    OUTPUT:
	RETVAL

int
ifscope_node()
    PROTOTYPE:
    CODE:
	RETVAL = SC_NODE;
    OUTPUT:
	RETVAL

int
ifscope_link()
    PROTOTYPE:
    CODE:
	RETVAL = SC_LINK;
    OUTPUT:
	RETVAL

int
ifscope_site()
    PROTOTYPE:
    CODE:
	RETVAL = SC_SITE;
    OUTPUT:
	RETVAL

int
ifscope_org()
    PROTOTYPE:
    CODE:
	RETVAL = SC_ORG;
    OUTPUT:
	RETVAL

int
ifscope_global()
    PROTOTYPE:
    CODE:
	RETVAL = SC_GLOBAL;
    OUTPUT:
	RETVAL

void
interface_list(flags = FL_UP)
	int flags
    PREINIT:
	struct ifaddrs * addrs = NULL;
	int nret = 0;
    PPCODE:
	if (getifaddrs(&addrs) != -1) {
	    struct ifaddrs * run;
	    AV * list = newAV();
	    int tf = 0;
	    /* translate our flags to the system's flags */
	    if (flags & FL_LOOPBACK) tf |= IFF_LOOPBACK;
	    if (flags & FL_BROADCAST) tf |= IFF_BROADCAST;
	    if (flags & FL_MULTICAST) tf |= IFF_MULTICAST;
	    if (flags & FL_UP) tf |= IFF_UP;
	    /* now scan the list and create results from it */
	    for (run = addrs; run; run = run->ifa_next) {
		AV * elem = NULL, * bc, * a4, * a6;
		int i, namelen;
		if ((run->ifa_flags & tf) != tf) continue;
		if (! run->ifa_addr) continue;
		if (run->ifa_addr->sa_family != AF_INET &&
		    run->ifa_addr->sa_family != AF_INET6)
			continue;
		/* have we already seen this interface? (yes I could use a HV) */
		namelen = strlen(run->ifa_name);
		for (i = 0; i < nret; i++) {
		    AV * arr;
		    SV ** p;
		    const char * s;
		    STRLEN l;
		    p = av_fetch(list, i, 0);
		    if (! p) continue;
		    arr = (AV *)SvRV(*p);
		    p = av_fetch(arr, 0, 0);
		    if (! p) continue;
		    s = SvPV_const(*p, l);
		    if (l != namelen) continue;
		    if (strncmp(run->ifa_name, s, l) != 0) continue;
		    elem = arr;
		    break;
		}
		if (elem) {
		    SV ** p;
		    p = av_fetch(elem, IT_BROADCAST, 0);
		    if (! p) continue;
		    bc = (AV *)SvRV(*p);
		    p = av_fetch(elem, IT_ADDRESS4, 0);
		    if (! p) continue;
		    a4 = (AV *)SvRV(*p);
		    p = av_fetch(elem, IT_ADDRESS6, 0);
		    if (! p) continue;
		    a6 = (AV *)SvRV(*p);
		} else {
		    int fv;
		    elem = newAV();
		    av_extend(elem, 6);
		    av_store(elem, IT_NAME, newSVpvn(run->ifa_name, namelen));
		    av_store(elem, IT_INDEX, newSVnv(if_nametoindex(run->ifa_name)));
		    bc = newAV();
		    av_store(elem, IT_BROADCAST, newRV_noinc((SV *)bc));
		    a4 = newAV();
		    av_store(elem, IT_ADDRESS4, newRV_noinc((SV *)a4));
		    a6 = newAV();
		    av_store(elem, IT_ADDRESS6, newRV_noinc((SV *)a6));
		    fv = 0;
		    if (run->ifa_flags & IFF_LOOPBACK) fv |= FL_LOOPBACK;
		    if (run->ifa_flags & IFF_BROADCAST) fv |= FL_BROADCAST;
		    if (run->ifa_flags & IFF_MULTICAST) fv |= FL_MULTICAST;
		    if (run->ifa_flags & IFF_UP) fv |= FL_UP;
		    av_store(elem, IT_FLAGS, newSVnv(fv));
		    av_push(list, newRV_noinc((SV *)elem));
		    nret++;
		}
		if (run->ifa_addr->sa_family == AF_INET) {
		    SV * a;
		    if (run->ifa_flags & IFF_BROADCAST) {
			a = newSVpvn((char *)&((struct sockaddr_in *)run->ifa_broadaddr)->sin_addr, 4);
			av_push(bc, a);
		    }
		    a = newSVpvn((char *)&((struct sockaddr_in *)run->ifa_addr)->sin_addr, 4);
		    av_push(a4, a);
		}
		if (run->ifa_addr->sa_family == AF_INET6) {
		    SV * a;
		    a = newSVpvn((char *)&((struct sockaddr_in6 *)run->ifa_addr)->sin6_addr, 16);
		    av_push(a6, a);
		}
	    }
	    freeifaddrs(addrs);
	    if (nret > 0) {
		int i;
		/* there's no doubt a better way to do this */
		EXTEND(SP, nret);
		for (i = 0; i < nret; i++) {
		    SV * elem;
		    elem = av_shift(list);
		    PUSHs(sv_2mortal(elem));
		}
		av_undef(list);
	    }
	    /* we can have a non-error empty result list so make sure
	     * errno is 0 here */
	    errno = 0;
	}
	XSRETURN(nret);

int
address_scope(addr)
	SV * addr
    PROTOTYPE: $
    PREINIT:
	STRLEN l;
	const unsigned char * a = (const unsigned char *)SvPVbyte(addr, l);
    CODE:
	if (l == sizeof(struct in6_addr)) {
	    if ((a[0] & 0xe0) == 0x20) {
		/* 2000::/3 */
		RETVAL = SC_GLOBAL;
	    } else if (a[0] == 0xff) {
		/* multicast */
		RETVAL = a[1] & 0x0f;
	    } else if (a[0] == 0xfe) {
		/* link local or site local */
		if ((a[1] & 0xc0) == 0x80)
		    RETVAL = SC_LINK;
		else
		    RETVAL = SC_SITE;
	    } else if (a[0] == 0) {
		int i = 0;
		while (i < sizeof(struct in6_addr) - 1 && a[i] == 0) i++;
		if (i == sizeof(struct in6_addr)) {
		    RETVAL = SC_GLOBAL;
		} else if (i == sizeof(struct in6_addr) - 1 && a[i] == 1) {
		    RETVAL = SC_NODE;
		} else {
		    RETVAL = SC_GLOBAL;
		}
	    } else {
	    }
	} else {
	    errno = EINVAL;
	    XSRETURN_UNDEF;
	}
    OUTPUT:
	RETVAL

int
address_multicast6(addr)
	SV * addr
    PROTOTYPE: $
    PREINIT:
	STRLEN l;
	const unsigned char * a = (const unsigned char *)SvPVbyte(addr, l);
    CODE:
	if (l == sizeof(struct in6_addr)) {
	    // XXX we'll need to check for more things but this will do for now
	    RETVAL = a[0] == 0xff;
	} else {
	    errno = EINVAL;
	    XSRETURN_UNDEF;
	}
    OUTPUT:
	RETVAL

