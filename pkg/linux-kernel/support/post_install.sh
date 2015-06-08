#!/bin/sh

cd /usr/src
rm -f linux
ln -s "$(ls -t | head -n 1)" linux

