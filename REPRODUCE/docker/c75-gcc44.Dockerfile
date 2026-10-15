# CentOS 7.5 userland (glibc-devel 2.17-222, built by gcc-4.8.5-28) with gcc upgraded to
# CentOS 7.9's 4.8.5-44. This reproduces binaries whose .comment carries both -28 (from
# glibc's crt1.o/libc_nonshared.a) and -44 (the program).
FROM ventoy-centos75
RUN printf '%s\n' '[c79]' 'name=CentOS-7.9.2009 - Base' 'baseurl=http://vault.centos.org/7.9.2009/os/$basearch/' \
      'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7' 'enabled=0' > /etc/yum.repos.d/c79.repo \
 && yum -y --enablerepo=c79 install gcc-4.8.5-44.el7 cpp-4.8.5-44.el7 libgcc-4.8.5-44.el7 libgomp-4.8.5-44.el7 libgcc-4.8.5-44.el7.i686 \
 && yum -y install bison flex && yum clean all \
 && rpm -q gcc glibc-devel binutils | tee /dev/stderr | grep -q 'gcc-4.8.5-44' && rpm -q glibc-devel | grep -q 2.17-222
