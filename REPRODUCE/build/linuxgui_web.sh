#!/bin/bash
# Runs INSIDE a CentOS 7 container. Runs Ventoy's own LinuxGUI/build.sh (V2DServer) and
# Plugson/build.sh, unmodified, at /home/share/Ventoy, for x86_64, i386 (gcc -m32),
# aarch64 (Linaro 7.4.1) and mips64el (Loongson gcc 7.3.1).
#   /src : Ventoy (ro)   /tc : toolchains (ro)   /out   TC : where the toolchains are mounted (default /tc)
#   JOBS : subset of "v2d plugson" (default both)
set -euo pipefail
JOBS=${JOBS:-"v2d plugson"}
rpm -q gcc glibc-devel
TC=${TC:-/tc}
export PATH=$PATH:$TC/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu/bin:$TC/mips-loongson-gcc7.3-linux-gnu/2019.06-29/bin
V=/home/share/Ventoy; rm -rf "$V"; mkdir -p "$V/INSTALL/tool/"{x86_64,i386,aarch64,mips64el}
cp -a /src/LinuxGUI /src/Plugson "$V/"
run() { echo "=== $1"; ( cd "$V/$1" && bash ./build.sh ) >"/out/log_$1.txt" 2>&1 || echo "    returned $? (see log)"; }
case " $JOBS " in *" v2d "*) run LinuxGUI ;; esac
case " $JOBS " in *" plugson "*) run Plugson ;; esac
for a in x86_64 i386 aarch64 mips64el; do
    for t in V2DServer Plugson; do [ -f "$V/INSTALL/tool/$a/$t" ] && cp "$V/INSTALL/tool/$a/$t" "/out/${t}_$a"; done
done
ls -l /out | grep -v log_
