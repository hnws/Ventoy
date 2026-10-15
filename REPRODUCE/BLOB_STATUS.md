# Ventoy #3224 blob list: status by group

> Per-entry status for Ventoy 1.1.18. "FINDINGS §n" refers to [FINDINGS.md](FINDINGS.md).

Source: opening post of ventoy/Ventoy#3224 (179 entries).

| Status | Entries |
|---|---:|
| Solved here: EFI apps + EfiFs drivers (FINDINGS §5.1) | 12 |
| Solved here: small tools (FINDINGS §7) | 13 |
| Solved here: GRUB images, **given one unpublished two-line change** (FINDINGS §7) | 3 |
| Solved here: wimboot ×2, **given three upstream `.S` files missing from the repo** (FINDINGS §8) | 2 |
| Solved here: `ipxe.krn`, **given one unpublished `printf(" ")`** (FINDINGS §8) | 1 |
| Solved here: exFAT ×4, FUSE ISO ×2, xzminidec ×3, LiveCD GRUB ×2 (FINDINGS §9) | 11 |
| Solved here: `BOOTMIPS.EFI`, **given the same unpublished `bitmap_scale.c` change** (FINDINGS §9) | 1 |
| Solved here: `memdisk` = upstream syslinux 6.03's own prebuilt binary (FINDINGS §9) | 1 |
| Code and data identical, only the GNU build ID differs (`xzminidec32`/`64`, FINDINGS §9) | 2 |
| **Not reproducible: built from source never published** (`vtoytool/01`, `/02`, FINDINGS §9) | 2 |
| Solved here: Ventoy's Linux host tools: V2DServer ×4, Plugson ×4, VentoyGUI ×3, Ventoy2Disk.gtk3/gtk2 x86_64 (FINDINGS §10) | 13 |
| Solved here: third-party initramfs tools: lz4cat ×6, lunzip ×3, zstdcat ×6, dmsetup ×4, vblade ×3 (FINDINGS §11) | 22 |
| Solved here: LiveCD `vmlinuz64` = TinyCore 11.x's own kernel (FINDINGS §11) | 1 |
| Solved here: BusyBox rebuilt from 1.32.0 source: x86_64/aarch64/mips64el ash+hexdump+xzcat (+ `64h`, `a64`, `m64`), `busyboxaa64`, `busyboxm64e` (FINDINGS §12) | 14 |
| Identical to upstream prebuilts: busybox.net `busybox32`/`busybox64`/LiveCDGUI copy, per-applet `ar`/`inotifyd`/`ash` ×2/`hexdump`/`xzcat` (i386), smallz4cat `lz4cat` (FINDINGS §12) | 10 |
| Covered by open PR ventoy/Ventoy#3752 (not merged) | 10 |
| **Unresolved** | **61** |

Of the 104 solved here (12 of them identical to upstream prebuilt downloads rather than rebuilt), 14 match only the release, because the git copy is stale
(6 EDK2 apps, 4 `vtoytool`, 4 GRUB images). Plugson's git copies are also stale, but they were
reproduced from their own 2023 source, and the x86_64 release copy from v1.1.18. The rest match git.
5 of the 104 needed source that Ventoy hasn't published (GRUB ×4, iPXE), and 2 needed
upstream files missing from the repo (wimboot).

## Ten picks for next (status as of 2026-10-15)

Chosen for: Ventoy's own or Ventoy-modified code, runs at boot or as root, buildable with
toolchains already pinned here or in #3752, and (for groups) one build covering several entries.

