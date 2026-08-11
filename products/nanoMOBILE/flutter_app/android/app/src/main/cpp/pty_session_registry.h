#ifndef NANOAI_PTY_SESSION_REGISTRY_H
#define NANOAI_PTY_SESSION_REGISTRY_H

#include <jni.h>
#include <sys/types.h>

#include "pty.h"

typedef struct PtySessionRecord {
    jlong id;
    PtySession pty;
    int in_use;
} PtySessionRecord;

PtySessionRecord* pty_registry_alloc(void);
void pty_registry_free(PtySessionRecord* rec);
int pty_registry_dup_fd(jlong id);
pid_t pty_registry_pid(jlong id);
int pty_registry_close(jlong id);

#endif
