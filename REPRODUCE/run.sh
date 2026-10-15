#!/bin/sh
# Rebuild Ventoy's prebuilt binaries and check them against git and the release.
# See REPRODUCE/README.md for what each step proves.
#
# Usage: sh REPRODUCE/run.sh STEP...     (or: sh REPRODUCE/run.sh all)
#   fetch      download everything in inputs.txt (SHA-256 checked) and unpack toolchains
#   images     build the Docker images (repo Dockerfile + REPRODUCE/docker/*)
#   release    download ventoy-$VER-linux.tar.gz (checked against the release's sha256.txt)
#              and unpack it, its VTOYEFI image and the initramfs cpios into REPRODUCE/ref
#   smalltools vtoycli, vlnk, vtoytool 00, vtoy_fuse_iso_64      (also makes cache/libc_c75.tar)
#   grub       GRUB x64/ia32/aa64 + mips64el, with the unpublished bitmap_scale.c edit (EDIT=0: without)
#   ipxe       ipxe.krn with the unpublished printf (EDIT=0: without)
#   wimboot    wimboot.x86_64/.i386.efi with the three missing upstream .S files
#   exfat      exFAT tools x86_64/i386, vtoy_fuse_iso_32/aa64
#   xzminidec  xzminidec* from the b63ce2a tree
#   livecd     LiveCD/GRUB/bootx64.efi from the a29bdfb tree
#   linuxgui   V2DServer, Plugson (current and 4df793e trees), VentoyGUI, Ventoy2Disk.gtk2/gtk3
#   tools      lunzip, zstdcat, dmsetup, vblade, lz4cat
#   busybox    BusyBox 1.32.0 applets and full builds
#   edk2       EFI apps and EfiFs drivers (EDK2/ci/run-all.sh)
#   verify     compare everything (REPRODUCE/verify.py)
#
# Needs on the host: docker, curl, git, python3, patch, xz, unzip, mtools (mcopy), cpio,
# sha256sum. Outputs go to REPRODUCE/out, downloads to REPRODUCE/cache, references to REPRODUCE/ref.
set -eu
cd "$(dirname "$0")/.."
ROOT=$PWD
RP=$ROOT/REPRODUCE
CACHE=$RP/cache
OUT=$RP/out
REF=$RP/ref
WORK=$RP/work
VER=$(sed -n 's/.*VENTOY_VERSION="\([^"]*\)".*/\1/p' INSTALL/grub/grub.cfg | head -1)
UPSTREAM=https://github.com/ventoy/Ventoy.git
CENTOS7=centos@sha256:be65f488b7764ad3638f236b7b515b3678369a5124c47b8d32916d6487418ea4
LINARO=gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu
LOONGSON=mips-loongson-gcc7.3-linux-gnu
EDIT=${EDIT:-1}
mkdir -p "$CACHE" "$OUT" "$REF" "$WORK"

log() { echo "== $*"; }

# The containers run as root, so their output is root-owned: clear and hand back via a container.
fresh() {  # DIR: empty, writable output directory
    if [ -e "$1" ]; then
        docker run --rm -v "$(dirname "$1")":/p ventoy-centos75 rm -rf "/p/$(basename "$1")"
    fi
    mkdir -p "$1"
}
own() {  # DIR: give the files back to the invoking user
    docker run --rm -v "$1":/o ventoy-centos75 chown -R "$(id -u):$(id -g)" /o
}

# run IMAGE SCRIPT OUTDIR [docker args...]: run a build/*.sh script in a container, with the
# repo at /src (read-only), downloads at /dl and OUTDIR at /out.
run() {
    img=$1 script=$2 name=$3; shift 3
    out=$OUT/$name; fresh "$out"
    log "$name ($img, $script)"
    docker run --rm -v "$ROOT":/src:ro -v "$CACHE":/dl:ro -v "$out":/out \
        -v "$RP/build/$script":/build.sh:ro -e LC_ALL=en_US.UTF-8 "$@" "$img" bash /build.sh
    own "$out"
}

