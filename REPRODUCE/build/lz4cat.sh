#!/bin/bash
# Runs INSIDE ventoy-centos75. Rebuilds the three lz4cat binaries with the flags that matched in §11.
tar -C / -xf /dl/libc_c75.tar
tar -C /opt -xf /dl/aarch64--uclibc--stable-2020.08-1.tar.bz2
tar -C /opt -xf /dl/mips64el-linux-musl-gcc730.tar.bz2; mv /opt/output /opt/mips64el-linux-musl-gcc730
export PATH=$PATH:/opt/aarch64--uclibc--stable-2020.08-1/bin:/opt/mips64el-linux-musl-gcc730/bin
mkdir -p /home/share/Ventoy/LZIP && cd /home/share/Ventoy/LZIP && cp /src/LZIP/smallz4cat.c .
gcc -specs /usr/local/musl/lib/musl-gcc.specs -static smallz4cat.c -o lz4cat64 && strip --strip-all lz4cat64
aarch64-buildroot-linux-uclibc-gcc -Os -static smallz4cat.c -o lz4cataa64 && aarch64-buildroot-linux-uclibc-strip --strip-all lz4cataa64
mips64el-linux-musl-gcc -mabi=64 -O2 -static -D_FILE_OFFSET_BITS=64 smallz4cat.c -o lz4catm64e && mips64el-linux-musl-strip --strip-all lz4catm64e
cp lz4cat64 lz4cataa64 lz4catm64e /out/
