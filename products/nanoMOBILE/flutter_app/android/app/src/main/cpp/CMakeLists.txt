cmake_minimum_required(VERSION 3.22.1)
project("nanoshell")

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

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
    # Registro de ownership/recolector separado del puente JNI (<200 líneas).
    worker_daemon_registry.c
    worker_daemons_jni.c
    data_stats_jni.cpp
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

# Pin the upstream runtime and compile only its LLM/Omni path; NPU/OpenCL stay off.
include(FetchContent)
# Windows limita algunas rutas de Ninja a 260 caracteres. El caché solo
# contiene fuentes intermedias de compilación; nunca se empaqueta en la APK.
if(CMAKE_HOST_WIN32)
    set(FETCHCONTENT_BASE_DIR "C:/nanoai_mnn_fetch" CACHE PATH
        "Short cache path for MNN sources" FORCE)
endif()
set(MNN_BUILD_SHARED_LIBS ON CACHE BOOL "Build MNN as one shared library" FORCE)
# Separate shared libraries are required by MNN's Android CMake scripts:
# their header-copy hooks are invalid for OBJECT libraries on CMake 3.22.
set(MNN_SEP_BUILD ON CACHE BOOL "Build MNN LLM/Omni as shared libraries" FORCE)
set(MNN_BUILD_LLM ON CACHE BOOL "Enable MNN-LLM" FORCE)
set(MNN_BUILD_LLM_OMNI ON CACHE BOOL "Enable Omni image/audio operators" FORCE)
set(MNN_BUILD_DIFFUSION OFF CACHE BOOL "Exclude diffusion runtime" FORCE)
set(MNN_BUILD_DEMO OFF CACHE BOOL "Exclude upstream demos" FORCE)
set(MNN_BUILD_TOOLS OFF CACHE BOOL "Exclude converter/tools" FORCE)
set(MNN_BUILD_CONVERTER OFF CACHE BOOL "Exclude model converter" FORCE)
set(MNN_BUILD_TEST OFF CACHE BOOL "Exclude upstream tests" FORCE)
set(MNN_BUILD_BENCHMARK OFF CACHE BOOL "Exclude benchmark binaries" FORCE)
set(MNN_LLM_BUILD_DEMO OFF CACHE BOOL "Exclude MNN LLM demo executables" FORCE)
set(MNN_OPENCL OFF CACHE BOOL "Start with the verified CPU backend" FORCE)
set(MNN_USE_LOGCAT ON CACHE BOOL "Route MNN logs to Android logcat" FORCE)
set(MNN_SUPPORT_BF16 ON CACHE BOOL "Support bfloat16 model operators" FORCE)
set(MNN_USE_CPP11 OFF CACHE BOOL "Compile MNN with C++17" FORCE)

# Upstream's fused LLM operators require C++17; restore app C++20 after import.
set(_NANO_CXX_STANDARD ${CMAKE_CXX_STANDARD})
set(CMAKE_CXX_STANDARD 17)
FetchContent_Declare(mnn_source
    # Archivo oficial de la etiqueta 3.6.1; evita que
    # FetchContent deje un .git incompleto en rutas Windows con espacios.
    URL https://github.com/alibaba/MNN/archive/refs/tags/3.6.1.tar.gz
)
FetchContent_MakeAvailable(mnn_source)
set(CMAKE_CXX_STANDARD ${_NANO_CXX_STANDARD})

# Keep Android's 16 KB page alignment for the two new shared libraries.
if(TARGET MNN)
    target_link_options(MNN PRIVATE -Wl,-z,max-page-size=16384)
endif()
add_library(nanomnn SHARED mnn_jni.cpp)
target_compile_features(nanomnn PRIVATE cxx_std_17)
target_include_directories(nanomnn PRIVATE
    "${mnn_source_SOURCE_DIR}/include"
    "${mnn_source_SOURCE_DIR}/transformers/llm/engine/include"
    ${JNI_INCLUDE_DIRS}
)
target_link_libraries(nanomnn PRIVATE llm ${liblog} android)
target_link_options(nanomnn PRIVATE -Wl,-z,max-page-size=16384)

