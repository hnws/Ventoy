# Ventoy analysis

> This is the analysis write-up as kept during the work. Script paths below refer to the original
> analysis workspace (`smalltools/ci/`, `grub/`, `p456/`, `next10/`, `batch3/`–`batch5/`, `verify/`). See the
> mapping table in [README.md](README.md) for where each one lives in `REPRODUCE/`. `src/Ventoy` means this repository.

Target: `ventoy-bin 1.1.18-1` installed at `/opt/ventoy`, cross-checked against the
Ventoy source at tag `v1.1.18` (commit `6116894`, "1.1.18 release"), cloned to
`src/Ventoy`. Analysis engine: REA with Ghidra 12.1.2. All findings are from static
analysis of shipped binaries and from the published source; nothing was booted.

## Status at a glance (2026-10-15)

Measured against the 179-entry blob list in the opening post of ventoy/Ventoy#3224
(per-entry status: `unresolved_blobs.md`):

| | Entries | Where |
|---|---:|---|
| Reproduced byte for byte (PE images apart from Ventoy's signature) | **104** | §5.1, §7–§12 |
| … of which identical to an upstream prebuilt download rather than rebuilt | 12 | §9, §11, §12 |
| Code and data identical, only the GNU build ID differs | 2 | §9 (`xzminidec32`/`64`) |
| Cannot be checked: built from source that was never published | 2 | §9 (`vtoytool` 01/02); §13: analysed with REA, reachable code matches published logic, unpublished parts are dead debug code |
| Covered by open PR ventoy/Ventoy#3752 (not re-checked here) | 10 | §6 |
| Unresolved | 61 | `unresolved_blobs.md` |

Findings worth reporting upstream:
1. **Unpublished edits in shipped binaries.**
   - All four 1.1.18 GRUB images (x64, ia32, aa64, mips64el) carry a two-line `bitmap_scale.c` change (§7, §9).
   - `ipxe.krn` carries an added `printf(" ")` in `call_bootsector()` (§8).
   - Both edits are harmless debug leftovers, each proven by rebuilding with exactly that edit.
2. **Missing source.**
   - wimboot's `prefix.S`/`startup.S`/`callback.S` aren't in the repo (§8).
   - `vtoytool/01`, `/02` contain code that isn't in any published revision (§9).
   - The `grub-mkimage` command for the LiveCD GRUB was never published (§9; reconstructed).
   - The Loongson gcc 8 toolchain used for the mips64el GUI isn't published (§10).
3. **Git and release disagree, or git binaries don't match the current source.** See "Git vs
   release, consolidated" at the end of §9. Anyone verifying against git sees false mismatches
   for the EDK2 apps, GRUB and `vtoytool` 00.
4. **Undocumented build inputs.** The release builds depend on things the docs don't mention:
   - build paths (`/home/share/Ventoy`, `/root/ExFAT`, `/root`)
   - mixed CentOS 7.5/7.9 compilers
   - 32-bit CentOS 6.9/6.10 and CentOS 5 hosts
   - a UTF-8 locale
   - the gitee libfuse zip layout
   - CentOS 7.5 glibc-devel with 7.9's gcc (§10)
   - cross toolchains under `/opt` (§10)
   - flags other than the documented ones for `lz4cat` (§11)
   - `/root/dmsetup` as dmsetup32's build directory (§11)
5. **Wrong documentation.** `BLOB_List.md` calls the busybox.net prebuilts and XZ Utils "full busybox" builds,
   and DOC 4.18 names the wrong libc for `64h` (§12).

Secure Boot shim pieces (`fbx64.efi`/VtoyShim, shims, MokManager) are deliberately out of
scope and are described only at a high level (§3).

**Posted:** a summary of these results went to ventoy/Ventoy#3224 on 2026-10-15
(https://github.com/ventoy/Ventoy/issues/3224#issuecomment-6198393891; text in
`drafts/issue-3224-comment.md`). Before posting, every claim was re-checked by `verify/verify_all.py`
(116 checks, all pass; output in `verify/verify_all.txt`). The re-check corrected two statements: the iPXE size
difference (§8) and the vtoytool 01/02 function list (§9).

**Scripts published:** branch [`reproducible-builds`](https://github.com/hnws/Ventoy/tree/reproducible-builds)
on the hnws/Ventoy fork (commit b5eb57c, on top of the EDK2 CI commit b96925e). It adds `REPRODUCE/` with `run.sh`, pinned inputs,
build images, build scripts, tools, patches, `verify.py` and this write-up. A from-scratch
`sh REPRODUCE/run.sh all` passes all 155 checks, including release copies for every architecture. The #3224 comment was edited (18:23 UTC) to
append a link to this branch, rather than posting a new comment.

## 1. Binaries committed in the Ventoy source repo

The repo is 2,888 files / 183 MB. It ships a large number of **prebuilt** binaries
rather than building everything from source:

| Count | Kind |
|------:|------|
| 1,602 | text / source |
| 604 | ELF object/relocatable (`.o`, mostly prebuilt GRUB modules) |
| 359 | compressed blobs (`.xz`/`.gz` payloads: cpio, efiboot img, grub, etc.) |
| 111 | ELF executables / shared libraries |
| 38 | PE / EFI images (Windows `.exe`, UEFI `.efi`) |
| 13 | archives (tar/zip/7z/cpio) |
| 12 | disk / boot images |
| 110 | images, 18 fonts, 21 other binary data |

Full per-file listing of everything non-text: `repo_binaries.txt`.
Classification source data: `repo_filetypes.tsv`.

The 38 PE/EFI files include Ventoy's own UEFI apps (`ventoy_*.efi`, `vtoyutil_*.efi`,
`iso9660_*.efi`, `udf_*.efi`), distro shims/MokManager (`BOOTX64.EFI`, `mmx64.efi`, …),
GRUB (`grubx64_real.efi`), Windows installers (`Ventoy2Disk*.exe`), the ImDisk driver,
and `vtoyjump*.exe`. The 111 committed ELF executables are mostly the `INSTALL/tool/<arch>/`
helpers (the same `vtoycli`/`vlnk`/`vtoygpt`/`V2DServer`/etc. that ship in the package)
plus bundled busybox, dmsetup, cryptsetup, squashfs, zstd, fuseiso and vblade builds for
four architectures.

## 2. `.vlnk` shortcut file format  (from tool/x86_64/vlnk)

32,768-byte file; only the first 512 bytes carry data:

| Offset | Size | Field |
|--------|-----:|-------|
| 0x000 | 16 | magic `"  www.ventoy.net"` |
| 0x010 | 4 | CRC-32C (Castagnoli, poly 0x1EDC6F41) of bytes 0x000-0x1FF with this field zeroed |
| 0x014 | 4 | target disk MBR signature (MBR offset 0x1B8) |
| 0x018 | 8 | target partition start offset in bytes (start LBA × 512) |
| 0x020 | ≤383 | NUL-terminated image path relative to that partition |

Independent parser/builder: `vlnk_parse.py` — verified byte-identical to the real
tool's output and accepted by `vlnk -t`.

## 3. UEFI Secure Boot chain  (from the VTOYEFI partition)

Extracted image: `extracted/ventoy.disk.img` (32 MB FAT16 labelled `VTOYEFI`),
contents under `extracted/vtoyefi/`. PE signer/section inspector: `pe_inspect.py`.

Chain: firmware → `BOOTX64.EFI` (genuine **Rocky Linux** shim, MS-signed) →
(first run) `mmx64.efi` MokManager enrolls `ENROLL_THIS_KEY_IN_MOKMANAGER.cer`
(**Ventoy Secure Boot Root CA**, self-signed, valid 2026-06-20 → 2126) →
`grubx64.efi` (actually `fbx64.efi`, Ventoy's `VtoyShim.dll`) → `grubx64_real.efi` (GRUB 2).

`fbx64.efi` reads the `SecureBoot`/`SetupMode` UEFI variables; when Secure Boot is on it
locates the shim lock protocol and replaces the firmware Security/Security2 architectural
protocol callbacks before launching real GRUB. Effect: once Ventoy's key is enrolled and
its shim is trusted, the signature check is bypassed for everything GRUB subsequently
chainloads. This is documented Ventoy behaviour (`SecureBoot.md`) and is why specific
Ventoy shim builds have appeared in UEFI revocation (`dbx`) lists.

ia32 shim/MokManager carry **Fedora** identities; x64 carry **Rocky Linux**. All Ventoy
EFI apps and the EfiFs drivers are signed by the Ventoy Secure Boot Root CA. EDK2 base is
`stable201911` (confirmed by build paths embedded in `vtoyutil`).

## 4. `ventoy_x64.efi` — how it boots an ISO  (source: EDK2/.../Application/Ventoy)

Entry point `VentoyEfiMain` (`Ventoy.inf` BASE_NAME=Ventoy, GUID 1c3a0915-…):
1. `ventoy_parse_cmdline` reads the **chain** that GRUB placed in memory.
2. `ventoy_install_blockio` exposes the ISO as a virtual EFI BlockIo device built from the
   chain's image/override/virt chunk tables (so the real ISO on disk + small patched
   regions appear as one contiguous optical disk), or a RAM disk in memdisk mode.
3. Optionally loads the `iso9660`/`udf` EfiFs driver so firmware can read the ISO.
4. `ventoy_boot` finds that file system, loads the ISO's own `EFI/BOOT/BOOTX64.EFI` and
   `StartImage`s it, with `ventoy_hook_start/stop` wrapping file-replacement hooks.

### The chain interface (GRUB → EFI app), from `include/grub/ventoy.h`
`ventoy_chain_head` = `ventoy_os_param os_param` followed by disk geometry, real/virtual
image sizes, a 2048-byte boot catalog, and three (offset,count) chunk tables:
`img_chunk` (where the real ISO data lives on disk), `override_chunk` (small patches),
`virt_chunk` (synthesized regions). `ventoy_os_param` (header: `VENTOY_GUID` + 1-byte
checksum) carries the disk GUID, disk size, partition id/type, `vtoy_img_path[384]`, image
size, the runtime image-location block, and a 32-byte reserved area whose fields select
Linux/Windows/wim chain type, iso9660-vs-udf, vlnk, etc.

## 5. Reproducible rebuild of the EFI binaries

Build is done the sanctioned way: CentOS 7 container (`Dockerfile`) that pins the
GCC 4.8-era toolchain + `acpica-tools`/`nasm`, EDK2 base `edk2-stable201911.zip`
downloaded from tianocore, Ventoy's modified tree overlaid from `EDK2/edk2_mod/`.
Scoped to X64 only (the repo's `buildedk.sh` also builds ia32/aa64/mips, which need
cross-compilers the Dockerfile does not install).

**Result: verified reproducible build.** Building under the same absolute path the
original used (`/home/share/Ventoy/EDKII/…`, via `EDK2/build_x64_repro.sh`) so the
embedded `__FILE__` strings match, the rebuilt `Ventoy.efi` is **byte-for-byte identical
to the shipped `ventoy_x64.efi` in all three sections** (`.text`, `.data`, `.reloc` —
0 differing bytes each). The shipped file is 80,304 bytes vs the rebuild's 77,824; the
extra 2,480 bytes are an appended Authenticode signature (PE Certificate Table at offset
77,824). Only **7 bytes** differ in the unsigned image, all in the PE header and all
signature-related:
- offsets 3760-3763 = PE optional-header **checksum** field
- offsets 3840-3847 = **Certificate Table** data-directory entry (points at the sig)

So the published source compiles to exactly the shipped binary; the sole real difference
is Ventoy's code-signing. Build artifacts:
`src/Ventoy/EDK2/ventoy_x64.repro.efi` (path-matched, sections identical) and
`ventoy_x64.rebuilt.efi` (built under our path; same sizes, differs only in the embedded
build-path strings and resulting rodata shift).

A first build under our own path (`EDK2/build_x64_only.sh`) produced the same section
sizes but ~15 KB of shifted bytes purely because the longer build-path strings folded
into `.text` shifted all following rodata and their references — eliminated once the path
matched, which is itself good evidence the only non-signature variance was the build path.

Note: a rebuilt binary is **not** signed by the Ventoy CA, so it only boots with Secure
Boot off. Re-signing into the Secure Boot chain is out of scope.

### 5.1 All Ventoy-built EFI binaries (x64, ia32, aa64)

Every EFI binary that Ventoy compiles itself, from the 1.1.18 package, was rebuilt and
compared with `EDK2/ci/compare_signed_pe.py`. The script cuts the shipped file at its
Certificate Table, compares each section byte for byte, and names every differing header
byte. Distro shims, MokManager, GRUB and Ventoy's shim loader (`fbx64.efi`) were out of scope.

| Binary | Source | Sections identical to 1.1.18 package | Header bytes differing (all signing fields) | Committed copy in git at v1.1.18 |
|---|---|---|---|---|
| ventoy_x64.efi | Ventoy EDK2 app | yes (.text/.data/.reloc = 0) | 7: CheckSum, CertificateTable | **stale**: last changed 1.0.78 (2022-07-01) |
| ventoy_ia32.efi | Ventoy EDK2 app | yes | 7 | stale (1.0.78) |
| ventoy_aa64.efi | Ventoy EDK2 app | yes | 7 | stale (1.0.78) |
| vtoyutil_x64.efi | Ventoy EDK2 app | yes | 5 | stale (1.0.78) |
| vtoyutil_ia32.efi | Ventoy EDK2 app | yes | 5 | stale (1.0.78) |
| vtoyutil_aa64.efi | Ventoy EDK2 app | yes | 6 | stale (1.0.78) |
| iso9660_x64.efi | efifs `37e58c9`–`61494b4` + Ventoy patch | yes | 7 | matches (unsigned blob from the 2020-04-04 initial commit) |
| udf_x64.efi | efifs `37e58c9`–`61494b4` + Ventoy patch | yes | 7 | matches (unsigned blob added 2020-12-11) |
| iso9660_ia32.efi | efifs `6e00f7e` + Ventoy patch | yes | 7 | matches (signed) |
| udf_ia32.efi | efifs `6e00f7e` + Ventoy patch | yes | 7 | matches (signed) |
| iso9660_aa64.efi | efifs `6e00f7e` + Ventoy patch | yes | 6 | matches (signed) |
| udf_aa64.efi | efifs `6e00f7e` + Ventoy patch | yes | 5 | matches (signed) |

The number of differing header bytes varies (5–7) only because some bytes of the
checksum and Certificate Table entry happen to agree by chance. Every differing byte
falls inside those two fields.

**Result: 12 of 12 match.** Apart from code signing, every Ventoy-built EFI binary in
1.1.18 is reproduced from public source.

#### Findings along the way
- **Committed EDK2 app blobs are stale.** `INSTALL/ventoy/ventoy_*.efi` and `vtoyutil_*.efi`
  in git were last updated in the 1.0.78 release (2022-07-01). Their source kept changing
  through 2026-06-29. The committed copies are unsigned, 10–13 KB smaller, and lack newer
  features such as Windows UEFI resolution locking (`ventoy_lock_res`). This doesn't reach
  users, because `INSTALL/all_in_one.sh` (Ventoy's CI) runs `EDK2/buildedk.sh` on every
  build and overwrites them. The 1.1.18 package contains fresh builds. Anyone taking
  `INSTALL/` straight from git, without running the build, would get 2022 binaries.
- **The x64 EfiFs drivers are 2020 builds, re-signed.** `iso9660_x64.efi` dates from Ventoy's
  initial commit (2020-04-04). `udf_x64.efi` was added on 2020-12-11, in the same commit
  (`ebaa4d9`) as the ia32/aa64 drivers. Neither was rebuilt afterwards, and the 1.1.18
  package ships those same bytes plus a 2026 Ventoy signature. **Both x64 drivers** were
  built from efifs master of 29 Feb–1 Mar 2020 (`37e58c9`, `0648a42` and `61494b4` give
  identical output). The ia32/aa64 drivers committed alongside `udf_x64.efi` match an
  **older** efifs base, `6e00f7e` (2019-09). The files in Ventoy's `EDK2/efiffs/org/` are
  consistent with that older base (they match efifs `58ceb03`–`6e00f7e`). Ventoy's
  2020-12-11 "Code Optimize" change to its efifs patch is whitespace only.
- **Ventoy's efifs changes** (`EDK2/efiffs/org` → `mod`): an `FS_NAME_NOCASE` UEFI variable
  that makes ISO9660 filename lookup case-insensitive, plus a fix to the
  `EFI_BUFFER_TOO_SMALL` handling in `GetInfo`. The org/ base also includes efifs's own
  `0000-GRUB-fixes.patch` applied to GRUB `4dd4ceec0`.
- **The x64 driver's efifs base can't be pinned to one commit.** Three adjacent commits give
  identical output. Commits before `4687c08` don't build against EDK2 stable201911 at all,
  because they reference `IntelFrameworkModulePkg`. `3ffbb6e` and later give different
  bytes. `e8be3c6` and later (GRUB update, then version 1.4) are excluded.

#### Toolchain and inputs
- Build image: the repo's `Dockerfile` (`centos:7` =
  `sha256:be65f488b7764ad3638f236b7b515b3678369a5124c47b8d32916d6487418ea4`, CentOS 7.9,
  gcc-4.8.5-44, nasm 2.10.07, acpica-tools 20160527).
- EDK2: `edk2-stable201911.zip`, SHA-256 `c6f691aa…49c1a60b`. This matches the hash pinned
  independently in PR #3755.
- aa64: Linaro GCC 7.4-2019.02 (`gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu`,
  SHA-256 `27f1dc2c…6fcac1bf9ab`). Linaro's own download site no longer serves this
  file, so it came from Ventoy's mirror (`ventoy/vtoytoolchain` release 1.0) and **was not
  checked against a Linaro-published checksum**. The resulting matches are strong
  circumstantial evidence that it's the toolchain Ventoy used.
- efifs: pbatard/efifs commits as listed, GRUB submodule `4dd4ceec0`, with efifs's
  `0000-GRUB-fixes.patch` and Ventoy's `EDK2/ventoy_efifs.patch` (= `efiffs/org` → `mod`).

Scripts: `src/Ventoy/EDK2/build_repro_all.sh` (Ventoy/VtoyUtil apps),
`build_efifs_repro.sh` (drivers; `PREPATCHED=1` applies Ventoy's patch as a diff), and
`ci/compare_signed_pe.py` (comparison, exits non-zero on any other difference).

## 6. Prior work (GitHub search, 2026-10-15)

Short answer: **others have worked on this, but I found no one who has shown
`ventoy_x64.efi` (or any Ventoy EDK2 app) to be byte-identical to the shipped
binary.** Searched ventoy/Ventoy issues and PRs, GitHub repositories, and the web.
Raw API responses are saved in `prior_work/`.

| Who / where | What they did | Relation to this work |
|---|---|---|
| ventoy/Ventoy #2795 (2024, closed, 170 comments) "Remove BLOBs from the source tree" | Community inventory of committed binaries; Long0x0 found 142/153 blobs had build scripts or docs; fnr1r identified the EFI shims and the Super-UEFIinSecureBoot-Disk origin of some loaders | Inventory only. No rebuilds |
| ventoy/Ventoy #3224 (2025–, open, 132 comments) "About the BLOBs in Ventoy" | Maintainer created `BLOB_List.md`; rbeede (2026-06-05) cross-checked documented upstream SHA-256s against committed files; Thrilleratplay (2026-01) called the EDK2 path a "herculean task" | Hash checks of upstream blobs. No EDK2 rebuild |
| PR #3229 (2025, open) "Remove 7zip BLOBs" | Reproducible 7za.exe from source via GitHub Actions | Explicitly does *not* match the shipped bytes |
| **PR #3752** (2026-09-15, open, LoomNode) | CI rebuilds the 5 `vtchmod*` tools in a digest-pinned CentOS 7.5 container and requires `cmp`-identical output to the committed files | **Closest precedent.** Same method as ours (byte-identical to committed), but different binaries. Notes that CentOS 7.5's gcc 4.8.5-28 is needed there (7.8's -39 gives different bytes) |
| **PR #3755** (2026-09-20, open, jmccarey) "Build modernization" | Modernized build incl. EDK2; `verify_reproducibility.sh` does a two-pass A/B build and compares A against B (covers `ventoy_x64.efi`, `vtoyutil_x64.efi`, `fbx64.efi`) | Checks only that its *own* builds agree, not that they match the shipped binaries. Also patches BaseTools (drops `-Werror`, Python fixes) |
| fnr1r / `ventoy-ng` org (2025) | Independent rebuild effort: EDK2 apps, GRUB, iPXE, cpio build "with fixes for newer toolchains" (Lemmy progress post) | Builds from source but makes no byte-identical claim against shipped binaries |

### Second search pass (2026-10-15, after the 12/12 result)

Searched again more widely: targeted GitHub issue/PR searches (efifs, iso9660_x64.efi,
vtoyutil, edk2, byte-identical, stale), the branches of every active fork, the latest
activity on #3224/#3752/#3755, extended web searches (forks, blogs, Codeberg/GitLab,
HN), and distro packaging. **I still found no published byte-for-byte rebuild of any
Ventoy EDK2 app or EfiFs driver, against either the release or git.** New items found:

| Who / where | What it does | Relation to this work |
|---|---|---|
| **tilas01/Ventoy-Reproducible** (fork, created 2026-09-09, synced to upstream every 10 min) | Builds Ventoy's binaries in GitHub Actions on a digest-pinned CentOS 7, builds each twice in different directories, and publishes a signed manifest plus a `ventoy-verify` tool | Closest overall effort, but its README lists "the EDK2 EFI binaries" as **"wired but not yet enabled"**, and its `blobs.yml` workflow has no EDK2 step. It compares against the binaries **committed in git**, which for the EDK2 apps are the stale 1.0.78 files, so a correct rebuild would show up there as a mismatch. Its `toolchains.lock` pins the same EDK2 zip (`c6f691aa…`) and Linaro tarball (`27f1dc2c…`) SHA-256s as ours |
| rdevshp, #3224 (2026-07-23) | Nix-based "deblob" build patch, generated by Codex and posted with the note "not properly reviewed" | Checked only that `nix build` succeeds. No comparison with shipped binaries |
| AUR `ventoy` (source build, Toolybird) | Rebuilds the Ventoy/VtoyUtil EDK2 apps on modern Arch, switching the toolchain from GCC48 to GCC5 and stripping `-Werror` | A working rebuild, not byte-identical, and nothing is compared. The EfiFs drivers are **copied prebuilt** from upstream. aa64 isn't built |
| nixpkgs `ventoy` | Packages the 1.1.18 release tarball | No rebuild |
| GPLaider/Ventoid (Android app) | Bundles the checksum-verified 1.1.18 payload | Explicitly makes no reproducibility claim for the signed EFI binaries |
| HN item 44810281; nixsanctuary.com "Ventoy – 718 Shades of Open Source" (2025-01-30) | Discussion and a blob-counting critique | Neither rebuilds or compares anything |

Still unique to this work: (1) the byte-level match of all 12 Ventoy-built EFI
binaries against the signed 1.1.18 release, (2) identification of the two efifs
bases, and of the x64 drivers as a re-signed 2020 build, (3) the finding that the
committed EDK2 app blobs are stale since 1.0.78. Point (3) matters to anyone,
Ventoy-Reproducible included, who checks rebuilds against git instead of a release.

### What this work adds
- A byte-level match of **all 12 Ventoy-built EFI binaries** in 1.1.18 (Ventoy and
  VtoyUtil apps, iso9660/udf EfiFs drivers; x64/ia32/aa64), see §5.1. The only
  differences are the 2,480-byte Authenticode signature plus the PE checksum and
  Certificate-Table header fields.
- The exact efifs bases: `6e00f7e` for ia32/aa64, and `37e58c9`–`61494b4` (Feb/Mar 2020)
  for x64.
- Two discrepancies between git and the release: the committed EDK2 app blobs are stale
  (1.0.78), and the x64 EfiFs drivers are a 2020 build that was re-signed.
- A CI draft in the style of PR #3752, local branch `ci/edk2-efi-reproducible` (commit
  `b96925e`) in `src/Ventoy`, **not pushed**. `EDK2/ci/run-all.sh` passed end to end
  locally against the checksum-verified ventoy-1.1.18 release tarball.
