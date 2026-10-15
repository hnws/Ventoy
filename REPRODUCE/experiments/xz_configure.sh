#!/bin/bash
# Runs INSIDE ventoy-centos75. Tries plausible static-musl configurations of XZ Utils 5.2.5 (no
# recipe in the Ventoy repo) and prints the SHA-256 of each stripped src/xz/xz.
tar -C / -xf /dl/libc_c75.tar
ln -sf /usr/local/musl/lib/libc.so /lib/ld-musl-x86_64.so.1
B=/home/share/Ventoy/XZ; mkdir -p $B
for v in "A|--disable-shared|-static" "B|--disable-shared --disable-nls|-static" "C||-static" "D|--disable-shared --enable-static|-static" "E|--disable-nls|-static"; do
    IFS='|' read n opts ld <<<"$v"
    rm -rf $B/xz-5.2.5; tar -xzf /dl/xz-5.2.5.tar.gz -C $B; cd $B/xz-5.2.5
    ./configure CC='gcc -specs /usr/local/musl/lib/musl-gcc.specs' LDFLAGS="$ld" $opts >/dev/null 2>&1 && make -j8 >/dev/null 2>&1
    f=src/xz/xz; [ -f src/xz/.libs/xz ] && f=src/xz/.libs/xz
    strip --strip-all $f 2>/dev/null; echo "$n [$opts $ld] $(sha256sum < $f | cut -c1-12) $(stat -c %s $f) $(file -b $f | cut -d, -f5)"
done
