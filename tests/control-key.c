#define _POSIX_C_SOURCE 200809L
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include "virtual-keyboard-client.h"

/* Test-only keyboard: standard evdev codes also reach Hyprland's key state.
 * Release on stdin, timeout or termination, including failed test assertions. */
static struct wl_seat *seat;
static struct zwp_virtual_keyboard_manager_v1 *manager;
static void stop(int signal_number) { (void)signal_number; }
static uint32_t now(void) {
    struct timespec time;
    clock_gettime(CLOCK_MONOTONIC, &time);
    return (uint32_t)(time.tv_sec * 1000 + time.tv_nsec / 1000000);
}
static void global(void *data, struct wl_registry *registry, uint32_t name,
                   const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(interface, "wl_seat"))
        seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
    else if (!strcmp(interface, "zwp_virtual_keyboard_manager_v1"))
        manager = wl_registry_bind(registry, name, &zwp_virtual_keyboard_manager_v1_interface, 1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}
static const struct wl_registry_listener listener = {global, removed};

static uint32_t key_code(const char *name) {
    if (!strcmp(name, "Control_L")) return 29;
    if (!strcmp(name, "Control_R")) return 97;
    if (!strcmp(name, "Shift_L")) return 42;
    if (!strcmp(name, "Shift_R")) return 54;
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 2 && argc != 3) return 2;
    uint32_t key = key_code(argv[1]);
    if (!key) return 2;
    if (argc == 3 && strcmp(argv[2], "Shift_L") && strcmp(argv[2], "Shift_R")) return 2;
    uint32_t shift = argc == 3 ? key_code(argv[2]) : 0;
    if (key == shift) return 2;
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 3;
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &listener, NULL);
    if (wl_display_roundtrip(display) < 0 || !seat || !manager) return 4;

    struct xkb_context *context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    struct xkb_rule_names names = {.layout = "us"};
    struct xkb_keymap *keymap = xkb_keymap_new_from_names(context, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!keymap) return 5;
    char *text = xkb_keymap_get_as_string(keymap, XKB_KEYMAP_FORMAT_TEXT_V1);
    FILE *file = tmpfile();
    if (!text || !file) return 6;
    size_t size = strlen(text) + 1;
    if (fwrite(text, 1, size, file) != size || fflush(file)) return 7;
    struct zwp_virtual_keyboard_v1 *keyboard = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(manager, seat);
    zwp_virtual_keyboard_v1_keymap(keyboard, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, fileno(file), size);
    if (wl_display_roundtrip(display) < 0) return 8;
    fclose(file); free(text);

    struct sigaction action = {.sa_handler = stop};
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL); sigaction(SIGINT, &action, NULL);
    uint32_t mask = 1u << xkb_keymap_mod_get_index(keymap,
        key == 42 || key == 54 ? XKB_MOD_NAME_SHIFT : XKB_MOD_NAME_CTRL);
    zwp_virtual_keyboard_v1_key(keyboard, now(), key, WL_KEYBOARD_KEY_STATE_PRESSED);
    if (shift) {
        mask |= 1u << xkb_keymap_mod_get_index(keymap, XKB_MOD_NAME_SHIFT);
        zwp_virtual_keyboard_v1_key(keyboard, now(), shift, WL_KEYBOARD_KEY_STATE_PRESSED);
    }
    zwp_virtual_keyboard_v1_modifiers(keyboard, mask, 0, 0, 0);
    int result = wl_display_roundtrip(display);
    if (result >= 0) {
        puts("pressed"); fflush(stdout);
        struct pollfd input = {.fd = STDIN_FILENO, .events = POLLIN};
        uint32_t started = now();
        char command[32];
        for (;;) {
            int remaining = 10000 - (int)(now() - started);
            if (remaining <= 0 || poll(&input, 1, remaining) <= 0) break;
            if (!fgets(command, sizeof(command), stdin)) break;
            // Tests may tap a digit on this same keyboard while Ctrl stays
            // held. A blank line retains the original release-and-exit API.
            if (strlen(command) != 6 || strncmp(command, "tap ", 4)
                    || command[4] < '0' || command[4] > '9' || command[5] != '\n') break;
            uint32_t digit = command[4] == '0' ? 11 : 2 + (uint32_t)(command[4] - '1');
            zwp_virtual_keyboard_v1_key(keyboard, now(), digit, WL_KEYBOARD_KEY_STATE_PRESSED);
            zwp_virtual_keyboard_v1_key(keyboard, now(), digit, WL_KEYBOARD_KEY_STATE_RELEASED);
            if (wl_display_roundtrip(display) < 0) { result = -1; break; }
            puts("tapped"); fflush(stdout);
        }
    }
    if (shift) zwp_virtual_keyboard_v1_key(keyboard, now(), shift, WL_KEYBOARD_KEY_STATE_RELEASED);
    zwp_virtual_keyboard_v1_key(keyboard, now(), key, WL_KEYBOARD_KEY_STATE_RELEASED);
    zwp_virtual_keyboard_v1_modifiers(keyboard, 0, 0, 0, 0);
    if (wl_display_roundtrip(display) < 0) result = -1;
    zwp_virtual_keyboard_v1_destroy(keyboard);
    wl_display_roundtrip(display);
    xkb_keymap_unref(keymap); xkb_context_unref(context);
    zwp_virtual_keyboard_manager_v1_destroy(manager);
    wl_seat_destroy(seat); wl_registry_destroy(registry);
    wl_display_disconnect(display);
    return result < 0 ? 9 : 0;
}