# tree SHA PATH...: the given paths of an older Ventoy commit, unpacked in $WORK/tree-SHA
tree() {
    sha=$1; shift
    d=$WORK/tree-$sha
    if [ ! -d "$d" ]; then
        git cat-file -e "$sha^{commit}" 2>/dev/null || git fetch -q --depth=1 "$UPSTREAM" "$sha"
        mkdir -p "$d"; git archive "$sha" "$@" | tar -x -C "$d"
    fi
    echo "$d"
}

step_fetch() {
    grep -v '^#' "$RP/inputs.txt" | grep . | while read -r sum path urls; do
        f=$CACHE/$path
        if [ -f "$f" ] && echo "$sum  $f" | sha256sum -c --quiet - 2>/dev/null; then continue; fi
        mkdir -p "$(dirname "$f")"; ok=
        for u in $urls; do
            if curl -fsSL --retry 3 -o "$f.part" "$u" && echo "$sum  $f.part" | sha256sum -c --quiet - 2>/dev/null; then
                mv "$f.part" "$f"; ok=1; break
            fi
            echo "   $path: no good copy at $u"
        done
        rm -f "$f.part"; [ -n "$ok" ] || { echo "cannot fetch $path"; exit 1; }
        echo "   fetched $path"
    done
    mkdir -p "$CACHE/tc"
    [ -d "$CACHE/tc/$LINARO" ] || tar -xf "$CACHE/$LINARO.tar.xz" -C "$CACHE/tc"
    [ -d "$CACHE/tc/$LOONGSON" ] || tar -xf "$CACHE/mips-loongson-gcc7.3-2019.06-29-linux-gnu.tar.gz" -C "$CACHE/tc"
    # CentOS 5's tar can't read .xz.
    [ -f "$CACHE/dietlibc-0.34.tar" ] || xz -dc "$CACHE/dietlibc-0.34.tar.xz" > "$CACHE/dietlibc-0.34.tar"
    # Ventoy's FUSE/exFAT scripts prefer mirrors-libfuse-fuse-2.9.9.zip (gitee), which unpacks to
    # libfuse/. The release builds used it; the directory name ends up in mount.exfat-fuse's build ID.
    [ -f "$CACHE/mirrors-libfuse-fuse-2.9.9.zip" ] || python3 -I - "$CACHE" <<'EOF'
import sys, zipfile
c = sys.argv[1]
with zipfile.ZipFile(f"{c}/libfuse-fuse-2.9.9.zip") as src, \
     zipfile.ZipFile(f"{c}/mirrors-libfuse-fuse-2.9.9.zip", "w", zipfile.ZIP_DEFLATED) as dst:
    for i in src.infolist():
        i2 = zipfile.ZipInfo("libfuse/" + i.filename.split("/", 1)[1], i.date_time)
        i2.external_attr = i.external_attr
        dst.writestr(i2, src.read(i))
EOF
}

step_images() {
    log "images"
    docker pull -q "$CENTOS7" >/dev/null; docker tag "$CENTOS7" centos:7
    docker build -q -t ventoy-build:ci "$ROOT" >/dev/null
    docker build -q -t ventoy-build:repro -f "$RP/docker/build-repro.Dockerfile" "$RP/docker" >/dev/null
    docker build -q -t ventoy-centos75 -f "$RP/docker/centos75.Dockerfile" "$RP/docker" >/dev/null
    docker build -q -t ventoy-c75-gcc44 -f "$RP/docker/c75-gcc44.Dockerfile" "$RP/docker" >/dev/null
    docker build -q -t ventoy-c75-gcc44-gtk -f "$RP/docker/c75-gcc44-gtk.Dockerfile" "$RP/docker" >/dev/null
    docker build -q -t ventoy-centos6-i386 -f "$RP/docker/centos6-i386.Dockerfile" "$CACHE" >/dev/null
    docker build -q -t ventoy-centos6-i386:gcc18 --build-arg GCC_PIN=4.4.7-18 -f "$RP/docker/centos6-i386.Dockerfile" "$CACHE" >/dev/null
    docker build -q -t ventoy-centos5 -f "$RP/docker/centos5.Dockerfile" "$CACHE" >/dev/null
}

