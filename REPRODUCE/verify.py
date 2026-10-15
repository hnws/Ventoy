#!/usr/bin/env python3
"""Compare every binary rebuilt by REPRODUCE/run.sh (or downloaded from upstream) with the
copy committed in git and with the copy in the release (REPRODUCE/ref, from `run.sh release`).

Modes:
  exact    byte-identical
  pe       Authenticode-signed PE: identical once the reference's signature is cut off
           (EDK2/ci/compare_signed_pe.py)
  buildid  ELF: every loaded byte identical except .note.gnu.build-id
  same     a list entry that is an identical copy of another committed file

Usage: python3 REPRODUCE/verify.py [-v]   (-v: also list checks whose input is missing)
Exit status 0 when every check whose files exist passes.
"""
import hashlib
import lzma
import os
import re
import subprocess
import sys
import tarfile
import tempfile

RP = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(RP)
O = os.path.join(RP, "out") + "/"
C = os.path.join(RP, "cache") + "/"
G = ROOT + "/"
VER = re.search(r'VENTOY_VERSION="([^"]+)"', open(G + "INSTALL/grub/grub.cfg").read()).group(1)
R = os.path.join(RP, "ref") + "/"
RT = f"{R}ventoy-{VER}/"           # release tarball
RE = f"{R}vtoyefi/"                # VTOYEFI partition (ventoy.disk.img)
RC = f"{R}cpio/"                   # initramfs cpios (+ toolx = inner tool.cpio.xz)
X = G + "IMG/cpio_"
ARCHES = ("x86_64", "i386", "aarch64", "mips64el")
CHECKS = []


def add(entry, rebuilt, ref, mode="exact", note=""):
    CHECKS.append((entry, rebuilt, ref, mode, note))


# ---- EFI apps and EfiFs drivers (EDK2/ci/run-all.sh)
for a in ("x64", "ia32", "aa64"):
    for m in ("ventoy", "vtoyutil", "iso9660", "udf"):
        add(f"INSTALL/ventoy/{m}_{a}.efi [release]", f"{G}EDK2/ci/out/{m}_{a}.efi", f"{RE}ventoy/{m}_{a}.efi", "pe")

# ---- vtoycli, vlnk, vtoytool 00, vtoy_fuse_iso
for a in ARCHES:
    for t in ("vtoycli", "vlnk"):
        add(f"INSTALL/tool/{a}/{t}", f"{O}smalltools-mixed/tool/{t}_{a}", f"{G}INSTALL/tool/{a}/{t}")
        add(f"INSTALL/tool/{a}/{t} [release]", f"{O}smalltools-mixed/tool/{t}_{a}", f"{RT}tool/{a}/{t}")
for t, cp in (("64", "ventoy_x86"), ("32", "ventoy_x86"), ("aa64", "ventoy_arm64"), ("m64e", "ventoy_mips64")):
    add(f"VtoyTool/vtoytool/00/vtoytool_{t} [release]", f"{O}smalltools-c79/vtoytool00/vtoytool_{t}",
        f"{RC}{cp}/toolx/tool/vtoytool/00/vtoytool_{t}")
add("FUSEISO/vtoy_fuse_iso_64", f"{O}smalltools-c75/vtoy_fuse_iso_64", f"{G}FUSEISO/vtoy_fuse_iso_64")
add("FUSEISO/vtoy_fuse_iso_aa64", f"{O}exfat-c7/vtoy_fuse_iso_aa64", f"{G}FUSEISO/vtoy_fuse_iso_aa64")
add("FUSEISO/vtoy_fuse_iso_32", f"{O}fuseiso-c6/vtoy_fuse_iso_32", f"{G}FUSEISO/vtoy_fuse_iso_32")
for t, cp in (("64", "ventoy_x86"), ("32", "ventoy_x86"), ("aa64", "ventoy_arm64")):
    add(f"FUSEISO/vtoy_fuse_iso_{t} [release]", f"{G}FUSEISO/vtoy_fuse_iso_{t}", f"{RC}{cp}/toolx/tool/vtoy_fuse_iso_{t}", "same")