- The key that makes it work: EDK2 RELEASE builds embed absolute `__FILE__` paths, so the
  tree must sit at `/home/share/Ventoy/EDKII/edk2-edk2-stable201911`. Under any other
  path, ~15 KB of `.text` shifts.
- Toolchain data point: it matched with CentOS **7.9**, `gcc-4.8.5-44`, binutils 2.27-44,
  using the repo's own `Dockerfile` (`centos:7`) unmodified. Unlike `vtchmod` in #3752,
  this EFI app did not need an exact older gcc patch release. Untested whether 7.5's gcc
  also matches.
- Possibly relevant to #3755: because `__FILE__` paths are embedded, a pass-B build in a
  different directory will normally differ from pass A unless the build path is fixed or
  normalized. I haven't run their scripts, so this is worth checking, not a finding.

Sources: https://github.com/ventoy/Ventoy/issues/2795 ·
https://github.com/ventoy/Ventoy/issues/3224 · https://github.com/ventoy/Ventoy/pull/3229 ·
https://github.com/ventoy/Ventoy/pull/3752 · https://github.com/ventoy/Ventoy/pull/3755 ·
https://github.com/ventoy-ng · https://piefed.jeena.net/post/159810 ·
https://discourse.ubuntu.com/t/is-balena-etcher-safe/75966 ·
https://github.com/tilas01/Ventoy-Reproducible · https://github.com/GPLaider/Ventoid ·
https://aur.archlinux.org/packages/ventoy · https://news.ycombinator.com/item?id=44810281 ·
https://nixsanctuary.com/ventoy-718-shades-of-open-source/

