#!/usr/bin/env python3
"""Read X11 geometry replies only. No input events, window changes or titles.

Optional runtime worker: missing X11/XRes support disables detection. Its parent
owns stdin and must renew a short lease; EOF or a stopped parent ends observation.
"""
import ctypes as C
import json
import os
import select
import sys
import time


class ClassHint(C.Structure):
    _fields_ = [("name", C.c_void_p), ("klass", C.c_void_p)]


class Configure(C.Structure):
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("synthetic", C.c_int),
                ("display", C.c_void_p), ("event", C.c_ulong), ("window", C.c_ulong),
                ("x", C.c_int), ("y", C.c_int), ("width", C.c_int), ("height", C.c_int),
                ("border", C.c_int), ("above", C.c_ulong), ("override", C.c_int)]


class Event(C.Union):
    _fields_ = [("type", C.c_int), ("configure", Configure), ("pad", C.c_long * 24)]


class Spec(C.Structure):
    _fields_ = [("client", C.c_uint32), ("mask", C.c_uint32)]


class Cookie(C.Structure):
    _fields_ = [("sequence", C.c_uint)]


class Iterator(C.Structure):
    _fields_ = [("data", C.c_void_p), ("rem", C.c_int), ("index", C.c_int)]


def bind(lib, name, result, *args):
    fn = getattr(lib, name)
    fn.restype, fn.argtypes = result, args
    return fn


def emit(kind, **fields):
    print(json.dumps(dict(kind=kind, at=int(time.time() * 1000), **fields), separators=(",", ":")), flush=True)


