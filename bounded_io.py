#!/usr/bin/env python3
"""Read small mutable state without letting a special file enter Quickshell."""
import json
import os
import stat
import sys
import tempfile


def bounded_read(path, limit):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            raise ValueError("not a bounded regular file")
        chunks = bytearray()
        while len(chunks) <= limit:
            part = os.read(descriptor, min(65536, limit + 1 - len(chunks)))
            if not part:
                break
            chunks.extend(part)
        if len(chunks) > limit:
            raise ValueError("file grew beyond limit")
        return chunks.decode("utf-8")
    finally:
        os.close(descriptor)


def atomic_write(path, text, limit):
    payload = text.encode("utf-8")
    if len(payload) > limit:
        raise ValueError("write exceeds limit")
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        pass
    else:
        if not stat.S_ISREG(info.st_mode):
            raise ValueError("not a regular destination")
    folder = os.path.dirname(path)
    descriptor, temporary = tempfile.mkstemp(prefix=".windowpeek-", dir=folder)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(payload)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("read", "write"):
        return 2
    action, path = sys.argv[1:3]
    limit = int(sys.argv[3])
    if limit < 1 or limit > 1024 * 1024:
        return 2
    try:
        if action == "read":
            result = {"status": "ok", "text": bounded_read(path, limit)}
        else:
            raw = sys.stdin.buffer.readline(limit * 8 + 1024)
            if not raw.endswith(b"\n") or len(raw) > limit * 8:
                raise ValueError("write input exceeds limit")
            value = json.loads(raw)
            if not isinstance(value, dict) or not isinstance(value.get("text"), str):
                raise ValueError("invalid write input")
            atomic_write(path, value["text"], limit)
            result = {"status": "ok"}
    except FileNotFoundError:
        result = {"status": "missing"} if action == "read" else {"status": "error"}
    except (OSError, UnicodeError, ValueError, TypeError):
        result = {"status": "error"}
    print(json.dumps(result, ensure_ascii=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