step_release() {
    log "release ventoy-$VER"
    base=https://github.com/ventoy/Ventoy/releases/download/v$VER
    tgz=ventoy-$VER-linux.tar.gz
    curl -fsSL --retry 3 -o "$CACHE/sha256-$VER.txt" "$base/sha256.txt"
    sum=$(awk -v f="$tgz" '$2==f {print $1}' "$CACHE/sha256-$VER.txt")
    [ -n "$sum" ] || { echo "no checksum for $tgz"; exit 1; }
    if ! { [ -f "$CACHE/$tgz" ] && echo "$sum  $CACHE/$tgz" | sha256sum -c --quiet - 2>/dev/null; }; then
        curl -fsSL --retry 3 -o "$CACHE/$tgz" "$base/$tgz"; echo "$sum  $CACHE/$tgz" | sha256sum -c --quiet -
    fi
    rm -rf "$REF"; mkdir -p "$REF/vtoyefi" "$REF/cpio"
    tar -xzf "$CACHE/$tgz" -C "$REF"
    xz -dc "$REF/ventoy-$VER/ventoy/ventoy.disk.img.xz" > "$WORK/ventoy.disk.img"
    mcopy -s -n -i "$WORK/ventoy.disk.img" '::/*' "$REF/vtoyefi/"
    for c in ventoy_x86 ventoy_arm64 ventoy_mips64; do
        mkdir -p "$REF/cpio/$c/toolx"
        (cd "$REF/cpio/$c" && cpio -idm --quiet < "$REF/vtoyefi/ventoy/$c.cpio")
        (cd "$REF/cpio/$c/toolx" && xz -dc ../ventoy/tool.cpio.xz | cpio -idm --quiet)
    done
}

step_smalltools() {
    run ventoy-centos75 smalltools.sh smalltools-c75 -e SAVE_LIBC=/out/libc_c75.tar
    cp "$OUT/smalltools-c75/libc_c75.tar" "$CACHE/libc_c75.tar"
    run ventoy-build:repro smalltools.sh smalltools-c79
    run ventoy-build:repro smalltools.sh smalltools-mixed -e PREBUILT_LIBC=/dl/libc_c75.tar
}

step_grub() {
    hyp=
    if [ "$EDIT" = 1 ]; then
        mkdir -p "$WORK/grub-hyp"
        tar -xJOf "$CACHE/grub-2.04.tar.xz" grub-2.04/grub-core/video/bitmap_scale.c > "$WORK/grub-hyp/bitmap_scale.orig.c"
        patch -s -o "$WORK/grub-hyp/bitmap_scale.c" "$WORK/grub-hyp/bitmap_scale.orig.c" "$RP/patches/grub-bitmap_scale.diff"
        hyp="-e HYPOTHESIS_FILE=/hyp/bitmap_scale.c"
    fi
    sfx=; [ "$EDIT" = 1 ] || sfx=-noedit
    # shellcheck disable=SC2086
    run ventoy-build:repro grub.sh grub$sfx -v "$CACHE/tc":/tc:ro -v "$WORK/grub-hyp":/hyp:ro $hyp
    # shellcheck disable=SC2086
    run ventoy-build:repro grub_mips.sh grub-mips$sfx -v "$CACHE/tc":/tc:ro -v "$WORK/grub-hyp":/hyp:ro $hyp
}

