
Trip is GPLv2, see COPYING.

This is a continuation/fork of Pierre Hebert's TRIvial Package manager.
[ref1](http//www.pierrox.net/trip/)
[ref2](http://www.linuxfromscratch.org/hints/downloads/files/package_management_using_trip.txt)


# Installation

To run, you need the unionfs-fuse package or similar file system (see Notes section).

Building and installing is the normal procedure.
```
git clone https://github.com/grencez/trip.git trip
cd trip
make
sudo make install
```

This puts scripts and binaries in `/usr/bin/`, configs in `/etc/trip/`, and mount points in `/mnt/trip/`.
Additionally, `trip` will use `/var/lib/trip/` to store package information.

```
make uninstall-bin
make install-bin
```


## Local Config

To use `$HOME/.trip/` instead of `/etc/trip/`, run with the following commands for a default installation:
```
sudo make install-bin
sudo install -d /mnt/trip/lfs /mnt/trip/union /mnt/trip/pkg
cp -r -T etc-trip ~/.trip
```

Many caveats exist though.

* If `/etc/trip/` exists, it will be used as a default before `$HOME/.trip/`. In this case, you must explicitly use the `TRIP_CONFIG_DIR` environment variable or the `-c` flag.
* The line `Defaults env_keep += "HOME"` must exist in your `/etc/sudoers` file (edit with `visudo`).


# Usage

The quick way to install packages is simply:
```
tripskel <progname> <version>  <source>
sudo trip -b <progname>-<version>
sudo trip -i <progname>-<version>-<arch>.tar.gz
```

For example:
Uninstall previous versions before building, else you won't get the files that overlap on install!
```
cd ~/packaging/apvlv
tripskel apvlv 0.0.9.6 ~/Downloads/apvlv-0.0.9.6.tar.gz
# List previous version.
trip -l | grep apvlv
# Uninstall previous version.
sudo trip -u apvlv-0.0.9.5-x86_64
sudo trip -u apvlv-doc-0.0.9.5-x86_64
# Build.
sudo trip -b apvlv-0.0.9.6
# Install.
sudo trip -i apvlv-0.0.9.6-x86_64.tar.gz
sudo trip -i apvlv-doc-0.0.9.6-x86_64.tar.gz
```

# Notes

Only configuration for unionfs-fuse is provided, but `/etc/trip/conf` can be modified to use other union file systems.

Packages are built and installed on a tmpfs by default, which can cause a system to run out of memory if it does not have much RAM or if the package is very large.
To avoid this, change the `TRIP_FS_PKG_MOUNT` command in `/etc/trip/conf` to mount a file (instead of RAM) via loopback to `TRIP_FS_PKG`.
I successfully did this in the past with the non-FUSE version of UnionFS, but could not do it with AUFS.


Please bug me, Alex Klinkhamer @ (com.gmail::grencez) about relevant stuff.
Updates found at https://github.com/grencez/trip

