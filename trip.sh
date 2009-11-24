#!/bin/bash

# Trip, a TRIvial Packager
#
# Copyright 2006-2007 Pierre Hebert <pierrox@pierrox.net>
# http//www.pierrox.net/trip/
#
# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2,
# or (at your option) any later version.
#
# This is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with dpkg; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

# :set ts=2 sw=2 nu et si

trap clean 2 15

# some mandatory default values
TRIP_CONFIG_DIR=${TRIP_CONFIG_DIR:-/etc/trip}
if [ ! -d "$TRIP_CONFIG_DIR" ]; then
    echo WTF IS WRONG $TRIP_CONFIG_DIR
  TRIP_CONFIG_DIR=/trip/conf
fi


# delete temporary files and directories, called on SIGINT and SIGTERM
function clean {
  # umount temporary filesystems
  umount "$TRIP_FS_UNION$TRIP_TMPDIR" 2> /dev/null
  umount "$TRIP_FS_UNION"/proc 2> /dev/null
  umount "$TRIP_FS_UNION"/sys 2> /dev/null
  umount "$TRIP_FS_UNION"/dev/shm 2> /dev/null
  umount "$TRIP_FS_UNION"/dev/pts 2> /dev/null
  umount "$TRIP_FS_UNION"/dev 2> /dev/null
  umount "$TRIP_FS_UNION" 2> /dev/null
}



# simple trace function
function trace {
  level="$1"
  shift
  if [ "$level" -le "$verbose_level" ]; then
    case "$level" in 1) mark='X';; 2) mark='-';; 3) mark='+';; *) mark='?';; esac 
    echo "$mark $*"
  fi
}



# do what it's name say
function usage {
  verbose_level=3
  trace 3 "Trip, a Trivial Package manager, using Unionfs. You are using version 0.3"
  trace 3 "usage : trip -i,   --install <binary package file> [--no-conflict]"
  trace 3 "                   (install from a pre-built binary package)"
  trace 3 "             -u,   --uninstall <package name>"
  trace 3 "                   (uninstall a package installed with trip)"
  trace 3 "             -b,   --build <source package directory>"
  trace 3 "                   (create a binary package from sources)"
  trace 3 "             -r,   --rebuild <package name>"
  trace 3 "                   (rebuild a binary package from an installed package)"
  trace 3 "             -w,   --wizard"
  trace 3 "                   (ask some questions, create a source package, build it and install it)"
  trace 3 "             -l,   --list [<package name>|<binary package file>]"
  trace 3 "                   (list installed packages, files from an installed package or files from a binary package)"
  trace 3 "             -f,   --find-file <file>"
  trace 3 "                   (find the package(s) containing \"file\")"
  trace 3 "             -bbi, --batch-build-install <package list>"
  trace 3 "                   (build and install a set of packages from \"package list\")"
  trace 3 "             -bu,  --batch-uninstall <package list>"
  trace 3 "                   (uninstall a set of packages from \"package list\")"
  trace 3 "                   --upgrade-bd-from-0.1-to-0.2"
  trace 3 "                   --upgrade-bd-from-0.2-to-0.3"
  trace 3 "                   (migrate data from a previous package database format)"
  trace 3 "             -c,   --config-dir <dir>"
  trace 3 "                   (specify an alternate configuration directory)"
  trace 3 "             -t,   --trip-path <path>"
  trace 3 "                   (specify an alternate path to this trip shell script)"
  trace 3 "             -v,   --verbose-level <0|1|2|3>"
  trace 3 "                   (verbosity where 0=quiet, 1=errors, 2=errors/warnings, 3=errors/warnings/infos)"
  trace 3 "             -h,   --help"
  trace 3 "                   (print this short help, see also http://www.pierrox.net/trip/ for more)"
}


# mktemp is not always available
function pseudo_mktemp {
  temp="$TRIP_TMPDIR/$2"
    rm -rf "$temp"
  if [ "$1" = "-f" ]; then
    touch "$temp"
  else 
    mkdir "$temp"
  fi

  echo "$temp"
}


