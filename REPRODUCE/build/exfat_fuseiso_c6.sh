#!/bin/bash
# Runs INSIDE ventoy-centos6-i386 (32-bit CentOS 6 userland, under linux32).
# The release's i386 builds embed /root/ExFAT/LIBFUSE and /root/LIBFUSE, so build there.
#   JOBS="exfat"   : ExFAT/buidlibfuse.sh + buidexfat.sh at /root/ExFAT -> i386 mkexfatfs, mount.exfat-fuse
#   JOBS="fuseiso" : musl 1.2.1, then FUSEISO/build_libfuse.sh + build.sh with FUSEISO's contents at /root
#   /src : Ventoy checkout (ro)   /dl : downloads (REPRODUCE/cache)   /out : results
set -euo pipefail
SRC=/src; OUT=/out; JOBS=${JOBS:-exfat}
uname -m; rpm -q gcc glibc automake
run() { echo "=== $2"; ( cd "$1" && bash "./$2" ) >"$OUT/log_$2.txt" 2>&1 || echo "    FAILED (see log)"; }
case " $JOBS " in *" exfat "*)
    W=/root/ExFAT; rm -rf "$W"; cp -a "$SRC/ExFAT" "$W"
    cp /dl/exfat-1.3.0.zip "$W/"
    cp /dl/mirrors-libfuse-fuse-2.9.9.zip "$W/"
    run "$W" buidlibfuse.sh
    run "$W" buidexfat.sh
    mkdir -p "$OUT/exfat_i386"; cp -a "$W"/EXFAT/shared/. "$OUT/exfat_i386/" || true ;;
esac
case " $JOBS " in *" fuseiso "*)
    t=$(mktemp -d); tar -C "$t" -xf /dl/musl-1.2.1.tar.gz
    ( cd "$t"/musl-1.2.1 && ./configure --prefix=/usr/local/musl >/dev/null && make -j"$(nproc)" >/dev/null && make install >/dev/null ); rm -rf "$t"
    # FUSEISO scripts use ../ExFAT/<zip>, so with FUSEISO's files in /root that is /ExFAT.
    mkdir -p /ExFAT; cp /dl/mirrors-libfuse-fuse-2.9.9.zip /ExFAT/
    cp -a "$SRC"/FUSEISO/. /root/
    run /root build_libfuse.sh
    run /root build.sh
    cp -a /root/vtoy_fuse_iso_32 "$OUT/" || true ;;
esac
ls -lR "$OUT" | grep -v '^total'
