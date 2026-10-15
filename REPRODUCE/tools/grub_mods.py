#!/usr/bin/env python3
"""List and compare the modules embedded in a GRUB EFI image (the PE 'mods' section).

Usage: grub_mods.py REBUILT.efi REFERENCE.efi [--dump DIR]

The mods section holds a grub_module_info header ('mimg' magic, total size) followed by
module records {u32 type, u32 size (incl. this 8-byte header), payload}. Type 0 records
are ELF modules; their name comes from the ELF '.modname' section. Other types are
memdisk, config, prefix, pubkey, etc.
"""
import hashlib
import os
import struct
import sys

TYPES = {0: "ELF", 1: "MEMDISK", 2: "CONFIG", 3: "PREFIX", 4: "PUBKEY", 5: "DTB", 6: "DISABLE_SHIM_LOCK"}


def mods_section(data):
    pe, = struct.unpack_from("<I", data, 0x3C)
    nsec, = struct.unpack_from("<H", data, pe + 6)
    opt, = struct.unpack_from("<H", data, pe + 20)
    for i in range(nsec):
        name, vs, _va, rs, rp = struct.unpack_from("<8sIIII", data, pe + 24 + opt + 40 * i)
        if name.rstrip(b"\0") == b"mods":
            return data[rp:rp + min(vs, rs) if vs else rp + rs]
    raise ValueError("no mods section")


def elf_modname(blob):
    is64 = blob[4] == 2
    if is64:
        shoff, = struct.unpack_from("<Q", blob, 0x28); shent, shnum, shstr = struct.unpack_from("<HHH", blob, 0x3A)
        hdr = lambda i: struct.unpack_from("<IIQQQQ", blob, shoff + i * shent)
        off_i, size_i = 4, 5
    else:
        shoff, = struct.unpack_from("<I", blob, 0x20); shent, shnum, shstr = struct.unpack_from("<HHH", blob, 0x2E)
        hdr = lambda i: struct.unpack_from("<IIIIII", blob, shoff + i * shent)
        off_i, size_i = 4, 5
    strtab = hdr(shstr)[off_i]
    for i in range(shnum):
        h = hdr(i)
        nm = blob[strtab + h[0]:blob.index(b"\0", strtab + h[0])]
        if nm == b".modname":
            return blob[h[off_i]:h[off_i] + h[size_i]].rstrip(b"\0").decode()
    return "?"


def modules(path):
    m = mods_section(open(path, "rb").read())
    magic = m[:4]
    if magic != b"mimg":
        raise ValueError(f"bad module magic {magic!r}")
    is64 = struct.unpack_from("<I", m, 4)[0] == 0      # 64-bit info has padding after magic
    hdr_len = 24 if is64 else 12
    total = struct.unpack_from("<Q" if is64 else "<I", m, 16 if is64 else 8)[0]
    pos, out = hdr_len, []
    while pos + 8 <= min(total, len(m)):
        typ, size = struct.unpack_from("<II", m, pos)
        if size < 8:
            break
        body = m[pos + 8:pos + size]
        name = elf_modname(body) if typ == 0 and body[:4] == b"\x7fELF" else TYPES.get(typ, str(typ))
        out.append((name, typ, size, body))
        pos += size
    return out


def main():
    a, b = modules(sys.argv[1]), modules(sys.argv[2])
    na, nb = [x[0] for x in a], [x[0] for x in b]
    print(f"modules: rebuilt {len(a)}, reference {len(b)}; same order: {na == nb}")
    if set(na) != set(nb):
        print("  only in rebuilt:", sorted(set(na) - set(nb)), " only in reference:", sorted(set(nb) - set(na)))
    db = {x[0]: x for x in b}
    diff = [(n, s, db[n][2]) for n, _, s, body in a if n in db and body != db[n][3]]
    print(f"modules with different contents: {len(diff)}")
    for n, s1, s2 in diff:
        print(f"  {n:20} size {s1} vs {s2}")
    if na != nb:
        first = next(i for i, (x, y) in enumerate(zip(na, nb)) if x != y)
        print(f"first order difference at #{first}: rebuilt {na[first:first+5]} vs reference {nb[first:first+5]}")
    if "--dump" in sys.argv:
        d = sys.argv[sys.argv.index("--dump") + 1]
        for tag, lst in (("rebuilt", a), ("reference", b)):
            os.makedirs(f"{d}/{tag}", exist_ok=True)
            for n, _, _, body in lst:
                open(f"{d}/{tag}/{n}.mod", "wb").write(body)


if __name__ == "__main__":
    main()
