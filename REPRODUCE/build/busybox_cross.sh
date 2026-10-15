#!/bin/bash
# Runs INSIDE ventoy-centos75: unpacks the Bootlin aarch64 and ventoy mips64el musl toolchains
# (paths as in Ventoy's makefiles), then runs build_bb.sh with the environment given.
tar -C /opt -xf /dl/aarch64--uclibc--stable-2020.08-1.tar.bz2
tar -C /opt -xf /dl/mips64el-linux-musl-gcc730.tar.bz2; mv /opt/output /opt/mips64el-linux-musl-gcc730
export PATH=$PATH:/opt/aarch64--uclibc--stable-2020.08-1/bin:/opt/mips64el-linux-musl-gcc730/bin
sh /build.sh