def main():
    x = C.CDLL("libX11.so.6")
    cb = C.CDLL("libxcb.so.1")
    res = C.CDLL("libxcb-res.so.0")
    libc = C.CDLL(None)
    free = bind(libc, "free", None, C.c_void_p)
    open_display = bind(x, "XOpenDisplay", C.c_void_p, C.c_char_p)
    close_display = bind(x, "XCloseDisplay", C.c_int, C.c_void_p)
    display = open_display(None)
    if not display:
        raise RuntimeError("no-x11")
    connect = bind(cb, "xcb_connect", C.c_void_p, C.c_char_p, C.c_void_p)
    disconnect = bind(cb, "xcb_disconnect", None, C.c_void_p)
    connection = connect(None, None)
    try:
        if bind(cb, "xcb_connection_has_error", C.c_int, C.c_void_p)(connection):
            raise RuntimeError("no-xres")
        root = bind(x, "XDefaultRootWindow", C.c_ulong, C.c_void_p)(display)
        atom = bind(x, "XInternAtom", C.c_ulong, C.c_void_p, C.c_char_p, C.c_int)
        clients_atom = atom(display, b"_NET_CLIENT_LIST", True)
        if not clients_atom:
            raise RuntimeError("no-managed-client-list")
        get_property = bind(x, "XGetWindowProperty", C.c_int,
                            C.c_void_p, C.c_ulong, C.c_ulong, C.c_long, C.c_long, C.c_int, C.c_ulong,
                            C.POINTER(C.c_ulong), C.POINTER(C.c_int), C.POINTER(C.c_ulong),
                            C.POINTER(C.c_ulong), C.POINTER(C.c_void_p))
        get_class = bind(x, "XGetClassHint", C.c_int, C.c_void_p, C.c_ulong, C.POINTER(ClassHint))
        xfree = bind(x, "XFree", C.c_int, C.c_void_p)
        choose = bind(x, "XSelectInput", C.c_int, C.c_void_p, C.c_ulong, C.c_long)
        flush = bind(x, "XFlush", C.c_int, C.c_void_p)
        pending = bind(x, "XPending", C.c_int, C.c_void_p)
        next_event = bind(x, "XNextEvent", C.c_int, C.c_void_p, C.POINTER(Event))
        query_ids = bind(res, "xcb_res_query_client_ids", Cookie, C.c_void_p, C.c_uint32, C.POINTER(Spec))
        reply_ids = bind(res, "xcb_res_query_client_ids_reply", C.c_void_p, C.c_void_p, Cookie, C.c_void_p)
        iterate = bind(res, "xcb_res_query_client_ids_ids_iterator", Iterator, C.c_void_p)
        advance = bind(res, "xcb_res_client_id_value_next", None, C.POINTER(Iterator))
        value_len = bind(res, "xcb_res_client_id_value_value_length", C.c_int, C.c_void_p)
        values = bind(res, "xcb_res_client_id_value_value", C.c_void_p, C.c_void_p)
        # Windows can disappear between enumeration and subscription. An X error
        # must not terminate the shell; it only invalidates this worker's source.
        error_type = C.CFUNCTYPE(C.c_int, C.c_void_p, C.c_void_p)
        error_handler = error_type(lambda _display, _error: 0)
        bind(x, "XSetErrorHandler", C.c_void_p, error_type)(error_handler)
        descriptor = bind(x, "XConnectionNumber", C.c_int, C.c_void_p)(display)

        def managed_windows():
            # The WM's EWMH list excludes Wine/Chromium helper windows sharing
            # a PID/class. XQueryTree includes them and makes one real window
            # look ambiguous. Real multiple managed windows remain ambiguous.
            kind, fmt, count, remaining = C.c_ulong(), C.c_int(), C.c_ulong(), C.c_ulong()
            data = C.c_void_p()
            status = get_property(display, root, clients_atom, 0, 4096, False, 33,
                                  C.byref(kind), C.byref(fmt), C.byref(count),
                                  C.byref(remaining), C.byref(data))  # XA_WINDOW
            try:
                if status or kind.value != 33 or fmt.value != 32 or remaining.value or count.value > 4096:
                    raise RuntimeError("invalid-managed-client-list")
                if count.value and not data:
                    raise RuntimeError("missing-managed-client-list")
                # Xlib exposes format-32 properties as native unsigned longs.
                return list(C.cast(data, C.POINTER(C.c_ulong))[:count.value]) if count.value else []
            finally:
                if data: xfree(data)

        def pid_for(window):
            spec = Spec(window, 2)  # XCB_RES_CLIENT_ID_MASK_LOCAL_CLIENT_PID
            reply = reply_ids(connection, query_ids(connection, 1, C.byref(spec)), None)
            if not reply:
                return 0
            try:
                item = iterate(reply)
                while item.rem:
                    if C.cast(item.data, C.POINTER(Spec)).contents.mask & 2 and value_len(item.data) > 0:
                        return C.cast(values(item.data), C.POINTER(C.c_uint32)).contents.value
                    advance(C.byref(item))
                return 0
            finally:
                free(reply)

        known = {}
        scan_at = 0
        renewed = time.monotonic()
        while time.monotonic() - renewed < 3:
            now = time.monotonic()
            if now >= scan_at:
                current = {}
                for window in managed_windows():
                    hint = ClassHint()
                    if not get_class(display, window, C.byref(hint)):
                        continue
                    try:
                        klass = C.string_at(hint.klass) if hint.klass else b""
                        if not klass or len(klass) > 1024:
                            continue
                        pid = known.get(window, {}).get("pid") or pid_for(window)
                        if not pid:
                            continue
                        current[window] = {"id": hex(window), "pid": pid, "class": klass.decode("utf-8", "replace"), "managed": True}
                        if len(current) > 256:
                            raise RuntimeError("too-many-sources")
                        if window not in known:
                            choose(display, window, 1 << 17)  # StructureNotifyMask only
                    finally:
                        if hint.name: xfree(hint.name)
                        if hint.klass: xfree(hint.klass)
                for window in known.keys() - current.keys():
                    choose(display, window, 0)
                    emit("forget", id=hex(window))
                known = current
                flush(display)
                emit("sources", sources=list(known.values()))
                scan_at = now + 0.5
            count = 0
            while pending(display) and count < 256:
                event = Event()
                next_event(display, C.byref(event))
                count += 1
                if event.type == 22 and event.configure.window in known:  # ConfigureNotify
                    c = event.configure
                    emit("geometry", id=hex(c.window), synthetic=bool(c.synthetic), width=c.width, height=c.height)
                elif event.type == 17:  # DestroyNotify shares event/window prefix
                    window = event.configure.window
                    known.pop(window, None)
                    emit("forget", id=hex(window))
            readable, _, _ = select.select([descriptor, sys.stdin.fileno()], [], [], 0.05)
            if sys.stdin.fileno() in readable:
                data = os.read(sys.stdin.fileno(), 4096)
                if not data: break
                renewed = time.monotonic()
    finally:
        disconnect(connection)
        close_display(display)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, BrokenPipeError):
        try: emit("unavailable")
        except BrokenPipeError: pass
        sys.exit(1)