| # | Entry | Why | Toolchain / risk | Status |
|---|---|---|---|---|
| 1 | `./INSTALL/EFI/BOOT/grubx64_real.efi` | Ventoy's modified GRUB 2.04: runs the whole boot menu on x64 UEFI | CentOS 7 gcc. Ventoy-signed, so compare without the signature. Rebuilt by `all_in_one.sh` on every release, so like the EDK2 apps the git copy may be stale: compare against the release | ✅ with unpublished `bitmap_scale.c` change |
| 2 | `./INSTALL/EFI/BOOT/grubia32_real.efi` | Same GRUB build, ia32 | Same build as #1 | ✅ with unpublished `bitmap_scale.c` change |
| 3 | `./INSTALL/EFI/BOOT/BOOTAA64.EFI` | Same GRUB build, arm64 | Linaro 7.4.1, already pinned here | ✅ with unpublished `bitmap_scale.c` change |
| 4 | `./INSTALL/ventoy/ipxe.krn` | Ventoy-modified iPXE (3fe683e), the BIOS-mode chainloader | CentOS 7 gcc via `IPXE/buildipxe.sh`. Also rebuilt every release | ✅ given unpublished `printf(" ")` |
| 5 | `./INSTALL/ventoy/wimboot.x86_64` | Ventoy-modified wimboot 2.7.3, on the Windows boot path | Plain `make` in `wimboot/`. Committed as `.xz` | ✅ byte-identical, missing `.S` restored |
| 6 | `./INSTALL/ventoy/wimboot.i386.efi` | Same wimboot build | Same build as #5 | ✅ byte-identical, missing `.S` restored |
| 7 | `./VtoyTool/vtoytool/00/vtoytool_64` | Ventoy's own tool, runs as root in the initramfs during boot | dietlibc 0.34 static. #3752 found it may need CentOS 7.5's gcc-4.8.5-28 and showed how to get dietlibc | ✅ byte-identical to release |
| 8 | `./INSTALL/tool/x86_64/vtoycli` | Ventoy's own installer helper. Runs as root and rewrites MBR/GPT and FAT (decompiled earlier in this project) | dietlibc / musl static | ✅ byte-identical |
| 9 | `./INSTALL/tool/x86_64/vlnk` | Ventoy's own `.vlnk` tool, whose file format we already decoded and verified | dietlibc / musl static | ✅ byte-identical |
| 10 | `./FUSEISO/vtoy_fuse_iso_64` | Ventoy's own FUSE ISO mounter from the initramfs | musl 1.2.1 static (+ libfuse) | ✅ byte-identical |

## Next ten picks (done 2026-10-15)

| # | Entry (and same-build extras) | Status |
|---|---|---|
| 11 | `./INSTALL/ventoy/memdisk` | ✅ identical to syslinux 6.03's prebuilt `bios/memdisk/memdisk` |
| 12 | `./FUSEISO/vtoy_fuse_iso_aa64` | ✅ byte-identical (Bootlin uclibc 2020.08-1) |
| 13 | `./FUSEISO/vtoy_fuse_iso_32` | ✅ byte-identical (CentOS 6.9 i386) |
| 14 | `./INSTALL/tool/x86_64/mkexfatfs` | ✅ byte-identical (CentOS 7.5) |
| 15 | `./INSTALL/tool/x86_64/mount.exfat-fuse` | ✅ byte-identical, libfuse unpacked as `libfuse/` |
| 16 | `./INSTALL/tool/i386/mkexfatfs` + `mount.exfat-fuse` | ✅ byte-identical (CentOS 6.10 i386, automake 1.11.2) |
| 17 | `./IMG/cpio_x86/ventoy/busybox/xzminidec64` (+ `32`, `64_musl`, `aa64`, `m64e`) | ✅ 3 byte-identical; `32`/`64` identical except the build ID. Source as of b63ce2a, git binaries predate 1.0.58's casts |
| 18 | `./INSTALL/EFI/BOOT/BOOTMIPS.EFI` | ✅ matches the release with the unpublished `bitmap_scale.c` change; git copy stale |
| 19 | `./LiveCD/GRUB/bootx64.efi` (= `./LiveCDGUI/GRUB/bootx64.efi`) | ✅ byte-identical, `grub-mkimage` reconstructed |
| 20 | `./VtoyTool/vtoytool/01/vtoytool_64` (= `02/`) | ❌ pre-repository build (CentOS 5, old dietlibc) with functions not in any published source |

Still open in the same groups: `INSTALL/tool/{aarch64,mips64el}/{mkexfatfs,mount.exfat-fuse}`.
The aarch64 builds record CentOS 7 aarch64's native gcc (4.8.5-36/-39), so they need an
aarch64 build host or emulation. The mips64el ones are glibc-linked and carry no compiler stamp.

## Third ten picks (done 2026-10-15): Ventoy's own Linux host tools

