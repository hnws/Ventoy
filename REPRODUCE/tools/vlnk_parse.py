#!/usr/bin/env python3
"""Parse and validate Ventoy .vlnk files (layout recovered from Ventoy 1.1.18 tool/x86_64/vlnk).

File = 32768 bytes (0x8000). Only the first 512-byte block carries data:
  0x000  16  magic "  www.ventoy.net"
  0x010   4  CRC-32C (Castagnoli) of bytes 0x000..0x1FF with this field zeroed
  0x014   4  MBR disk signature of the target disk (MBR offset 0x1B8)
  0x018   8  byte offset of the target partition (start sector * 512)
  0x020 384  NUL-terminated path of the image, relative to that partition's root
Rest of the file is zero.
"""
import struct
import sys

MAGIC = b"  www.ventoy.net"
SIZE = 0x8000

# Table-driven CRC-32C (reflected poly 0x82F63B78), as built by vlnk's FUN_00400bd5.
_TABLE = []
for _i in range(256):
    _c = _i
    for _ in range(8):
        _c = (_c >> 1) ^ 0x82F63B78 if _c & 1 else _c >> 1
    _TABLE.append(_c)


def crc32c(data: bytes) -> int:
    crc = 0xFFFFFFFF
    for b in data:
        crc = (crc >> 8) ^ _TABLE[(crc ^ b) & 0xFF]
    return crc ^ 0xFFFFFFFF


def parse(data: bytes) -> dict:
    if len(data) != SIZE:
        raise ValueError(f"size {len(data)} != {SIZE}")
    block = bytearray(data[:0x200])
    if block[:16] != MAGIC:
        raise ValueError("bad magic")
    crc, disk_sig, part_offset = struct.unpack_from("<IIQ", block, 0x10)
    block[0x10:0x14] = b"\0\0\0\0"
    actual = crc32c(block)
    path = bytes(block[0x20:0x20 + 0x180]).split(b"\0", 1)[0].decode("utf-8", "replace")
    return {
        "crc_ok": crc == actual,
        "crc": f"{crc:08X}",
        "disk_signature": f"{disk_sig:08X}",
        "partition_offset": part_offset,
        "partition_start_sector": part_offset // 512,
        "path": path,
    }


def build(path: str, disk_signature: int, partition_start_sector: int) -> bytes:
    raw = path.encode()
    if len(raw) > 0x17F:
        raise ValueError("path too long for vlnk (max 383 bytes)")
    block = bytearray(0x200)
    block[:16] = MAGIC
    struct.pack_into("<IQ", block, 0x14, disk_signature, partition_start_sector * 512)
    block[0x20:0x20 + len(raw)] = raw
    struct.pack_into("<I", block, 0x10, crc32c(block))
    return bytes(block) + bytes(SIZE - 0x200)


if __name__ == "__main__":
    for name in sys.argv[1:]:
        with open(name, "rb") as f:
            print(name, parse(f.read()))
