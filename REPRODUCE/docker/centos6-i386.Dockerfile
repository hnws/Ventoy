# Build context: REPRODUCE/cache (run.sh images).
# CentOS 6.10 i386 (32-bit userland). Ventoy's DOC: "build exfat-util 32-bit in a 32-bit CentOS system".
# The release's i386 mkexfatfs/mount.exfat-fuse record gcc 4.4.7-23 (CentOS 6.10).
# GCC_PIN=4.4.7-18 swaps in CentOS 6.9's gcc (recorded in vtoy_fuse_iso_32).
FROM --platform=linux/386 centos@sha256:a93df2e96e07f56ea48f215425c6f1673ab922927894595bb5c0ee4c5a955133
ARG GCC_PIN=
RUN rm -f /etc/yum.repos.d/*.repo && printf '%s\n' \
  '[base]' 'name=CentOS-6.10 - Base i386' 'baseurl=http://vault.centos.org/6.10/os/i386/' \
  'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6' \
  '[c69]' 'name=CentOS-6.9 - Base i386' 'baseurl=http://vault.centos.org/6.9/os/i386/' \
  'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6' 'enabled=0' \
  > /etc/yum.repos.d/vault.repo \
 && yum -y install util-linux-ng \
 && linux32 yum -y install gcc make binutils glibc-devel tar xz bzip2 unzip zip which file \
      automake autoconf gettext gettext-devel libtool pkgconfig \
 && if [ -n "$GCC_PIN" ]; then linux32 yum -y --enablerepo=c69 downgrade gcc-$GCC_PIN.el6 cpp-$GCC_PIN.el6 libgcc-$GCC_PIN.el6 libgomp-$GCC_PIN.el6; fi \
 && linux32 yum clean all && rpm -q gcc glibc automake autoconf libtool
ENTRYPOINT ["linux32"]
# buidexfat.sh: "automake 1.11.1 must update to automake 1.11.2" (exfat 1.3.0 uses AM_PROG_AR).
# ftp.gnu.org automake-1.11.2.tar.gz, SHA-256 c339e387...ce546.
COPY automake-1.11.2.tar.gz /tmp/
RUN cd /tmp && echo 'c339e3871d6595620760725da61de02cf1c293af8a05b14592d6587ac39ce546  automake-1.11.2.tar.gz' | sha256sum -c \
 && tar xf automake-1.11.2.tar.gz && cd automake-1.11.2 && linux32 ./configure --prefix=/usr >/dev/null \
 && make >/dev/null && make install >/dev/null && cd / && rm -rf /tmp/automake-1.11.2* && automake --version | head -1
