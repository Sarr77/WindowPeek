// Fictional resize source for a private compositor, with Wine-like helper windows.
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    int companion = argc == 2 && !strcmp(argv[1], "--floating-companion");
    if (argc > 1 && !companion) return 2;
    const char *isolated = getenv("WINDOWPEEK_ISOLATED");
    if (!isolated || strcmp(isolated, "1")) return 2;
    Display *display = XOpenDisplay(NULL);
    if (!display) return 2;
    XClassHint cls = {.res_name="windowpeek-focus-fixture", .res_class="WindowPeekFocusFixture"};
    Window windows[8];
    for (int i=0; i<8; ++i) {
        windows[i] = XCreateSimpleWindow(display, DefaultRootWindow(display), 0, 0, 420, 300, 0, 0, 0);
        XSetClassHint(display, windows[i], &cls);
    }
    XStoreName(display, windows[0], "Fictional X11 resize fixture");
    XMapWindow(display, windows[0]);
    if (companion) {
        XClassHint other = {.res_name="windowpeek-companion", .res_class="WindowPeekCompanionFixture"};
        XSetClassHint(display, windows[1], &other);
        XStoreName(display, windows[1], "Fictional floating companion");
        Atom type = XInternAtom(display, "_NET_WM_WINDOW_TYPE", False);
        Atom dialog = XInternAtom(display, "_NET_WM_WINDOW_TYPE_DIALOG", False);
        XChangeProperty(display, windows[1], type, XA_ATOM, 32, PropModeReplace,
                        (unsigned char *)&dialog, 1);
        XSetTransientForHint(display, windows[1], windows[0]);
        XResizeWindow(display, windows[1], 160, 60);
        XMapWindow(display, windows[1]);
    }
    XSync(display, False);
    for (int i=0; i<28; ++i) {
        for (int j=0; j<3; ++j) {
            XResizeWindow(display, windows[0], 420+j%2, 300);
            XSync(display, False);
            usleep(5000);
        }
        usleep(1485000);
    }
    for (int i=0; i<8; ++i) XDestroyWindow(display, windows[i]);
    XCloseDisplay(display);
    return 0;
}
