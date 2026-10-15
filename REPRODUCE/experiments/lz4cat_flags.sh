#!/bin/bash
# Runs INSIDE ventoy-centos75. Tries compiler/flag variants of LZIP/buildlz4.txt for smallz4cat.c
# and prints the SHA-256 of each stripped result. /src (ro) /dl (ro)
tar -C / -xf /dl/libc_c75.tar
tar -C /opt -xf /dl/aarch64--uclibc--stable-2020.08-1.tar.bz2
tar -C /opt -xf /dl/mips64el-linux-musl-gcc730.tar.bz2; mv /opt/output /opt/mips64el-linux-musl-gcc730
export PATH=$PATH:/opt/aarch64--uclibc--stable-2020.08-1/bin:/opt/mips64el-linux-musl-gcc730/bin
mkdir -p /home/share/Ventoy/LZIP && cd /home/share/Ventoy/LZIP && cp /src/LZIP/smallz4cat.c .
try() { n=$1; s=$2; shift 2; rm -f t; "$@" smallz4cat.c -o t 2>/dev/null && $s --strip-all t && echo "$n $(sha256sum < t | cut -c1-12) $(stat -c %s t)" || echo "$n FAILED"; }
for o in "-D_FILE_OFFSET_BITS=64" ""; do
  try "aa64[$o]" aarch64-buildroot-linux-uclibc-strip aarch64-buildroot-linux-uclibc-gcc -Os -static $o
  try "m64e[$o]" mips64el-linux-musl-strip mips64el-linux-musl-gcc -mips64r2 -mabi=64 -static -Os $o
  try "64diet[$o]" strip /opt/diet64/bin/diet -Os gcc $o
  try "64musl[$o]" strip gcc -specs /usr/local/musl/lib/musl-gcc.specs -static -Os $o
  try "64musl-O2[$o]" strip gcc -specs /usr/local/musl/lib/musl-gcc.specs -static -O2 $o
done
