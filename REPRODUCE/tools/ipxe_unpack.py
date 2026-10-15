#!/usr/bin/env python3
"""Unpack the LZMA payload of an iPXE .lkrn and locate build_id / build_timestamp.

Usage: ipxe_unpack.py PROBE.lkrn REFERENCE.lkrn PROBE_ID PROBE_TIMESTAMP

PROBE was built with known placeholder values (BUILD_ID_CMD / BUILD_TIMESTAMP). The
payload is raw LZMA1 with lc=2 lp=0 pb=0 (src/util/zbin.c). For both files, find the
offset where the payload starts, decompress it, find the placeholders in the probe image,
and read the reference's values at the same offsets.
"""
import lzma
import struct
import sys

FILTERS = [{"id": lzma.FILTER_LZMA1, "lc": 2, "lp": 0, "pb": 0, "dict_size": 1 << 26}]


def unpack(data):
    best = (0, None, None)
    for off in range(0, len(data) - 16):
        try:
            d = lzma.LZMADecompressor(lzma.FORMAT_RAW, filters=FILTERS)
            out = d.decompress(data[off:], max_length=1 << 22)
        except lzma.LZMAError:
            continue
        if len(out) > best[0]:
            best = (len(out), off, out)
            if len(out) > 4 * len(data) // 3:
                break
    return best[1], best[2]


def main():
    probe, ref = (open(p, "rb").read() for p in sys.argv[1:3])
    pid, pts = int(sys.argv[3], 0), int(sys.argv[4], 0)
    po, pout = unpack(probe)
    ro, rout = unpack(ref)
    print(f"probe payload at {po:#x} -> {len(pout)} bytes; reference payload at {ro:#x} -> {len(rout)} bytes")
    print(f"uncompressed prefix identical: {probe[:min(po, ro)] == ref[:min(po, ro)]}")
    found = {}
    for name, val in (("build_id", pid), ("build_timestamp", pts)):
        needle = struct.pack("<I", val)
        hits = [i for i in range(len(pout) - 3) if pout[i:i + 4] == needle]
        found[name] = hits
        vals = [struct.unpack_from("<I", rout, i)[0] for i in hits]
        print(f"{name}: probe offsets {[hex(h) for h in hits]} -> reference values {[hex(v) for v in vals]}")
    diff = sum(a != b for a, b in zip(pout, rout)) + abs(len(pout) - len(rout))
    print(f"decompressed images differ in {diff} bytes (expected: only those 8)")


if __name__ == "__main__":
    main()
