"""El runtime hijo termina si el servidor web desaparece: Job Object de Windows."""

import ctypes
import os
from ctypes import wintypes


# Estructuras Win32 conservan tamaños/alineación; no inspeccionan memoria del modelo.
class BasicLimits(ctypes.Structure):
    _fields_ = [("process_time", ctypes.c_int64), ("job_time", ctypes.c_int64),
                ("flags", wintypes.DWORD), ("min_ws", ctypes.c_size_t),
                ("max_ws", ctypes.c_size_t), ("active", wintypes.DWORD),
                ("affinity", ctypes.c_size_t), ("priority", wintypes.DWORD),
                ("scheduling", wintypes.DWORD)]


class ExtendedLimits(ctypes.Structure):
    _fields_ = [("basic", BasicLimits), ("io", ctypes.c_uint64 * 6),
                ("process_memory", ctypes.c_size_t), ("job_memory", ctypes.c_size_t),
                ("peak_process", ctypes.c_size_t), ("peak_job", ctypes.c_size_t)]


class RuntimeJob:
    """Solo posee hijos asignados explícitamente; nunca adopta ni mata un motor ajeno."""

    def __init__(self):
        if os.name != "nt":
            raise OSError("Este lanzador local requiere Windows")
        self.kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        signatures = {
            "CreateJobObjectW": ([ctypes.c_void_p, wintypes.LPCWSTR], wintypes.HANDLE),
            "SetInformationJobObject": ([wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD], wintypes.BOOL),
            "AssignProcessToJobObject": ([wintypes.HANDLE, wintypes.HANDLE], wintypes.BOOL),
            "OpenProcess": ([wintypes.DWORD, wintypes.BOOL, wintypes.DWORD], wintypes.HANDLE),
            "CloseHandle": ([wintypes.HANDLE], wintypes.BOOL),
        }
        for name, (arguments, result) in signatures.items():
            function = getattr(self.kernel, name)
            function.argtypes, function.restype = arguments, result
        self.handle = self.kernel.CreateJobObjectW(None, None)
        limits = ExtendedLimits()
        limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE.
        if not self.handle or not self.kernel.SetInformationJobObject(self.handle, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            self.close()
            raise OSError("No se pudo asegurar el ciclo de vida del runtime")

    def attach(self, pid: int):
        """Permisos mínimos para asignar el hijo; el handle temporal se libera siempre."""
        process = self.kernel.OpenProcess(0x100 | 0x1, False, pid)
        try:
            if not process or not self.kernel.AssignProcessToJobObject(self.handle, process):
                raise OSError("No se pudo proteger el proceso hijo de Nano")
        finally:
            if process:
                self.kernel.CloseHandle(process)

    def close(self):
        """Cerrar el Job finaliza únicamente sus procesos, también ante cierre del padre."""
        if getattr(self, "handle", None):
            self.kernel.CloseHandle(self.handle)
            self.handle = None