step_ipxe() {
    hyp=; sfx=-noedit
    if [ "$EDIT" = 1 ]; then
        d=$WORK/ipxe-hyp/arch/x86/image; mkdir -p "$d"
        tar -xjOf IPXE/ipxe_org_code/ipxe-3fe683e.tar.bz2 ipxe-3fe683e/src/arch/x86/image/bootsector.c > "$d/bootsector.orig.c"
        patch -s -o "$d/bootsector.c" "$d/bootsector.orig.c" "$RP/patches/ipxe-bootsector.diff"; rm "$d/bootsector.orig.c"
        hyp="-e HYPOTHESIS_DIR=/hyp"; sfx=
    fi
    mkdir -p "$WORK/ipxe-hyp"
    # shellcheck disable=SC2086
    run ventoy-build:repro ipxe.sh ipxe$sfx -v "$WORK/ipxe-hyp":/hyp:ro $hyp
}

step_wimboot() {
    run ventoy-build:repro wimboot.sh wimboot -e UPSTREAM_S=/dl/wimboot-S
}

step_exfat() {
    run ventoy-centos75 exfat_fuseiso_c7.sh exfat-c7 -e JOBS="exfat fuseaa64" -e LIBFUSE_MIRROR=1
    run ventoy-centos6-i386 exfat_fuseiso_c6.sh exfat-c6 -e JOBS=exfat
    run ventoy-centos6-i386:gcc18 exfat_fuseiso_c6.sh fuseiso-c6 -e JOBS=fuseiso
}

step_xzminidec() {
    # The committed xzminidec binaries predate 1.0.58's changes to xz-embedded.
    t=$(tree b63ce2a3df409eb0dd0bed5b977a75605997fd3c Ventoy2Disk/Ventoy2Disk/xz-embedded-20130513)
    out=$OUT/xzminidec; fresh "$out"; log "xzminidec (b63ce2a tree)"
    docker run --rm -v "$t":/src:ro -v "$CACHE":/dl:ro -v "$out":/out -v "$RP/build/xzminidec.sh":/build.sh:ro \
        -e LC_ALL=en_US.UTF-8 ventoy-centos75 bash /build.sh
    own "$out"
}

step_livecd() {
    t=$(tree a29bdfbc3cb8967f182882bceec22d96dbf83fca GRUB2 INSTALL/grub LiveCD)
    # The grub-mkimage command for this image was never published: take the module list (in
    # order) from the committed image itself. Prefix /EFI/boot and embed.cfg are in the image too.
    python3 -I - "$RP/tools" LiveCD/GRUB/bootx64.efi > "$WORK/livecd-modlist" <<'EOF'
import sys; sys.path.insert(0, sys.argv[1]); import grub_mods
print(" ".join(n for n, t, s, b in grub_mods.modules(sys.argv[2]) if t == 0))
EOF
    out=$OUT/livecd; fresh "$out"; log "livecd (a29bdfb tree)"
    docker run --rm -v "$t":/src:ro -v "$CACHE":/dl:ro -v "$out":/out -v "$WORK/livecd-modlist":/modlist:ro \
        -v "$RP/build/livecd_grub.sh":/build.sh:ro -e LC_ALL=en_US.UTF-8 ventoy-build:repro bash /build.sh
    own "$out"
}

step_linuxgui() {
    # Cross toolchains must sit under /opt: their install path reaches the build ID.
    opt="-v $CACHE/tc/$LINARO:/opt/$LINARO:ro -v $CACHE/tc/$LOONGSON:/opt/$LOONGSON:ro -e TC=/opt"
    # shellcheck disable=SC2086
    run ventoy-c75-gcc44 linuxgui_web.sh linuxgui-web $opt
    # The committed Plugson binaries are 2023-01-13 builds (4df793e); the release ships newer ones.
    t=$(tree 4df793e0217183e20045d5d06058e4c6ebf8a32f Plugson LinuxGUI)
    out=$OUT/linuxgui-plugson-4df793e; fresh "$out"; log "Plugson (4df793e tree)"
    # shellcheck disable=SC2086
    docker run --rm -v "$t":/src:ro -v "$CACHE":/dl:ro -v "$out":/out -v "$RP/build/linuxgui_web.sh":/build.sh:ro \
        -e LC_ALL=en_US.UTF-8 -e JOBS=plugson $opt ventoy-c75-gcc44 bash /build.sh
    own "$out"
    # shellcheck disable=SC2086
    run ventoy-c75-gcc44 linuxgui_vgui.sh linuxgui-vgui $opt
    run ventoy-c75-gcc44-gtk linuxgui_gtk.sh linuxgui-gtk
}

