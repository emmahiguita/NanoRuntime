import json, os, sys
print("python:", sys.version)
print("cwd:", os.getcwd())
print("json ok")
# test file I/O
with open("/data/user/0/dev.nanoai.mobile/files/nano/tmp/pytest.txt", "w") as f:
    f.write("hello from python")
print("file_io ok")
print("ALL_OK")
