# ventoy-c75-gcc44 plus CentOS 7.5's GTK 2/3 and libglade development packages (LinuxGUI/build_gtk.sh).
FROM ventoy-c75-gcc44
RUN yum -y install gtk3-devel gtk2-devel libglade2-devel pkgconfig && yum clean all && rpm -q gtk3-devel gtk2-devel libglade2-devel glib2-devel
