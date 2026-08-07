#!/bin/sh
# Fake xkbcomp — creates the output file so Xvnc doesn't crash
# Xvnc passes the output file as the last argument
out=""
for arg in "$@"; do
  case "$arg" in
    *.xkm) out="$arg" ;;
  esac
done
if [ -n "$out" ]; then
  touch "$out" 2>/dev/null || true
fi
exit 0
