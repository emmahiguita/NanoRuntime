export HOME=/data/data/dev.nanoai.mobile/files/nano/home
export PREFIX=/data/user/0/dev.nanoai.mobile/files/nano/usr
export PATH=/data/user/0/dev.nanoai.mobile/files/nano/usr/bin:/system/bin
export LD_LIBRARY_PATH=/data/user/0/dev.nanoai.mobile/files/nano/usr/lib
mkdir -p $PREFIX/share/X11/xkb/rules $PREFIX/share/X11/xkb/symbols
touch $PREFIX/share/X11/xkb/rules/evdev
touch $PREFIX/share/X11/xkb/rules/evdev.lst
files/nano/usr/bin/Xvnc :1 -geometry 1024x768 -depth 24 -SecurityTypes None -localhost yes &
sleep 3
ps | grep Xvnc
echo DONE