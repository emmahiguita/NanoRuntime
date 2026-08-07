import struct, os, glob

base = r'C:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\build_tools\extracted'

def check_elf(path, label):
    if not os.path.exists(path):
        print(f'{label}: NOT FOUND ({path})')
        return
    with open(path, 'rb') as f:
        ehdr = f.read(64)
        e_type = struct.unpack('<H', ehdr[16:18])[0]
        type_str = {2: 'ET_EXEC', 3: 'ET_DYN'}.get(e_type, f'Unknown({e_type})')
        e_shoff = struct.unpack('<Q', ehdr[40:48])[0]
        e_shentsize = struct.unpack('<H', ehdr[58:60])[0]
        e_shnum = struct.unpack('<H', ehdr[60:62])[0]
        e_shstrndx = struct.unpack('<H', ehdr[62:64])[0]
        f.seek(e_shoff + e_shstrndx * e_shentsize)
        shstr_hdr = f.read(e_shentsize)
        shstr_offset = struct.unpack('<Q', shstr_hdr[24:32])[0]
        shstr_size = struct.unpack('<Q', shstr_hdr[32:40])[0]
        f.seek(shstr_offset)
        shstr_data = f.read(shstr_size)
        dynstr_off = dynstr_sz = dynamic_off = dynamic_sz = None
        f.seek(e_shoff)
        for i in range(e_shnum):
            shdr = f.read(e_shentsize)
            sh_name = struct.unpack('<I', shdr[0:4])[0]
            name_end = shstr_data.find(b'\x00', sh_name)
            sec_name = shstr_data[sh_name:name_end].decode() if name_end > 0 else ''
            if sec_name == '.dynstr':
                dynstr_off = struct.unpack('<Q', shdr[24:32])[0]
                dynstr_sz = struct.unpack('<Q', shdr[32:40])[0]
            elif sec_name == '.dynamic':
                dynamic_off = struct.unpack('<Q', shdr[24:32])[0]
                dynamic_sz = struct.unpack('<Q', shdr[32:40])[0]
        deps = []
        if dynamic_off and dynstr_off:
            f.seek(dynstr_off)
            dynstr = f.read(dynstr_sz)
            f.seek(dynamic_off)
            idx = 0
            while idx < dynamic_sz:
                d_tag = struct.unpack('<q', f.read(8))[0]
                d_val = struct.unpack('<Q', f.read(8))[0]
                if d_tag == 1:
                    end = dynstr.find(b'\x00', d_val)
                    deps.append(dynstr[d_val:end].decode())
                elif d_tag == 0:
                    break
                idx += 16
        print(f'{label}: {type_str}, deps=[{", ".join(deps) if deps else "NONE (static)"}]')

# Find all .so files
for filepath in glob.glob(os.path.join(base, '**', '*.so*'), recursive=True):
    name = os.path.basename(filepath)
    size = os.path.getsize(filepath)
    if size > 0:
        check_elf(filepath, name)
