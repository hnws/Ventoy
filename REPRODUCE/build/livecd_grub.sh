#!/bin/bash
# Runs INSIDE a CentOS 7 build container. Rebuilds LiveCD/GRUB/bootx64.efi (added 2020-09-02, a29bdfb):
# the x86_64-efi part of GRUB2/buildgrub.sh from that commit's tree, then grub-mkimage with the
# module list (in order) and prefix read from the committed image, and LiveCD/GRUB/embed.cfg.
# The grub-mkimage command itself was never published.
#   /src : a29bdfb tree (GRUB2, INSTALL/grub, LiveCD) (ro)   /dl : grub-2.04.tar.xz
#   /modlist : module names in image order   /out
set -euo pipefail
V=/home/share/Ventoy
rm -rf "$V"; mkdir -p "$V"
cp -a /src/GRUB2 /src/INSTALL /src/LiveCD "$V/"
cp /dl/grub-2.04.tar.xz "$V/GRUB2/"
ln -sf "$(command -v gcc)" /usr/local/bin/x86_64-linux-gnu-gcc
rpm -q gcc
cd "$V/GRUB2"; VT_GRUB_DIR=$PWD
rm -rf INSTALL SRC NBP PXE; mkdir SRC NBP PXE
tar -xf grub-2.04.tar.xz -C ./SRC/
/bin/cp -a ./MOD_SRC/grub-2.04 ./SRC/
cd ./SRC/grub-2.04
./autogen.sh >/out/grub_x64.log 2>&1
./configure --with-platform=efi --prefix=$VT_GRUB_DIR/INSTALL/ >>/out/grub_x64.log 2>&1
make -j"$(nproc)" >>/out/grub_x64.log 2>&1
make install >>/out/grub_x64.log 2>&1
"$VT_GRUB_DIR/INSTALL/bin/grub-mkimage" -v --directory "$VT_GRUB_DIR/INSTALL/lib/grub/x86_64-efi" \
    --prefix '/EFI/boot' --config "$V/LiveCD/GRUB/embed.cfg" --output /out/bootx64.efi \
    --format 'x86_64-efi' --compression 'auto' $(head -1 /modlist) >>/out/grub_x64.log 2>&1
ls -l /out/bootx64.efi