# build inside a chrooted unionfs a binary package from a source directory $1
function build_chroot {
  trap - 2 15

  src_dir="$1"

  # get the package meta data
  source "$src_dir/support/identification"

  # give a default values for meta data
  [ -z "$TRIP_RELEASE" ] && TRIP_RELEASE=1
  [ -z "$TRIP_ARCH" ] && TRIP_ARCH=`uname -m`

  export TRIP_NAME TRIP_VERSION TRIP_RELEASE TRIP_ARCH

  # create a temporary build directory
  tmp_build_dir=`pseudo_mktemp -d "build_dir"`
  if [ ! -d "$tmp_build_dir" ]
  then
    trace 1 "unable to create a temporary build directory"
    return 1
  fi

  # export the temporary src and build directory location for the package scripts
  export SRC_DIR="$src_dir"
  export TMP_BUILD_DIR="$tmp_build_dir"

  # build the package
  if [ -x "$src_dir/support/build.sh" ]
  then 
    trace 3 "building the package"
    "$src_dir/support/build.sh"
    if [ $? != 0 ]; then
      trace 1 "chroot build step failed"
      return 1
    fi
  fi

  # install the package
  install_failed=0
  trace 3 "fake-installing the package"
  "$src_dir/support/install.sh"
  if [ $? != 0 ]; then
    trace 1 "install step failed"
    install_failed=1
  fi

  if [ $install_failed = 1 ]; then
    return 1
  fi
}

