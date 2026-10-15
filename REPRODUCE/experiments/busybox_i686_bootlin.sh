#!/bin/bash
# Runs INSIDE ventoy-centos75: Bootlin x86-i686 uClibc 2020.08-1 toolchain at /opt, then build_bb.sh.
tar -C /opt -xf /dl/x86-i686--uclibc--stable-2020.08-1.tar.bz2
export PATH=$PATH:/opt/x86-i686--uclibc--stable-2020.08-1/bin
sh /build.sh
