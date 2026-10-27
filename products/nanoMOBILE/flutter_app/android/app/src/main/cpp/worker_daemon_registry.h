/* QUÉ: ownership de hijos detached; el PID se conserva hasta waitpid.
 * CÓMO: spawn/kill/recolección comparten un registro privado con exclusión mutua.
 * POR QUÉ: reemplazar un modelo no debe borrar al hijo que todavía debe recogerse.
 */
#ifndef WORKER_DAEMON_REGISTRY_H
#define WORKER_DAEMON_REGISTRY_H

int worker_daemon_spawn(const char* binary, const char* const argv[],
                        const char* const envp[]);
int worker_daemon_is_alive(int pid);
int worker_daemon_kill(int pid);

#endif
