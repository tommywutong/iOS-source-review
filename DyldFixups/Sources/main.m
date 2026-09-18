#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <os/log.h>
#include <os/signpost.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/types.h>

#define BASELINE 0
#define REBASE_DENSE 1
#define REBASE_SPARSE 2
#define BIND_REPEATED 3
#define BIND_UNIQUE 4
#define INIT_HEAVY 5

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
#elif DYLD_EXPERIMENT_VARIANT == INIT_HEAVY
extern void dyldlab_init_heavy_marker(void);
#define VARIANT_NAME "init_heavy"
#define MARKER dyldlab_init_heavy_marker
#else
#define VARIANT_NAME "baseline"
#endif

static uint64_t now_ns(void) {
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0) mach_timebase_info(&timebase);
    return mach_absolute_time() * timebase.numer / timebase.denom;
}

static volatile uint64_t early_constructor_ns;
static volatile uint64_t late_constructor_ns;
static os_log_t lab_log;
static os_signpost_id_t launch_signpost;

__attribute__((used, noinline, visibility("default")))
void dyldlab_breakpoint_pre_main(void) {
    __asm__ volatile("" ::: "memory");
}

__attribute__((used, noinline, visibility("default")))
void dyldlab_breakpoint_main(void) {
    __asm__ volatile("" ::: "memory");
}

__attribute__((used, noinline, visibility("default")))
void dyldlab_breakpoint_marker(void) {
    __asm__ volatile("" ::: "memory");
}

__attribute__((used, noinline, visibility("default")))
void dyldlab_breakpoint_exit(void) {
    __asm__ volatile("" ::: "memory");
}

__attribute__((constructor(100))) static void setup_launch_signpost(void) {
    lab_log = os_log_create("com.tommywu.lab.dyldfixups", "launch");
    launch_signpost = os_signpost_id_generate(lab_log);
    os_signpost_interval_begin(lab_log, launch_signpost, "process_lifecycle");
}

__attribute__((constructor(101))) static void record_early_constructor(void) {
    early_constructor_ns = now_ns();
    dyldlab_breakpoint_pre_main();
}

__attribute__((constructor(65534))) static void record_late_constructor(void) {
    late_constructor_ns = now_ns();
}

static void read_vm_info(task_vm_info_data_t *vm, kern_return_t *kr) {
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    *kr = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)vm, &count);
}

int main(int argc, char **argv) {
    uint64_t main_entry_ns = now_ns();
    dyldlab_breakpoint_main();
    os_signpost_event_emit(lab_log, launch_signpost, "main_entry");
    (void)argc;
    (void)argv;

    struct rusage usage = {0};
    task_events_info_data_t events = {0};
    mach_msg_type_number_t event_count = TASK_EVENTS_INFO_COUNT;
    kern_return_t event_kr = task_info(mach_task_self(), TASK_EVENTS_INFO,
                                       (task_info_t)&events, &event_count);
    task_vm_info_data_t vm = {0};
    kern_return_t vm_kr = KERN_FAILURE;
    read_vm_info(&vm, &vm_kr);
    getrusage(RUSAGE_SELF, &usage);

    printf("DYLDLAB_RESULT variant=%s wall_ns=%llu user_us=%lld system_us=%lld maxrss=%ld faults=%llu pageins=%llu cow_faults=%llu task_info=%d images=%u resident_bytes=%llu footprint_bytes=%llu virtual_bytes=%llu internal_bytes=%llu compressed_bytes=%llu vm_info=%d\n",
           VARIANT_NAME,
           (unsigned long long)main_entry_ns,
           (long long)usage.ru_utime.tv_sec * 1000000LL + usage.ru_utime.tv_usec,
           (long long)usage.ru_stime.tv_sec * 1000000LL + usage.ru_stime.tv_usec,
           usage.ru_maxrss,
           (unsigned long long)(event_kr == KERN_SUCCESS ? events.faults : 0),
           (unsigned long long)(event_kr == KERN_SUCCESS ? events.pageins : 0),
           (unsigned long long)(event_kr == KERN_SUCCESS ? events.cow_faults : 0),
           event_kr,
           _dyld_image_count(),
           (unsigned long long)(vm_kr == KERN_SUCCESS ? vm.resident_size : 0),
           (unsigned long long)(vm_kr == KERN_SUCCESS ? vm.phys_footprint : 0),
           (unsigned long long)(vm_kr == KERN_SUCCESS ? vm.virtual_size : 0),
           (unsigned long long)(vm_kr == KERN_SUCCESS ? vm.internal : 0),
           (unsigned long long)(vm_kr == KERN_SUCCESS ? vm.compressed : 0),
           vm_kr);

    uint64_t marker_start_ns = main_entry_ns;
    uint64_t marker_end_ns = main_entry_ns;
#if DYLD_EXPERIMENT_VARIANT != BASELINE
    marker_start_ns = now_ns();
    dyldlab_breakpoint_marker();
    MARKER();
    marker_end_ns = now_ns();
#endif
    uint64_t exit_ns = now_ns();
    dyldlab_breakpoint_exit();
    os_signpost_event_emit(lab_log, launch_signpost, "before_exit");
    os_signpost_interval_end(lab_log, launch_signpost, "process_lifecycle");
    printf("DYLDLAB_TIMELINE variant=%s constructor_ns=%llu constructor_tail_ns=%llu main_entry_ns=%llu marker_start_ns=%llu marker_end_ns=%llu exit_ns=%llu\n",
           VARIANT_NAME,
           (unsigned long long)early_constructor_ns,
           (unsigned long long)late_constructor_ns,
           (unsigned long long)main_entry_ns,
           (unsigned long long)marker_start_ns,
           (unsigned long long)marker_end_ns,
           (unsigned long long)exit_ns);
    fflush(stdout);
    return 0;
}
