#!/bin/sh

rmdir "$TMP_BUILD_DIR/"
ln -s "$SRC_DIR/src" "$TMP_BUILD_DIR"
cd "$TMP_BUILD_DIR"
make -j3