| # | Entry | Status |
|---|---|---|
| 21–24 | `./INSTALL/tool/{x86_64,i386,aarch64,mips64el}/V2DServer` | ✅ byte-identical (CentOS 7.5 + gcc -44; toolchains under `/opt`) |
| 25–28 | `./INSTALL/tool/{x86_64,i386,aarch64,mips64el}/Plugson` | ✅ git copies from the 2023 tree (4df793e); x86_64 release from v1.1.18 |
| 29–31 | `./INSTALL/VentoyGUI.{x86_64,i386,aarch64}` | ✅ byte-identical |
| 32 | `./INSTALL/tool/x86_64/Ventoy2Disk.gtk3` (+ `gtk2`) | ✅ byte-identical (CentOS 7.5 GTK headers) |

Blocked in the same group:
- `VentoyGUI.mips64el` and `mips64el/Ventoy2Disk.gtk3` need the unpublished Loongson gcc 8.3.0 toolchain.
- The Qt5 builds need the Qt 5.9.0 SDK or `EXLIB` sysroots.
- i386/aarch64 GTK need i686 GTK devel packages or `EXLIB/aarch64`.

## Fourth batch: 15 picks (done 2026-10-15), third-party initramfs tools

| # | Entry (+ identical copies) | Status |
|---|---|---|
| 33–35 | `./LZIP/lunzip{32,64,aa64}` | ✅ byte-identical |
| 36–38 | `./LZIP/lz4cat{64,aa64,m64e}` (+ `IMG/cpio_*/ventoy/tool/` copies) | ✅ byte-identical, flags differ from `buildlz4.txt` |
| 39–41 | `./ZSTD/zstdcat{,64,aa64}` (+ `IMG/cpio_*/ventoy/tool/` copies) | ✅ byte-identical |
| 42–45 | `./DMSETUP/dmsetup{32,64,aa64,m64e}` | ✅ byte-identical (`dmsetup32` built in `/root/dmsetup`) |
| 46 | `./VBLADE/vblade-master/vblade_{32,64,aa64}` | ✅ byte-identical |
| 47 | `./LiveCD/ISO/EFI/boot/vmlinuz64` | ✅ = TinyCore 11.x upstream |

Still open nearby: `IMG/cpio_x86/ventoy/tool/lz4cat` (7 KB, no compiler stamp), unsquashfs ×3 (patched squashfs 4.4,
aa64 built natively on arm64), veritysetup ×2 (Ubuntu 18.04 / Debian 10 hosts), and all the BusyBox builds.

## Fifth batch: 20 picks (done 2026-10-15), BusyBox and DOC §5 downloads

| # | Entry (+ identical copies) | Status |
|---|---|---|
| 48–50 | `./INSTALL/tool/x86_64/{ash,hexdump,xzcat}` (+ `IMG/.../64h`) | ✅ rebuilt (musl, build.txt) |
| 51–53 | `./INSTALL/tool/aarch64/{ash,hexdump,xzcat}` (+ `IMG/.../a64`) | ✅ rebuilt (Bootlin) |
| 54–56 | `./INSTALL/tool/mips64el/{ash,hexdump,xzcat}` (+ `IMG/.../m64`) | ✅ rebuilt (mips musl, banner time from config header) |
| 57 | `./IMG/cpio_arm64/ventoy/busybox/busyboxaa64` | ✅ rebuilt (defconfig + static + ar + inotifyd) |
| 58 | `./IMG/cpio_mips64/ventoy/busybox/busyboxm64e` | ✅ rebuilt (defconfig + static) |
| 59–60 | `./IMG/cpio_x86/ventoy/busybox/busybox{32,64}` (+ `LiveCDGUI/EXT/busybox-x86_64`) | ✅ = busybox.net prebuilt multiarch |
| 61–66 | `./IMG/cpio_x86/ventoy/{busybox/ash,tool/ar,tool/inotifyd}`, `./INSTALL/tool/i386/{ash,hexdump,xzcat}` | ✅ = busybox.net per-applet downloads (DOC §5) |
| 67 | `./IMG/cpio_x86/ventoy/tool/lz4cat` | ✅ = smallz4cat-x32-v1.4 (DOC 5.1) |
| — | `./IMG/cpio_x86/ventoy/busybox/xzcat64_musl` | ❌ not matched: XZ Utils 5.2.5 + musl; `-O3` is 656 bytes off |

