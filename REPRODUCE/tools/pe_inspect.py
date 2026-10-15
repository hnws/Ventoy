#!/usr/bin/env python3
"""Summarize UEFI PE images: machine, subsystem, sections, SBAT, and Authenticode signers.

Usage: pe_inspect.py FILE...   (signer details need the `openssl` CLI)
"""
import struct
import subprocess
import sys

MACHINES = {0x14C: "i386", 0x8664: "x64", 0xAA64: "arm64", 0x166: "mips"}
SUBSYSTEMS = {10: "EFI app", 11: "EFI boot driver", 12: "EFI runtime driver"}


def sections(data, pe):
    nsec, = struct.unpack_from("<H", data, pe + 6)
    opt_size, = struct.unpack_from("<H", data, pe + 20)
    out = []
    base = pe + 24 + opt_size
    for i in range(nsec):
        name, vsize, vaddr, rsize, rptr = struct.unpack_from("<8sIIII", data, base + 40 * i)
        out.append((name.rstrip(b"\0").decode("latin1"), vsize, vaddr, rsize, rptr))
    return out


def signers(blob):
    """Return certificate subject/issuer lines from a WIN_CERTIFICATE PKCS#7 blob."""
    try:
        r = subprocess.run(["openssl", "pkcs7", "-inform", "DER", "-print_certs", "-noout"],
                           input=blob, capture_output=True, timeout=30)
    except FileNotFoundError:
        return ["(openssl not available)"]
    return [l for l in r.stdout.decode(errors="replace").splitlines() if l.strip()]


def inspect(path):
    data = open(path, "rb").read()
    pe, = struct.unpack_from("<I", data, 0x3C)
    if data[pe:pe + 4] != b"PE\0\0":
        print(f"{path}: not a PE image")
        return
    machine, = struct.unpack_from("<H", data, pe + 4)
    opt = pe + 24
    magic, = struct.unpack_from("<H", data, opt)
    pe32plus = magic == 0x20B
    subsystem, = struct.unpack_from("<H", data, opt + 68)
    ddir = opt + (112 if pe32plus else 96)
    cert_off, cert_size = struct.unpack_from("<II", data, ddir + 4 * 8)
    secs = sections(data, pe)
    print(f"== {path}")
    print(f"   machine={MACHINES.get(machine, hex(machine))} subsystem={SUBSYSTEMS.get(subsystem, subsystem)} "
          f"sections={','.join(s[0] for s in secs)}")
    for name, vsize, vaddr, rsize, rptr in secs:
        if name == ".sbat":
            sbat = data[rptr:rptr + min(vsize, rsize)].rstrip(b"\0").decode(errors="replace")
            print("   SBAT:", " | ".join(l for l in sbat.splitlines() if l))
        if name == ".vendor_cert":
            print(f"   .vendor_cert section present ({vsize} bytes)")
    if cert_off and cert_size:
        pos = cert_off
        while pos < cert_off + cert_size:
            length, rev, ctype = struct.unpack_from("<IHH", data, pos)
            if length < 8:
                break
            for line in signers(data[pos + 8:pos + length]):
                print("   sig:", line)
            pos += (length + 7) & ~7
    else:
        print("   unsigned")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        inspect(p)
