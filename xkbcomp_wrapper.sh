#!/bin/sh
# xkbcomp wrapper — delegates to xkbcli-compile-keymap
# Xvnc calls: xkbcomp -w 1 -R<prefix> -xkm - <outfile>
export LD_LIBRARY_PATH=/data/user/0/dev.nanoai.mobile/files/nano/usr/lib
PREFIX=/data/user/0/dev.nanoai.mobile/files/nano/usr
exec $PREFIX/libexec/xkbcommon/xkbcli-compile-keymap "$@"
