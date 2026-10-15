# Reproducing Ventoy's prebuilt binaries

This directory rebuilds the prebuilt binaries listed in the opening post of
[ventoy/Ventoy#3224](https://github.com/ventoy/Ventoy/issues/3224) from the published source.
It then compares each one byte for byte with the copy committed in git and the copy in the release.
Results for Ventoy **1.1.18** are summarised in
[this comment](https://github.com/ventoy/Ventoy/issues/3224#issuecomment-6198393891), and given in
full in [`FINDINGS.md`](FINDINGS.md) and [`BLOB_STATUS.md`](BLOB_STATUS.md).

**For 1.1.18, 104 of the 179 entries are verified:**
- 92 are rebuilt from source.
- 12 are identical to the upstream download that Ventoy's docs point to.
- 2 more match except for the GNU build ID, and 2 come from source that was never published.

## Running it

```sh
sh REPRODUCE/run.sh all              # or individual steps, e.g.: sh REPRODUCE/run.sh fetch images grub verify
python3 REPRODUCE/verify.py          # re-run just the comparison
```

Needs on the host: docker, curl, git, python3, patch, xz, unzip, mtools (`mcopy`), cpio and
sha256sum. A full run takes roughly an hour and a few GB of disk. The run creates:
- `REPRODUCE/cache`: downloads, all pinned by SHA-256 in [`inputs.txt`](inputs.txt)
- `REPRODUCE/out`: build outputs
- `REPRODUCE/ref`: the release, unpacked (`ventoy-$VER-linux.tar.gz`, checked against the release's `sha256.txt`)

| Step | Builds | Container |
|---|---|---|
| `smalltools` | `vtoycli`, `vlnk` (4 arches), `vtoytool/00/*`, `vtoy_fuse_iso_64` | CentOS 7.5 / 7.9, and "mixed": libc built by 7.5's gcc, program by 7.9's |
| `grub` | `grubx64_real.efi`, `grubia32_real.efi`, `BOOTAA64.EFI`, `BOOTMIPS.EFI` | 7.9 (+ Linaro 7.4.1, Loongson gcc 7.3) |
| `ipxe`, `wimboot` | `ipxe.krn`; `wimboot.x86_64`, `wimboot.i386.efi` | 7.9 |
| `exfat` | exFAT x86_64/i386, `vtoy_fuse_iso_32`/`_aa64` | 7.5; **32-bit CentOS 6.10 / 6.9** |
| `xzminidec` | `xzminidec{32,64,64_musl,aa64,m64e}` (from the b63ce2a tree) | 7.5 |
| `livecd` | `LiveCD/GRUB/bootx64.efi` (from the a29bdfb tree) | 7.9 |
| `linuxgui` | `V2DServer`, `Plugson` (current and 4df793e trees), `VentoyGUI`, `Ventoy2Disk.gtk2/gtk3` | **7.5 glibc-devel + 7.9's gcc** |
| `tools` | lunzip, lz4cat, zstdcat, dmsetup (device-mapper 1.02.28), vblade | 7.5; CentOS 6 i386 |
| `busybox` | BusyBox 1.32.0 `ash`/`hexdump`/`xzcat` (x86_64/aarch64/mips64el), full arm64/mips64 builds | 7.5 + musl / Bootlin / mips musl |
| `edk2` | EFI apps and EfiFs drivers ([`EDK2/ci/run-all.sh`](../EDK2/ci/run-all.sh)) | 7.9 |

Expected noise: in the `smalltools-mixed` run, `FUSEISO/build_libfuse.sh` reports `FAILED`. The
saved musl has no dynamic loader for configure's test program. Only `vtoycli`/`vlnk` are taken from that run;
`vtoy_fuse_iso_64` comes from `smalltools-c75`. Likewise `tools-c75` fails `dmsetup64` (`dmsetup.static: No
such file`); `tools-fix-c75` builds it with the loader in place.

Each `build/*.sh` script runs inside its container with the repo mounted read-only at `/src`,
downloads at `/dl` and the output directory at `/out`. Most of them run Ventoy's own build
scripts unmodified, at the original path `/home/share/Ventoy`.

## What the comparison needs to match

Each of these is needed to match at least one binary. None of them is documented in the repo:

- **Build path**:
  - EDK2 embeds `__FILE__` strings; libfuse embeds its install prefix.
  - 32-bit tools were built under `/root/ExFAT`, `/root` and `/root/dmsetup`. The path reaches either a string in the binary or, through debug info, the GNU build ID.
  - The cross toolchains must be installed under `/opt/...`.
- **Compiler per binary** (read `.comment`): pure 7.5, pure 7.9, or "7.5 with gcc updated to 7.9" (two stamps, `-28` and `-44`). The 32-bit tools need CentOS 6.9 or 6.10 i386.
- **Locale**: VtoyTool's `*.c` glob order depends on the locale; release builds used a UTF-8 locale.
- **libfuse zip layout**: the release builds used the gitee `mirrors-libfuse-fuse-2.9.9.zip`, which unpacks to `libfuse/`. `run.sh fetch` makes it from the pinned codeload zip.
- **Older trees**: `xzminidec*` (b63ce2a), git's `Plugson` (4df793e) and the LiveCD GRUB (a29bdfb) predate later source changes. `run.sh` fetches those commits by SHA.

## Unpublished changes

[`patches/`](patches) holds the two edits that the shipped binaries contain but the published
source doesn't. `run.sh grub` and `run.sh ipxe` apply them by default; with `EDIT=0` they build the published
source as-is, which then does **not** match.

- [`grub-bitmap_scale.diff`](patches/grub-bitmap_scale.diff): upstream `grub-core/video/bitmap_scale.c`, two error messages
- [`ipxe-bootsector.diff`](patches/ipxe-bootsector.diff): `printf(" ")` at the start of `call_bootsector()`

## Layout

| Path | Contents |
|---|---|
| `run.sh`, `inputs.txt`, `verify.py` | driver, pinned downloads, comparison |
| `build/` | container-side build scripts |
| `docker/` | build images. `build-repro` is the repo's own `Dockerfile` image with its RPM database rebuilt (it can come out corrupt); `centos75` is adapted from ventoy/Ventoy#3752; `c75-gcc44` is 7.5 glibc + 7.9 gcc; `centos6-i386` is 32-bit CentOS 6.10 (`GCC_PIN=4.4.7-18` for 6.9's gcc); `centos5` is used for the `vtoytool/01` experiment |
| `tools/` | `compare_elf.py` (section diff; reports "only the build ID differs"), `grub_mods.py` (GRUB `mods` section), `ipxe_unpack.py` (iPXE LZMA payload), `applets.py` (BusyBox applet table), `pe_inspect.py`, `vlnk_parse.py` (`.vlnk` format), `survey.sh`, `cmp_tools.sh` |
| `experiments/` | the sweeps behind negative or partial results: `lz4cat` flag variants, the dmsetup32 build directory, XZ Utils for `xzcat*_musl` (not matched), Bootlin i686 BusyBox (not matched), and CentOS 5 `vtoytool/01` (not matched: source not published) |
| `FINDINGS.md` | the full write-up. It refers to scripts by their names in the original analysis workspace (see the table below) |
| `BLOB_STATUS.md` | every #3224 entry with its status |

Original workspace name → file here:

| Workspace | Here |
|---|---|
| `smalltools/ci/build.sh`, `Dockerfile.centos75`, `compare_elf.py` | `build/smalltools.sh`, `docker/centos75.Dockerfile`, `tools/compare_elf.py` |
| `grub/build_grub.sh`, `build_grub_mips.sh`, `grub_mods.py`, `bitmap_scale_hypothesis.diff` | `build/grub.sh`, `build/grub_mips.sh`, `tools/grub_mods.py`, `patches/grub-bitmap_scale.diff` |
| `p456/build_ipxe.sh`, `build_wimboot.sh`, `ipxe_unpack.py`, `ipxe_bootsector_hypothesis.diff` | `build/ipxe.sh`, `build/wimboot.sh`, `tools/ipxe_unpack.py`, `patches/ipxe-bootsector.diff` |
| `next10/build_c7.sh`, `build_c6.sh`, `build_xz.sh`, `build_livecd_grub.sh`, `build_c5.sh` | `build/exfat_fuseiso_c7.sh`, `build/exfat_fuseiso_c6.sh`, `build/xzminidec.sh`, `build/livecd_grub.sh`, `experiments/vtoytool01_centos5.sh` |
| `batch3/build_web.sh`, `build_vgui.sh`, `build_gtk_x86.sh`, `Dockerfile.c75-gcc44*` | `build/linuxgui_{web,vgui,gtk}.sh`, `docker/c75-gcc44*.Dockerfile` |
| `batch4/build_tools_c75.sh`, `build_fix_c75.sh`, `build_tools_c6.sh`, `lz4_variants.sh`, `dm32_paths.sh` | `build/tools_c75.sh`, `build/tools_fix_c75.sh`, `build/tools_c6.sh`, `experiments/lz4cat_flags.sh`, `experiments/dmsetup32_paths.sh` |
| `verify/regen_lz4.sh` | `build/lz4cat.sh` (the flags that match, which differ from `LZIP/buildlz4.txt`) |
| `batch5/build_bb.sh`, `run_cross.sh`, `applets.py`, `xz_*.sh`, `run_i686.sh` | `build/busybox.sh`, `build/busybox_cross.sh`, `tools/applets.py`, `experiments/xz_*.sh`, `experiments/busybox_i686_bootlin.sh` |
| `verify/verify_all.py` | `verify.py` (same checks, plus release copies for every architecture) |

`tools_c75.sh` also builds `lz4cat` the way `LZIP/buildlz4.txt` documents. Those three outputs do **not**
match; `build/lz4cat.sh` produces the matching ones.

Not covered: the shims, MokManager and Super-UEFIinSecureBoot loaders (third-party signed),
Windows binaries, BSD kernel modules, the Qt5 GUIs, and the GTK GUIs for i386, aarch64 and mips64el.
See `BLOB_STATUS.md` for the rest.

The scripts and analysis were written with an AI assistant (Claude). Every result above is a
byte comparison that `verify.py` re-runs.
