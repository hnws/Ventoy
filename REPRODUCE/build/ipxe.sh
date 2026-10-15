#!/bin/bash
# Runs INSIDE a Ventoy build container. Reproduces IPXE/buildipxe.sh + src/build.sh at the
# original path, but builds bin/ipxe.lkrn directly instead of bin/ipxe.iso + loop mount
# (the ISO's ipxe.krn is a copy of bin/ipxe.lkrn).
# IPXE_BUILD_ID / IPXE_BUILD_TIMESTAMP override the random build ID and the `date +%s`
# timestamp that iPXE's Makefile.housekeeping links in.
#   /src : Ventoy checkout (ro)   /out
set -euo pipefail
rpm -q xz-devel perl >/dev/null 2>&1 || yum -y -q install xz-devel perl >/dev/null
V=/home/share/Ventoy
rm -rf "$V"; mkdir -p "$V"
cp -a /src/IPXE "$V/"
cd "$V/IPXE"
# --- IPXE/buildipxe.sh ---
rm -rf ipxe-3fe683e
tar -xf ipxe_org_code/ipxe-3fe683e.tar.bz2 -C ./
rm -rf ./ipxe-3fe683e/src/bin
rm -rf ./ipxe-3fe683e/src/drivers
/bin/cp -a ipxe_mod_code/ipxe-3fe683e ./
cd ipxe-3fe683e/src
# HYPOTHESIS_DIR: overlay files to test a hypothesis about unpublished changes (not Ventoy source).
[ -z "${HYPOTHESIS_DIR:-}" ] || cp -a "$HYPOTHESIS_DIR"/. ./
# --- src/build.sh: make -e -k -j 8 bin/ipxe.iso BIOS_MODE=BIOS ---
gcc --version | head -1
extra=()
[ -z "${IPXE_BUILD_ID:-}" ] || extra+=("BUILD_ID_CMD=echo $IPXE_BUILD_ID")
[ -z "${IPXE_BUILD_TIMESTAMP:-}" ] || extra+=("BUILD_TIMESTAMP=$IPXE_BUILD_TIMESTAMP")
make -e -k -j"$(nproc)" bin/ipxe.lkrn BIOS_MODE=BIOS ${extra[@]+"${extra[@]}"} >/out/ipxe_make.log 2>&1 || { tail -20 /out/ipxe_make.log; exit 1; }
cp -f bin/ipxe.lkrn /out/ipxe.krn
cp -f bin/ipxe.lkrn.tmp bin/ipxe.lkrn.zinfo /out/ 2>/dev/null || true
ls -l /out/ipxe.krn
