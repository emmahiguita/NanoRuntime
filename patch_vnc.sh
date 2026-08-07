#!/bin/sh
set -e

PREFIX=/data/data/dev.nanoai.mobile/files/nano/usr
F=$PREFIX/bin/Xvnc

if [ ! -f $F.bak ]; then
  cp $F $F.bak
  export LD_LIBRARY_PATH=/data/user/0/dev.nanoai.mobile/files/nano/usr/lib
  $PREFIX/bin/python3 -c "
data = open('$F', 'rb').read()
old = b'/data/data/com.termux/files/usr'
new = b'/data/data/dev.nanoai.mobile/f\x00'
data = data.replace(old, new)
open('$F', 'wb').write(data)
print('Xvnc patched')
"
fi

for bin in openbox tint2; do
  FB=$PREFIX/bin/$bin
  if [ ! -f $FB.bak ]; then
    cp $FB $FB.bak
    $PREFIX/bin/python3 -c "
data = open('$FB', 'rb').read()
old = b'/data/data/com.termux/files/usr'
new = b'/data/data/dev.nanoai.mobile/f\x00'
data = data.replace(old, new)
open('$FB', 'wb').write(data)
print('$bin patched')
"
  fi
done

cd /data/data/dev.nanoai.mobile
ln -sf files/nano/usr f 2>/dev/null || true

cd $PREFIX/share/X11 2>/dev/null && ln -sf ../xkeyboard-config-2 xkb 2>/dev/null || true

cd $PREFIX
for dir in compat geometry keycodes rules symbols types; do
  ln -sf share/xkeyboard-config-2/$dir $dir 2>/dev/null || true
done

cat > $PREFIX/bin/xkbcomp << 'XEOF'
#!/bin/sh
out=""
for arg in "$@"; do case "$arg" in *.xkm) out="$arg" ;; esac; done
[ -n "$out" ] && touch "$out"
exit 0
XEOF
chmod 755 $PREFIX/bin/xkbcomp

echo "ALL PATCHES APPLIED"
