#!/bin/sh
# Builds one BusyBox 1.32.0 binary the way BUSYBOX/build.txt describes:
#   tar xf busybox-1.32.0.tar.bz2; copy <cfg> as .config; [modify Makefile CC for musl]; make; rename busybox
# Env: CFG   = config file under /src/BUSYBOX (e.g. x86_64_ash.config), or 'defconfig' (+ CONFIG_STATIC=y)
#      NAME  = output name in /out
#      EXTRA_Y = with CFG=defconfig, extra symbols to enable (e.g. "AR INOTIFYD")
#      MAKEARGS = extra make arguments (ARCH=..., CROSS_COMPILE=..., "CFLAGS+=...")
#      MUSL=1 : apply build.txt's Makefile edit (CC/MODFLAGS with musl-gcc.specs)
#      TS    = optional AUTOCONF_TIMESTAMP (the banner's build time), e.g. "2021-03-04 12:59:59 CST"
#      BBDIR = build directory (default /home/share/Ventoy/BUSYBOX)
set -e
BBDIR=${BBDIR:-/home/share/Ventoy/BUSYBOX}
rm -rf "$BBDIR"; mkdir -p "$BBDIR"; cd "$BBDIR"
tar -xjf /dl/busybox-1.32.0.tar.bz2; cd busybox-1.32.0
if [ "$CFG" = defconfig ]; then
    # build.txt "How to build full busybox": make defconfig; menuconfig -> static build
    eval make $MAKEARGS defconfig >/out/log_$NAME.defconfig.txt 2>&1
    sed -i 's|^# CONFIG_STATIC is not set|CONFIG_STATIC=y|' .config
    # EXTRA_Y: further symbols switched on in menuconfig; their sub-options take menuconfig defaults.
    for y in $EXTRA_Y; do sed -i "s|^# CONFIG_$y is not set|CONFIG_$y=y|" .config; done
    [ -z "$EXTRA_Y" ] || yes "" | eval make $MAKEARGS oldconfig >>/out/log_$NAME.defconfig.txt 2>&1
else
    cp "/src/BUSYBOX/$CFG" .config
fi
if [ -n "$MUSL" ]; then
    sed -i 's|^CC\t\t= $(CROSS_COMPILE)gcc|CC\t\t= gcc -specs "/usr/local/musl/lib/musl-gcc.specs"|' Makefile
    sed -i 's|^MODFLAGS\t= -DMODULE|MODFLAGS\t= -DMODULE -specs "/usr/local/musl/lib/musl-gcc.specs"|' Makefile
    grep -n 'musl-gcc.specs' Makefile >&2
fi
eval make $MAKEARGS silentoldconfig </dev/null >/out/log_$NAME.txt 2>&1
if [ -n "$TS" ]; then
    sed -i "s|^#define AUTOCONF_TIMESTAMP .*|#define AUTOCONF_TIMESTAMP \"$TS\"|" include/autoconf.h
fi
grep AUTOCONF_TIMESTAMP include/autoconf.h >&2
eval make $MAKEARGS >>/out/log_$NAME.txt 2>&1
cp busybox "/out/$NAME"
