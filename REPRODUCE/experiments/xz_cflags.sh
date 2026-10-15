#!/bin/bash
# Runs INSIDE ventoy-centos75. CFLAGS (CFS) x configure-option (OPTS, comma = space) sweep for static-musl XZ 5.2.5.
tar -C / -xf /dl/libc_c75.tar; ln -sf /usr/local/musl/lib/libc.so /lib/ld-musl-x86_64.so.1
B=/home/share/Ventoy/XZ; mkdir -p $B
for cf in ${CFS:-"-O3"}; do for opt in ${OPTS:-""}; do opt=${opt//,/ }
    rm -rf $B/xz-5.2.5; tar -xzf /dl/xz-5.2.5.tar.gz -C $B; cd $B/xz-5.2.5
    ./configure CC='gcc -specs /usr/local/musl/lib/musl-gcc.specs' CFLAGS="$cf" LDFLAGS=-static $opt >/dev/null 2>&1 && make -j8 >/dev/null 2>&1
    strip --strip-all src/xz/xz; echo "[CFLAGS=$cf opt=$opt] $(sha256sum < src/xz/xz | cut -c1-12) $(stat -c %s src/xz/xz)"
done; done
