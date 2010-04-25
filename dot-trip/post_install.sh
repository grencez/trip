#!/bin/sh

if [ -x "$TRIP_INSTALL_DIR/usr/bin/install-info" ]; then
  INFO="$TRIP_INSTALL_DIR/usr/share/info"
  rm -f "$INFO/dir" && for i in "$INFO"/*info; do "$TRIP_INSTALL_DIR/usr/bin/install-info" --dir-file="$INFO/dir" "$i"; done
fi

[ -f "$TRIP_INSTALL_DIR/etc/ld.so.conf" ] && ldconfig -r "$TRIP_INSTALL_DIR"
exit 0