None of Ventoy's own sources for these (`vtoycli`, `Vlnk/src`, `VtoyTool`, `FUSEISO`,
GRUB `grub-core/ventoy`, `IPXE/ipxe_mod_code`, wimboot) use `__DATE__`/`__TIME__`.
That is a good sign, but the upstream parts of GRUB, iPXE and wimboot weren't checked.

### Deliberately not picked
- **Third-party signed loaders** (shims, MokManager, Super-UEFIinSecureBoot `grub.efi`/`grubia32.efi`):
  signed by Microsoft or distros, so they can only be checked by hash against their upstream
  sources, not rebuilt.
- **BSD kernel modules** (20): need FreeBSD/DragonFly builders.
- **Windows binaries** (15): need MSVC. ImDisk is a third-party driver.
- **GTK/Qt GUIs, Plugson, V2DServer**: large dependency trees. Possible later.
- **BusyBox and third-party Linux tools** (58): mostly upstream code. Lower Ventoy-specific risk, and
  some are already documented with upstream hashes.

# Full grouped list

Marked entries: ✅ reproduced here, ≈ code identical but build ID differs, ❌ cannot be checked
(source not published). The EFI group (0) and the vtchmod group (1) are labelled in their headings.
Unmarked entries are unresolved.

## 1 Covered by open PR ventoy/Ventoy#3752 (vtchmod) (10)

- `./BUSYBOX/chmod/vtchmod32`
- `./BUSYBOX/chmod/vtchmod64`
- `./BUSYBOX/chmod/vtchmod64_musl`
- `./BUSYBOX/chmod/vtchmodaa64`
- `./BUSYBOX/chmod/vtchmodm64e`
- `./IMG/cpio_arm64/ventoy/busybox/vtchmodaa64`
- `./IMG/cpio_mips64/ventoy/busybox/vtchmodm64e`
- `./IMG/cpio_x86/ventoy/busybox/vtchmod32`
- `./IMG/cpio_x86/ventoy/busybox/vtchmod64`
- `./IMG/cpio_x86/ventoy/busybox/vtchmod64_musl`

## 10 Third-party Linux tools (dmsetup, veritysetup, unsquashfs, lz4/lunzip, zstd, vblade) (28)

- `./cryptsetup/veritysetup32`
- `./cryptsetup/veritysetup64`
- `./DMSETUP/dmsetup32` — ✅ §11
- `./DMSETUP/dmsetup64` — ✅ §11
- `./DMSETUP/dmsetupaa64` — ✅ §11
- `./DMSETUP/dmsetupm64e` — ✅ §11
- `./IMG/cpio_arm64/ventoy/tool/lz4cataa64` — ✅ §11 (= LZIP copy)
- `./IMG/cpio_arm64/ventoy/tool/zstdcataa64` — ✅ §11 (= ZSTD copy)
- `./IMG/cpio_mips64/ventoy/tool/lz4catm64e` — ✅ §11 (= LZIP copy)
- `./IMG/cpio_x86/ventoy/tool/lz4cat` — ✅ = upstream prebuilt §12
- `./IMG/cpio_x86/ventoy/tool/lz4cat64` — ✅ §11 (= LZIP copy)
- `./IMG/cpio_x86/ventoy/tool/zstdcat` — ✅ §11 (= ZSTD copy)
- `./IMG/cpio_x86/ventoy/tool/zstdcat64` — ✅ §11 (= ZSTD copy)
- `./LZIP/lunzip32` — ✅ §11
- `./LZIP/lunzip64` — ✅ §11
- `./LZIP/lunzipaa64` — ✅ §11
- `./LZIP/lz4cat64` — ✅ §11 (undocumented flags)
- `./LZIP/lz4cataa64` — ✅ §11 (undocumented flags)
- `./LZIP/lz4catm64e` — ✅ §11 (undocumented flags)
- `./SQUASHFS/unsquashfs_32`
- `./SQUASHFS/unsquashfs_64`
- `./SQUASHFS/unsquashfs_aa64`
- `./VBLADE/vblade-master/vblade_32` — ✅ §11
- `./VBLADE/vblade-master/vblade_64` — ✅ §11
- `./VBLADE/vblade-master/vblade_aa64` — ✅ §11
- `./ZSTD/zstdcat` — ✅ §11
- `./ZSTD/zstdcat64` — ✅ §11
- `./ZSTD/zstdcataa64` — ✅ §11

