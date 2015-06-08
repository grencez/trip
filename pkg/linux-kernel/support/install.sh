#!/bin/sh

cd "$TMP_BUILD_DIR"
make modules_install

# Work around unionfs
mount /boot
cp arch/x86_64/boot/bzImage "/boot/kernel-$TRIP_VERSION"
umount /boot

make clean

mkdir -p "/usr/src/linux-$TRIP_VERSION/"
cp -rPT --preserve=mode,timestamps  "./" "/usr/src/linux-$TRIP_VERSION/"

cd /lib/modules/$TRIP_VERSION
rm source build
ln -s /usr/src/linux-$TRIP_VERSION source
ln -s /usr/src/linux-$TRIP_VERSION build