## 7. More binaries from the #3224 list: small tools and GRUB

Picks 7–10 and 1–3 from `unresolved_blobs.md`, plus the extra entries the same builds
produced. All compared byte for byte (ELF tools with `smalltools/ci/compare_elf.py`, PE
images with `compare_signed_pe.py`, GRUB modules with `grub/grub_mods.py`).

### Results: 16 more list entries reproduce

| List entry | Reference | Result | Built with |
|---|---|---|---|
| `INSTALL/tool/x86_64/vtoycli` | release = git | **byte-identical** (`fa94676d…`) | program: CentOS 7.9 gcc-4.8.5-44; musl 1.2.1 built by CentOS 7.5 gcc-4.8.5-28 |
| `INSTALL/tool/x86_64/vlnk` | release = git | **byte-identical** (`f06c9bdb…`) | same as vtoycli |
| `INSTALL/tool/i386/{vtoycli,vlnk}` | git | **byte-identical** | program 7.9; dietlibc 0.34 built by 7.5 |
| `INSTALL/tool/{aarch64,mips64el}/{vtoycli,vlnk}` | git | **byte-identical** (4 files) | Bootlin uclibc 2020.08-1 / ventoy musl-cross-make (pins from #3752) |
| `FUSEISO/vtoy_fuse_iso_64` | release = git | **byte-identical** (`7a8e2091…`) | CentOS 7.5 gcc-4.8.5-28, musl 1.2.1, libfuse 2.9.9 (codeload zip `636cdf34…`), built at `/home/share/Ventoy` |
| `VtoyTool/vtoytool/00/vtoytool_{64,32}` | release | **byte-identical** (`_64` = `7eb5bf7c…`) | CentOS 7.9 gcc-4.8.5-44, dietlibc built by -44, **`LC_ALL=en_US.UTF-8`** |
| `VtoyTool/vtoytool/00/vtoytool_{aa64,m64e}` | release | **byte-identical** | cross compilers as above |
| `INSTALL/EFI/BOOT/grubx64_real.efi` | release | sections identical, signature only (`42cc383c…` unsigned) | see "GRUB" below |
| `INSTALL/EFI/BOOT/grubia32_real.efi` | release | sections identical, signature only (`ef3d1417…` unsigned) | see "GRUB" below |
| `INSTALL/EFI/BOOT/BOOTAA64.EFI` | release | **byte-identical** (`3b93a998…`) | see "GRUB" below |

The reproduction depended on several details:
- **Mixed compilers.** The x86 `vtoycli`/`vlnk` carry two GCC stamps in `.comment`: the
  libc was compiled by CentOS 7.5's gcc-4.8.5-28, the program by CentOS 7.9's -44. That
  fits a build host that was upgraded from 7.5 to 7.9 without rebuilding
  `/usr/local/musl` and `/opt/diet32`. It was reproduced by building the libcs in a 7.5
  container and the tools in a 7.9 container. Every loaded section already matched without
  this. Only the non-loaded `.comment` differed.
- **Locale changes link order.** `VtoyTool/build.sh` compiles `*.c BabyISO/*.c`. Under a
  UTF-8 locale the glob puts `biso_9660.c` before `biso.c`; under the C locale it's the
  other way round, which shuffles about 8 KB of `.text`. The release was built under a UTF-8 locale.
- **Embedded build path.** libfuse bakes its install prefix
  (`/home/share/Ventoy/FUSEISO/LIBFUSE/bin/fusermount`) into `vtoy_fuse_iso_64`.
- **Different tools, different compilers.** `vtoy_fuse_iso_64` (built in 2020) is pure 7.5,
  `vtoytool` (2026) is pure 7.9, and `vtoycli`/`vlnk` are mixed.

### GRUB: the release contains an unpublished two-line change

The tarball `grub-2.04.tar.xz` (SHA-256 `e5292496…`) matches ftp.gnu.org, Ventoy's mirror
and Ventoy-Reproducible's pin, and has a good GPG signature from GRUB maintainer Daniel
Kiper. The key is not in the local web of trust. Ventoy's own `buildgrub.sh` commands
were run for x86_64/i386/arm64-efi at `/home/share/Ventoy` (CentOS 7.9 gcc -44,
`en_US.UTF-8`, Linaro 7.4.1 for arm64, an `x86_64-linux-gnu-gcc` symlink for CentOS).
Whether the locale matters for GRUB was not tested.

Built from the published v1.1.18 source, the GRUB kernel (`.text`), `.data` and `.reloc`
are identical in all three images, as are **103 of 104 embedded modules** (93 of 94 on
arm64). The one exception is **`bitmap_scale.mod`**, which is 72–80 bytes larger in the
release. Its strings show both "requested to scale to a size w/ a zero dimension" errors
changed to `"1 … %d %d"` and `"2 … %d %d"`.

- That text is in neither upstream GRUB (2.04, 2.12, current master) nor anywhere in the
  Ventoy repo at v1.1.18 or in the commits since the tag. Ventoy doesn't keep
  `bitmap_scale.c` under `GRUB2/MOD_SRC`, so it is built from the upstream file.
- Rebuilding with exactly this change (`grub/bitmap_scale_hypothesis.diff`) makes all three
  images match the release: `grubx64_real.efi`/`grubia32_real.efi` apart from the signature,
  `BOOTAA64.EFI` as a whole file.

```
100: "1 requested to scale to a size w/ a zero dimension %d %d", dst_width, dst_height);
202: "2 requested to scale to a size w/ a zero dimension %d %d", dst_width, dst_height);
```

So the shipped 1.1.18 GRUB = the published source + this local edit, which only adds the
requested width and height to two error messages. It looks like leftover debugging
instrumentation. It is harmless, but it means the published source doesn't exactly
correspond to the shipped binary. The GRUB images committed in git are stale since 1.0.98 (2024-05-19).

### Git vs release, updated
More stale blobs: `VtoyTool/vtoytool/00/*` (last committed 1.1.01, Feb 2025; VtoyTool source
changed through 2026-10-08) and `grubx64_real.efi`/`grubia32_real.efi`/`BOOTAA64.EFI`
(1.0.98). Like the EDK2 apps, these are rebuilt for releases but not committed.

Scripts: `smalltools/ci/{Dockerfile.centos75,fetch.sh,SHA256SUMS,build.sh,compare_elf.py}`
(scaffold adapted from ventoy/Ventoy#3752; `PREBUILT_LIBC`/`SAVE_LIBC` for the mixed
build), `grub/{build_grub.sh,grub_mods.py,bitmap_scale_hypothesis.diff}`.

## 8. iPXE and wimboot (picks 4–6)

| List entry | Reference | Result |
|---|---|---|
| `INSTALL/ventoy/wimboot.x86_64` | git (unsigned); release = git + 2026 Ventoy signature | **byte-identical to git** (`2d6f38be…`) once three missing upstream `.S` files are restored |
| `INSTALL/ventoy/wimboot.i386.efi` | same | **byte-identical to git** (`7fac83b2…`), same condition |
| `INSTALL/ventoy/ipxe.krn` | release = git (both from 2022) | **byte-identical** (`11521fae…`) **given one unpublished line** |

### wimboot: published source is missing three files
- Ventoy ships wimboot 2.7.3 with 8 modified C files. The 1.1.18 release's `wimboot.x86_64`
  and `wimboot.i386.efi` are the 2022 (1.0.80) git builds plus a Ventoy Authenticode
  signature: all sections are identical, and only CheckSum and the Certificate Table differ.
  This is the same pattern as the x64 EfiFs drivers.
- **`prefix.S`, `startup.S` and `callback.S` are not in Ventoy's repo**, so the published tree
  can't build wimboot (`No rule to make target 'prefix.x86_64.o'`). The cause is almost
  certainly wimboot's own `src/.gitignore` entry `*.s` (meant for generated assembly), which
  also matches `*.S` when git runs on a case-insensitive filesystem (Windows/macOS).
- Taking the three files from upstream wimboot v2.7.3 (`fc3ee1e`) reproduces both binaries
  byte for byte, on CentOS 7.9 and 7.5 alike. That also proves Ventoy did not modify them.
  `efireloc` needs `binutils-devel` (libbfd), which the repo's Dockerfile doesn't install.

### iPXE: the release contains an unpublished `printf(" ")`
- `IPXE/ipxe_org_code/ipxe-3fe683e.tar.bz2` is **identical to upstream iPXE at commit
  3fe683e** (0 differing files). Ventoy patches about 15 files, adds its own
  `ventoy_int13.c`, `ventoy_vdisk.c` and others, and its build script **deletes `src/drivers`**
  before copying in its own, keeping only the drivers it carries.
- iPXE links a random build ID and a `date +%s` timestamp, but in this BIOS build both
  variables are discarded. They appear only in the symbol table, never in the image.
- Built from the published source (`bin/ipxe.lkrn`, which is what the ISO's `ipxe.krn` is),
  the image differed: the file is 18 bytes larger (it's LZMA-compressed), and the decompressed
  payload is 16 bytes smaller (118,624 vs 118,640). To compare, I decompressed both LZMA payloads
  (raw LZMA1, lc=2 lp=0 pb=0, behind iPXE's x86 BCJ-style call filter). Everything matched
  up to `call_bootsector()`, after which everything was shifted by 16 bytes. The shipped
  `call_bootsector()` starts with an extra `push <" ">; call printf`.
- Adding exactly **`printf(" ");` at the start of `call_bootsector()`** in upstream
  `arch/x86/image/bootsector.c`, a file Ventoy does not otherwise modify, makes `ipxe.krn`
  **byte-identical** (`p456/ipxe_bootsector_hypothesis.diff`). Neither the compiler patch
  level (CentOS 7.5 vs 7.9) nor the locale made any difference here.

So both of the large Ventoy-modified boot components rebuilt here, GRUB and iPXE, ship with
a one- or two-line debugging edit that isn't in the published source. Both edits are
harmless (an extra space printed, and extra numbers in two error messages). But in both
cases the shipped binary doesn't exactly correspond to the published source.

Scripts: `p456/build_wimboot.sh` (`UPSTREAM_S=` restores the `.S` files),
`p456/build_ipxe.sh` (`HYPOTHESIS_DIR=` overlay; `IPXE_BUILD_ID`/`IPXE_BUILD_TIMESTAMP`
overrides), `p456/ipxe_unpack.py` (LZMA payload unpacker).

## 9. Next ten picks (2026-10-15)

13 more list entries now reproduce byte for byte, 2 match except for the GNU build ID, and
2 are shown to come from source that was never published. Scripts are in `next10/`.

| List entry | Reference | Result | Built with |
|---|---|---|---|
| `INSTALL/ventoy/memdisk` | release = git | **identical to upstream's prebuilt** `bios/memdisk/memdisk` in syslinux-6.03.tar.xz (kernel.org, SHA-256 `26d3986d…`, matching kernel.org's `sha256sums.asc` listing; that file's PGP signature was not checked) | not rebuilt; Ventoy ships syslinux's own binary |
| `FUSEISO/vtoy_fuse_iso_aa64` | release = git | **byte-identical** (`8c423c2e…`) | Bootlin aarch64 uclibc 2020.08-1, `build_libfuse_aarch64.sh` + `build_aarch64.sh`, at `/home/share/Ventoy` |
| `FUSEISO/vtoy_fuse_iso_32` | release = git | **byte-identical** (`05737af1…`) | **CentOS 6.9 i386**, gcc-4.4.7-18, musl 1.2.1, FUSEISO files in `/root` |
| `INSTALL/tool/x86_64/mkexfatfs` | release = git | **byte-identical** (`8de9ffce…`) | CentOS 7.5 gcc-4.8.5-28, exfat 1.3.0 (codeload zip), at `/home/share/Ventoy/ExFAT` |
| `INSTALL/tool/x86_64/mount.exfat-fuse` | release = git | **byte-identical** (`fe962cee…`) | same, **libfuse unpacked to `libfuse/`** (see below) |
| `INSTALL/tool/i386/{mkexfatfs,mount.exfat-fuse}` | git | **byte-identical** (2 files) | **CentOS 6.10 i386**, gcc-4.4.7-23, automake 1.11.2, at `/root/ExFAT` |
| `IMG/cpio_*/…/xzminidec{64_musl,aa64,m64e}` | release = git | **byte-identical** (3 files) | `ventoy_makefile*`, xz-embedded **as of b63ce2a** (2021-03-05) |
| `IMG/cpio_x86/…/xzminidec{32,64}` | release = git | all sections identical **except the 20-byte GNU build ID** | same; see below |
| `INSTALL/EFI/BOOT/BOOTMIPS.EFI` | release | **byte-identical to the release** (`70a53774…`) given the same unpublished `bitmap_scale.c` edit as §7 | Loongson mips gcc 7.3.1 (2019.06-29, ventoy/vtoytoolchain), CentOS 7.9 host |
| `LiveCD/GRUB/bootx64.efi`, `LiveCDGUI/GRUB/bootx64.efi` (same file) | git (2020-09-02) | **byte-identical** (`24ec8ccc…`) | GRUB from the a29bdfb tree, CentOS 7.9, `grub-mkimage` reconstructed (below) |
| `VtoyTool/vtoytool/{01,02}/vtoytool_64` (same file) | release = git | **not reproducible: source never published** | see below |

### Notes
- **exFAT `mount.exfat-fuse`: libfuse's directory name is in the build ID.** libfuse builds with
  autoconf's default `-g`, so its build directory goes into the debug info, and the GNU build ID
  is a hash of the unstripped link. With the codeload zip (`libfuse-fuse-2.9.9/`) only the
  build ID differed. Ventoy's scripts prefer `mirrors-libfuse-fuse-2.9.9.zip`, which unpacks
  to `libfuse/` (a gitee mirror). Repacking the same files under `libfuse/` gives a
  byte-identical binary. `buidlibfuse.sh` isn't executable in git, so it is run with `bash` first, as DOC 4.9 does.
- **32-bit tools were built on 32-bit CentOS 6**, as DOC says. The scripts pick 32-bit mode from
  `uname`, so the container runs under `linux32`. exfat 1.3.0 needs automake 1.11.2, as
  `buidexfat.sh` warns. The embedded paths show where things were built: `/root/ExFAT/LIBFUSE`
  and `/root/LIBFUSE`.
- **xzminidec: git binaries predate a source change.** The 1.0.58 release (2021-11-06) added
  `(uint32_t)` casts to xz-embedded, which changes 688 bytes of `.text`. Built from the tree at
  b63ce2a, where the binaries were committed, every loaded byte matches. The dietlibc builds
  (`32`, `64`) keep a GNU build ID that hashes `-ggdb3` debug info, including the build
  directory. None of `/home/share/Ventoy`, `/home/Ventoy-master`, `/root/Ventoy` or `/home/Ventoy`
  reproduces it, so the original build path is unknown. The build ID is a note section; no code or data differs.
- **BOOTMIPS.EFI** has the same `"1 …"/"2 … %d %d"` `bitmap_scale` strings as the x86/arm64
  images. With the §7 edit it matches the release exactly. The git copy is stale (1.0.98).
  So the unpublished edit is present in all four architectures' GRUB images.
- **LiveCD GRUB**: Ventoy never published the `grub-mkimage` command for this image. Using the module list
  and order read from the image itself, prefix `/EFI/boot`, `LiveCD/GRUB/embed.cfg` and GRUB
  built from the same-day tree gives a byte-identical image. This 2020 build has a stock
  `bitmap_scale.c`, so the debug edit came later.
- **vtoytool 01/02** (`fc0eac0e…`, CentOS 5 gcc-4.1.2-55, dietlibc): this binary is in the very
  first commit (2020-04-04) as `01/`. It moved to `02/` on 2020-08-29, and a copy was added back as `01/` in 2021.
  It contains 31 `BISO_DUMP_Show*` functions (ISO 9660 dumpers) and `vtoy_simple_check_blkdev`, which
  **don't exist in any BabyISO/VtoyTool source in the repo**, not even the initial commit. `biso.h` declares
  `BISO_DumpVD`, but no revision implements it. BabyISO has only two commits: 2020-04-04 and 2026-10-08.
  (Correction, 2026-10-15: an earlier version of this note also named `vtoy_check_os_param`, but that
  function *is* in `vtoydump.c`. The reference build simply didn't inline it.) It also links a dietlibc
  older than 0.34 (C `memcpy`/`memset`, `errno.S`, no `vdso_dlsym`). Built from the initial
  commit with CentOS 5.11 + dietlibc 0.34, it comes out 14 KB smaller with different code. It is
  a pre-repository build, kept as a fallback that the initramfs tries after `00/`, and cannot
  be checked against published source.

### Toolchains added
- `next10/Dockerfile.centos6-i386`: `centos:6` (386, `a93df2e9…`), vault 6.10 i386, util-linux-ng
  for `linux32`, automake 1.11.2 from ftp.gnu.org (`c339e387…`; GPG key FC818E17429F96EA not in
  the local keyring). `--build-arg GCC_PIN=4.4.7-18` downgrades to CentOS 6.9's gcc.
- `next10/Dockerfile.centos5`: `centos:5` (`70fffd68…`) + gcc-4.1.2-55 RPMs from vault 5.11 (os + updates).
  CentOS 5's yum can't negotiate TLS with vault.centos.org any more, so the RPMs are fetched on the host and
  checked with `rpm -K` against the image's CentOS 5 key (all `gpg OK`).
- Loongson `mips-loongson-gcc7.3-2019.06-29-linux-gnu.tar.gz` (actually bzip2) from
  ventoy/vtoytoolchain, SHA-256 `e9280281…`, unpacked to `toolchains/`.

Scripts: `next10/build_c7.sh` (exFAT x86_64, `LIBFUSE_MIRROR=1`; FUSE ISO aa64),
`next10/build_c6.sh` (i386 exFAT; `JOBS=fuseiso` for vtoy_fuse_iso_32), `next10/build_c5.sh`
(vtoytool with dietlibc on CentOS 5), `next10/build_xz.sh` (`VROOT=` build root),
`next10/build_livecd_grub.sh`, `grub/build_grub_mips.sh`.

### How the release copies were checked
- The `INSTALL/tool/x86_64` files come from `/opt/ventoy/tool/x86_64`. The Arch package ships only
  x86_64 tools, so the i386 exFAT tools were compared with git only.
- The `IMG/cpio_*` files and `vtoytool`/FUSE ISO come from the release's `ventoy_x86.cpio`,
  `ventoy_arm64.cpio` and `ventoy_mips64.cpio` (VTOYEFI partition), including the inner
  `tool.cpio.xz`. Every file checked there equals its git copy.
- The release also ships `tool/x86_64/mkexfatfs_static`, which isn't in git or the #3224 list.
  `buidexfat.sh` builds it, but it wasn't checked here.

### Git vs release, consolidated
| Binary | Git copy | Release copy | Rebuilds from |
|---|---|---|---|
| EDK2 apps `ventoy_*.efi`, `vtoyutil_*.efi` | stale (1.0.78, 2022) | current | v1.1.18 source |
| GRUB `grubx64_real`/`grubia32_real`/`BOOTAA64`/`BOOTMIPS` | stale (1.0.98, 2024) | current | v1.1.18 source **+ unpublished `bitmap_scale.c` edit** |
| `vtoytool/00/*` | stale (1.1.01, 2025) | current | v1.1.18 source |
| `xzminidec*` | = release (2021-03) | = git | source **as of b63ce2a**; v1.1.18 source differs (1.0.58 casts) |
| `wimboot.*` | unsigned 2022 build | same build + 2026 signature | source **+ 3 upstream `.S` files missing from the repo** |
| x64 EfiFs drivers | 2020 build | same build, re-signed | efifs `37e58c9`–`61494b4` |
| `ipxe.krn` | = release (2022) | = git | source **+ unpublished `printf(" ")`** |
| `Plugson` (all arches) | stale (2023-01) | x86_64 current | git copies from the 4df793e tree; release from v1.1.18 |
| `V2DServer`, `VentoyGUI`, `Ventoy2Disk.gtk*` | = release | = git (Arch package strips `VentoyGUI`, `qt5`) | v1.1.18 source |
| `vtoytool/01`, `/02` | = release (2020-04) | = git | **no published source** |

## 10. Third batch: Ventoy's own Linux host tools (2026-10-15)

These are Ventoy's own programs that run as root on the user's machine while it writes the
USB drive: the web UI server, the plugin configurator, the GUI launcher and the GTK GUI.
**13 more list entries reproduce byte for byte.** Scripts are in `batch3/`.

| List entry | Reference | Result |
|---|---|---|
| `INSTALL/tool/{x86_64,i386,aarch64,mips64el}/V2DServer` | git (2025-02-22, 9a8dc42); release x86_64 = git | **byte-identical**, all 4 (x86_64 `f08534c5…`), from v1.1.18 source |
| `INSTALL/tool/x86_64/Plugson` | release (`3ac3062b…`) ≠ git | **byte-identical to the release** from v1.1.18 source |
| `INSTALL/tool/{x86_64,i386,aarch64,mips64el}/Plugson` | git (2023-01-13, 4df793e) | **byte-identical**, all 4, from the **4df793e** tree; the git copies are stale |
| `INSTALL/VentoyGUI.{x86_64,i386,aarch64}` | git (2025-12-20) = release | **byte-identical** (x86_64 `ab677750…`), from v1.1.18 source |
| `INSTALL/tool/x86_64/Ventoy2Disk.gtk3` | git = release (`8001ea58…`) | **byte-identical** |
| `INSTALL/tool/x86_64/Ventoy2Disk.gtk2` | git (`253ddaf9…`) | **byte-identical** |

(The Plugson row for x86_64 counts once; the release copy and the git copy both reproduce,
from different source revisions.)

### What it took
- **CentOS 7.5 with gcc upgraded to 7.9's -44.** Every x86 binary here carries two
  `.comment` stamps, -28 and -44. On CentOS 7.9 everything, including glibc's `crt1.o`
  and `libc_nonshared.a`, is stamped -44, and the result differs: no `.plt.got`, different
  layout. With CentOS 7.5's glibc-devel (2.17-222, built by -28) and gcc 4.8.5-44 from the
  7.9 vault (`batch3/Dockerfile.c75-gcc44`), the output is byte-identical. That
  explains the "mixed compiler" pattern seen in §7 as well: the build host is a CentOS 7.5
  system whose gcc was later updated to 7.9's, while glibc-devel stayed at 7.5.
- **The cross toolchains must be installed under `/opt`.** With Linaro 7.4.1 mounted at
  `/tc/...`, aarch64 `V2DServer` differed only in its GNU build ID. Mounted at
  `/opt/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu` (DOC's location), it is byte-identical.
  The toolchain path reaches the unstripped link, and so the build-ID hash. The Loongson toolchain
  is likewise mounted at `/opt/mips-loongson-gcc7.3-linux-gnu`.
- **GTK**: CentOS 7.5's gtk3-devel 3.22.26 / gtk2-devel 2.24.31 / libglade2-devel, Ventoy's
  `build_gtk.sh` unmodified (`batch3/Dockerfile.c75-gcc44-gtk`).
- `VentoyGUI` was built with the exact `VentoyGUI` line from `build_gtk.sh` (one gcc call).
  v1.1.18 and ef93b55 give the same output.

### Findings
- **Plugson in git is stale.** The git copies are 2023-01-13 builds. Plugson's source changed
  through 2026-06, and the release's x86_64 Plugson is a fresh build that matches v1.1.18. The
  other architectures' release copies weren't available in the Arch package. Later, `REPRODUCE/verify.py` checked them against the full release tarball: the release's i386/aarch64/mips64el Plugson also match builds from v1.1.18, so only git is stale.
- **The Arch package modifies two files.** `/opt/ventoy/VentoyGUI.x86_64` and
  `tool/x86_64/Ventoy2Disk.qt5` differ from git only because makepkg strips binaries by default
  (`OPTIONS=(strip …)` in `/etc/makepkg.conf`). Stripping the git copies gives the installed
  files exactly. Ventoy's own release equals git for both. This doesn't affect any earlier
  comparison: those used the VTOYEFI image and cpio contents, or files that Ventoy had already stripped.
- **Not reproducible with published tools:**
  - `VentoyGUI.mips64el` and `mips64el/Ventoy2Disk.gtk3` record "loongson cross toolchain 8.3.0". `build_gtk.sh` expects
    `/opt/mips-loongson-gcc8-linux-gnu-2021-02-08`, which ventoy/vtoytoolchain doesn't publish
    (it has only the gcc 7.3 toolchain).
  - The Qt5 builds need the Qt 5.9.0 SDK at `/opt/Qt5.9.0` (x86_64), or `LinuxGUI/EXLIB` sysroots, so they weren't attempted.
  - i386/aarch64 GTK need i686 GTK devel packages or `EXLIB/aarch64`. They are possible but not done.

Scripts: `batch3/build_web.sh` (V2DServer + Plugson, `TC=/opt`, `JOBS=`), `batch3/build_vgui.sh`,
`batch3/build_gtk_x86.sh`, `batch3/cmp_tools.sh`, `batch3/survey.sh` (moved from next10), and
`smalltools/ci/compare_elf.py`, which now handles 32-bit ELF and reports "only the GNU build ID differs".

## 11. Fourth batch: third-party initramfs tools (2026-10-15)

15 picks: lz4cat ×3, lunzip ×3, zstdcat ×3, dmsetup ×4, vblade (one pick, 3 binaries) and the LiveCD kernel.
They cover **23 list entries**, because `IMG/cpio_*/ventoy/tool/{lz4cat64,lz4cataa64,lz4catm64e,zstdcat,zstdcat64,zstdcataa64}`
are identical copies of the `LZIP/`/`ZSTD/` files. **All 23 reproduce byte for byte.** Scripts are in `batch4/`.

| List entries | Recipe | Result | Notes |
|---|---|---|---|
| `LZIP/lunzip{64,aa64}` | DOC 4.19 | **byte-identical** | lunzip 1.11 from `LZIP/lunzip-1.11.tar.gz`; diet (CentOS 7.5) / Bootlin |
| `LZIP/lunzip32` | DOC 4.19 | **byte-identical** | **CentOS 6.9 i386** gcc 4.4.7-18, dietlibc at `/opt/diet` |
| `ZSTD/zstdcat64`, `zstdcataa64` (+ IMG copies) | `ZSTD/build.txt` | **byte-identical** | zstd v1.0.0 (codeload zip, SHA-256 `8fe92947…`) |
| `ZSTD/zstdcat` (+ IMG copy) | `ZSTD/build.txt` | **byte-identical** | CentOS 6.10 i386, dietlibc at `/opt/diet` |
| `DMSETUP/dmsetup{64,aa64,m64e}` | `DMSETUP/build.txt` | **byte-identical** | device-mapper 1.02.28 from `device-mapper-1.02.28-2.el5.src.rpm` (CentOS 5.3 vault, `rpm -K` gpg OK; no patches in the SRPM). musl / Bootlin / mips musl |
| `DMSETUP/dmsetup32` | `DMSETUP/build.txt` | **byte-identical** | CentOS 6.10 i386 + diet, **built in `/root/dmsetup`** (see below) |
| `VBLADE/vblade-master/vblade_{64,32,aa64}` | `build.sh` | **byte-identical** | CentOS 7.5; `_32` needs `libgcc-4.8.5-28.el7_5.1.i686` |
| `LZIP/lz4cat{64,aa64,m64e}` (+ IMG copies) | `LZIP/buildlz4.txt` | **byte-identical, but not with the documented flags** | see below |
| `LiveCD/ISO/EFI/boot/vmlinuz64` | `LiveCD/README.txt` | **identical to TinyCore 11.x's** `vmlinuz64` | MD5 `ab3a8196…` matches the README and tinycorelinux.net's `.md5.txt`; downloaded over plain HTTP, but checked against both MD5s |

### Notes
- **lz4cat: `buildlz4.txt` doesn't describe how the committed binaries were built.**
  - `lz4cataa64` matches only **without** `-D_FILE_OFFSET_BITS=64`. With it, uClibc's `fopen` is redirected to
    `fopen64` (`_stdio_fopen(..., -2)` instead of `-1`), which changes 18 bytes.
  - `lz4cat64` was rebuilt in commit 463d0b20 ("rebuild lz4cat64", 2020-12-22) with **musl and no
    optimisation flag**: `gcc -specs musl-gcc.specs -static smallz4cat.c`. It isn't the documented `diet -Os`.
  - `lz4catm64e` matches with `-mabi=64 -O2` (**no** `-mips64r2`, `-O2` rather than `-Os`).
  - Harmless, but the documented commands produce different binaries.
- **dmsetup32's build directory is in its build ID.** device-mapper builds with autoconf's
  default `-g`, so the unstripped link carries `DW_AT_comp_dir`. A sweep of candidate parent directories
  found `/root/dmsetup` gives a byte-identical binary. That's consistent with the other 32-bit tools built under `/root` (§9).
- **The musl dynamic loader** (`/lib/ld-musl-x86_64.so.1`) has to exist for device-mapper's configure
  test with `musl-gcc.specs`. musl's own `make install` creates it. Our saved libc tarball didn't
  include it, so `build_fix_c75.sh` adds the link.
- **Build-script gotcha:** device-mapper's `make.tmpl` has `MAKEFLAGS = @JOBS@`, and configure picks up `$JOBS`
  from the environment. A selector variable named `JOBS` turned make into debug mode and broke the build.
  The batch-4 scripts use `PICK`.

Scripts: `batch4/build_tools_c75.sh` (lz4cat as documented, lunzip, zstdcat, dmsetup, vblade),
`batch4/build_fix_c75.sh` (dmsetup64, vblade_32), `batch4/lz4_variants.sh` (flag sweep),
`batch4/build_tools_c6.sh` (`PICK=lunzip|zstd|dmsetup`; use image tag `gcc18` for lunzip32),
`batch4/dm32_paths.sh` (build-directory sweep).

## 12. Fifth batch: BusyBox and the upstream downloads (2026-10-15)

**24 more list entries verified.** 17 were rebuilt from source or matched to busybox.net's prebuilt
multiarch binaries. 7 are the per-applet downloads that DOC §5 lists with URL and SHA-256.
Scripts are in `batch5/`.

### Rebuilt from BusyBox 1.32.0 (busybox.net tarball, SHA-256 `c35d87f1…`, good GPG signature from Denis Vlasenko)
| List entries | Recipe | Result |
|---|---|---|
| `INSTALL/tool/x86_64/{ash,hexdump,xzcat}`, `IMG/cpio_x86/ventoy/busybox/64h` (= x86_64 `ash`) | `BUSYBOX/build.txt` x86_64: `x86_64_*.config`, Makefile `CC = gcc -specs musl-gcc.specs`, CentOS 7.5 | **byte-identical** (4 entries) |
| `INSTALL/tool/aarch64/{ash,hexdump,xzcat}`, `IMG/cpio_arm64/ventoy/busybox/a64` (= `ash`) | `ARCH=arm64 CROSS_COMPILE=aarch64-linux-` (Bootlin uclibc 2020.08-1) | **byte-identical** (4) |
| `INSTALL/tool/mips64el/{ash,hexdump,xzcat}`, `IMG/cpio_mips64/ventoy/busybox/m64` (= `ash`) | `ARCH=mips CROSS_COMPILE=mips64el-linux-musl-` + build.txt's CFLAGS/LDFLAGS | **byte-identical** (4), with the banner time set to the `# <date>` header of each `mips64el_*.config` |
| `IMG/cpio_mips64/ventoy/busybox/busyboxm64e` (.xz) | "full busybox": `make defconfig` + `CONFIG_STATIC=y` | **byte-identical**, banner `2021-03-04 14:11:58 CST` |
| `IMG/cpio_arm64/ventoy/busybox/busyboxaa64` (.xz) | defconfig + static **+ `AR` (with `FEATURE_AR_LONG_FILENAMES`, `FEATURE_AR_CREATE`) + `INOTIFYD`** | **byte-identical**, banner `2020-12-08 10:16:41 CST` |

The BusyBox banner embeds kconfig's build time (`AUTOCONF_TIMESTAMP`). `batch5/build_bb.sh` takes it as
`TS=` and writes it into `include/autoconf.h` after kconfig runs. The MIPS banners equal the
config files' own header timestamps to the second. The aarch64/x86_64 single-applet builds contain no banner.

### Identical to upstream prebuilt binaries (downloaded, not rebuilt)
| List entry | Upstream file |
|---|---|
| `IMG/cpio_x86/ventoy/busybox/busybox64` (.xz), `LiveCDGUI/EXT/busybox-x86_64` | busybox.net `binaries/1.31.0-defconfig-multiarch-musl/busybox-x86_64` |
| `IMG/cpio_x86/ventoy/busybox/busybox32` (.xz) | busybox.net `binaries/1.28.1-defconfig-multiarch/busybox-i686` |
| `IMG/cpio_x86/ventoy/tool/ar`, `inotifyd` | `binaries/1.30.0-i686/busybox_AR`, `busybox_INOTIFYD` (DOC 5.2, 5.3) |
| `IMG/cpio_x86/ventoy/busybox/ash` | `binaries/1.27.1-i686/busybox_ASH` (DOC 5.4) |
| `INSTALL/tool/i386/{xzcat,hexdump}` | `binaries/1.30.0-i686/busybox_XZCAT`, `busybox_HEXDUMP` (DOC 5.6, 5.7) |
| `INSTALL/tool/i386/ash` | `binaries/1.31.0-i686-uclibc/busybox_ASH` (DOC 5.11) |
| `IMG/cpio_x86/ventoy/tool/lz4cat` | `create.stephan-brumme.com/smallz4/smallz4cat-x32-v1.4` (DOC 5.1) |

These confirm that Ventoy shipped the upstream files unmodified. They say nothing about how
upstream built them. Before reading DOC §5, I had tried rebuilding the i386 tools with
uClibc 0.9.30.1 mini-native-i686 and Bootlin x86-i686 uclibc. Neither matched, as expected for
busybox.net's own builds.

### Ventoy's documentation is wrong in places
- `BLOB_List.md` lists `busybox32`/`busybox64` as "build: BUSYBOX/build.txt full busybox". They are
  **busybox.net's prebuilt multiarch binaries** (1.28.1 i686, 1.31.0 x86_64 musl).
- `BLOB_List.md` lists `xzcat32_musl`/`xzcat64_musl` under the same "full busybox" note. They are **XZ Utils
  5.2.5** (`xz (XZ Utils) 5.2.5`), statically linked against musl. They are not BusyBox at all (see "Still open").
- DOC 4.18 says `IMG/cpio/ventoy/busybox/64h` is built with uClibc `mini-native-x86_64`. It is
  byte-identical to `INSTALL/tool/x86_64/ash`, built with **musl** per `build.txt`. The mini-native build
  is 23 KB smaller.
- `build.txt`'s "full busybox" (defconfig + static) is exact for `busyboxm64e`. `busyboxaa64`
  additionally enables `ar` and `inotifyd`.

### Still open in this group
- `xzcat64_musl`: XZ Utils 5.2.5 (tukaani.org tarball, SHA-256 `f6f4910f…`, good signature from
  Lasse Collin) built with `musl-gcc.specs -static` on CentOS 7.5 comes closest with `CFLAGS=-O3`:
  235,712 bytes vs 236,368. Neither the default flags, `-Os`/`-O1`/`-O0`, nor the
  `--disable-nls`/`--disable-threads`/`--enable-small` variants match. No recipe exists.
- `xzcat32_musl`: built with Debian 11's gcc 10.2.1-6 (`.comment`), so it needs an i386 Debian 11 +
  musl-tools environment. Not attempted.

Scripts: `batch5/build_bb.sh` (`CFG`, `NAME`, `MAKEARGS`, `MUSL=1`, `TS`, `CFG=defconfig` + `EXTRA_Y`),
`batch5/run_cross.sh`, `batch5/run_i686.sh`, `batch5/applets.py` (lists a BusyBox applet table),
`batch5/xz_variants.sh`, `batch5/xz_cflags.sh`. The uClibc mini-native rootfs images
(`uclibc-mini-native-{x86_64,i686}:0.9.30.1`) were imported from uclibc.org tarballs
(`38203f01…`, `37172fec…`). They were used only for the negative results above.

## 13. What `vtoytool/01` and `/02` actually contain (REA + Ghidra, 2026-10-15)

`VtoyTool/vtoytool/01/vtoytool_64` (= `02/`, SHA-256 `fc0eac0e…`) can't be rebuilt from published
source (§9), so it was analysed directly. Inputs: REA `open_binary` with the Ghidra provider (12.1.2). The binary is not stripped, so
function names are real. Evidence bundle: `decomp/vtoytool01_evidence.json`.

**Inventory.** 262 procedures, 134 of them Ventoy/BabyISO (the rest is dietlibc). Against the initial-commit
source (05a1b86), parsing every `.c` file:
- 100 are defined in published source.
- 2 are only declared in `biso.h` (`BISO_DumpVD`, `BISO_DumpPathTable`).
- 1 is referenced only in commented-out calls (`BISO_DUMP_ShowSUSPEntry`).
- 31 exist in no published revision: 30 `BISO_DUMP_Show*` functions plus `vtoy_simple_check_blkdev`.

**The unpublished code is dead code, apart from one helper.**
- The 30 `BISO_DUMP_Show*` functions are an ISO 9660/Rock Ridge/El Torito pretty-printer. For example, `BISO_DUMP_ShowPVD` only `printf`s
  the Primary Volume Descriptor's fields. They are reachable only from `BISO_DumpVD`, `BISO_DumpPathTable` and
  `BISO_DUMP_ShowSUSPEntry`, and none of those has a caller. The only reference to the
  `g_astBISO_DUMP_ShowEntryFunc` pointer table is inside `BISO_DUMP_ShowSUSPEntry`; the only "reference" to that
  function is in `.eh_frame`. A union of the forward call graphs from `entry`, `main` and the four command handlers
  reaches none of the 31. The published `biso_dump.c` is an 87-line stub of the same module: Ventoy trimmed the
  library before publishing it, but this 2020 binary still carries the full version.
- `vtoy_simple_check_blkdev` is live. It's the older form of the published `vtoy_is_possible_blkdev`, and skips only
  `ram*` and `loop*` block devices, where the published code also skips `dm-*` and `sr*`.

**What the reachable code does.** It's an earlier version of the published VtoyTool, with four commands dispatched
by `strstr` on `argv` through `g_cmd_list` (`vtoydump`, `vtoydm`, `loader`, `--install`):
- `--install` (what `vtoytool_install.sh` runs, as root, in the initramfs): for each non-`-` command, `link("/ventoy/tool/<argv0 name>", "/ventoy/tool/<cmd>")`.
  Nothing else. It's identical in logic to the published `vtoytool_install`.
- `vtoydump` (`c:f:v::`) finds the Ventoy OS-parameter block: with `-f FILE` from a file, as in the published code.
  **Without `-f` it has two fallbacks that the published source documents in a comment but no longer contains:**
  - BIOS: read-only `mmap(/dev/mem, 0x80000, 0x1c000)`, scanned in 16-byte steps for the Ventoy GUID with a zero checksum over 0x400 bytes.
  - UEFI: read `/sys/firmware/efi/vars/VentoyOsParam-fd955401-89da-43c7-a39e-c7e531e58446/data`. **This path is broken:**
    after `read(fd, buf, 0x400)` it rejects anything but an 8-byte read (`CMP R12D, 0x8` at `0x400f25`), which looks like
    a `sizeof(pointer)` mistake, so it never succeeds.

  It then finds the Ventoy disk among `/sys/block/*` by size (sysfs or the `BLKGETSIZE64` ioctl) and, if ambiguous, by the GUID at offset 0x180, and prints `/dev/<disk>#<image path>`. `-c DEV` checks a given disk.
- `vtoydm` (`s:l:o:d:f:v::i::p::c::h::e::`):
  - `-p` prints a device-mapper linear table from the image map.
  - `-i` dumps the ISO tree (via the *published* `BISO_DumpFileTree`).
  - `-e` extracts sectors to a file with `fopen(..., "wb")`.
- `loader`:
  1. reads `/ventoy/loader_exec_file`
  2. runs `system()` on `/ventoy/loader_hook_cmd` if present
  3. `execv`s the target with arguments from `/ventoy/loader_exec_cmdline`

  Same logic as the published `vtoyloader.c`.

**Nothing else.** The linked libc functions include no sockets, no `setuid`/`setgid`, no `mount`, `unlink`,
`chmod` or module loading. The only file writes are `link()` (`--install`) and `vtoydm -e`'s output file. `fork`/`execve` come only
via `system()` and `execv()` in `loader`. Strings contain no URLs or IP addresses; the only paths are Ventoy's
`/ventoy/...`, `/sys/block`, `/sys/firmware/efi...`, `/dev/...`, plus dietlibc's `/bin/sh`, `/dev/urandom` and `/etc/localtime`.

**When it runs, and a compatibility caveat.** `vtoytool_install.sh` tries `vtoytool/00`, then `01`, then `02`
(`ls` order), trying `vtoytool_64` then `vtoytool_32` in each and stopping at the first `--install` that succeeds.
So on x86, `01` only runs when neither `00/vtoytool_64` nor `00/vtoytool_32` can execute on the booting kernel. On
arm64 and mips64 the loop looks for `vtoytool_aa64`/`vtoytool_m64e`, which `01/` and `02/` don't contain, so their copies in
those cpios are never used. In that case the hooks still call `vtoydump -s`/`-t` and `vtoydm -r`/`-w`, which this 2020 binary
doesn't support (it prints usage and exits 1). On such a system, those hook features fail. `02` is byte-identical to
`01`, so it adds nothing as a further fallback.

**Verdict.** The code that can actually run in `01/02` matches published logic, apart from the `vtoydump`
memory/EFI-variable fallbacks, which the hooks never use since they always pass `-f`. Its unpublished
content is a debug pretty-printer that is unreachable. No hidden or harmful behaviour was found. This is a static analysis only;
nothing was executed.