## 8 Ventoy's own initramfs tools (vtoytool, vtoy_fuse_iso) (9)

- `./FUSEISO/vtoy_fuse_iso_32` — ✅ §9
- `./FUSEISO/vtoy_fuse_iso_64` — ✅ §7
- `./FUSEISO/vtoy_fuse_iso_aa64` — ✅ §9
- `./VtoyTool/vtoytool/00/vtoytool_32` — ✅ §7 (release)
- `./VtoyTool/vtoytool/00/vtoytool_64` — ✅ §7 (release)
- `./VtoyTool/vtoytool/00/vtoytool_aa64` — ✅ §7 (release)
- `./VtoyTool/vtoytool/00/vtoytool_m64e` — ✅ §7 (release)
- `./VtoyTool/vtoytool/01/vtoytool_64` — ❌ source not published §9
- `./VtoyTool/vtoytool/02/vtoytool_64` — ❌ source not published §9

## 9 BusyBox builds and applets in the initramfs (18)

- `./IMG/cpio_arm64/ventoy/busybox/a64` — ✅ rebuilt §12 (= INSTALL ash)
- `./IMG/cpio_arm64/ventoy/busybox/xzminidecaa64` — ✅ §9
- `./IMG/cpio_mips64/ventoy/busybox/m64` — ✅ rebuilt §12 (= INSTALL ash)
- `./IMG/cpio_mips64/ventoy/busybox/xzminidecm64e` — ✅ §9
- `./IMG/cpio_x86/ventoy/busybox/64h` — ✅ rebuilt §12 (= INSTALL ash)
- `./IMG/cpio_x86/ventoy/busybox/ash` — ✅ = upstream prebuilt §12
- `./IMG/cpio_x86/ventoy/busybox/xzminidec32` — ≈ build ID only §9
- `./IMG/cpio_x86/ventoy/busybox/xzminidec64` — ≈ build ID only §9
- `./IMG/cpio_x86/ventoy/busybox/xzminidec64_musl` — ✅ §9
- `./IMG/cpio_x86/ventoy/tool/ar` — ✅ = upstream prebuilt §12
- `./IMG/cpio_x86/ventoy/tool/inotifyd` — ✅ = upstream prebuilt §12
- `./LiveCDGUI/EXT/busybox-x86_64` — ✅ = upstream prebuilt §12
- `./IMG/cpio_x86/ventoy/busybox/busybox32` — ✅ = upstream prebuilt §12
- `./IMG/cpio_x86/ventoy/busybox/busybox64` — ✅ = upstream prebuilt §12
- `./IMG/cpio_x86/ventoy/busybox/xzcat32_musl`
- `./IMG/cpio_x86/ventoy/busybox/xzcat64_musl`
- `./IMG/cpio_arm64/ventoy/busybox/busyboxaa64` — ✅ rebuilt §12
- `./IMG/cpio_mips64/ventoy/busybox/busyboxm64e` — ✅ rebuilt §12

## 3 Ventoy-modified GRUB 2.04 images (6)

- `./INSTALL/EFI/BOOT/BOOTAA64.EFI` — ✅ with unpublished bitmap_scale edit (release) §7
- `./INSTALL/EFI/BOOT/BOOTMIPS.EFI` — ✅ with unpublished bitmap_scale edit (release) §9
- `./INSTALL/EFI/BOOT/grubia32_real.efi` — ✅ with unpublished bitmap_scale edit (release) §7
- `./INSTALL/EFI/BOOT/grubx64_real.efi` — ✅ with unpublished bitmap_scale edit (release) §7
- `./LiveCDGUI/GRUB/bootx64.efi` — ✅ §9
- `./LiveCD/GRUB/bootx64.efi` — ✅ §9

## 2 Third-party signed loaders (shims, MokManager, Super-UEFIinSecureBoot) (6)

- `./INSTALL/EFI/BOOT/grub.efi`
- `./INSTALL/EFI/BOOT/BOOTIA32.EFI`
- `./INSTALL/EFI/BOOT/BOOTX64.EFI`
- `./INSTALL/EFI/BOOT/grubia32.efi`
- `./INSTALL/EFI/BOOT/mmia32.efi`
- `./INSTALL/EFI/BOOT/MokManager.efi`

