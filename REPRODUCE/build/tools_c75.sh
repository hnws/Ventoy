#!/bin/bash
# Runs INSIDE ventoy-centos75 (gcc-4.8.5-28). Follows Ventoy's build notes step by step:
#   LZIP/buildlz4.txt (lz4cat64/aa64/m64e), DOC 4.19 (lunzip64/aa64), ZSTD/build.txt (zstdcat64/aa64),
#   DMSETUP/build.txt (dmsetup64/aa64/m64e), VBLADE/vblade-master/build.sh (vblade_64/32/aa64).
#   /src : Ventoy (ro)  /dl : downloads + libc_c75.tar (REPRODUCE/cache)  /out
set -u
tar -C / -xf /dl/libc_c75.tar      # /opt/diet32, /opt/diet64, /usr/local/musl (built by gcc -28)
tar -C /opt -xf /dl/aarch64--uclibc--stable-2020.08-1.tar.bz2
tar -C /opt -xf /dl/mips64el-linux-musl-gcc730.tar.bz2; mv /opt/output /opt/mips64el-linux-musl-gcc730
export PATH=$PATH:/opt/aarch64--uclibc--stable-2020.08-1/bin:/opt/mips64el-linux-musl-gcc730/bin
V=/home/share/Ventoy; rm -rf "$V"; mkdir -p "$V"; cp -a /src/LZIP /src/ZSTD /src/DMSETUP /src/VBLADE "$V/"
log() { echo "=== $1"; }
# ---- lz4cat (LZIP/buildlz4.txt), stripped like the committed files
cd "$V/LZIP"; log lz4cat
/opt/diet64/bin/diet -Os gcc -D_FILE_OFFSET_BITS=64  smallz4cat.c -o  lz4cat64 && strip --strip-all lz4cat64
aarch64-buildroot-linux-uclibc-gcc -Os -static -D_FILE_OFFSET_BITS=64  smallz4cat.c -o  lz4cataa64 && aarch64-buildroot-linux-uclibc-strip --strip-all lz4cataa64
mips64el-linux-musl-gcc -mips64r2 -mabi=64 -static -Os -D_FILE_OFFSET_BITS=64 smallz4cat.c -o  lz4catm64e && mips64el-linux-musl-strip --strip-all lz4catm64e
cp lz4cat64 lz4cataa64 lz4catm64e /out/
# ---- lunzip (DOC 4.19)
for a in 64 aa64; do
    log lunzip$a; rm -rf "$V/lz$a"; mkdir "$V/lz$a"; tar -xzf "$V/LZIP/lunzip-1.11.tar.gz" -C "$V/lz$a"; cd "$V/lz$a/lunzip-1.11"
    if [ $a = 64 ]; then ( PATH=$PATH:/opt/diet64/bin; ./configure --disable-nls CC='diet gcc -nostdinc' && make ) >/out/log_lunzip$a.txt 2>&1; strip --strip-all lunzip
    else ( ./configure --disable-nls CC='aarch64-buildroot-linux-uclibc-gcc -static' && make ) >/out/log_lunzip$a.txt 2>&1; aarch64-buildroot-linux-uclibc-strip --strip-all lunzip; fi
    cp lunzip /out/lunzip$a
done
# ---- zstdcat (ZSTD/build.txt)
ZF="-I../lib -I../lib/common -I../lib/dictBuilder -I../lib/legacy -O3 -Wall -Wextra -Wcast-qual -Wcast-align -Wshadow -Wstrict-aliasing=1 -Wswitch-enum -Wdeclaration-after-statement -Wstrict-prototypes -Wundef   -DZSTD_LEGACY_SUPPORT=1"
ZS="../lib/decompress/zstd_decompress.o ../lib/decompress/huf_decompress.c ../lib/common/entropy_common.c ../lib/common/fse_decompress.c ../lib/common/xxhash.c ../lib/common/zstd_common.c ../lib/compress/zstd_compress.c ../lib/compress/fse_compress.c ../lib/compress/huf_compress.c ../lib/legacy/zstd_v01.c ../lib/legacy/zstd_v02.c ../lib/legacy/zstd_v03.c ../lib/legacy/zstd_v04.c ../lib/legacy/zstd_v05.c ../lib/legacy/zstd_v06.c ../lib/legacy/zstd_v07.c ../lib/dictBuilder/divsufsort.c ../lib/dictBuilder/zdict.c zstdcli.c fileio.c bench.c datagen.c dibio.c"
for a in 64 aa64; do
    log zstdcat$a; rm -rf "$V/zs$a"; mkdir "$V/zs$a"; cd "$V/zs$a"; unzip -q /dl/zstd-1.0.0.zip; cd zstd-1.0.0/programs
    if [ $a = 64 ]; then
        /opt/diet64/bin/diet -Os gcc -pipe -nostdinc         -falign-loops=32 $ZF ../lib/decompress/zstd_decompress.c -c -o ../lib/decompress/zstd_decompress.o
        /opt/diet64/bin/diet -Os gcc -pipe -nostdinc           $ZF $ZS -o zstd; strip --strip-all zstd
    else
        aarch64-linux-gcc  -static   -falign-loops=32 $ZF ../lib/decompress/zstd_decompress.c -c -o ../lib/decompress/zstd_decompress.o
        aarch64-linux-gcc    -static      $ZF $ZS -o zstd; aarch64-linux-strip --strip-all zstd
    fi >/out/log_zstd$a.txt 2>&1
    cp zstd /out/zstdcat$a
done
# ---- dmsetup (DMSETUP/build.txt), device-mapper 1.02.28 from the CentOS 5.3 SRPM
for a in 64 aa64 m64e; do
    log dmsetup$a; rm -rf "$V/dm$a"; mkdir "$V/dm$a"; cd "$V/dm$a"; tar -xzf /dl/dmsrpm/device-mapper.1.02.28.tgz; cd device-mapper.1.02.28
    {
    case $a in
    64)   ./configure --disable-nls  --disable-selinux --disable-shared  --enable-static_link CC='gcc -specs /usr/local/musl/lib/musl-gcc.specs'
          touch include/linux/limits.h include/linux/types.h
          echo '#include <sys/mount.h>' > include/linux/fs.h ;;
    aa64) ./configure CC=aarch64-linux-gcc --target=arm --host=x86_64-linux-gnu --disable-nls  --disable-selinux --disable-shared  --enable-static_link
          sed -i '/#define malloc rpl_malloc/d' include/configure.h ;;
    m64e) ./configure CC="mips64el-linux-musl-gcc -mips64r2 -mabi=64" --target=mips --host=x86_64-linux-gnu --disable-nls  --disable-selinux --disable-shared  --enable-static_link
          sed -i '/#define malloc rpl_malloc/d' include/configure.h ;;
    esac
    make
    } >/out/log_dmsetup$a.txt 2>&1
    case $a in 64) strip --strip-all dmsetup/dmsetup.static ;; aa64) aarch64-linux-strip dmsetup/dmsetup.static ;; m64e) mips64el-linux-musl-strip dmsetup/dmsetup.static ;; esac
    cp dmsetup/dmsetup.static /out/dmsetup$a
done
# ---- vblade (build.sh, unmodified)
log vblade; cd "$V/VBLADE/vblade-master"; bash ./build.sh >/out/log_vblade.txt 2>&1; cp vblade_64 vblade_32 vblade_aa64 /out/ 2>/dev/null
ls -l /out | grep -v log_
