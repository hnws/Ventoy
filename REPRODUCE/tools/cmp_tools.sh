#!/bin/bash
# cmp_tools.sh OUTDIR : compare OUTDIR/<tool>_<arch> with git INSTALL/tool/<arch>/<tool>
# (and the release copy in /opt/ventoy for x86_64).
O=$1; S=$(dirname "$0")/../src/Ventoy/INSTALL/tool
for f in "$O"/*_*; do
    b=$(basename "$f"); t=${b%%_*}; a=${b#*_}
    case $a in x86_64|i386|aarch64|mips64el) ;; *) continue ;; esac
    [ "$a" = x86_64 ] && [ "$t" = mips64el ] && continue
    h=$(sha256sum < "$f" | cut -c1-12); g=$(sha256sum < "$S/$a/$t" | cut -c1-12)
    r=-; [ "$a" = x86_64 ] && [ -f /opt/ventoy/tool/x86_64/$t ] && r=$(sha256sum < /opt/ventoy/tool/x86_64/$t | cut -c1-12)
    m=differ; [ "$h" = "$g" ] && m="MATCH git"; [ "$h" = "$r" ] && m="$m MATCH release"
    echo "$t/$a: $h git $g rel $r -> $m"
done
