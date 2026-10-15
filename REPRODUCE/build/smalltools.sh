#!/bin/bash
# Runs INSIDE the CentOS 7.5 container (Dockerfile.centos75, adapted from ventoy/Ventoy#3752).
# Installs dietlibc 0.34, musl 1.2.1 and the cross toolchains where
# DOC/BuildVentoyFromSource.txt puts them, then runs Ventoy's own build scripts,
# unmodified, in a writable copy of the tree:
#   vtoycli/build.sh  Vlnk/build.sh  VtoyTool/build.sh  FUSEISO/build_libfuse.sh + build.sh
#   /src : Ventoy checkout (read-only)   /dl : tarballs   /out : results
set -euo pipefail
SRC=/src; DL=/dl; OUT=/out
rpm -q gcc

# PREBUILT_LIBC=<tar>: unpack dietlibc+musl built elsewhere (e.g. by the CentOS 7.5 gcc)
# instead of building them with this container's gcc. SAVE_LIBC=<tar>: save them after building.
if [ -n "${PREBUILT_LIBC:-}" ]; then
    tar -C / -xf "$PREBUILT_LIBC"
else
    t=$(mktemp -d); cp "$DL/dietlibc-0.34.tar.xz" "$t/"
    ( cd "$t" && bash "$SRC/DOC/installdietlibc.sh" >/dev/null 2>&1 ); rm -rf "$t"
    t=$(mktemp -d); tar -C "$t" -xf "$DL/musl-1.2.1.tar.gz"
    ( cd "$t"/musl-1.2.1 && ./configure --prefix=/usr/local/musl >/dev/null && make -j"$(nproc)" >/dev/null && make install >/dev/null ); rm -rf "$t"
    [ -z "${SAVE_LIBC:-}" ] || tar -C / -cf "$SAVE_LIBC" opt/diet32 opt/diet64 usr/local/musl
fi
tar -C /opt -xf "$DL/aarch64--uclibc--stable-2020.08-1.tar.bz2"
tar -C /opt -xf "$DL/mips64el-linux-musl-gcc730.tar.bz2"; mv /opt/output /opt/mips64el-linux-musl-gcc730
export PATH=$PATH:/opt/aarch64--uclibc--stable-2020.08-1/bin:/opt/mips64el-linux-musl-gcc730/bin

# Build at the original path: libfuse embeds its install prefix (FUSEISO/LIBFUSE/bin/fusermount).
W=/home/share/Ventoy; rm -rf "$W"; mkdir -p "$W"
cp -a "$SRC/vtoycli" "$SRC/Vlnk" "$SRC/VtoyTool" "$SRC/FUSEISO" "$W/"
mkdir -p "$W/INSTALL/tool/"{i386,x86_64,aarch64,mips64el} "$W/ExFAT"
cp "$DL/libfuse-fuse-2.9.9.zip" "$W/ExFAT/"

run() { echo "=== $1"; ( cd "$W/$(dirname "$1")" && bash "./$(basename "$1")" ) >"$OUT/log_$(echo "$1" | tr / _).txt" 2>&1 || echo "    FAILED (see log)"; }
run vtoycli/build.sh
run Vlnk/build.sh
run VtoyTool/build.sh
run FUSEISO/build_libfuse.sh
run FUSEISO/build.sh

mkdir -p "$OUT/tool" "$OUT/vtoytool00"
for a in i386 x86_64 aarch64 mips64el; do
    for t in vtoycli vlnk; do [ -f "$W/INSTALL/tool/$a/$t" ] && cp "$W/INSTALL/tool/$a/$t" "$OUT/tool/${t}_$a"; done
done
cp -a "$W"/VtoyTool/vtoytool/00/. "$OUT/vtoytool00/" 2>/dev/null || true
cp -a "$W"/FUSEISO/vtoy_fuse_iso_64 "$OUT/" 2>/dev/null || true
for f in "$OUT"/tool/*_x86_64 "$OUT"/vtoytool00/vtoytool_64 "$OUT"/vtoy_fuse_iso_64; do
    [ -f "$f" ] && printf '%-40s %s\n' "${f#$OUT/}" "$(readelf -p .comment "$f" 2>/dev/null | sed -n 's/^ *\[ *[0-9]*\] *//p' | tr '\n' ' ')"
done
rm -rf "$W"
