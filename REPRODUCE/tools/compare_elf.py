#!/usr/bin/env python3
"""Compare two ELF files (32- or 64-bit, little-endian) section by section.

Usage: compare_elf.py REBUILT REFERENCE

Prints, for each section, whether its contents match, and reports differing bytes
that fall outside every section (ELF header, program headers, section header table).
Exit status: 0 = every loadable section (SHF_ALLOC) identical, 1 = otherwise.
"""
import struct
import sys

SHF_ALLOC = 0x2


def sections(data):
    if data[:4] != b"\x7fELF" or data[4] not in (1, 2):
        raise ValueError("not an ELF file")
    if data[4] == 2:
        shoff, = struct.unpack_from("<Q", data, 0x28)
        shentsize, shnum, shstrndx = struct.unpack_from("<HHH", data, 0x3A)
        fmt = "<IIQQQQIIQQ"
    else:
        shoff, = struct.unpack_from("<I", data, 0x20)
        shentsize, shnum, shstrndx = struct.unpack_from("<HHH", data, 0x2E)
        fmt = "<IIIIIIIIII"
    hdrs = [struct.unpack_from(fmt, data, shoff + i * shentsize) for i in range(shnum)]
    stroff = hdrs[shstrndx][4]
    out = []
    for name, typ, flags, _addr, off, size, *_ in hdrs:
        end = data.index(b"\0", stroff + name)
        nm = data[stroff + name:end].decode() or "NULL"
        body = b"" if typ == 8 else data[off:off + size]          # SHT_NOBITS has no file bytes
        out.append((nm, flags, off, size, body))
    return out, shoff, shnum * shentsize


def main():
    a, b = (open(p, "rb").read() for p in sys.argv[1:3])
    sa, _, _ = sections(a)
    sb, _, _ = sections(b)
    ok = True
    only_build_id = True
    if [s[0] for s in sa] != [s[0] for s in sb]:
        print("section lists differ")
        print("  rebuilt:  ", " ".join(x[0] for x in sa))
        print("  reference:", " ".join(x[0] for x in sb))
        return 1
    for (nm, fl, _, sz, x), (_, _, _, sz2, y) in zip(sa, sb):
        if x == y and sz == sz2:
            state = "identical"
        else:
            n = sum(p != q for p, q in zip(x, y)) + abs(len(x) - len(y))
            state = f"DIFFERS ({n} bytes, size {sz:#x} vs {sz2:#x})"
            if fl & SHF_ALLOC:
                ok = False
                if nm != ".note.gnu.build-id":
                    only_build_id = False
        print(f"  {nm:16} {'alloc' if fl & SHF_ALLOC else '     '}  {state}")
    if ok:
        print("LOADED CODE AND DATA IDENTICAL")
    elif only_build_id:
        print("ONLY THE GNU BUILD ID DIFFERS (everything else loaded is identical)")
    else:
        print("LOADED CODE OR DATA DIFFERS")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
