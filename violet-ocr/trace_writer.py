from __future__ import annotations

import atexit
import json
import os
import threading
import time
from multiprocessing import Lock


TRACE_THREAD_BASE = 1000


class TraceWriter:
    def __init__(self, path: str):
        self.path = os.path.abspath(path)
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        open(self.path, "w", encoding="utf-8").close()
        self.lock = threading.Lock()
        self.tid_lock = threading.Lock()
        self.process_lock = Lock()
        self.pid = os.getpid()
        self.t0 = time.perf_counter()
        self.closed = False
        self.thread_ids: dict[str, int] = {}
        atexit.register(self.close)

    def _now_us(self) -> int:
        return int((time.perf_counter() - self.t0) * 1_000_000)

    def _tid(self, label: str) -> int:
        needs_metadata = False
        with self.tid_lock:
            if label not in self.thread_ids:
                self.thread_ids[label] = TRACE_THREAD_BASE + len(self.thread_ids)
                needs_metadata = True
            tid = self.thread_ids[label]
        if needs_metadata:
            self._write(
                {
                    "name": "thread_name",
                    "ph": "M",
                    "pid": self.pid,
                    "tid": tid,
                    "args": {"name": label},
                }
            )
        return tid

    def _write(self, event: dict) -> None:
        with self.lock:
            if self.closed:
                return
            with self.process_lock:
                with open(self.path, "a", encoding="utf-8", newline="\n") as output:
                    output.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")))
                    output.write("\n")

    def instant(self, name: str, cat: str, tid: str, args: dict | None = None) -> None:
        self._write(
            {
                "name": name,
                "cat": cat,
                "ph": "i",
                "s": "t",
                "ts": self._now_us(),
                "pid": self.pid,
                "tid": self._tid(tid),
                "args": args or {},
            }
        )

    def complete(
        self,
        name: str,
        cat: str,
        start: float,
        end: float,
        tid: str,
        args: dict | None = None,
    ) -> None:
        self._write(
            {
                "name": name,
                "cat": cat,
                "ph": "X",
                "ts": int((start - self.t0) * 1_000_000),
                "dur": max(0, int((end - start) * 1_000_000)),
                "pid": self.pid,
                "tid": self._tid(tid),
                "args": args or {},
            }
        )

    def close(self) -> None:
        with self.lock:
            if self.closed:
                return
            self.closed = True


class NullTrace:
    path = ""

    def instant(self, name: str, cat: str, tid: str, args: dict | None = None) -> None:
        return

    def complete(
        self,
        name: str,
        cat: str,
        start: float,
        end: float,
        tid: str,
        args: dict | None = None,
    ) -> None:
        return

    def close(self) -> None:
        return


TRACE: TraceWriter | NullTrace = NullTrace()