# ---- GRUB (with the unpublished bitmap_scale.c edit), iPXE (with the unpublished printf), wimboot
add("INSTALL/EFI/BOOT/grubx64_real.efi [release]", f"{O}grub/grubx64_real.efi", f"{RE}EFI/BOOT/grubx64_real.efi", "pe", "+edit")
add("INSTALL/EFI/BOOT/grubia32_real.efi [release]", f"{O}grub/grubia32_real.efi", f"{RE}EFI/BOOT/grubia32_real.efi", "pe", "+edit")
add("INSTALL/EFI/BOOT/BOOTAA64.EFI [release]", f"{O}grub/BOOTAA64.EFI", f"{RE}EFI/BOOT/BOOTAA64.EFI", "exact", "+edit")
add("INSTALL/EFI/BOOT/BOOTMIPS.EFI [release]", f"{O}grub-mips/BOOTMIPS.EFI", f"{RE}EFI/BOOT/BOOTMIPS.EFI", "exact", "+edit")
add("INSTALL/ventoy/ipxe.krn", f"{O}ipxe/ipxe.krn", f"{G}INSTALL/ventoy/ipxe.krn", "exact", "+edit")
add("INSTALL/ventoy/ipxe.krn [release]", f"{O}ipxe/ipxe.krn", f"{RE}ventoy/ipxe.krn", "exact", "+edit")
for w in ("wimboot.x86_64", "wimboot.i386.efi"):
    add(f"INSTALL/ventoy/{w}", f"{O}wimboot/{w}", f"xz:{G}INSTALL/ventoy/{w}.xz", "exact", "+.S")
    add(f"INSTALL/ventoy/{w} [release]", f"{O}wimboot/{w}", f"xz:{RE}ventoy/{w}.xz", "pe", "+.S")
add("LiveCD/GRUB/bootx64.efi", f"{O}livecd/bootx64.efi", f"{G}LiveCD/GRUB/bootx64.efi")
add("LiveCDGUI/GRUB/bootx64.efi", f"{G}LiveCD/GRUB/bootx64.efi", f"{G}LiveCDGUI/GRUB/bootx64.efi", "same")

# ---- exFAT
for a, d in (("x86_64", "exfat-c7/exfat_x86_64"), ("i386", "exfat-c6/exfat_i386")):
    for t in ("mkexfatfs", "mount.exfat-fuse"):
        add(f"INSTALL/tool/{a}/{t}", f"{O}{d}/{t}", f"{G}INSTALL/tool/{a}/{t}")
        add(f"INSTALL/tool/{a}/{t} [release]", f"{O}{d}/{t}", f"{RT}tool/{a}/{t}")

# ---- xzminidec (b63ce2a tree)
for n, cp in (("64_musl", "x86"), ("aa64", "arm64"), ("m64e", "mips64")):
    add(f"IMG/cpio_{cp}/ventoy/busybox/xzminidec{n}", f"{O}xzminidec/xzminidec{n}", f"{X}{cp}/ventoy/busybox/xzminidec{n}")
for n in ("32", "64"):
    add(f"IMG/cpio_x86/ventoy/busybox/xzminidec{n}", f"{O}xzminidec/xzminidec{n}", f"{X}x86/ventoy/busybox/xzminidec{n}", "buildid")
for n, cp in (("32", "x86"), ("64", "x86"), ("64_musl", "x86"), ("aa64", "arm64"), ("m64e", "mips64")):
    add(f"IMG/cpio_{cp}/ventoy/busybox/xzminidec{n} [release]", f"{X}{cp}/ventoy/busybox/xzminidec{n}",
        f"{RC}ventoy_{cp}/ventoy/busybox/xzminidec{n}", "same")

# ---- Ventoy's Linux host tools
for a in ARCHES:
    add(f"INSTALL/tool/{a}/V2DServer", f"{O}linuxgui-web/V2DServer_{a}", f"{G}INSTALL/tool/{a}/V2DServer")
    add(f"INSTALL/tool/{a}/V2DServer [release]", f"{O}linuxgui-web/V2DServer_{a}", f"{RT}tool/{a}/V2DServer")
    add(f"INSTALL/tool/{a}/Plugson", f"{O}linuxgui-plugson-4df793e/Plugson_{a}", f"{G}INSTALL/tool/{a}/Plugson", "exact", "4df793e tree")
    add(f"INSTALL/tool/{a}/Plugson [release]", f"{O}linuxgui-web/Plugson_{a}", f"{RT}tool/{a}/Plugson")
for a in ("x86_64", "i386", "aarch64"):
    add(f"INSTALL/VentoyGUI.{a}", f"{O}linuxgui-vgui/VentoyGUI.{a}", f"{G}INSTALL/VentoyGUI.{a}")
    add(f"INSTALL/VentoyGUI.{a} [release]", f"{O}linuxgui-vgui/VentoyGUI.{a}", f"{RT}VentoyGUI.{a}")
