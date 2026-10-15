#!/bin/bash
# Runs INSIDE the Ventoy build container. Reproduces the x86_64-efi, i386-efi and
# arm64-efi parts of GRUB2/buildgrub.sh, using the same commands, at the original path
# /home/share/Ventoy (install.sh derives VT_DIR from it and mips configure hardcodes it).
# mips64el and i386-pc are skipped. Outputs: grubx64_real.efi, grubia32_real.efi, BOOTAA64.EFI.
#   /src : Ventoy checkout (ro)   /dl : grub-2.04.tar.xz   /tc : Linaro toolchain   /out
set -euo pipefail
V=/home/share/Ventoy
rm -rf "$V"; mkdir -p "$V"
cp -a /src/GRUB2 /src/INSTALL "$V/"
cp /dl/grub-2.04.tar.xz "$V/GRUB2/"
# buildgrub.sh uses HOST_CC=x86_64-linux-gnu-gcc, which CentOS names x86_64-redhat-linux-gcc.
ln -sf "$(command -v gcc)" /usr/local/bin/x86_64-linux-gnu-gcc
gcc --version | head -1

cd "$V/GRUB2"
VT_GRUB_DIR=$PWD
rm -rf INSTALL SRC NBP PXE; mkdir SRC NBP PXE
tar -xf grub-2.04.tar.xz -C ./SRC/
/bin/cp -a ./MOD_SRC/grub-2.04 ./SRC/
cd ./SRC/grub-2.04
# HYPOTHESIS_FILE: test a hypothesis about unpublished changes (not part of Ventoy's source).
[ -z "${HYPOTHESIS_FILE:-}" ] || cp "$HYPOTHESIS_FILE" grub-core/video/bitmap_scale.c

step() { echo "======== $1"; }
step "x86_64-efi"
make distclean >/dev/null 2>&1 || true
./autogen.sh >/out/grub_x64.log 2>&1
./configure --with-platform=efi --prefix=$VT_GRUB_DIR/INSTALL/ >>/out/grub_x64.log 2>&1
make -j"$(nproc)" >>/out/grub_x64.log 2>&1
sh install.sh uefi >>/out/grub_x64.log 2>&1 || echo "install.sh uefi returned $?"

step "i386-efi"
make distclean >/dev/null 2>&1 || true
./autogen.sh >/out/grub_ia32.log 2>&1
./configure --target=i386 --with-platform=efi --prefix=$VT_GRUB_DIR/INSTALL/ >>/out/grub_ia32.log 2>&1
make -j"$(nproc)" >>/out/grub_ia32.log 2>&1
sh install.sh i386efi >>/out/grub_ia32.log 2>&1 || echo "install.sh i386efi returned $?"

step "arm64-efi"
PATH=$PATH:/tc/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu/bin
make distclean >/dev/null 2>&1 || true
./autogen.sh >/out/grub_aa64.log 2>&1
./configure --prefix=$VT_GRUB_DIR/INSTALL/ \
  --target=aarch64 --with-platform=efi \
  --host=x86_64-linux-gnu \
  HOST_CC=x86_64-linux-gnu-gcc \
  BUILD_CC=gcc \
  TARGET_CC=aarch64-linux-gnu-gcc \
  TARGET_OBJCOPY=aarch64-linux-gnu-objcopy \
  TARGET_STRIP=aarch64-linux-gnu-strip TARGET_NM=aarch64-linux-gnu-nm \
  TARGET_RANLIB=aarch64-linux-gnu-ranlib >>/out/grub_aa64.log 2>&1
make -j"$(nproc)" >>/out/grub_aa64.log 2>&1
sh install.sh arm64 >>/out/grub_aa64.log 2>&1 || echo "install.sh arm64 returned $?"

for f in grubx64_real.efi grubia32_real.efi BOOTAA64.EFI; do
    cp -f "$V/INSTALL/EFI/BOOT/$f" /out/ && ls -l "/out/$f"
done
