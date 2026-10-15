#!/bin/bash
# Runs INSIDE ventoy-c75-gcc44. Runs the VentoyGUI line of LinuxGUI/build_gtk.sh, verbatim,
# for x86_64 (gcc), i386 (gcc -m32) and aarch64 (Linaro, under /opt). mips64el needs
# Loongson gcc 8 (/opt/mips-loongson-gcc8-linux-gnu-2021-02-08), which isn't published.
#   /src : tree with LinuxGUI (ro)   /out
set -eu
export PATH=$PATH:/opt/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu/bin
V=/home/share/Ventoy; rm -rf "$V"; mkdir -p "$V/INSTALL"; cp -a /src/LinuxGUI "$V/"; cd "$V/LinuxGUI"
for v in "gcc x86_64" "gcc -m32 i386" "aarch64-linux-gnu-gcc aarch64"; do
    set -- $v; toolDir=${!#}; cc=${v% *}
    $cc -O2 -D_FILE_OFFSET_BITS=64 Ventoy2Disk/ventoy_gui.c Ventoy2Disk/Core/ventoy_json.c -I Ventoy2Disk/Core  -DVTOY_GUI_ARCH="\"$toolDir\"" -o VentoyGUI.$toolDir
    cp VentoyGUI.$toolDir /out/
done
ls -l /out
