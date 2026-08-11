/*
 * util.h — Shared utility functions for nanoshell.c and pty.c.
 *
 * Extracted during audit 2026-08-08 to eliminate code duplication.
 * Both nanoshell.c and pty.c had identical _apply_env and _count_argv.
 */
#ifndef NANOAI_UTIL_H
#define NANOAI_UTIL_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Count non-NULL entries in a NULL-terminated string array.
 * Returns 0 if argv is NULL.
 */
int count_argv(const char* const argv[]);

/*
 * Apply KEY=VALUE pairs from envp to the process environment.
 * envp must be NULL-terminated. NULL envp is a no-op.
 * Temporarily duplicates each string for strchr safety; freed internally.
 */
void apply_env(const char* const envp[]);

/*
 * Apply RLIMIT_AS (virtual memory cap, default 512 MB) in child processes.
 * Must be called in the forked child BEFORE dlopen/execve so runaway
 * binaries (tar -x on huge files, leaky daemons) can't exhaust device RAM.
 * Override cap with NANOAI_RLIMIT_AS_MB (megabytes).
 */
void apply_rlimit_as(void);

#ifdef __cplusplus
}
#endif

#endif /* NANOAI_UTIL_H */
