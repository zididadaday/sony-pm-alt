#!/bin/sh
mkdir temp
wget https://github.com/gphoto/libgphoto2/archive/refs/tags/v2.5.32.tar.gz
tar -xvf v2.5.32.tar.gz -C temp 
cd /root/temp/libgphoto2-2.5.32
patch -p1 -ruN -d . < /root/sony-library_c.patch > /root/patch.log
autoreconf -is --force
./configure --with-libexif=auto
make
make install
