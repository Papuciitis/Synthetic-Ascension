// LD_PRELOAD shim for offline Movie Maker trailer captures. No game code changes.
//
// 1. Clock: Godot's OS::get_ticks_usec() reads CLOCK_MONOTONIC_RAW on Linux,
//    and the game times enemy strides, hit flashes, HUD pulses and SFX
//    throttles with it. Offline frames take far longer than 1/60 s of wall
//    time (and the thermal guard pauses the engine), so those clocks would race
//    ahead of the recorded simulation. Real time passes through until the first
//    tick; afterwards every OS.get_environment("SA_MOVIE_CLOCK_TICK") advances
//    the clock to start + frames/fps, and inside a frame it creeps forward by
//    process CPU time * SA_MOVIE_CLOCK_K (default 0.05) so budgeted loops still
//    end. It never runs backwards.
// 2. Pointer: OS.get_environment("SA_MOVIE_POINTER:x,y") makes XQueryPointer
//    (DisplayServerX11::mouse_get_position) report root position x,y, so mouse
//    aim and hover follow the director instead of the desktop pointer;
//    "SA_MOVIE_POINTER:off" restores the real pointer.
// "SA_MOVIE_STATE" returns "engaged,frames,virtual_ns,rtld_next_calls".
//
// gcc -O2 -shared -fPIC -o movieclock.so movieclock.c -ldl -lpthread
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef int (*clock_gettime_t)(clockid_t, struct timespec *);
typedef char *(*getenv_t)(const char *);
typedef void *(*dlsym_t)(void *, const char *);
typedef int (*xquerypointer_t)(void *, unsigned long, unsigned long *, unsigned long *,
                               int *, int *, int *, int *, unsigned int *);

static clock_gettime_t real_clock_gettime;
static getenv_t real_getenv;
static dlsym_t real_dlsym;
static xquerypointer_t real_xquerypointer;

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static int engaged;
static int64_t start_ns, base_ns, last_ns, cpu_at_tick, frames, frame_ns = 16666667;
static double creep = 0.05;
static volatile int pointer_on, pointer_x, pointer_y;
static volatile long rtld_next_calls;
static char state[128];

static void init(void) {
    if (real_dlsym) return;
    real_dlsym = (dlsym_t)dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.34");
    if (!real_dlsym) real_dlsym = (dlsym_t)dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.2.5");
    real_clock_gettime = (clock_gettime_t)real_dlsym(RTLD_NEXT, "clock_gettime");
    real_getenv = (getenv_t)real_dlsym(RTLD_NEXT, "getenv");
    const char *fps = real_getenv("SA_MOVIE_CLOCK_FPS");
    if (fps && atof(fps) > 0) frame_ns = (int64_t)(1e9 / atof(fps));
    const char *k = real_getenv("SA_MOVIE_CLOCK_K");
    if (k && atof(k) >= 0) creep = atof(k);
}

static int64_t ns_of(const struct timespec *t) { return (int64_t)t->tv_sec * 1000000000LL + t->tv_nsec; }

static int64_t cpu_now(void) {
    struct timespec t;
    real_clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t);
    return ns_of(&t);
}

static void tick(void) {
    int64_t cpu = cpu_now();
    pthread_mutex_lock(&lock);
    if (!engaged) {
        struct timespec t;
        real_clock_gettime(CLOCK_MONOTONIC_RAW, &t);
        start_ns = base_ns = last_ns = ns_of(&t);
        frames = 0;
        engaged = 1;
    } else {
        frames++;
        int64_t next = start_ns + frames * frame_ns;
        base_ns = next > last_ns ? next : last_ns + 1;
    }
    cpu_at_tick = cpu;
    pthread_mutex_unlock(&lock);
}

int clock_gettime(clockid_t id, struct timespec *ts) {
    init();
    if (id != CLOCK_MONOTONIC_RAW || !engaged) return real_clock_gettime(id, ts);
    int64_t cpu = cpu_now();
    pthread_mutex_lock(&lock);
    int64_t v = base_ns + (int64_t)((double)(cpu - cpu_at_tick) * creep);
    if (v <= last_ns) v = last_ns + 1;
    last_ns = v;
    pthread_mutex_unlock(&lock);
    ts->tv_sec = v / 1000000000LL;
    ts->tv_nsec = v % 1000000000LL;
    return 0;
}

char *getenv(const char *name) {
    init();
    if (name && strncmp(name, "SA_MOVIE_", 9) == 0) {
        if (strcmp(name, "SA_MOVIE_CLOCK_TICK") == 0) { tick(); return NULL; }
        if (strncmp(name, "SA_MOVIE_POINTER:", 17) == 0) {
            int x, y;
            if (sscanf(name + 17, "%d,%d", &x, &y) == 2) { pointer_x = x; pointer_y = y; pointer_on = 1; }
            else pointer_on = 0;
            return NULL;
        }
        if (strcmp(name, "SA_MOVIE_STATE") == 0) {
            pthread_mutex_lock(&lock);
            snprintf(state, sizeof state, "%d,%lld,%lld,%ld", engaged, (long long)frames,
                     (long long)(last_ns - start_ns), (long)rtld_next_calls);
            pthread_mutex_unlock(&lock);
            return state;
        }
    }
    return real_getenv(name);
}

static int fake_xquerypointer(void *display, unsigned long w, unsigned long *root, unsigned long *child,
                              int *root_x, int *root_y, int *win_x, int *win_y, unsigned int *mask) {
    int ok = real_xquerypointer(display, w, root, child, root_x, root_y, win_x, win_y, mask);
    if (pointer_on) {
        // The capture window is fullscreen at the root origin, so root and
        // window coordinates coincide.
        *root_x = *win_x = pointer_x;
        *root_y = *win_y = pointer_y;
        *mask = 0;
        ok = 1;
    }
    return ok;
}

void *dlsym(void *handle, const char *symbol) {
    init();
    if (handle == RTLD_NEXT) rtld_next_calls++;
    void *found = real_dlsym(handle, symbol);
    if (found && symbol && strcmp(symbol, "XQueryPointer") == 0) {
        real_xquerypointer = (xquerypointer_t)found;
        return (void *)fake_xquerypointer;
    }
    return found;
}
