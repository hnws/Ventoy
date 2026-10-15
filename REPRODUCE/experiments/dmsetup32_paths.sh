#!/bin/bash
# Runs INSIDE ventoy-centos6-i386. Builds dmsetup32 (DMSETUP/build.txt) with the source unpacked
# under each candidate parent directory and prints the result's SHA-256 (build ID varies with path).
t=$(mktemp -d); tar -C "$t" -xJf /dl/dietlibc-0.34.tar.xz; ( cd "$t/dietlibc-0.34" && make >/dev/null 2>&1 && make install >/dev/null 2>&1 ); rm -rf "$t"
export PATH=$PATH:/opt/diet/bin
for d in "$@"; do
    mkdir -p "$d"; cd "$d"; rm -rf device-mapper.1.02.28; tar -xzf /dl/dmsrpm/device-mapper.1.02.28.tgz; cd device-mapper.1.02.28
    CC="diet gcc" ./configure --disable-nls  --disable-selinux --disable-shared >/dev/null 2>&1
    sed -i '/#define malloc rpl_malloc/d' include/configure.h
    printf '%s\n' '#ifndef UINT32_MAX' '#define UINT32_MAX  (4294967295U)' '#endif' '' '#ifndef UINT64_C' '#define UINT64_C(c) c ## ULL' '#endif' >> include/configure.h
    make >/dev/null 2>&1; strip dmsetup/dmsetup
    echo "$d $(sha256sum < dmsetup/dmsetup | cut -c1-12)"
done
