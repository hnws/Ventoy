#!/bin/bash
# Runs INSIDE ventoy-centos75. DOC 4.15-4.18: xzminidec{32,64,64_musl,aa64,m64e} from
# Ventoy2Disk/Ventoy2Disk/xz-embedded-20130513/userspace with Ventoy's ventoy_makefile*.
#   /src : Ventoy (ro)  /dl : smalltools tarballs  /out
#   VROOT : build root (default /home/share/Ventoy; -ggdb3 puts the path in the build ID)
set -euo pipefail
VROOT=${VROOT:-/home/share/Ventoy}
tar -C / -xf /dl/libc_c75.tar      # dietlibc 0.34 + musl 1.2.1 built by CentOS 7.5 gcc
tar -C /opt -xf /dl/aarch64--uclibc--stable-2020.08-1.tar.bz2
tar -C /opt -xf /dl/mips64el-linux-musl-gcc730.tar.bz2; mv /opt/output /opt/mips64el-linux-musl-gcc730
mkdir -p "$VROOT/Ventoy2Disk"; cp -a /src/Ventoy2Disk/Ventoy2Disk "$VROOT/Ventoy2Disk/"
cd "$VROOT/Ventoy2Disk/Ventoy2Disk/xz-embedded-20130513/userspace"
for v in "ventoy_makefile 32 strip" "ventoy_makefile64 64 strip" "ventoy_makefile64_musl 64_musl strip" \
         "ventoy_makefileaa64 aa64 /opt/aarch64--uclibc--stable-2020.08-1/bin/aarch64-linux-strip" \
         "ventoy_makefilem64e m64e /opt/mips64el-linux-musl-gcc730/bin/mips64el-linux-musl-strip"; do
    set -- $v
    rm -f *.o xzminidec
    make -f "$1" xzminidec >/out/log_$2.txt 2>&1 || { echo "$1 failed"; continue; }
    cp xzminidec /out/xzminidec${2}_unstripped
    $3 --strip-all xzminidec; cp xzminidec /out/xzminidec$2
done
ls -l /out