for g in ("gtk3", "gtk2"):
    add(f"INSTALL/tool/x86_64/Ventoy2Disk.{g}", f"{O}linuxgui-gtk/Ventoy2Disk.{g}_x86_64", f"{G}INSTALL/tool/x86_64/Ventoy2Disk.{g}")
    add(f"INSTALL/tool/x86_64/Ventoy2Disk.{g} [release]", f"{O}linuxgui-gtk/Ventoy2Disk.{g}_x86_64", f"{RT}tool/x86_64/Ventoy2Disk.{g}")

# ---- third-party initramfs tools
T = {"LZIP/lunzip64": "tools-c75/lunzip64", "LZIP/lunzipaa64": "tools-c75/lunzipaa64", "LZIP/lunzip32": "tools-c6-gcc18/lunzip32",
     "LZIP/lz4cat64": "lz4cat/lz4cat64", "LZIP/lz4cataa64": "lz4cat/lz4cataa64", "LZIP/lz4catm64e": "lz4cat/lz4catm64e",
     "ZSTD/zstdcat64": "tools-c75/zstdcat64", "ZSTD/zstdcataa64": "tools-c75/zstdcataa64", "ZSTD/zstdcat": "tools-c6/zstdcat",
     "DMSETUP/dmsetup64": "tools-fix-c75/dmsetup64", "DMSETUP/dmsetupaa64": "tools-c75/dmsetupaa64",
     "DMSETUP/dmsetupm64e": "tools-c75/dmsetupm64e", "DMSETUP/dmsetup32": "tools-c6/dmsetup32",
     "VBLADE/vblade-master/vblade_64": "tools-c75/vblade_64", "VBLADE/vblade-master/vblade_aa64": "tools-c75/vblade_aa64",
     "VBLADE/vblade-master/vblade_32": "tools-fix-c75/vblade_32"}
for e, o in T.items():
    add(e, O + o, G + e)
for e, same in (("x86/ventoy/tool/lz4cat64", "LZIP/lz4cat64"), ("arm64/ventoy/tool/lz4cataa64", "LZIP/lz4cataa64"),
                ("mips64/ventoy/tool/lz4catm64e", "LZIP/lz4catm64e"), ("x86/ventoy/tool/zstdcat", "ZSTD/zstdcat"),
                ("x86/ventoy/tool/zstdcat64", "ZSTD/zstdcat64"), ("arm64/ventoy/tool/zstdcataa64", "ZSTD/zstdcataa64")):
    add(f"IMG/cpio_{e}", G + same, X + e, "same")

# ---- BusyBox 1.32.0
for a in ("x86_64", "aarch64", "mips64el"):
    for t in ("ash", "hexdump", "xzcat"):
        add(f"INSTALL/tool/{a}/{t}", f"{O}busybox/{t}_{a}", f"{G}INSTALL/tool/{a}/{t}")
        add(f"INSTALL/tool/{a}/{t} [release]", f"{O}busybox/{t}_{a}", f"{RT}tool/{a}/{t}")
for e, same in (("x86/ventoy/busybox/64h", "INSTALL/tool/x86_64/ash"), ("arm64/ventoy/busybox/a64", "INSTALL/tool/aarch64/ash"),
                ("mips64/ventoy/busybox/m64", "INSTALL/tool/mips64el/ash")):
    add(f"IMG/cpio_{e}", G + same, X + e, "same")
add("IMG/cpio_arm64/ventoy/busybox/busyboxaa64", f"{O}busybox/busyboxaa64", f"xz:{X}arm64/ventoy/busybox/busyboxaa64.xz")
add("IMG/cpio_mips64/ventoy/busybox/busyboxm64e", f"{O}busybox/busyboxm64e", f"xz:{X}mips64/ventoy/busybox/busyboxm64e.xz")

