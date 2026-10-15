# The repo's own build image (ventoy-build:ci, from /Dockerfile) with its RPM database rebuilt.
# `yum -q install` in that Dockerfile can leave an rpmdb whose entries read back as corrupt
# ("rpmdbNextIterator: skipping h# ... region trailer: BAD"), so `rpm -q gcc` reports gcc as not
# installed although it is. The build scripts use rpm -q, so repair the database once here.
FROM ventoy-build:ci
RUN rpm --rebuilddb && rpm -q gcc glibc-devel bison flex
