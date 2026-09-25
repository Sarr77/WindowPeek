#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <poll.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <wayland-client.h>
#include "virtual-pointer-client.h"

/* Test-only frame boundary after a compositor cursor warp. Some dispatchers
 * emit motion without wl_pointer.frame; Qt queues that motion until a frame. */
static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data, struct wl_registry *registry, uint32_t name,
                   const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(interface, "zwlr_virtual_pointer_manager_v1"))
        manager = wl_registry_bind(registry, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}
static const struct wl_registry_listener listener = {global, removed};

int main(int argc, char **argv) {
    int listen = argc == 2 && !strcmp(argv[1], "--listen");
    if (argc > 1 && !listen) return 2;
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 2;
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &listener, NULL);
    if (wl_display_roundtrip(display) < 0 || !manager) return 3;
    struct zwlr_virtual_pointer_v1 *pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
    wl_display_roundtrip(display);
    if (listen) { puts("ready"); fflush(stdout); }
    int result = 0;
    time_t deadline = time(NULL) + 30;
    do {
    int clicks = 0, scroll = 0, absolute = 0;
    unsigned x = 0, y = 0, width = 0, height = 0;
    uint32_t button = 0x110;
    if (listen) {
        struct pollfd input = {.fd=STDIN_FILENO,.events=POLLIN};
        int remaining = (int)(deadline-time(NULL))*1000;
        char command[128];
        if (remaining<=0 || poll(&input,1,remaining)<=0 || !fgets(command,sizeof(command),stdin)) break;
        if (sscanf(command,"move %u %u %u %u", &x, &y, &width, &height)==4 && width && height && x<width && y<height) absolute=1;
        else if (!strcmp(command,"double\n")) clicks=2;
        else if (!strcmp(command,"click\n")) clicks=1;
        else if (!strcmp(command,"right\n")) { clicks=1; button=0x111; }
        else if (!strcmp(command,"scroll\n")) scroll=1;
        else if (!strcmp(command,"finger\n")) scroll=2;
        else if (strcmp(command,"frame\n")) break;
    }
    struct timespec time;
    clock_gettime(CLOCK_MONOTONIC, &time);
    if (!scroll) {
        if (absolute)
            zwlr_virtual_pointer_v1_motion_absolute(pointer, (uint32_t)(time.tv_sec * 1000 + time.tv_nsec / 1000000), x, y, width, height);
        else
            zwlr_virtual_pointer_v1_motion(pointer, (uint32_t)(time.tv_sec * 1000 + time.tv_nsec / 1000000), 0, 0);
        zwlr_virtual_pointer_v1_frame(pointer);
        result = wl_display_roundtrip(display);
    }
    if (scroll && result >= 0) {
        zwlr_virtual_pointer_v1_axis_source(pointer, scroll == 2 ? WL_POINTER_AXIS_SOURCE_FINGER : WL_POINTER_AXIS_SOURCE_WHEEL);
        if (scroll == 2)
            zwlr_virtual_pointer_v1_axis(pointer, (uint32_t)(time.tv_sec*1000+time.tv_nsec/1000000),
                WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_double(0.3));
        else
        zwlr_virtual_pointer_v1_axis_discrete(pointer, (uint32_t)(time.tv_sec*1000+time.tv_nsec/1000000),
            WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_int(15), 1);
        zwlr_virtual_pointer_v1_frame(pointer);
        result = wl_display_roundtrip(display);
        if (scroll == 2 && result >= 0) {
            zwlr_virtual_pointer_v1_axis_stop(pointer, (uint32_t)(time.tv_sec*1000+time.tv_nsec/1000000+1), WL_POINTER_AXIS_VERTICAL_SCROLL);
            zwlr_virtual_pointer_v1_frame(pointer);
            result = wl_display_roundtrip(display);
        }
    }
    for (int n=0;n<clicks && result>=0;n++) {
        for (int pressed=1;pressed>=0;pressed--) {
            clock_gettime(CLOCK_MONOTONIC, &time);
            zwlr_virtual_pointer_v1_button(pointer,(uint32_t)(time.tv_sec*1000+time.tv_nsec/1000000),button,
                pressed ? WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED);
            zwlr_virtual_pointer_v1_frame(pointer);
            result=wl_display_roundtrip(display);
            struct timespec pause={.tv_sec=0,.tv_nsec=15000000};nanosleep(&pause,NULL);
        }
    }
    if (listen) { puts(scroll ? "scrolled" : clicks ? "clicked" : "framed"); fflush(stdout); }
    } while (listen && result>=0);
    zwlr_virtual_pointer_v1_destroy(pointer);
    zwlr_virtual_pointer_manager_v1_destroy(manager);
    wl_registry_destroy(registry);
    wl_display_roundtrip(display);
    wl_display_disconnect(display);
    return result < 0 ? 4 : 0;
}
