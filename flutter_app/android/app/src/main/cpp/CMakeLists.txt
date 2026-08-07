cmake_minimum_required(VERSION 3.22.1)
project("nanoshell")
enable_language(ASM)

# ── libnanoshell.so — fork+dlopen BusyBox o generic PIE binaries + PTY ──
add_library(nanoshell SHARED
    nanoshell.c
    pty.c
    pty_jni.c
)
find_library(libdl dl)
target_link_libraries(nanoshell ${libdl})
set_target_properties(nanoshell PROPERTIES C_VISIBILITY_PRESET default)

# jni.h viene con el NDK; asegurar que el include path esté presente
include_directories(${ANDROID_NDK}/sysroot/usr/include)

# ── libnanoroot.so — LD_PRELOAD fakechroot (path redirection) ──
add_library(nanoroot SHARED
    nanoroot.c
)
target_link_libraries(nanoroot ${libdl})
set_target_properties(nanoroot PROPERTIES C_VISIBILITY_PRESET default)