# ---- upstream binaries Ventoy ships unmodified (downloaded by `run.sh fetch`)
U = C + "upstream/"
add("INSTALL/ventoy/memdisk", "syslinux:", f"{G}INSTALL/ventoy/memdisk", "exact", "upstream")
add("INSTALL/ventoy/memdisk [release]", "syslinux:", f"{RE}ventoy/memdisk", "exact", "upstream")
add("LiveCD/ISO/EFI/boot/vmlinuz64", f"{U}vmlinuz64", f"{G}LiveCD/ISO/EFI/boot/vmlinuz64", "exact", "upstream")
add("IMG/cpio_x86/ventoy/busybox/busybox64", f"{U}busybox-x86_64", f"xz:{X}x86/ventoy/busybox/busybox64.xz", "exact", "upstream")
add("LiveCDGUI/EXT/busybox-x86_64", f"{U}busybox-x86_64", f"{G}LiveCDGUI/EXT/busybox-x86_64", "exact", "upstream")
add("IMG/cpio_x86/ventoy/busybox/busybox32", f"{U}busybox-i686", f"xz:{X}x86/ventoy/busybox/busybox32.xz", "exact", "upstream")
for f, ref in (("busybox_AR-1.30.0-i686", "x86/ventoy/tool/ar"), ("busybox_INOTIFYD-1.30.0-i686", "x86/ventoy/tool/inotifyd"),
               ("busybox_ASH-1.27.1-i686", "x86/ventoy/busybox/ash"), ("smallz4cat-x32-v1.4", "x86/ventoy/tool/lz4cat")):
    add(f"IMG/cpio_{ref}", U + f, X + ref, "exact", "upstream")
for f, t in (("busybox_ASH-1.31.0-i686-uclibc", "ash"), ("busybox_HEXDUMP-1.30.0-i686", "hexdump"), ("busybox_XZCAT-1.30.0-i686", "xzcat")):
    add(f"INSTALL/tool/i386/{t}", U + f, f"{G}INSTALL/tool/i386/{t}", "exact", "upstream")
    add(f"INSTALL/tool/i386/{t} [release]", U + f, f"{RT}tool/i386/{t}", "exact", "upstream")


def load(path, tmp):
    """Readable path for a check operand ('xz:' = decompress, 'syslinux:' = memdisk from the tarball)."""
    if path.startswith("xz:"):
        out = os.path.join(tmp, hashlib.sha1(path.encode()).hexdigest())
        if os.path.isfile(path[3:]):
            with open(path[3:], "rb") as f, open(out, "wb") as o:
                o.write(lzma.decompress(f.read()))
        return out
    if path == "syslinux:":
        out = os.path.join(tmp, "memdisk")
        tgz = C + "syslinux-6.03.tar.xz"
        if os.path.isfile(tgz) and not os.path.isfile(out):
            with tarfile.open(tgz) as t, open(out, "wb") as o:
                o.write(t.extractfile("syslinux-6.03/bios/memdisk/memdisk").read())
        return out
    if not os.path.isfile(path) and os.path.isfile(path + ".xz"):
        return load("xz:" + path + ".xz", tmp)    # the release tarball ships most tools .xz-compressed
    return path


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def check(rebuilt, ref, mode, tmp):
    a, b = load(rebuilt, tmp), load(ref, tmp)
    missing = [p for p in (a, b) if not os.path.isfile(p)]
    if missing:
        return None, "missing " + os.path.relpath(missing[0] if missing[0] != a else rebuilt, ROOT)
    if mode in ("exact", "same"):
        ok = sha(a) == sha(b)
        return ok, sha(b)[:12] if ok else f"{sha(a)[:12]} != {sha(b)[:12]}"
    tool = {"pe": f"{G}EDK2/ci/compare_signed_pe.py", "buildid": f"{RP}/tools/compare_elf.py"}[mode]
    r = subprocess.run([sys.executable, "-I", tool, a, b], capture_output=True, text=True)
    last = (r.stdout.strip().splitlines() or ["?"])[-1].strip()
    if mode == "pe":
        return r.returncode == 0, last
    return last.startswith("ONLY THE GNU BUILD ID DIFFERS"), last


def main():
    verbose = "-v" in sys.argv
    fails = skipped = 0
    passed = set()
    with tempfile.TemporaryDirectory() as tmp:
        for entry, rebuilt, ref, mode, note in CHECKS:
            ok, msg = check(rebuilt, ref, mode, tmp)
            if ok is None:
                skipped += 1
                if verbose:
                    print(f"SKIP  {mode:7} {entry:58} {msg}")
                continue
            fails += not ok
            if ok:
                passed.add(entry.replace(" [release]", ""))
            print(f"{'PASS' if ok else 'FAIL'}  {mode:7} {entry:58} {note + ': ' if note else ''}{msg}")
    print(f"\n{len(CHECKS) - skipped} checks run, {fails} failed, {skipped} skipped (inputs not built/fetched); "
          f"{len(passed)} distinct list entries passed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
