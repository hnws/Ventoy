#!/bin/bash
# Runs INSIDE ventoy-c75-gcc44-gtk. Runs LinuxGUI/build_gtk.sh unmodified at /home/share/Ventoy.
# Only the x86_64 gtk3/gtk2 builds can succeed here: i386 needs i686 GTK devel packages,
# aarch64 needs EXLIB/aarch64, and mips64el needs the unpublished Loongson gcc 8.
set -u
V=/home/share/Ventoy; rm -rf "$V"; mkdir -p "$V/INSTALL/tool/"{x86_64,i386,aarch64,mips64el}
cp -a /src/LinuxGUI "$V/"; cd "$V/LinuxGUI"
bash ./build_gtk.sh >/out/log_build_gtk.txt 2>&1
for g in gtk3 gtk2; do cp "$V/INSTALL/tool/x86_64/Ventoy2Disk.$g" "/out/Ventoy2Disk.${g}_x86_64" 2>/dev/null; done
ls -l /out
