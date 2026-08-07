import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// FFI bindings for libnanoshell.so — in-process binary execution.
///
/// Two modes:
///   spawnBusyBox() — dlopen libbusybox.so → busybox_main (fast path)
///   spawnGeneric() — dlopen any PIE binary by absolute path → main()
///
/// Both fork() + dlopen() + pipe stdout/stderr. No execve() — bypasses SELinux.
final class Nanoshell {
  static Nanoshell? _instance;
  late final DynamicLibrary _lib;
  late final _SpawnBusyBox _spawnBB;
  late final _SpawnGeneric _spawnGen;
  late final _Free _free;
  late final _LastError _lastError;
  bool _loaded = false;

  Nanoshell._();

  static Nanoshell get instance {
    _instance ??= Nanoshell._();
    return _instance!;
  }

  void load() {
    if (_loaded) return;
    _lib = DynamicLibrary.open('libnanoshell.so');
    _spawnBB = _lib.lookupFunction<_SpawnBusyBoxC, _SpawnBusyBox>('nanoshell_spawn_busybox');
    _spawnGen = _lib.lookupFunction<_SpawnGenericC, _SpawnGeneric>('nanoshell_spawn_generic');
    _free = _lib.lookupFunction<_FreeC, _Free>('nanoshell_free_string');
    _lastError = _lib.lookupFunction<_LastErrorC, _LastError>('nanoshell_last_error');
    _loaded = true;
  }

  bool get isLoaded => _loaded;

  /// Run a BusyBox applet. Example: spawnBusyBox(['ls', '-la']).
  ({String stdout, String stderr, int exitCode}) spawnBusyBox(
    List<String> args, {
    Map<String, String>? env,
  }) {
    if (!_loaded) load();
    final argv = _marshalStrArray(args);
    final (envp, envPtrs) = _marshalEnv(env);
    final (outS, outE) = _allocOutPtrs();

    final exitCode = _spawnBB(argv, envp, outS, outE);
    return _collectAndFree(exitCode, outS, outE, argv, args.length, envp, envPtrs);
  }

  /// Run any PIE binary (ET_DYN) by absolute path.
  ///
  /// [binaryPath] must be absolute (e.g. /data/.../files/nano/usr/bin/python).
  /// [ldPreload] sets LD_PRELOAD in child for fakechroot (e.g. "libnanoroot.so").
  /// Example: spawnGeneric('/data/.../usr/bin/curl', ['curl', '-V']).
  ({String stdout, String stderr, int exitCode}) spawnGeneric(
    String binaryPath,
    List<String> args, {
    Map<String, String>? env,
    String? ldPreload,
  }) {
    if (!_loaded) load();
    final pathPtr = binaryPath.toNativeUtf8(allocator: malloc);
    final argv = _marshalStrArray(args);
    final (envp, envPtrs) = _marshalEnv(env);
    final ldPtr = ldPreload?.toNativeUtf8(allocator: malloc) ?? Pointer<Utf8>.fromAddress(0);
    final (outS, outE) = _allocOutPtrs();

    final exitCode = _spawnGen(pathPtr, argv, envp, ldPtr, outS, outE);

    // Free the path and ld_preload strings
    malloc.free(pathPtr);
    if (ldPtr != Pointer<Utf8>.fromAddress(0)) malloc.free(ldPtr);

    return _collectAndFree(exitCode, outS, outE, argv, args.length, envp, envPtrs);
  }

  String get lastError => _lastError().toDartString();

  // ── Internal marshalling ──

  Pointer<Pointer<Utf8>> _marshalStrArray(List<String> strings) {
    final arr = malloc.allocate<Pointer<Utf8>>(strings.length + 1);
    for (var i = 0; i < strings.length; i++) {
      arr[i] = strings[i].toNativeUtf8(allocator: malloc);
    }
    arr[strings.length] = Pointer<Utf8>.fromAddress(0);
    return arr;
  }

