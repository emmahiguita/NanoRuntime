"""
NanoAI Desktop Package Installer
Downloads and extracts Termux .deb packages for Linux desktop (Xvnc + openbox + tint2).
Uses Python's built-in lzma + tarfile to avoid the broken xz binary on Android.
"""
import os, sys, struct, lzma, tarfile, io, hashlib, urllib.request, json, tempfile, subprocess
from pathlib import Path

# ── Config ──
DEVICE_ID = "VGL7MVFMDYQG8T55"
STAGING = Path(os.environ["TEMP"]) / "nano_desktop_pkgs"
ROOTFS_REMOTE = "/data/user/0/dev.nanoai.mobile/files/nano"

TERMUX_REPOS = {
    "main": "https://packages-cf.termux.dev/apt/termux-main",
    "x11": "https://packages-cf.termux.dev/apt/termux-x11",
    "root": "https://packages-cf.termux.dev/apt/termux-root",
}

DESKTOP_PACKAGES = [
    "tigervnc", "openbox", "tint2", "libpng", "brotli",
    "libandroid-support", "libxcb", "libx11", "libxau", "libxdmcp",
    "libxext", "libpixman", "libxfont2", "libxkbfile", "fontconfig",
    "libexpat", "libunistring", "libidn2", "xkeyboard-config",
]

UA_HEADERS = {"User-Agent": "apt/2.7.14 (arm64) (termux)"}

def log(msg):
    print(f"  {msg}", flush=True)

def fetch_url(url, dest=None):
    req = urllib.request.Request(url, headers=UA_HEADERS)
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read()
    if dest:
        Path(dest).write_bytes(data)
    return data

def parse_packages_index(text, repo):
    """Parse Termux Packages index into dict of pkg_info."""
    pkgs = {}
    for para in text.split("\n\n"):
        name = version = depends = filename = sha256 = ""
        for line in para.split("\n"):
            if line.startswith("Package: "):
                name = line[9:].strip()
            elif line.startswith("Version: "):
                version = line[9:].strip()
            elif line.startswith("Depends: "):
                depends = line[9:].strip()
            elif line.startswith("Filename: "):
                filename = line[10:].strip()
            elif line.startswith("SHA256: "):
                sha256 = line[8:].strip()
        if name and filename:
            pkgs[name] = {
                "name": name, "version": version, "depends": depends,
                "filename": filename, "sha256": sha256,
                "repo_url": f"{repo}/{filename}",
            }
    return pkgs

def resolve_dependencies(targets, index):
    """BFS resolve all dependencies for target packages."""
    to_install = []
    seen = set()
    queue = list(targets)
    while queue:
        pkg = queue.pop(0)
        if pkg in seen:
            continue
        seen.add(pkg)
        info = index.get(pkg)
        if not info:
            log(f"WARN: package not found: {pkg}")
            continue
        to_install.append(info)
        # Parse dependencies
        deps_str = info.get("depends", "")
        if deps_str:
            for dep in deps_str.split(","):
                dep_name = dep.strip().split("|")[0].strip().split(" ")[0]
                if dep_name and dep_name not in seen:
                    queue.append(dep_name)
    return to_install

def extract_deb(deb_data, dest_dir):
    """Extract a .deb archive to dest_dir using Python's ar parser + lzma + tarfile."""
    # Parse ar archive
    if deb_data[:8] != b"!\x3c\x61\x72\x63\x68\x3e\x0a":  # !<arch>\n
        raise ValueError("Not a valid .deb ar archive")

    pos = 8
    data_xz = None

    while pos + 60 <= len(deb_data):
        if deb_data[pos + 58] != 0x60 or deb_data[pos + 59] != 0x0A:
            break

        name = deb_data[pos:pos+16].rstrip(b" ").rstrip(b"/").decode("ascii", errors="replace")
        size_str = deb_data[pos+48:pos+58].rstrip(b" ").decode("ascii", errors="replace")
        size = int(size_str)
        payload_start = pos + 60

        if name == "data.tar.xz":
            data_xz = deb_data[payload_start:payload_start+size]
            break

        pos = payload_start + size + (size % 2)

    if data_xz is None:
        raise ValueError("data.tar.xz not found in .deb")

    # Decompress xz
    decompressed = lzma.decompress(data_xz)

    # Extract tar
    with tarfile.open(fileobj=io.BytesIO(decompressed)) as tar:
        for member in tar.getmembers():
            # Strip ./data/data/com.termux/files/usr/ prefix (6 components)
            parts = member.name.lstrip("./").split("/")
            if len(parts) > 6 and parts[:6] == ["data", "data", "com.termux", "files", "usr"]:
                member.name = "/".join(parts[6:])
            else:
                # Strip any prefix up to "usr/"
                try:
                    usr_idx = parts.index("usr")
                    member.name = "/".join(parts[usr_idx+1:])
                except ValueError:
                    pass

            if not member.name:
                continue

            tar.extract(member, dest_dir, filter="data")

