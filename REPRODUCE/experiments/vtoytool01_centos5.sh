#!/bin/bash
# Runs INSIDE ventoy-centos5 (gcc 4.1.2-55). Builds dietlibc 0.34 with the steps of
# DOC/installdietlibc.sh (CentOS 5's tar can't read .xz, so the tarball is supplied
# decompressed), then runs VtoyTool/build.sh from the tree mounted at /vt.
#   /vt : VtoyTool tree (ro)   /dl : dietlibc-0.34.tar   /out : results
set -eu
rpm -q gcc glibc; locale | head -3
t=$(mktemp -d); cd "$t"
for a in 64 32; do
    tar -xf /dl/dietlibc-0.34.tar; cd dietlibc-0.34
    if [ $a = 32 ]; then sed "s/MYARCH:=.*/MYARCH=i386/" -i Makefile; sed "s/CC=gcc/CC=gcc -m32/" -i Makefile; fi
    prefix=/opt/diet$a make -j4 >/dev/null 2>&1 || echo "diet$a build failed"
    prefix=/opt/diet$a make install >/dev/null 2>&1 || true
    cd ..; rm -rf dietlibc-0.34
done
W=/home/share/Ventoy/VtoyTool; mkdir -p "$(dirname $W)"; cp -a /vt "$W"; cd "$W"
bash ./build.sh >/out/log_build.txt 2>&1 || echo "build.sh: $(tail -2 /out/log_build.txt | tr '\n' ' ')"
for f in vtoytool_64 vtoytool_32 vtoytool/00/vtoytool_64 vtoytool/00/vtoytool_32; do [ -f "$f" ] && cp "$f" /out/ ; done
ls -l /out