  (Pointer<Pointer<Utf8>>, List<Pointer<Utf8>>) _marshalEnv(Map<String, String>? env) {
    final ptrs = <Pointer<Utf8>>[];
    if (env == null || env.isEmpty) {
      return (Pointer<Pointer<Utf8>>.fromAddress(0), ptrs);
    }
    final arr = malloc.allocate<Pointer<Utf8>>(env.length + 1);
    var j = 0;
    for (final e in env.entries) {
      final s = '${e.key}=${e.value}'.toNativeUtf8(allocator: malloc);
      ptrs.add(s);
      arr[j++] = s;
    }
    arr[env.length] = Pointer<Utf8>.fromAddress(0);
    return (arr, ptrs);
  }

  (Pointer<Pointer<Utf8>>, Pointer<Pointer<Utf8>>) _allocOutPtrs() {
    final outS = malloc.allocate<Pointer<Utf8>>(1);
    final outE = malloc.allocate<Pointer<Utf8>>(1);
    outS.value = Pointer<Utf8>.fromAddress(0);
    outE.value = Pointer<Utf8>.fromAddress(0);
    return (outS, outE);
  }

  ({String stdout, String stderr, int exitCode}) _collectAndFree(
    int exitCode,
    Pointer<Pointer<Utf8>> outS,
    Pointer<Pointer<Utf8>> outE,
    Pointer<Pointer<Utf8>> argv,
    int argc,
    Pointer<Pointer<Utf8>> envp,
    List<Pointer<Utf8>> envPtrs,
  ) {
    final stdoutStr = outS.value == Pointer<Utf8>.fromAddress(0) ? '' : outS.value.toDartString();
    final stderrStr = outE.value == Pointer<Utf8>.fromAddress(0) ? '' : outE.value.toDartString();

    if (outS.value != Pointer<Utf8>.fromAddress(0)) _free(outS.value);
    if (outE.value != Pointer<Utf8>.fromAddress(0)) _free(outE.value);
    malloc.free(outS);
    malloc.free(outE);

    for (var i = 0; i < argc; i++) malloc.free(argv[i]);
    malloc.free(argv);

    for (final p in envPtrs) malloc.free(p);
    if (envp != Pointer<Pointer<Utf8>>.fromAddress(0)) malloc.free(envp);

    return (stdout: stdoutStr, stderr: stderrStr, exitCode: exitCode);
  }
}

// ── FFI type aliases ──

// nanoshell_spawn_busybox: (argv, envp, out_stdout, out_stderr) → int
typedef _SpawnBusyBoxC = Int32 Function(
  Pointer<Pointer<Utf8>> argv, Pointer<Pointer<Utf8>> envp,
  Pointer<Pointer<Utf8>> outS, Pointer<Pointer<Utf8>> outE);
typedef _SpawnBusyBox = int Function(
  Pointer<Pointer<Utf8>> argv, Pointer<Pointer<Utf8>> envp,
  Pointer<Pointer<Utf8>> outS, Pointer<Pointer<Utf8>> outE);

// nanoshell_spawn_generic: (path, argv, envp, ld_preload, out_stdout, out_stderr) → int
typedef _SpawnGenericC = Int32 Function(
  Pointer<Utf8> path, Pointer<Pointer<Utf8>> argv, Pointer<Pointer<Utf8>> envp,
  Pointer<Utf8> ldPreload, Pointer<Pointer<Utf8>> outS, Pointer<Pointer<Utf8>> outE);
typedef _SpawnGeneric = int Function(
  Pointer<Utf8> path, Pointer<Pointer<Utf8>> argv, Pointer<Pointer<Utf8>> envp,
  Pointer<Utf8> ldPreload, Pointer<Pointer<Utf8>> outS, Pointer<Pointer<Utf8>> outE);

// nanoshell_free_string, nanoshell_last_error
typedef _FreeC = Void Function(Pointer<Utf8> str);
typedef _Free = void Function(Pointer<Utf8> str);
typedef _LastErrorC = Pointer<Utf8> Function();
typedef _LastError = Pointer<Utf8> Function();

final malloc = calloc;