def push_to_device(local_dir, remote_base):
    """Push extracted files to device using adb."""
    # First push all files to /data/local/tmp, then copy with run-as
    local_dir = Path(local_dir)
    remote_tmp = "/data/local/tmp/nano_staging"

    # Create tarball of extracted files and push
    local_tar = local_dir.parent / "nano_desktop.tar"
    log(f"Creating tarball: {local_tar}")

    # Use tar to create archive
    subprocess.run([
        "tar.exe", "-cf", str(local_tar), "-C", str(local_dir), "."
    ], check=True, capture_output=True)

    log(f"Pushing tarball to device ({local_tar.stat().st_size} bytes)...")
    subprocess.run([
        "adb", "-s", DEVICE_ID, "push", str(local_tar), remote_tmp + ".tar"
    ], check=True, capture_output=True)

    log("Extracting on device...")
    # Use Termux tar (installed at usr/bin/tar) for full compatibility
    tar_bin = f"{remote_base}/usr/bin/tar"
    target_dir = f"{remote_base}/usr"
    subprocess.run([
        "adb", "-s", DEVICE_ID, "shell",
        f"run-as dev.nanoai.mobile sh -c 'LD_LIBRARY_PATH={remote_base}/usr/lib {tar_bin} -xf {remote_tmp}.tar -C {target_dir} 2>&1 && echo DONE'"
    ], check=True)

def main():
    STAGING.mkdir(parents=True, exist_ok=True)

    # Step 1: Fetch package indices
    print("=== Fetching package indices ===")
    all_pkgs = {}
    for repo_name, repo_url in TERMUX_REPOS.items():
        if repo_name == "main":
            index_url = f"{repo_url}/dists/stable/main/binary-aarch64/Packages"
        elif repo_name == "x11":
            index_url = f"{repo_url}/dists/x11/main/binary-aarch64/Packages"
        elif repo_name == "root":
            index_url = f"{repo_url}/dists/root/stable/binary-aarch64/Packages"

        log(f"Fetching {repo_name}: {index_url}")
        try:
            data = fetch_url(index_url).decode("utf-8", errors="replace")
            pkgs = parse_packages_index(data, repo_url)
            log(f"  {len(pkgs)} packages")
            all_pkgs.update(pkgs)
        except Exception as e:
            log(f"ERROR fetching {repo_name}: {e}")

    # Step 2: Resolve dependencies
    print(f"\n=== Resolving dependencies for {len(DESKTOP_PACKAGES)} desktop packages ===")
    to_install = resolve_dependencies(DESKTOP_PACKAGES, all_pkgs)
    log(f"Total packages to install: {len(to_install)}")

    # Step 3: Download and extract each .deb
    extract_dir = STAGING / "rootfs"
    extract_dir.mkdir(exist_ok=True)

    print(f"\n=== Downloading and extracting {len(to_install)} packages ===")
    for i, pkg in enumerate(to_install):
        name = pkg["name"]
        url = pkg["repo_url"]
        log(f"[{i+1}/{len(to_install)}] {name} ({pkg['version']})")

        try:
            deb_data = fetch_url(url)
            extract_deb(deb_data, extract_dir)
            log(f"  ✓ extracted")
        except Exception as e:
            log(f"  ✗ FAILED: {e}")

    # Step 4: Push to device
    print(f"\n=== Pushing to device {DEVICE_ID} ===")
    push_to_device(extract_dir, ROOTFS_REMOTE)

    print("\n=== DONE ===")

if __name__ == "__main__":
    main()
