#!/usr/bin/env python3
"""Print the applet names compiled into a static BusyBox binary (the NUL-separated
applet_names table that starts with "[" "[[")."""
import sys
d = open(sys.argv[1], "rb").read()
i = d.find(b"[\x00[[\x00")
if i < 0:
    sys.exit("no applet table")
names, j = [], i
while True:
    k = d.index(b"\x00", j)
    if k == j:
        break
    names.append(d[j:k].decode())
    j = k + 1
print("\n".join(names))