## 6 BusyBox applets in INSTALL/tool (12)

- `./INSTALL/tool/aarch64/ash` — ✅ rebuilt §12
- `./INSTALL/tool/aarch64/hexdump` — ✅ rebuilt §12
- `./INSTALL/tool/aarch64/xzcat` — ✅ rebuilt §12
- `./INSTALL/tool/i386/ash` — ✅ = upstream prebuilt §12
- `./INSTALL/tool/i386/hexdump` — ✅ = upstream prebuilt §12
- `./INSTALL/tool/i386/xzcat` — ✅ = upstream prebuilt §12
- `./INSTALL/tool/mips64el/ash` — ✅ rebuilt §12
- `./INSTALL/tool/mips64el/hexdump` — ✅ rebuilt §12
- `./INSTALL/tool/mips64el/xzcat` — ✅ rebuilt §12
- `./INSTALL/tool/x86_64/ash` — ✅ rebuilt §12
- `./INSTALL/tool/x86_64/hexdump` — ✅ rebuilt §12
- `./INSTALL/tool/x86_64/xzcat` — ✅ rebuilt §12

## 4 Ventoy's own Linux host tools (INSTALL/tool, VentoyGUI) (30)

- `./INSTALL/tool/aarch64/Ventoy2Disk.gtk3`
- `./INSTALL/tool/i386/Ventoy2Disk.gtk3`
- `./INSTALL/tool/i386/Ventoy2Disk.gtk2`
- `./INSTALL/tool/mips64el/Ventoy2Disk.gtk3` — blocked: unpublished Loongson gcc 8 §10
- `./INSTALL/tool/x86_64/Ventoy2Disk.gtk3` — ✅ §10
- `./INSTALL/tool/x86_64/Ventoy2Disk.gtk2` — ✅ §10
- `./INSTALL/tool/aarch64/Ventoy2Disk.qt5`
- `./INSTALL/tool/i386/Ventoy2Disk.qt5`
- `./INSTALL/tool/mips64el/Ventoy2Disk.qt5`
- `./INSTALL/tool/x86_64/Ventoy2Disk.qt5`
- `./INSTALL/tool/aarch64/Plugson` — ✅ §10 (git, 2023 tree)
- `./INSTALL/tool/i386/Plugson` — ✅ §10 (git, 2023 tree)
- `./INSTALL/tool/mips64el/Plugson` — ✅ §10 (git, 2023 tree)
- `./INSTALL/tool/x86_64/Plugson` — ✅ §10 (git and release)
- `./INSTALL/tool/aarch64/V2DServer` — ✅ §10
- `./INSTALL/tool/i386/V2DServer` — ✅ §10
- `./INSTALL/tool/mips64el/V2DServer` — ✅ §10
- `./INSTALL/tool/x86_64/V2DServer` — ✅ §10
- `./INSTALL/tool/aarch64/vlnk` — ✅ §7
- `./INSTALL/tool/i386/vlnk` — ✅ §7
- `./INSTALL/tool/mips64el/vlnk` — ✅ §7
- `./INSTALL/tool/x86_64/vlnk` — ✅ §7
- `./INSTALL/tool/aarch64/vtoycli` — ✅ §7
- `./INSTALL/tool/i386/vtoycli` — ✅ §7
- `./INSTALL/tool/mips64el/vtoycli` — ✅ §7
- `./INSTALL/tool/x86_64/vtoycli` — ✅ §7
- `./INSTALL/VentoyGUI.aarch64` — ✅ §10
- `./INSTALL/VentoyGUI.i386` — ✅ §10
- `./INSTALL/VentoyGUI.mips64el` — blocked: unpublished Loongson gcc 8 §10
- `./INSTALL/VentoyGUI.x86_64` — ✅ §10

## 5 exFAT tools (exfat 1.3.0 + Ventoy patches) (8)

- `./INSTALL/tool/aarch64/mkexfatfs`
- `./INSTALL/tool/aarch64/mount.exfat-fuse`
- `./INSTALL/tool/i386/mkexfatfs` — ✅ §9
- `./INSTALL/tool/i386/mount.exfat-fuse` — ✅ §9
- `./INSTALL/tool/mips64el/mkexfatfs`
- `./INSTALL/tool/mips64el/mount.exfat-fuse`
- `./INSTALL/tool/x86_64/mkexfatfs` — ✅ §9
- `./INSTALL/tool/x86_64/mount.exfat-fuse` — ✅ §9

