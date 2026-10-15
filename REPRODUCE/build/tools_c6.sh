#!/bin/bash
# Runs INSIDE ventoy-centos6-i386 (linux32). ZSTD/build.txt and DMSETUP/build.txt: "install dietc libc
# (just make && make install)" -> /opt/diet, then PATH=$PATH:/opt/diet/bin.
#   PICK: subset of "lunzip zstd dmsetup"   /src (ro)  /dl : downloads (REPRODUCE/cache)  /out
set -u
# (Not named JOBS: device-mapper's configure substitutes $JOBS into MAKEFLAGS.)
PICK=${PICK:-"lunzip zstd dmsetup"}
rpm -q gcc
t=$(mktemp -d); tar -C "$t" -xJf /dl/dietlibc-0.34.tar.xz; ( cd "$t/dietlibc-0.34" && make >/dev/null 2>&1 && make install >/dev/null 2>&1 ); rm -rf "$t"
export PATH=$PATH:/opt/diet/bin
V=/home/share/Ventoy; rm -rf "$V"; mkdir -p "$V"
case " $PICK " in *" lunzip "*)
    mkdir "$V/lz"; tar -xzf /src/LZIP/lunzip-1.11.tar.gz -C "$V/lz"; cd "$V/lz/lunzip-1.11"
    ( ./configure --disable-nls CC='diet gcc -nostdinc' && make ) >/out/log_lunzip32.txt 2>&1; strip --strip-all lunzip; cp lunzip /out/lunzip32 ;;
esac
case " $PICK " in *" zstd "*)
    mkdir "$V/zs"; cd "$V/zs"; unzip -q /dl/zstd-1.0.0.zip; cd zstd-1.0.0/programs
    ZF="-I../lib -I../lib/common -I../lib/dictBuilder -I../lib/legacy -O3 -Wall -Wextra -Wcast-qual -Wcast-align -Wshadow -Wstrict-aliasing=1 -Wswitch-enum -Wdeclaration-after-statement -Wstrict-prototypes -Wundef   -DZSTD_LEGACY_SUPPORT=1"
    { diet -Os gcc -pipe -nostdinc         -falign-loops=32 $ZF ../lib/decompress/zstd_decompress.c -c -o ../lib/decompress/zstd_decompress.o
      diet -Os gcc -pipe -nostdinc           $ZF ../lib/decompress/zstd_decompress.o ../lib/decompress/huf_decompress.c ../lib/common/entropy_common.c ../lib/common/fse_decompress.c ../lib/common/xxhash.c ../lib/common/zstd_common.c ../lib/compress/zstd_compress.c ../lib/compress/fse_compress.c ../lib/compress/huf_compress.c ../lib/legacy/zstd_v01.c ../lib/legacy/zstd_v02.c ../lib/legacy/zstd_v03.c ../lib/legacy/zstd_v04.c ../lib/legacy/zstd_v05.c ../lib/legacy/zstd_v06.c ../lib/legacy/zstd_v07.c ../lib/dictBuilder/divsufsort.c ../lib/dictBuilder/zdict.c zstdcli.c fileio.c bench.c datagen.c dibio.c -o zstd; } >/out/log_zstd32.txt 2>&1
    strip --strip-all zstd; cp zstd /out/zstdcat ;;
esac
case " $PICK " in *" dmsetup "*)
    # The release dmsetup32 was built in /root/dmsetup: the path is in its debug info, so in the build ID.
    rm -rf /root/dmsetup; mkdir -p /root/dmsetup; cd /root/dmsetup; tar -xzf /dl/dmsrpm/device-mapper.1.02.28.tgz; cd device-mapper.1.02.28
    { CC="diet gcc" ./configure --disable-nls  --disable-selinux --disable-shared
      sed -i '/#define malloc rpl_malloc/d' include/configure.h
      printf '%s\n' '#ifndef UINT32_MAX' '#define UINT32_MAX  (4294967295U)' '#endif' '' '#ifndef UINT64_C' '#define UINT64_C(c) c ## ULL' '#endif' >> include/configure.h
      make; } >/out/log_dmsetup32.txt 2>&1
    strip dmsetup/dmsetup; cp dmsetup/dmsetup /out/dmsetup32 ;;
esac
ls -l /out | grep -v log_
