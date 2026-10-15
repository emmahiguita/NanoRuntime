"""Protección local de secretos con DPAPI del usuario actual, sin claves propias."""

import ctypes
import os
from ctypes import wintypes


# DATA_BLOB mantiene el contrato Win32; no se emplea cifrado casero ni ámbito máquina.
class DataBlob(ctypes.Structure):
    _fields_ = [("size", wintypes.DWORD), ("data", ctypes.POINTER(ctypes.c_ubyte))]


def transform(data: bytes, *, decrypt: bool = False) -> bytes:
    """Cifra/descifra bajo la cuenta Windows y libera la memoria nativa incluso al fallar."""
    if os.name != "nt" or not data or len(data) > 65536:
        raise ValueError("DPAPI requiere Windows y un bloque de configuración válido")
    crypt = ctypes.WinDLL("crypt32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    operation = crypt.CryptUnprotectData if decrypt else crypt.CryptProtectData
    operation.argtypes = [ctypes.POINTER(DataBlob), ctypes.c_void_p,
                          ctypes.POINTER(DataBlob), ctypes.c_void_p,
                          ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(DataBlob)]
    operation.restype = wintypes.BOOL
    kernel.LocalFree.argtypes = [ctypes.c_void_p]
    kernel.LocalFree.restype = ctypes.c_void_p
    buffer = ctypes.create_string_buffer(data)
    source = DataBlob(len(data), ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ubyte)))
    output = DataBlob()
    try:
        # CRYPTPROTECT_UI_FORBIDDEN evita diálogos; NO habilita LOCAL_MACHINE.
        if not operation(ctypes.byref(source), None, None, None, None, 1,
                         ctypes.byref(output)):
            raise OSError("Windows no pudo proteger o abrir la configuración privada")
        return ctypes.string_at(output.data, output.size)
    finally:
        ctypes.memset(buffer, 0, len(buffer))
        if output.data:
            ctypes.memset(output.data, 0, output.size)
            kernel.LocalFree(output.data)
