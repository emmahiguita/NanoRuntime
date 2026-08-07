import sys
data = open(sys.argv[1], 'rb').read()
old = b'/data/data/com.termux/files/usr'
new = b'/data/data/dev.nanoai.mobile/f\x00'
print(f'old={len(old)} new={len(new)}')
count = data.count(old)
data = data.replace(old, new)
open(sys.argv[1], 'wb').write(data)
print(f'Replaced {count} occurrences')
