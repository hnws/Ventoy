#!/bin/bash
# Runs INSIDE a CentOS 7 container (ventoy-centos75 = gcc-4.8.5-28).
# Runs Ventoy's own scripts, unmodified, at the original path /home/share/Ventoy:
#   ExFAT/buidlibfuse.sh + buidexfat.sh (DOC 4.9)         : x86_64 mkexfatfs, mount.exfat-fuse
#   FUSEISO/build_libfuse_aarch64.sh + build_aarch64.sh : vtoy_fuse_iso_aa64 (Bootlin uclibc 2020.08-1)
#   /src : Ventoy checkout (ro)   /dl : downloads (REPRODUCE/cache)   /out : results
# JOBS: space-separated subset of "exfat fuseaa64" (default both).
set -euo pipefail
SRC=/src; OUT=/out
JOBS=${JOBS:-"exfat fuseaa64"}
rpm -q gcc; locale
W=/home/share/Ventoy; rm -rf "$W"; mkdir -p "$W"
cp -a "$SRC/ExFAT" "$SRC/FUSEISO" "$W/"
cp /dl/libfuse-fuse-2.9.9.zip /dl/exfat-1.3.0.zip "$W/ExFAT/"
# LIBFUSE_MIRROR=1: also supply the zip as mirrors-libfuse-fuse-2.9.9.zip (unpacks to libfuse/), which the scripts prefer.
[ -z "${LIBFUSE_MIRROR:-}" ] || cp /dl/mirrors-libfuse-fuse-2.9.9.zip "$W/ExFAT/"
run() { echo "=== $1"; ( cd "$W/$(dirname "$1")" && bash "./$(basename "$1")" ) >"$OUT/log_$(echo "$1" | tr / _).txt" 2>&1 || echo "    FAILED (see log)"; }
case " $JOBS " in *" exfat "*)
    run ExFAT/buidlibfuse.sh
    run ExFAT/buidexfat.sh
    mkdir -p "$OUT/exfat_x86_64"; cp -a "$W"/ExFAT/EXFAT/shared/. "$OUT/exfat_x86_64/" || true ;;
esac
case " $JOBS " in *" fuseaa64 "*)
    tar -C /opt -xf /dl/aarch64--uclibc--stable-2020.08-1.tar.bz2
    export PATH=$PATH:/opt/aarch64--uclibc--stable-2020.08-1/bin
    run FUSEISO/build_libfuse_aarch64.sh
    run FUSEISO/build_aarch64.sh
    cp -a "$W"/FUSEISO/vtoy_fuse_iso_aa64 "$OUT/" || true ;;
esac
ls -lR "$OUT" | grep -v '^total'
