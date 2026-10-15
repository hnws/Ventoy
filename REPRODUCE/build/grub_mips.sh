#!/bin/bash
# Runs INSIDE the Ventoy build container (CentOS 7.9). The mips64el-efi part of
# GRUB2/buildgrub.sh, with the same commands, at /home/share/Ventoy (configure's --prefix is
# hardcoded there). Toolchain: mips-loongson-gcc7.3-2019.06-29 from ventoy/vtoytoolchain
# (DOC/BuildVentoyFromSource.txt). Output: BOOTMIPS.EFI.
#   /src : Ventoy checkout (ro)   /dl : grub-2.04.tar.xz   /tc : toolchains   /out
#   HYPOTHESIS_FILE : optional replacement grub-core/video/bitmap_scale.c
set -euo pipefail
V=/home/share/Ventoy
rm -rf "$V"; mkdir -p "$V"
cp -a /src/GRUB2 /src/INSTALL "$V/"
cp /dl/grub-2.04.tar.xz "$V/GRUB2/"
ln -sf "$(command -v gcc)" /usr/local/bin/x86_64-linux-gnu-gcc
gcc --version | head -1
cd "$V/GRUB2"
VT_GRUB_DIR=$PWD
rm -rf INSTALL SRC NBP PXE; mkdir SRC NBP PXE
tar -xf grub-2.04.tar.xz -C ./SRC/
/bin/cp -a ./MOD_SRC/grub-2.04 ./SRC/
cd ./SRC/grub-2.04
[ -z "${HYPOTHESIS_FILE:-}" ] || cp "$HYPOTHESIS_FILE" grub-core/video/bitmap_scale.c

PATH=$PATH:/tc/mips-loongson-gcc7.3-linux-gnu/2019.06-29/bin
mips-linux-gnu-gcc --version | head -1
./autogen.sh >/out/grub_mips.log 2>&1
./configure  --prefix=/home/share/Ventoy/GRUB2/INSTALL/ \
--target=mips64el --with-platform=efi \
--host=x86_64-linux-gnu  \
HOST_CC=x86_64-linux-gnu-gcc \
BUILD_CC=gcc \
TARGET_CC="mips-linux-gnu-gcc -mabi=64 -Wno-error=cast-align -Wno-error=misleading-indentation" \
TARGET_OBJCOPY=mips-linux-gnu-objcopy \
TARGET_STRIP=mips-linux-gnu-strip TARGET_NM=mips-linux-gnu-nm \
TARGET_RANLIB=mips-linux-gnu-ranlib >>/out/grub_mips.log 2>&1
make -j"$(nproc)" >>/out/grub_mips.log 2>&1
sh install.sh mips64el >>/out/grub_mips.log 2>&1 || echo "install.sh mips64el returned $?"
cp -f "$V/INSTALL/EFI/BOOT/BOOTMIPS.EFI" /out/ && ls -l /out/BOOTMIPS.EFI
