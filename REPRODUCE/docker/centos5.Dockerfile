# Build context: REPRODUCE/cache (run.sh images).
# CentOS 5.11 x86_64, gcc 4.1.2-55: the compiler recorded in VtoyTool/vtoytool/{01,02}/vtoytool_64.
# CentOS 5's yum can't negotiate TLS with vault.centos.org any more, so the RPMs are
# downloaded on the host (REPRODUCE/cache/c5rpm, from vault 5.11 os + updates) and checked here with rpm -K
# against the image's own CentOS 5 key before installing.
FROM centos@sha256:70fffd687ff9545662c30f9043108489c698662861cd5f76070f7e2cd350564f
COPY c5rpm/ /tmp/c5rpm/
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5 \
 && rpm -K /tmp/c5rpm/*.rpm | tee /dev/stderr | grep -qv 'gpg OK' && exit 1 || true \
 && rpm -Uvh /tmp/c5rpm/*.rpm && rm -rf /tmp/c5rpm && rpm -q gcc glibc glibc-devel binutils make
