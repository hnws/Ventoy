#!/bin/bash
# Runs INSIDE a Ventoy build container. Builds wimboot 2.7.3 (Ventoy-modified) like
# wimboot/build.sh does (make in wimboot-2.7.3/src), at the original path, and keeps the
# two files Ventoy ships: wimboot.x86_64 and wimboot.i386.efi (uncompressed).
#   /src : Ventoy checkout (ro)   /out
set -euo pipefail
V=/home/share/Ventoy
rm -rf "$V"; mkdir -p "$V"
cp -a /src/wimboot "$V/"
cd "$V/wimboot/wimboot-2.7.3/src"
# prefix.S/startup.S/callback.S are missing from Ventoy's repo (wimboot's own .gitignore has
# "*.s", which also matches "*.S" on a case-insensitive filesystem). UPSTREAM_S=<dir> supplies
# them from upstream wimboot v2.7.3.
[ -z "${UPSTREAM_S:-}" ] || cp "$UPSTREAM_S"/prefix.S "$UPSTREAM_S"/startup.S "$UPSTREAM_S"/callback.S .
gcc --version | head -1
# efireloc (a host tool run on the built ELF) links against libbfd: needs binutils-devel.
rpm -q binutils-devel zlib-devel >/dev/null 2>&1 || yum -y -q install binutils-devel zlib-devel >/dev/null
rpm -q binutils binutils-devel
make clean >/dev/null 2>&1 || true
# Ventoy runs plain `make -j 16` (target "all", which also wants gcab for wimboot.cab).
# Build the two shipped files through the same Makefile rules.
make -j"$(nproc)" wimboot.x86_64 wimboot.i386.efi >/out/wimboot_make.log 2>&1 || { tail -20 /out/wimboot_make.log; exit 1; }
cp -f wimboot.x86_64 wimboot.i386.efi /out/
ls -l /out/wimboot.x86_64 /out/wimboot.i386.efi