## 7 Windows binaries (Ventoy2Disk, vtoyjump, Plugson/Vlnk .exe, ImDisk) (15)

- `./INSTALL/ventoy/imdisk/32/imdisk.cpl`
- `./INSTALL/ventoy/imdisk/32/imdisk.exe`
- `./INSTALL/ventoy/imdisk/32/imdisk.sys`
- `./INSTALL/ventoy/imdisk/64/imdisk.cpl`
- `./INSTALL/ventoy/imdisk/64/imdisk.exe`
- `./INSTALL/ventoy/imdisk/64/imdisk.sys`
- `./INSTALL/Ventoy2Disk.exe`
- `./INSTALL/Ventoy2Disk_ARM.exe`
- `./INSTALL/Ventoy2Disk_ARM64.exe`
- `./INSTALL/Ventoy2Disk_X64.exe`
- `./INSTALL/ventoy/vtoyjump32.exe`
- `./INSTALL/ventoy/vtoyjump64.exe`
- `./Plugson/vs/VentoyPlugson/Release/VentoyPlugson.exe`
- `./Plugson/vs/VentoyPlugson/x64/Release/VentoyPlugson_X64.exe`
- `./Vlnk/vs/VentoyVlnk/Release/VentoyVlnk.exe`

## 0 SOLVED here (EFI apps + EfiFs drivers) (12)

- `./INSTALL/ventoy/iso9660_aa64.efi`
- `./INSTALL/ventoy/udf_aa64.efi`
- `./INSTALL/ventoy/iso9660_ia32.efi`
- `./INSTALL/ventoy/udf_ia32.efi`
- `./INSTALL/ventoy/iso9660_x64.efi`
- `./INSTALL/ventoy/udf_x64.efi`
- `./INSTALL/ventoy/ventoy_aa64.efi`
- `./INSTALL/ventoy/ventoy_ia32.efi`
- `./INSTALL/ventoy/ventoy_x64.efi`
- `./INSTALL/ventoy/vtoyutil_aa64.efi`
- `./INSTALL/ventoy/vtoyutil_ia32.efi`
- `./INSTALL/ventoy/vtoyutil_x64.efi`

## 11 Boot payloads (iPXE, wimboot, memdisk, TinyCore kernel) (5)

- `./INSTALL/ventoy/ipxe.krn` — ✅ with unpublished printf §8
- `./INSTALL/ventoy/memdisk` — ✅ = syslinux 6.03 prebuilt §9
- `./LiveCD/ISO/EFI/boot/vmlinuz64` — ✅ = TinyCore 11.x §11
- `./INSTALL/ventoy/wimboot.i386.efi` — ✅ with restored upstream .S §8
- `./INSTALL/ventoy/wimboot.x86_64` — ✅ with restored upstream .S §8

## 12 BSD binaries (geom_ventoy.ko, DragonFly dmsetup/init) (20)

- `./Unix/ventoy_unix/DragonFly/sbin/dmsetup`
- `./Unix/ventoy_unix/DragonFly/sbin/init`
- `./Unix/ventoy_unix/ClonOS/geom_ventoy_ko/13.x/64/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/10.x/32/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/10.x/64/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/11.x/32/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/11.x/64/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/12.x/32/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/12.x/64/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/13.x/32/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/13.x/64/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/14.x/32/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/14.x/64/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/9.x/32/geom_ventoy.ko`
- `./Unix/ventoy_unix/FreeBSD/geom_ventoy_ko/9.x/64/geom_ventoy.ko`
- `./Unix/ventoy_unix/MidnightBSD/geom_ventoy_ko/11.x/32/geom_ventoy.ko`
- `./Unix/ventoy_unix/MidnightBSD/geom_ventoy_ko/11.x/64/geom_ventoy.ko`
- `./Unix/ventoy_unix/MidnightBSD/geom_ventoy_ko/2.x/32/geom_ventoy.ko`
- `./Unix/ventoy_unix/MidnightBSD/geom_ventoy_ko/2.x/64/geom_ventoy.ko`
- `./Unix/ventoy_unix/pfSense/geom_ventoy_ko/14.x/64/geom_ventoy.ko`

