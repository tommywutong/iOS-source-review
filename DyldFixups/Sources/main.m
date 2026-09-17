#include <mach/mach.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/types.h>

#define BASELINE 0
#define REBASE_DENSE 1
#define REBASE_SPARSE 2
#define BIND_REPEATED 3
#define BIND_UNIQUE 4

#if DYLD_EXPERIMENT_VARIANT == REBASE_DENSE
extern void dyldlab_rebase_dense_marker(void);
#define VARIANT_NAME "rebase_dense"
#define MARKER dyldlab_rebase_dense_marker
#elif DYLD_EXPERIMENT_VARIANT == REBASE_SPARSE
extern void dyldlab_rebase_sparse_marker(void);
#define VARIANT_NAME "rebase_sparse"
#define MARKER dyldlab_rebase_sparse_marker
#elif DYLD_EXPERIMENT_VARIANT == BIND_REPEATED
extern void dyldlab_bind_repeated_marker(void);
#define VARIANT_NAME "bind_repeated"
#define MARKER dyldlab_bind_repeated_marker
#elif DYLD_EXPERIMENT_VARIANT == BIND_UNIQUE
extern void dyldlab_bind_unique_marker(void);
#define VARIANT_NAME "bind_unique"
#define MARKER dyldlab_bind_unique_marker
#else
#define VARIANT_NAME "baseline"
#endif

static uint64_t now_ns(void) {
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0) mach_timebase_info(&timebase);
    return mach_absolute_time() * timebase.numer / timebase.denom;
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    struct rusage usage = {0};
    task_events_info_data_t events = {0};
    getrusage(RUSAGE_SELF, &usage);
    mach_msg_type_number_t count = TASK_EVENTS_INFO_COUNT;
    kern_return_t kr = task_info(mach_task_self(), TASK_EVENTS_INFO,
                                  (task_info_t)&events, &count);
    uint64_t wall_ns = now_ns();
    printf("DYLDLAB_RESULT variant=%s wall_ns=%llu user_us=%lld system_us=%lld faults=%llu pageins=%llu cow_faults=%llu task_info=%d\n",
           VARIANT_NAME,
           (unsigned long long)wall_ns,
           (long long)usage.ru_utime.tv_sec * 1000000LL + usage.ru_utime.tv_usec,
           (long long)usage.ru_stime.tv_sec * 1000000LL + usage.ru_stime.tv_usec,
           (unsigned long long)(kr == KERN_SUCCESS ? events.faults : 0),
           (unsigned long long)(kr == KERN_SUCCESS ? events.pageins : 0),
           (unsigned long long)(kr == KERN_SUCCESS ? events.cow_faults : 0),
           kr);
#if DYLD_EXPERIMENT_VARIANT != BASELINE
    MARKER();
#endif
    fflush(stdout);
    return 0;
}
