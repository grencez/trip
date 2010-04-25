#!/bin/sh

if [ $# -lt 3 ]
then
    echo "USEAGE: trip-skel.sh NAME VERSION SRC(/|.tgz|.tar.(gz|bz2))"
    exit 1
fi

name="$1"
vers="$2"
src_loc=`readlink -f "$3"`
unset tempf

mkdir -p "$name-$vers"
pushd "$name-$vers"
mkdir -p support src

###### BEG SUPPORT
pushd support
cat > build.sh << "EOF"
#!/bin/sh

cd "$TMP_BUILD_DIR/"
cp -rPpT "$SRC_DIR/src/" "./"
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make -j3
EOF

cat > install.sh << "EOF"
#!/bin/sh

cd "$TMP_BUILD_DIR"
make install
EOF


cat > identification <<EOF
TRIP_NAME="$name"
TRIP_VERSION="$vers"
TRIP_URL="http://www.google.com/search?q=${name}+program"
TRIP_DESCRIPTION="$name is a locally installed application."
EOF

chmod +x build.sh install.sh
popd # now in base package dir
###### END SUPPORT

dest_loc="src"
test ! -f "$dest_loc" &&
if expr "$src_loc" : "http://.*\.t\(ar\.\)\?\.gz" >/dev/null
then
    tempf=`mktemp tmp.XXXX.tgz`
    wget -O "$tempf" "$src_loc"
    src_loc="$tempf"
fi

if expr "$src_loc" : "^.*\(tar\.gz\|tgz\|bz2\)$" >/dev/null
then
    dir="`tar -tf "$src_loc" | head -n 1`"
    dir="`expr "$dir" : "^\([^/]*\)/.*$"`"
    if [    `tar -tf "$src_loc" | wc -l` \
        -eq `tar -tf "$src_loc" | grep -c "^$dir"` ]
    then
        tar -xpf "$src_loc" --transform="s:$dir:./:" -C "$dest_loc"
    else
        tar -xpf "$src_loc" -C "$dest_loc"
    fi
    unset dir
else
    cp -rPpT "$src_loc/" "$dest_loc/"
fi

popd # back to original

if test "$tempf"
then
    rm "$tempf"
    unset tempf
fi

exit 0

