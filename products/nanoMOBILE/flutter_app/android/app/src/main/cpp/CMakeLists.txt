cmake_minimum_required(VERSION 3.22.1)
project("nanoshell")

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)

# JNI headers from NDK toolchain (NOT find_package(JNI) — that requires
# a desktop JDK which is irrelevant for Android cross-compilation).
# The Android toolchain sets CMAKE_ANDROID_NDK; we construct JNI paths from it.
set(JNI_ROOT "${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/${CMAKE_HOST_SYSTEM_NAME}-${CMAKE_HOST_SYSTEM_PROCESSOR}/sysroot/usr/include")
set(JNI_INCLUDE_DIRS "${JNI_ROOT}")

# â”€â”€ libnanoshell.so — fork+dlopen BusyBox or generic PIE binaries + PTY â”€â”€
add_library(nanoshell SHARED
    util.c
    nanoshell.c
    pty.c
    jni_cstr_array.c
    pty_session_registry.c
    pty_jni.c
    worker_jni.c
)
find_library(libdl dl)
find_library(liblog log)
target_link_libraries(nanoshell ${libdl} ${liblog})
target_include_directories(nanoshell PRIVATE ${JNI_INCLUDE_DIRS})
set_target_properties(nanoshell PROPERTIES C_VISIBILITY_PRESET default)

# Release optimization: -O2 for speed
target_compile_options(nanoshell PRIVATE
    -Wall -Wextra
    $<$<CONFIG:Release>:-O2>
    $<$<CONFIG:Release>:-DNDEBUG>
)

# â”€â”€ libnanoroot.so — LD_PRELOAD fakechroot (path redirection) â”€â”€
add_library(nanoroot SHARED
    nanoroot.c
)
target_link_libraries(nanoroot ${libdl})
target_include_directories(nanoroot PRIVATE ${JNI_INCLUDE_DIRS})
set_target_properties(nanoroot PROPERTIES C_VISIBILITY_PRESET default)

target_compile_options(nanoroot PRIVATE
    -Wall -Wextra
    $<$<CONFIG:Release>:-O2>
    $<$<CONFIG:Release>:-DNDEBUG>
)

