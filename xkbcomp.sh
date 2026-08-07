#!/bin/sh
out=""
for arg in "$@"; do
  case "$arg" in
    *.xkm) out="$arg" ;;
  esac
done
if [ -n "$out" ]; then
  touch "$out"
fi
exit 0
