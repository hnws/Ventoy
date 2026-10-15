#!/bin/bash
# Runs INSIDE ventoy-centos75. Second pass for the two builds that need extra setup:
#  dmsetup64 : musl's configure test runs a dynamically linked program, which needs musl's loader
#              (/lib/ld-musl-x86_64.so.1, normally installed by musl's make install).
#  vblade_32 : gcc -m32 needs CentOS 7.5's 32-bit libgcc (libgcc-4.8.5-28.el7_5.1.i686).
set -u
tar -C / -xf /dl/libc_c75.tar
ln -sf /usr/local/musl/lib/libc.so /lib/ld-musl-x86_64.so.1
yum -y -q install libgcc-4.8.5-28.el7_5.1.i686 >/dev/null 2>&1; rpm -q libgcc.i686
V=/home/share/Ventoy; rm -rf "$V"; mkdir -p "$V"; cp -a /src/VBLADE "$V/"
mkdir "$V/dm64"; cd "$V/dm64"; tar -xzf /dl/dmsrpm/device-mapper.1.02.28.tgz; cd device-mapper.1.02.28
{ ./configure --disable-nls  --disable-selinux --disable-shared  --enable-static_link CC='gcc -specs /usr/local/musl/lib/musl-gcc.specs'
  touch include/linux/limits.h include/linux/types.h
  echo '#include <sys/mount.h>' > include/linux/fs.h
  make; } >/out/log_dmsetup64.txt 2>&1
strip --strip-all dmsetup/dmsetup.static && cp dmsetup/dmsetup.static /out/dmsetup64
cd "$V/VBLADE/vblade-master"; bash ./build.sh >/out/log_vblade.txt 2>&1; cp vblade_32 /out/ 2>/dev/null
ls -l /out | grep -v log_
