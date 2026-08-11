/*
 * libandroid-shmem shim: implementa shmget/shmat/shmdt/shmctl.
 *
 * MOTIVO: el .deb de Termux instala libandroid-shmem.so SIN SONAME en su
 * .dynamic. El worker dlopen'd de nanoai resuelve DT_NEEDED por nombre en
 * el namespace clns-7; sin SONAME el linker no indexa la lib y libcairo,
 * libEGL_mesa, libGLX_mesa, libImlib2 y libgallium fallan con
 * "libandroid-shmem.so not found". Este shim se compila CON SONAME
 * (libandroid-shmem.so) para que el lookup por nombre funcione.
 *
 * IMPORTANTE: no puede depender de libandroid.so (ASharedMemory_*): ese
 * modulo NO esta en el namespace clns-7 de la app. Se usa memfd_create
 * via syscall + mmap (solo libc). La semantica es local al proceso
 * (suficiente para el dlopen del worker; cairo/XShm cae al path sin shm
 * entre procesos distintos).
 *
 * Compilar (NDK):
 *   <ndk>/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android26-clang.cmd
 *     -shared -fPIC -O2 -o libandroid-shmem.so libandroid-shmem.c
 *     -Wl,-soname,libandroid-shmem.so
 */
#include <fcntl.h>
#include <pthread.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/ipc.h>
#include <sys/mman.h>
#include <sys/shm.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef __NR_memfd_create
#define __NR_memfd_create 219 /* aarch64 */
#endif
#ifndef MFD_CLOEXEC
#define MFD_CLOEXEC 0x0001U
#endif
#define ASHMEM_SET_SIZE _IOW(0x77, 3, size_t)

#define MAX_SHM 256

typedef struct {
    int used;      /* slot ocupado */
    int shmid;     /* id devuelto a la app */
    key_t key;
    size_t size;
    int fd;        /* memfd/ashmem */
    void *addr;    /* mapeo creado por shmat */
    size_t map_len;
    int refs;      /* shm_nattch */
} shm_slot;

static shm_slot g_slots[MAX_SHM];
static int g_next_id = 1;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;

static shm_slot *slot_by_shmid(int shmid) {
    for (int i = 0; i < MAX_SHM; i++) {
        if (g_slots[i].used && g_slots[i].shmid == shmid) return &g_slots[i];
    }
    return NULL;
}

static int shm_fd_create(size_t size) {
    int fd = (int)syscall(__NR_memfd_create, "nanoai_shm", 0);
    if (fd < 0) {
        /* kernels sin memfd: fallback a /dev/ashmem (sigue en Android) */
        fd = open("/dev/ashmem", O_RDWR | O_CLOEXEC);
        if (fd < 0) return -1;
        if (ioctl(fd, ASHMEM_SET_SIZE, size) < 0) {
            close(fd);
            return -1;
        }
        return fd;
    }
    if (ftruncate(fd, (off_t)size) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

int shmget(key_t key, size_t size, int shmflg) {
    (void)shmflg;
    if (size == 0) return -1;
    pthread_mutex_lock(&g_lock);
    /* Reutilizar region existente con misma key y tamano compatible
     * (IPC_PRIVATE = key 0 => siempre nueva). */
    if (key != IPC_PRIVATE) {
        for (int i = 0; i < MAX_SHM; i++) {
            if (g_slots[i].used && g_slots[i].key == key) {
                if (g_slots[i].size >= size) {
                    int id = g_slots[i].shmid;
                    pthread_mutex_unlock(&g_lock);
                    return id;
                }
                pthread_mutex_unlock(&g_lock);
                return -1;
            }
        }
    }
    for (int i = 0; i < MAX_SHM; i++) {
        if (!g_slots[i].used) {
            int fd = shm_fd_create(size);
            if (fd < 0) {
                pthread_mutex_unlock(&g_lock);
                return -1;
            }
            g_slots[i].used = 1;
            g_slots[i].shmid = g_next_id++;
            g_slots[i].key = key;
            g_slots[i].size = size;
            g_slots[i].fd = fd;
            g_slots[i].addr = NULL;
            g_slots[i].map_len = 0;
            g_slots[i].refs = 0;
            int id = g_slots[i].shmid;
            pthread_mutex_unlock(&g_lock);
            return id;
        }
    }
    pthread_mutex_unlock(&g_lock);
    return -1;
}

void *shmat(int shmid, const void *shmaddr, int shmflg) {
    (void)shmaddr; /* solo mapeo a direccion elegida por el kernel */
    pthread_mutex_lock(&g_lock);
    shm_slot *s = slot_by_shmid(shmid);
    if (!s || s->addr != NULL) {
        pthread_mutex_unlock(&g_lock);
        return (void *)-1;
    }
    int prot = PROT_READ | PROT_WRITE;
    if (shmflg & SHM_RDONLY) prot = PROT_READ;
    void *addr = mmap(NULL, s->size, prot, MAP_SHARED, s->fd, 0);
    if (addr == MAP_FAILED) {
        pthread_mutex_unlock(&g_lock);
        return (void *)-1;
    }
    s->addr = addr;
    s->map_len = s->size;
    s->refs++;
    pthread_mutex_unlock(&g_lock);
    return addr;
}

int shmdt(const void *shmaddr) {
    pthread_mutex_lock(&g_lock);
    for (int i = 0; i < MAX_SHM; i++) {
        shm_slot *s = &g_slots[i];
        if (s->used && s->addr == shmaddr) {
            if (munmap((void *)shmaddr, s->map_len) < 0) {
                pthread_mutex_unlock(&g_lock);
                return -1;
            }
            s->addr = NULL;
            s->map_len = 0;
            if (s->refs > 0) s->refs--;
            pthread_mutex_unlock(&g_lock);
            return 0;
        }
    }
    pthread_mutex_unlock(&g_lock);
    return -1;
}

int shmctl(int shmid, int cmd, struct shmid_ds *buf) {
    pthread_mutex_lock(&g_lock);
    shm_slot *s = slot_by_shmid(shmid);
    if (!s) {
        pthread_mutex_unlock(&g_lock);
        return -1;
    }
    switch (cmd) {
        case IPC_RMID:
            if (s->addr) munmap(s->addr, s->map_len);
            close(s->fd);
            memset(s, 0, sizeof(*s));
            s->used = 0;
            break;
        case IPC_STAT:
            if (buf) {
                memset(buf, 0, sizeof(*buf));
                buf->shm_segsz = s->size;
                buf->shm_nattch = s->refs;
                buf->shm_lpid = getpid();
            }
            break;
        default:
            /* IPC_SET y otros: noop */
            break;
    }
    pthread_mutex_unlock(&g_lock);
    return 0;
}

/*
 * Los binarios de Termux (Xvnc, etc.) estan LINKED contra los simbolos con
 * prefijo libandroid_* que exporta la lib original. Sin estos alias, el
 * dlopen de Xvnc falla con "cannot locate symbol libandroid_shmdt".
 */
int libandroid_shmget(key_t key, size_t size, int shmflg) {
    return shmget(key, size, shmflg);
}
void *libandroid_shmat(int shmid, const void *shmaddr, int shmflg) {
    return shmat(shmid, shmaddr, shmflg);
}
int libandroid_shmdt(const void *shmaddr) {
    return shmdt(shmaddr);
}
int libandroid_shmctl(int shmid, int cmd, struct shmid_ds *buf) {
    return shmctl(shmid, cmd, buf);
}