step_tools() {
    if [ ! -d "$CACHE/dmsrpm" ]; then
        mkdir -p "$WORK/dmsrpm"
        docker run --rm -v "$CACHE":/dl:ro -v "$WORK/dmsrpm":/x -w /x ventoy-centos75 \
            sh -c 'rpm2cpio /dl/device-mapper-1.02.28-2.el5.src.rpm | cpio -idm --quiet'
        cp -r "$WORK/dmsrpm" "$CACHE/dmsrpm"
    fi
    run ventoy-centos75 tools_c75.sh tools-c75
    run ventoy-centos75 tools_fix_c75.sh tools-fix-c75
    run ventoy-centos6-i386:gcc18 tools_c6.sh tools-c6-gcc18 -e PICK=lunzip
    run ventoy-centos6-i386 tools_c6.sh tools-c6 -e PICK="zstd dmsetup"
    run ventoy-centos75 lz4cat.sh lz4cat
}

step_busybox() {
    out=$OUT/busybox; fresh "$out"; log busybox
    bb() {  # image entry env...
        img=$1 entry=$2; shift 2
        docker run --rm -v "$ROOT":/src:ro -v "$CACHE":/dl:ro -v "$out":/out -v "$RP/build/busybox.sh":/build.sh:ro \
            -v "$RP/build/busybox_cross.sh":/run.sh:ro "$@" "$img" bash -c "$entry"
    }
    M='ARCH=mips CROSS_COMPILE=mips64el-linux-musl- "CFLAGS+=-mips64r2 -mabi=64 -Os" "LDFLAGS+=-mips64r2 -mabi=64 -Os"'
    for t in ash hexdump xzcat; do
        bb ventoy-centos75 'tar -C / -xf /dl/libc_c75.tar; sh /build.sh' -e CFG="x86_64_$t.config" -e NAME="${t}_x86_64" -e MUSL=1
        bb ventoy-centos75 'bash /run.sh' -e CFG="aarch64_$t.config" -e NAME="${t}_aarch64" -e "MAKEARGS=ARCH=arm64 CROSS_COMPILE=aarch64-linux-"
        # The mips64el banners carry the build time, equal to the config file's header date (author's TZ: CST).
        ts="$(date -u -d "$(sed -n '4s/^# //p' "BUSYBOX/mips64el_$t.config")" '+%Y-%m-%d %H:%M:%S') CST"
        bb ventoy-centos75 'bash /run.sh' -e CFG="mips64el_$t.config" -e NAME="${t}_mips64el" -e "MAKEARGS=$M" -e "TS=$ts"
    done
    # Full builds: "make defconfig" + static (BUSYBOX/build.txt). Banner times from the shipped binaries.
    bb ventoy-centos75 'bash /run.sh' -e CFG=defconfig -e NAME=busyboxaa64 -e "EXTRA_Y=AR FEATURE_AR_LONG_FILENAMES FEATURE_AR_CREATE INOTIFYD" \
        -e "MAKEARGS=ARCH=arm64 CROSS_COMPILE=aarch64-linux-" -e "TS=2020-12-08 10:16:41 CST"
    bb ventoy-centos75 'bash /run.sh' -e CFG=defconfig -e NAME=busyboxm64e -e "MAKEARGS=$M" -e "TS=2021-03-04 14:11:58 CST"
    own "$out"
}

step_edk2() { sh EDK2/ci/run-all.sh "$VER"; }

step_verify() { python3 -I "$RP/verify.py"; }

[ $# -gt 0 ] || { sed -n '2,25p' "$0"; exit 1; }
[ "$1" != all ] || set -- fetch images release smalltools grub ipxe wimboot exfat xzminidec livecd linuxgui tools busybox edk2 verify
for s in "$@"; do "step_$s"; done
