#!/bin/bash
# Read-only survey: size, linkage, compiler stamps, hash vs release copy.
# Usage: survey.sh FILE...   (paths relative to the Ventoy checkout)
cd "$(dirname "$0")/../src/Ventoy" || exit 1
for f in "$@"; do
    c=$(readelf -p .comment "$f" 2>/dev/null | grep -o 'GCC.*\|clang.*' | sort | uniq -c | tr -s ' ' | tr '\n' ';')
    l=$(file -b "$f" | grep -o 'statically linked\|dynamically linked\|stripped\|not stripped' | tr '\n' ',')
    h=$(sha256sum < "$f" | cut -c1-8)
    r=/opt/ventoy/tool/x86_64/$(basename "$f")
    rh=-
    [ -f "$r" ] && rh=$(sha256sum < "$r" | cut -c1-8)
    echo "$f | $(stat -c %s "$f") | $l | $c | git $h rel $rh"
done