function build {
  src_dir="$1"

  if [ "${src_dir:0:1}" != "/" ]; then
    src_dir="$PWD/$src_dir"
  fi

  # some sanity checks before to begin
  if [ ! -d "$src_dir" ]; then
    trace 1 "the source package \"$src_dir\" does not exists"
    return 1
  fi

  if [ ! -x "$src_dir/support/install.sh" ]; then
    trace 1 "the support/install.sh file is mandatory but does not exists or is not executable"
    return 1
  fi
  if [ ! -r "$src_dir/support/identification" ]; then
    trace 1 "the support/identification file is mandatory but does not exists"
    return 1
  fi

  # get the package meta data, and check some of them
  trace 3 "reading package identification"
  source "$src_dir/support/identification"

  [ -z "$TRIP_RELEASE" ] && TRIP_RELEASE=1
  [ -z "$TRIP_ARCH" ] && TRIP_ARCH=`uname -m`

  if [ -z "$TRIP_NAME" ]; then
    trace 1 "identification : the TRIP_NAME variable is not set"
    return 1
  fi
  if [ -z "$TRIP_VERSION" ]; then
    trace 1 "identification : the TRIP_VERSION variable is not set"
    return 1
  fi

  trace 3 "we are about to build $TRIP_NAME-$TRIP_VERSION for $TRIP_ARCH"

  # clean the package filesystem before to begin install
  trace 3 "cleaning package filesystem before to build"
  if [ -z "$TRIP_FS_PKG" ]; then
    trace 1 "check the TRIP_FS_PKG variable : it is empty !"
  else
    rm -rf "$TRIP_FS_PKG"/*
  fi


  # mount temporary filesystems
  mount "$TRIP_FS_UNION"
  if [ $? != 0 ]; then
    trace 1 "unable to mount the union filesystem"
    return 1
  fi
  mount --bind /dev "$TRIP_FS_UNION/dev"
  mount -t devpts devpts "$TRIP_FS_UNION/dev/pts"
  mount -t tmpfs shm "$TRIP_FS_UNION/dev/shm"
  mount -t proc proc "$TRIP_FS_UNION/proc"
  mount -t sysfs sysfs "$TRIP_FS_UNION/sys"

  # remounting the tmp directory via bind avoid to filter files in this directory (idea from Stef Bon)
  mount --bind "$TRIP_TMPDIR" "$TRIP_FS_UNION$TRIP_TMPDIR"

  # go into the chroot jail
  if [ "$TRIP_MODE" = "hosted" ]; then
    chroot "$TRIP_FS_UNION" /tools/bin/env -i HOME=/root TERM="$TERM" PS1='\u:\w\$ ' PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin /tools/bin/bash --login +h -c "$TRIP_PATH --build_chroot '$src_dir' --config-dir '$config_dir'"
  else
    chroot "$TRIP_FS_UNION" /bin/bash -c "$TRIP_PATH --build_chroot '$src_dir' --config-dir '$config_dir'"
  fi

  ret=$?
  
  # umount temporary filesystems
  umount "$TRIP_FS_UNION$TRIP_TMPDIR" 2> /dev/null
  umount "$TRIP_FS_UNION/proc" 2> /dev/null
  umount "$TRIP_FS_UNION/sys" 2> /dev/null
  umount "$TRIP_FS_UNION/dev/shm" 2> /dev/null
  umount "$TRIP_FS_UNION/dev/pts" 2> /dev/null
  umount "$TRIP_FS_UNION/dev" 2> /dev/null
  umount "$TRIP_FS_UNION" 2> /dev/null
  
  # test the exit status of chroot
  if [ $ret != 0 ]; then
    trace 1 "build failed"
    return 1
  fi
  
  # list deleted, modified and added files
  trace 3 "examining installed files"
  install_status
  if [ `stat -c %s "$tmp_deleted_files"` != "0" ]; then
    trace 2 "there was deleted files :"
    cat "$tmp_deleted_files"
  fi
  if [ `stat -c %s "$tmp_modified_files"` != "0" ]; then
    trace 2 "there was modified files :"
    cat "$tmp_modified_files"
  fi
  if [ `stat -c %s "$tmp_added_files"` = "0" ]; then
    trace 2 "no file added"
  fi

  # build list of packaged files = modified files + added files - excluded files from conf - exclude files from package + included files from package
  tmp_pkg_files=`pseudo_mktemp -f "pkg_files"`
  cat "$tmp_modified_files" "$tmp_added_files" > "$tmp_pkg_files"
  if [ -r "$config_dir/exclude" ]; then
    cat "$tmp_pkg_files" | grep -v -f "$config_dir/exclude" > "$tmp_pkg_files.new"
    rm "$tmp_pkg_files"; mv "$tmp_pkg_files.new" "$tmp_pkg_files"
  fi
  if [ -r "$src_dir/support/exclude" ]; then
    cat "$tmp_pkg_files" | grep -v -f "$src_dir/support/exclude" > "$tmp_pkg_files.new"
    rm "$tmp_pkg_files"; mv "$tmp_pkg_files.new" "$tmp_pkg_files"
  fi
  if [ -r "$src_dir/support/include" ]; then
    cat "$src_dir/support/include" >> "$tmp_pkg_files"
  fi

  # create a temporary build directory
  tmp_pkg_build_dir=`pseudo_mktemp -d "pkg_build_dir"`
  if [ ! -d "$tmp_pkg_build_dir" ]
  then
    trace 1 "unable to create a temporary build directory"
    return 1
  fi

  # build the binary package
  trace 3 "building the binary package"
  pkg_name="$TRIP_NAME-$TRIP_VERSION-$TRIP_RELEASE.$TRIP_ARCH"
  pkg_dir="$tmp_pkg_build_dir/$pkg_name"
  rm -rf "$pkg_dir"
  mkdir -p "$pkg_dir"
  
  tar --create --file="$pkg_dir/files.tar" --directory="$TRIP_FS_PKG" --no-recursion --files-from="$tmp_pkg_files"
  mkdir "$pkg_dir/support"
  cp "$src_dir/support/identification" "$pkg_dir/support"
  for f in "$src_dir/support/"{pre,post}_{,un}install.sh; do
    [ -f "$f" ] && cp "$f" "$pkg_dir/support"
  done

  tar --create --directory="$tmp_pkg_build_dir" "$pkg_name" | gzip > "$pkg_name.tar.gz"

  trace 3 "created binary package \"$pkg_name.tar.gz\""
}



# list deleted, modified and added files during install stage
function install_status {
  tmp_deleted_files=`pseudo_mktemp -f "deleted_files"`
  tmp_modified_files=`pseudo_mktemp -f "modified_files"`
  tmp_added_files=`pseudo_mktemp -f "added_files"`
  if [ ! -f "$tmp_deleted_files" -o ! -f "$tmp_modified_files" -o ! -f "$tmp_added_files" ]; then
    trace 1 "unable to create a temporary file"
    return 1
  fi

  
  # compute the length of the pkg path prefix, including a trailing "/"
  let "pkg_length=${#TRIP_FS_PKG}+1"
  
  # find deleted directories
  find "$TRIP_FS_PKG" -name ".wh.__dir_opaque" |
  (
  while read wh; do
    d=`dirname "$wh"`
    d=${d:$pkg_length}
    if [ ! -d "$TRIP_FS_PKG/$d" -a -d "$TRIP_FS_ROOT/$d" ]; then
      echo "$d" >> "$tmp_deleted_files"
    fi
  done
  )

  # find deleted files
  find "$TRIP_FS_PKG" -name ".wh.*" | grep -v "\.wh\.__dir_opaque" |
  (
  while read wh; do
    d=`dirname "$wh"`
    d=${d:$pkg_length}
    f=`basename "$wh"`
    f=${f:5}
    if [ ! -e "$TRIP_FS_PKG/$d/$f" -a -e "$TRIP_FS_ROOT/$d/$f" ]; then
      echo "$d/$f" >> "$tmp_deleted_files"
    fi
  done
  )

  # find added and modified files
  find "$TRIP_FS_PKG" | grep -v "\.wh\." |
  (
  while read f; do
    f=${f:$pkg_length}
    if [ "$f" ]; then
      if [ ! -e "$TRIP_FS_ROOT/$f" ]; then
        echo "$f" >> "$tmp_added_files"
      else
        s1=`stat -c "%a %u %g" "$TRIP_FS_ROOT/$f"`
        s2=`stat -c "%a %u %g" "$TRIP_FS_PKG/$f"`
        if [ "$s1" != "$s2" ]; then
          echo "$f" >> "$tmp_modified_files"
        else
          if [ ! -d "$TRIP_FS_PKG/$f" ]; then
            diff -q "$TRIP_FS_ROOT/$f" "$TRIP_FS_PKG/$f" > /dev/null 2>/dev/null
            if [ $? = 1 ]; then
              echo "$f" >> "$tmp_modified_files"
            fi
          fi
        fi
      fi
    fi
  done
  )
}



# install a binary package
# 3 pass :
#  - extract the support subdirectory
#  - check potential file conflicts
#  - extract package files
# 3 pass needs gunziping 3 times the archive but do not require intermediate disk space
function install {
  bin_pkg="$1"

  trace 3 "installing $bin_pkg"

  # need a temporary directory to extract package support files
  tmp_install_dir=`pseudo_mktemp -d "install_dir"`
  if [ ! -d "$tmp_install_dir" ]; then
    trace 1 "unable to create a temporary directory"
    return 1
  fi

  # extract then read package infos
  trace 3 "extracting meta data from the archive \"$1\""
  pkg_name=`tar -tf "$bin_pkg" | head -n 1 | sed "s/\/$//"`

  gzip -dc "$bin_pkg" | tar --extract --directory="$tmp_install_dir" "$pkg_name/support" 2> /dev/null

  if [ $? != 0 ]; then
    trace 1 "an error occured while extracting meta data from the archive"
    return 1
  fi

  if [ -f "$tmp_install_dir/$pkg_name/support/identification" ]; then
    source "$tmp_install_dir/$pkg_name/support/identification"
  else
    trace 1 "the archive does not look like a trip archive (no support/identification file)"
    return 1
  fi

  if [ -z "$TRIP_NAME" ]; then
    trace 1 "the TRIP_NAME variable is not set"
    return 1
  fi

  if [ -z "$TRIP_VERSION" ]; then
    trace 1 "the TRIP_VERSION variable is not set"
    return 1
  fi

  if [ -z "$TRIP_RELEASE" ]; then
    trace 1 "the TRIP_RELEASE variable is not set"
    return 1
  fi

  [ -z "$TRIP_ARCH" ] && TRIP_ARCH=`uname -m`

  pkg_name="$TRIP_NAME-$TRIP_VERSION-$TRIP_RELEASE.$TRIP_ARCH"

  # check that the package is not already installed (same name-version-release-arch)
  db_entry="$TRIP_DB/$pkg_name"
  if [ -d "$db_entry" ]; then
    trace 1 "the package \"$pkg_name\" is already installed"
    return 1
  fi

  # check for file conflicts (directories are not considered a source of conflict)
  if [ $no_conflict = 0 ]; then
    trace 3 "checking potential file conflicts"
    tmp_install_conflicts=`pseudo_mktemp -f "install_conflicts"`
    gzip -dc "$bin_pkg" | tar --extract --to-stdout "$pkg_name/files.tar" | tar --list |
    (
      while read f; do
        if [ ! -d "$TRIP_INSTALL_DIR/$f" ]; then
          if [ -e "$TRIP_INSTALL_DIR/$f" -o -L "$TRIP_INSTALL_DIR/$f" ]; then
            echo "$f" >> "$tmp_install_conflicts"
          fi
        fi
      done
    )
    if [ `stat -c %s "$tmp_install_conflicts"` != "0" ]; then
      trace 1 "file conflicts have been found :"
      cat "$tmp_install_conflicts"
      return 1
    else
      trace 3 "no conflict found"
    fi
  else
    trace 3 "ignoring potential file conflicts"
  fi
  
  # create the package entry in the TRIP database, and copy some files
  trace 3 "creating package database entry"
  if mkdir -p "$db_entry" 2> /dev/null; then
    # save the list of installed files
    gzip -dc "$bin_pkg" | tar --extract --to-stdout "$pkg_name/files.tar" | tar --list > "$db_entry/files"
    
    # save the detailled list of installed files (tar output may differ according to locale)
    gzip -dc "$bin_pkg" | tar --extract --to-stdout "$pkg_name/files.tar" | tar --list --verbose > "$db_entry/files-detail"

    # copy support scripts
    # {pre,post}_install.sh scripts are also stored in case the package is rebuilded, uninstalled and then re-installed from the rebuilded archive
    for i in "$tmp_install_dir/$pkg_name"/support/{pre,post}_{un,}install.sh "$tmp_install_dir/$pkg_name/support/identification"; do
      if [ -r "$i" ]; then
        cp "$i" "$db_entry"
        if [ $? != 0 ]; then
          trace 1 "unable to copy \""`basename "$i"`"\" to \"$db_entry\""
          rm -rf "$db_entry"
          return 1
        fi
      fi
    done
  else
    trace 1 "unable to create the directory \"$db_entry\""
    return 1
  fi

  # run common pre install script
  if [ -x "$config_dir/pre_install.sh" ]; then
    trace 3 "running common pre install script"
    "$config_dir/pre_install.sh"
    if [ $? != 0 ]; then
      trace 1 "common pre install script failed, please check manually that the system has not been altered"
      rm -rf "$db_entry"
      return 1
    fi
  fi
  
  # run pre install script
  if [ -x "$tmp_install_dir/$pkg_name/support/pre_install.sh" ]; then
    trace 3 "running pre install script"
    "$tmp_install_dir/$pkg_name/support/pre_install.sh"
    if [ $? != 0 ]; then
      trace 1 "pre install script failed, please check manually that the system has not been altered"
      rm -rf "$db_entry"
      return 1
    fi
  fi
  
  # needed to prevent symbols to be resolved in newly installed libraries. instead bind all symbols now, at start of execution of tar
  # this is especially needed for update of glibc
  export LD_BIND_NOW=yes

  # extract the file archive into the destination directory, and saves the list of files
  trace 3 "extracting files from archive"
  gzip -dc "$bin_pkg" | tar --extract --to-stdout "$pkg_name/files.tar" | tar --extract --directory="$TRIP_INSTALL_DIR"
  unset LD_BIND_NOW
  if [ $? != 0 ]; then
    trace 1 "an error occured while extracting the file archive, attempting to uninstall files..."

    # trying to remove installed files can only be done if no overwrite has been done (no conflict)
    remove_files "$db_entry/files"

    rm -rf "$db_entry"
    return 1
  fi

  
  # run post install script
  if [ -x "$tmp_install_dir/$pkg_name/support/post_install.sh" ]; then
    trace 3 "running post install script"
    "$tmp_install_dir/$pkg_name/support/post_install.sh"
    if [ $? != 0 ]; then
      trace 1 "post install script failed, the package may have been partially installed"
    fi
  fi

  # run common post install script
  if [ -x "$config_dir/post_install.sh" ]; then
    trace 3 "running common post install script"
    "$config_dir/post_install.sh"
    if [ $? != 0 ]; then
      trace 1 "common post install script failed, the package may have been partially installed"
    fi
  fi

  # finally store the package name in the list of installed package
  echo $pkg_name >> "$TRIP_DB/list"
  
  trace 3 "the package \"$pkg_name\" has been successfully installed"
}



function uninstall {
  pkg_name="$1"
  db_entry="$TRIP_DB/$pkg_name"

  trace 3 "uninstalling $pkg_name"

  if [ ! -d "$db_entry" ]; then
    trace 1 "the package \"$pkg_name\" is not installed"
    return 1
  fi

  if [ ! -r "$db_entry/files" ]; then
    trace 1 "the list of files belonging to the package \"$pkg_name\" is not available"
    return 1
  fi

  # run common pre uninstall script
  if [ -x "$config_dir/pre_uninstall.sh" ]; then
    trace 3 "running common pre uninstall script"
    "$config_dir/pre_uninstall.sh"
    if [ $? != 0 ]; then
      trace 1 "common pre uninstall script failed, please check manually that the system has not been altered"
      return 1
    fi
  fi
  
  # run pre uninstall script
  if [ -x "$TRIP_DB/$pkg_name/pre_uninstall.sh" ]; then
    trace 3 "running pre uninstall script"
    "$TRIP_DB/$pkg_name/pre_uninstall.sh"
    if [ $? != 0 ]; then
      trace 1 "pre uninstall script failed, please check manually that the system has not been altered"
      return 1
    fi
  fi
  
  # remove files
  trace 3 "removing files"
  remove_files "$db_entry/files"
  
  # run post uninstall script
  if [ -x "$TRIP_DB/$pkg_name/post_uninstall.sh" ]; then
    trace 3 "running post uninstall script"
    "$TRIP_DB/$pkg_name/post_uninstall.sh"
    if [ $? != 0 ]; then
      trace 1 "post uninstall script failed, the package may have been partially uninstalled"
    fi
  fi
  
  # run common post uninstall script
  if [ -x "$config_dir/post_uninstall.sh" ]; then
    trace 3 "running common post uninstall script"
    "$config_dir/post_uninstall.sh"
    if [ $? != 0 ]; then
      trace 1 "common post uninstall script failed, the package may have been partially uninstalled"
    fi
  fi
  
  # remove the package from the database, and from the package list
  trace 3 "removing the package from the database"
  rm -rf "$db_entry"
  sed "/$pkg_name/d" -i "$TRIP_DB/list"
}



# delete files and empty directories listed in the file "$1"
# this is realized in 2 pass : first files, then empty directories
# files are listed with a path relative to / ("usr/lib", not "/usr/lib")
function remove_files {
  files="$1"
  cat "$files" |
  (
    while read f; do
      f="$TRIP_INSTALL_DIR/$f"
      if [ -L "$f" -o -e "$f" -a ! -d "$f" ]; then
        rm -f "$f"
        if [ $? != 0 ]; then
          trace 2 "unable to delete the file \"$f\""
        fi
      fi
    done
  )
  cat "$files" |
  (
    while read f; do
      f="$TRIP_INSTALL_DIR/$f"
      if [ -d "$f" ]; then
        rmdir --ignore-fail-on-non-empty --parents "$f"
        if [ $? != 0 ]; then
          trace 2 "unable to delete the directory \"$f\""
        fi
      fi
    done
  )
}



# ask the user a few questions, and create a source directory, suitable for invocation of trip --build
function wizard {
  
  # meta infos
  default_arch=`uname -m`
  until echo -n "Package name : "; read name; [ "$name" ]; do echo "  please enter a valid package name"; done
  until echo -n "Package version : "; read version; [ "$version" ]; do echo "  please enter a valid package version"; done
  if [ -d "$name-$version" ]; then
    default_answer=yes
    echo -n "A package \"$name-$version\" already exists. Erase it (yes/no) ? [$default_answer] : "; read answer; answer=${answer:-$default_answer}
    if [ "$answer" = "yes" ]; then
      rm -rf "$name-$version"
    fi
  fi
  until echo -n "Package url : "; read url; [ "$url" ]; do echo "  please enter a valid package url"; done
  echo -n "Package description : "; read description

  # source files
  i=0
  while echo -n "Source file #$i (leave it blank to stop) : "; read files[$i]; [ "${files[$i]}" ];do let i++; done
  
  # build.sh and install.sh scripts. 
  # - a default script is proposed
  # - if not modified by the user, remove it
  # - if modified store it

  [ "$EDITOR" ] || EDITOR=vim

  # build.sh
  tmp_build_script=`pseudo_mktemp -f "build_script"`
  cat > "$tmp_build_script" <<- EOF
	#!/bin/sh

	cd "\$TMP_BUILD_DIR/" &&
	tar xf "\$SRC_DIR/src/\$TRIP_NAME-\$TRIP_VERSION.tar."[gb]z* &&
	cd "\$TRIP_NAME-\$TRIP_VERSION" &&
	./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var &&
	make
	EOF
  chmod +x "$tmp_build_script"

  date_1=`stat -c %Z "$tmp_build_script"`
  "$EDITOR" "$tmp_build_script"
  date_2=`stat -c %Z "$tmp_build_script"`
  if [ "$date_1" = "$date_2" ]; then
    rm -f "$tmp_build_script"
  fi

  # install.sh
  tmp_install_script=`pseudo_mktemp -f "install_script"`
  cat > "$tmp_install_script" <<- EOF
	#!/bin/sh

	cd "\$TMP_BUILD_DIR/\$TRIP_NAME-\$TRIP_VERSION" &&
	make install
	EOF
  chmod +x "$tmp_install_script"

  date_1=`stat -c %Z "$tmp_install_script"`
  "$EDITOR" "$tmp_install_script"
  date_2=`stat -c %Z "$tmp_install_script"`
  if [ "$date_1" = "$date_2" ]; then
    rm -f "$tmp_install_script"
  fi

  # now that all informations are gathered construct a src directory
  mkdir -p "$name-$version/"{src,support}
  
  cat > "$name-$version/support/identification" <<- EOF
	TRIP_NAME="$name"
	TRIP_VERSION="$version"
	TRIP_RELEASE=1
	TRIP_URL="$url"
	TRIP_DESCRIPTION="$description"
	EOF

	[ -f "$tmp_build_script" ] && mv "$tmp_build_script" "$name-$version/support/build.sh"
	[ -f "$tmp_install_script" ] && mv "$tmp_install_script" "$name-$version/support/install.sh"

  i=0
  while [ "${files[$i]}" ]; do
    [ -e "${files[$i]}" ] && cp -r "${files[$i]}" "$name-$version/src/"
    let i++
  done

  default_answer=yes
  echo -n "Build the package ? (yes/no) ? [$default_answer] : "; read answer; answer=${answer:-$default_answer}
  if [ "$answer" = "yes" ]; then
    build "$PWD/$name-$version"
    if [ $? = 0 ]; then
      default_answer=yes
      echo -n "Install the package ? (yes/no) ? [$default_answer] : "; read answer; answer=${answer:-$default_answer}
      if [ "$answer" = "yes" ]; then
        trip --install "$PWD/$name-$version-"*.tar.gz
      fi
    fi
  fi
}



# list already installed packages, or files belonging to a package
function list {
  if [ -z "$1" ]; then
    # no argument : list of installed packages
    cat "$TRIP_DB/list"
  else
    if [ $verbose_level = 3 ]; then
      files=files-detail
      verbose="--verbose"
    else
      files=files
      verbose=""
    fi
    
    if [ -f "$TRIP_DB/$1"*"/$files" ]; then
      # argument is an installed package
      cat "$TRIP_DB/$1"*"/$files"
    else
      if [ -f "$1" ]; then
        # argument is a file
        gzip -dc "$1" | tar --extract --to-stdout "*files.tar" | tar --list $verbose
      else
        trace 1 "no such package \"$1\" (nor installed, neither a file)"
      fi
    fi
  fi
}



# find the package containing a file
function find_file {
  find "$TRIP_DB" -name content | xargs grep -l "$1" |
  (
    while read f; do
      trace 3 "$f : "
      grep "$1" "$f"
    done
  )
}

# batch build and install a list of source packages
function batch_build_install {
  if [ "$no_conflict" = 1 ]; then
    n="--no-conflict"
  fi

  cat $1 |
  (
    while read pkg; do
      "$TRIP_PATH" -b "$pkg" || exit 1
      "$TRIP_PATH" $n -i "$pkg-"* || exit 1
    done
  )
}

# uninstall a list of packages
function batch_uninstall {
  cat $1 |
  (
    while read pkg; do
      "$TRIP_PATH" -u "$pkg" || exit 1
    done
  )
}

# upgrade the installed packages database from 0.1 format to 0.2
function upgrade_bd_0_1_0_2 {
  cd "$TRIP_DB" || { trace 1 "unable to cd into $TRIP_DB"; exit 1; }

  for i in *
  do 
    if [ -d "$i" ] && [ -f "$i/content" ]; then
      cd $i
      mv content content.old
      rm -f error
      ( tar -C "$TRIP_INSTALL_DIR" -T content.old -c || touch error ) | ( tar tv || touch error ) > content.new
      if [ ! -f error ]; then
        rm -f content.old
        mv content.new content
      else
        trace 1 "unable to upgrade package \"$i\", it will be left untouched"
        mv content.old content
        rm -f content.new error
      fi
      cd ..
    fi
  done
}

# upgrade the installed packages database from 0.2 format to 0.3
function upgrade_bd_0_2_0_3 {
  cd "$TRIP_DB" || { trace 1 "unable to cd into $TRIP_DB"; exit 1; }

  for i in *
  do 
    if [ -d "$i" ] && [ -f "$i/content" ]; then
      cd $i
      mv content files-detail
      cat files-detail | tr -s " " | cut -f6 -d" " > files
      cd ..
    fi
  done
}

# rebuild a binary package from an installed package
# (warning : the newly created package file may be different from the original if files have been altered)
function rebuild {
  pkg_name="$1"
  files="$TRIP_DB/$pkg_name/files"
  if [ ! -f "$files" ]; then
    trace 1 "the package \"$pkg_name\" does not seem to be valid"
    exit 1
  fi
  
  mkdir -p "$pkg_name/support" || { trace 1 "unable to create a temporary directory"; exit 1; }
  
  [ $verbose_level = 3 ] && verbose="--verbose"
  trace 3 "creating an archive with the files belonging to the package..."
  tar --directory="$TRIP_INSTALL_DIR" --create --files-from "$files" $verbose > "$pkg_name/files.tar"
  
  trace 3 "copying support files..."
  for i in "$TRIP_DB/$pkg_name/identification" "$pkg_name/support" "$TRIP_DB/$pkg_name/"{pre,post}_{un,}install.sh
  do
    [ -f "$i" ] && cp "$i" "$pkg_name/support"
  done

  trace 3 "creating the binary package..."
  tar czf "$pkg_name.tar.gz" "$pkg_name"
  rm -rf "$pkg_name"
}

##########################
# here begins the script #
##########################

# process command line parameters
config_dir=""
mode="usage"
no_conflict=0
verbose_level=1
trip_path=""

while [ "$1" ]; do
  case "$1" in
    --install|-i)
      mode=install
      arg1="$2"
      shift
      ;;
      
    --uninstall|-u)
      mode=uninstall
      arg1="$2"
      shift
      ;;

    --build|-b)
      mode=build
      arg1="$2"
      shift
      ;;

    --build_chroot)
      mode=build_chroot
      arg1="$2"
      shift
      ;;
    
    --wizard|-w)
      mode=wizard
      ;;

    --list|-l)
      mode=list
      arg1="$2"
      shift
      ;;

    --find-file|-f)
      mode=find-file
      arg1="$2"
      shift
      ;;
    
    --batch-build-install|-bbi)
      mode=batch_build_install
      arg1="$2"
      shift
      ;;

    --batch-uninstall|-bu)
      mode=batch_uninstall
      arg1="$2"
      shift
      ;;

    --upgrade-bd-from-0.1-to-0.2)
      mode=upgrade_bd_0_1_0_2
      ;;

    --upgrade-bd-from-0.2-to-0.3)
      mode=upgrade_bd_0_2_0_3
      ;;

    --rebuild|-r)
      mode=rebuild
      arg1="$2"
      shift
      ;;

    --no-conflict|-nc)
      no_conflict=1
      ;;

    --verbose-level|-v)
      verbose_level=$2
      shift
      ;;

    --config-dir|-c)
      config_dir="$2"
      shift
      ;;
      
    --trip-path|-t)
      trip_path="$2"
      shift
      ;;
      
    --help|-h)
      mode=usage
      ;;

    "")
      break
      ;;
      
    *) 
      trace 1 "unknown parameter \"$1\""
      usage
      exit 2
      ;;
  esac
  shift
done

# time to show some limited help ?
if [ "$mode" == "usage" ]; then
  usage
  exit 0
fi

# determine the configuration directory
config_dir="${config_dir:-$TRIP_CONFIG_DIR}"

if [ ! -r "$config_dir/conf" ]; then
  trace 1 "unable to read config file \"$config_dir/conf\""
  exit 2
fi

source "$config_dir/conf"

# override TRIP_PATH if specified on command line
if [ ! -z "$trip_path" ]; then
  TRIP_PATH="$trip_path"
fi

# TRIP_INSTALL_DIR is used by {pre,post}_{un,}install.sh scripts
export TRIP_INSTALL_DIR



# precious sanity check before to do some cleaning...
if [ "$TRIP_TMPDIR" == "/" -o "$TRIP_TMPDIR" == "" ]; then
  trace 1 "the temp directory \"$TRIP_TMPDIR\" has not a correct value"
  exit 2
fi

# create a temp directory, in which all temp files will be put
mkdir -p "$TRIP_TMPDIR"
if [ ! -d "$TRIP_TMPDIR" ]; then
  trace 1 "the temp directory \"$TRIP_TMPDIR\" does not exist and could not be created"
  exit 2
fi


# in case some program use mktemp, make sure these temp files are located in TRIP_TMPDIR
export TMPDIR="$TRIP_TMPDIR"

# some build do not use the same user, so ensure that tmp is rw for everybody when building a package
[ "$mode" = build ] && chmod 0777 "$TRIP_TMPDIR"


# do the real work
case "$mode" in
  install)              install "$arg1" ;;
  uninstall)            uninstall "$arg1" ;;
  build)                build "$arg1" ;;
  build_chroot)         build_chroot "$arg1" ;;
  wizard)               wizard ;;
  list)                 list "$arg1" ;;
  find-file)            find_file "$arg1" ;;
  batch_build_install)  batch_build_install "$arg1" ;;
  batch_uninstall)      batch_uninstall "$arg1" ;;
  upgrade_bd_0_1_0_2)   upgrade_bd_0_1_0_2 ;;
  upgrade_bd_0_2_0_3)   upgrade_bd_0_2_0_3 ;;
  wizard)               wizard ;;
  rebuild)              rebuild "$arg1" ;;
esac

ret=$?

clean

trace 3 "done"

exit $ret
