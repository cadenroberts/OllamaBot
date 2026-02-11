#!/usr/bin/env python3
"""
code — local DAG scheduler + worker + CLI for multi-agent collaboration.

Single-file: SQLite WAL DB, HTTP API, plan compiler, worker loop, CLI.
Pointer-based payloads. True DAG deps. Leases + heartbeats. Content-addressed dedupe.
Policy: ACCRUE ALL IDEAS, NO REFACTOR, single-writer artifacts.
"""

import argparse
import hashlib
import http.server
import json
import os
import re
import signal
import sqlite3
import subprocess
import sys
import threading
import time
import traceback
import urllib.parse
import urllib.request
from contextlib import contextmanager
from pathlib import Path

# ─── Constants ───────────────────────────────────────────────────────────────

VERSION = "0.1.0"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 7337
DEFAULT_DB = ".cursor/code/code.db"
LEASE_MS = 30000
MAX_ATTEMPTS = 3
ARTIFACT_DIR = "docs/code_runtime/artifacts/by-hash"
VALID_PREFIXES = ("@file:", "@cmd:", "@url:", "@git:", "@gh:", "@doc:")

# ─── DB Schema ───────────────────────────────────────────────────────────────

SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=5000;

CREATE TABLE IF NOT EXISTS jobs (
    id TEXT PRIMARY KEY,
    lane INTEGER NOT NULL DEFAULT 0,
    payload TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued',
    holder TEXT,
    lease_until REAL,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL,
    error TEXT,
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    dedupe_key TEXT
);

CREATE TABLE IF NOT EXISTS job_deps (
    job_id TEXT NOT NULL,
    dep_id TEXT NOT NULL,
    PRIMARY KEY (job_id, dep_id),
    FOREIGN KEY (job_id) REFERENCES jobs(id),
    FOREIGN KEY (dep_id) REFERENCES jobs(id)
);

CREATE TABLE IF NOT EXISTS events (
    ts REAL NOT NULL,
    job_id TEXT,
    kind TEXT NOT NULL,
    msg TEXT
);

CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_lane ON jobs(lane);
CREATE INDEX IF NOT EXISTS idx_jobs_dedupe ON jobs(dedupe_key);
CREATE INDEX IF NOT EXISTS idx_job_deps_dep ON job_deps(dep_id);
CREATE INDEX IF NOT EXISTS idx_events_job ON events(job_id);
"""

# ─── DB Layer ────────────────────────────────────────────────────────────────


def init_db(db_path):
    os.makedirs(os.path.dirname(db_path) or ".", exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.executescript(SCHEMA)
    conn.close()


@contextmanager
def db_conn(db_path):
    conn = sqlite3.connect(db_path, timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    try:
        yield conn
    finally:
        conn.close()


def log_event(conn, job_id, kind, msg=""):
    conn.execute(
        "INSERT INTO events(ts, job_id, kind, msg) VALUES(?, ?, ?, ?)",
        (time.time(), job_id, kind, msg[:500] if msg else ""),
    )


def validate_payload(payload):
    if not any(payload.startswith(p) for p in VALID_PREFIXES):
        raise ValueError(
            f"Payload must start with one of {VALID_PREFIXES}. Got: {payload[:80]}"
        )


def enqueue_job(conn, job_id, lane, payload, dedupe_key=None, max_attempts=MAX_ATTEMPTS):
    validate_payload(payload)
    now = time.time()
    conn.execute(
        """INSERT OR IGNORE INTO jobs(id, lane, payload, status, created_at, updated_at, dedupe_key, max_attempts)
           VALUES(?, ?, ?, 'queued', ?, ?, ?, ?)""",
        (job_id, lane, payload, now, now, dedupe_key, max_attempts),
    )
    log_event(conn, job_id, "enqueued", payload[:120])


def add_dep(conn, job_id, dep_id):
    conn.execute(
        "INSERT OR IGNORE INTO job_deps(job_id, dep_id) VALUES(?, ?)",
        (job_id, dep_id),
    )


def requeue_stale(conn):
    now = time.time()
    conn.execute("BEGIN IMMEDIATE")
    try:
        stale = conn.execute(
            "SELECT id, attempts, max_attempts FROM jobs WHERE status='running' AND lease_until < ?",
            (now,),
        ).fetchall()
        count = 0
        for row in stale:
            if row["attempts"] < row["max_attempts"]:
                conn.execute(
                    "UPDATE jobs SET status='queued', holder=NULL, lease_until=NULL, updated_at=? WHERE id=?",
                    (now, row["id"]),
                )
                log_event(conn, row["id"], "requeued", "stale lease")
            else:
                conn.execute(
                    "UPDATE jobs SET status='failed', error='max attempts exceeded', updated_at=? WHERE id=?",
                    (now, row["id"]),
                )
                log_event(conn, row["id"], "failed", "max attempts exceeded")
            count += 1
        conn.execute("COMMIT")
    except Exception:
        conn.execute("ROLLBACK")
        raise
    return count


def check_dedupe(dedupe_key):
    """Return True if artifact with this hash already exists."""
    if not dedupe_key:
        return False
    artifact_dir = Path(ARTIFACT_DIR)
    if not artifact_dir.exists():
        return False
    for f in artifact_dir.iterdir():
        if f.stem == dedupe_key:
            return True
    return False


def claim_ready(conn, holder, lane=None, batch=1, lease_ms=LEASE_MS):
    requeue_stale(conn)
    now = time.time()
    lease_until = now + lease_ms / 1000.0

    lane_clause = ""
    params = []
    if lane is not None:
        lane_clause = "AND j.lane = ?"
        params.append(lane)

    query = f"""
        SELECT j.id, j.lane, j.payload, j.dedupe_key
        FROM jobs j
        WHERE j.status = 'queued'
          {lane_clause}
          AND NOT EXISTS (
              SELECT 1 FROM job_deps d
              JOIN jobs dj ON dj.id = d.dep_id
              WHERE d.job_id = j.id AND dj.status != 'done'
          )
        ORDER BY j.created_at
        LIMIT ?
    """
    params.append(batch)
    rows = conn.execute(query, params).fetchall()

    claimed = []
    for row in rows:
        jid = row["id"]
        dk = row["dedupe_key"]

        # Dedupe: skip if artifact already exists
        if check_dedupe(dk):
            conn.execute(
                "UPDATE jobs SET status='done', holder=?, updated_at=? WHERE id=? AND status='queued'",
                (holder, now, jid),
            )
            log_event(conn, jid, "dedupe_skip", f"artifact exists for {dk}")
            conn.commit()
            continue

        res = conn.execute(
            """UPDATE jobs SET status='running', holder=?, lease_until=?, attempts=attempts+1, updated_at=?
               WHERE id=? AND status='queued'""",
            (holder, lease_until, now, jid),
        )
        if res.rowcount:
            log_event(conn, jid, "claimed", f"holder={holder}")
            claimed.append(
                {
                    "id": jid,
                    "lane": row["lane"],
                    "payload": row["payload"],
                    "dedupe_key": dk,
                }
            )
    conn.commit()
    return claimed


def mark_done(conn, job_id, holder=None):
    now = time.time()
    if holder:
        conn.execute(
            "UPDATE jobs SET status='done', updated_at=? WHERE id=? AND status='running' AND holder=?",
            (now, job_id, holder),
        )
    else:
        conn.execute(
            "UPDATE jobs SET status='done', updated_at=? WHERE id=? AND status='running'",
            (now, job_id),
        )
    log_event(conn, job_id, "done", "")
    conn.commit()


def mark_failed(conn, job_id, error="", holder=None):
    now = time.time()
    if holder:
        conn.execute(
            "UPDATE jobs SET status='failed', error=?, updated_at=? WHERE id=? AND status='running' AND holder=?",
            (error[:1000], now, job_id, holder),
        )
    else:
        conn.execute(
            "UPDATE jobs SET status='failed', error=?, updated_at=? WHERE id=? AND status='running'",
            (error[:1000], now, job_id),
        )
    log_event(conn, job_id, "failed", error[:200])
    conn.commit()


def heartbeat(conn, job_id, holder, lease_ms=LEASE_MS):
    now = time.time()
    lease_until = now + lease_ms / 1000.0
    res = conn.execute(
        "UPDATE jobs SET lease_until=?, updated_at=? WHERE id=? AND status='running' AND holder=?",
        (lease_until, now, job_id, holder),
    )
    conn.commit()
    return res.rowcount > 0


def get_stats(conn):
    rows = conn.execute(
        "SELECT status, COUNT(*) as cnt FROM jobs GROUP BY status"
    ).fetchall()
    stats = {r["status"]: r["cnt"] for r in rows}
    stats["total"] = sum(stats.values())
    return stats


def get_jobs(conn, status=None, limit=100):
    if status:
        rows = conn.execute(
            "SELECT id, lane, payload, status, holder, error, attempts FROM jobs WHERE status=? ORDER BY created_at LIMIT ?",
            (status, limit),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT id, lane, payload, status, holder, error, attempts FROM jobs ORDER BY created_at LIMIT ?",
            (limit,),
        ).fetchall()
    return [dict(r) for r in rows]


# ─── Plan Compiler ───────────────────────────────────────────────────────────


def plan_slug(path):
    name = Path(path).stem
    return re.sub(r"[^a-zA-Z0-9_.-]", "_", name)


def extract_sha_from_payload(payload):
    m = re.search(r"#sha1=([a-fA-F0-9]+)", payload)
    if m:
        return m.group(1)
    return None


def parse_plan(plan_path):
    """Parse a markdown plan into jobs and deps."""
    text = Path(plan_path).read_text()
    slug = plan_slug(plan_path)

    # Extract policy
    policy = {}
    for line in text.splitlines():
        stripped = line.strip().lower()
        if stripped.startswith("policy:"):
            parts = stripped[len("policy:"):].split(",")
            for p in parts:
                p = p.strip()
                if "=" in p:
                    k, v = p.split("=", 1)
                    policy[k.strip()] = v.strip()

    # Check plan_id header
    plan_id = slug
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.lower().startswith("plan_id="):
            plan_id = stripped.split("=", 1)[1].strip()
            break

    # ACCRUE_ALL_IDEAS enforcement
    accrue = policy.get("accrue_all_ideas", "false").lower() == "true"
    if accrue:
        orphan_count = 0
        for line in text.splitlines():
            if "TODO_ORPHAN:" in line:
                orphan_count += 1
        if orphan_count > 0:
            raise RuntimeError(
                f"ACCRUE_ALL_IDEAS policy active but {orphan_count} TODO_ORPHAN markers found. "
                "All ideas must be captured as steps before marking plan complete."
            )

    # Parse steps: lines matching - [ ] id=... lane=... payload=...
    step_re = re.compile(
        r"^-\s*\[\s*\]\s+(.+)$"
    )
    field_re = re.compile(r"(\w+)=(\S+)")

    steps = []
    for line in text.splitlines():
        m = step_re.match(line.strip())
        if not m:
            continue
        rest = m.group(1)
        fields = dict(field_re.findall(rest))
        if "id" not in fields:
            continue
        if "lane" not in fields:
            continue
        if "payload" not in fields:
            # payload may contain spaces if quoted, but our regex won't capture that.
            # Try extracting payload= to end of line after other fields
            payload_m = re.search(r"payload=(.+?)(?:\s+(?:dedupe|deps)=|$)", rest)
            if payload_m:
                fields["payload"] = payload_m.group(1).strip()
            else:
                continue

        step_id = fields["id"]
        lane = int(fields["lane"])

        # Reconstruct payload: everything after payload= minus trailing known fields
        # Use a more robust extraction
        payload_start = rest.find("payload=")
        if payload_start >= 0:
            payload_raw = rest[payload_start + len("payload="):]
            # Strip trailing field assignments that come after
            # But payload can contain spaces, so we look for next field= pattern
            # that isn't part of the payload
            cleaned = payload_raw
            # Remove trailing deps=..., dedupe=... etc if they appear
            for trailing_field in ["deps=", "dedupe="]:
                idx = cleaned.rfind(trailing_field)
                if idx > 0:
                    cleaned = cleaned[:idx].rstrip()
            fields["payload"] = cleaned
        else:
            # Fallback
            fields["payload"] = fields.get("payload", "")

        payload = fields["payload"]
        deps_str = fields.get("deps", "")
        deps = [d.strip() for d in deps_str.split(",") if d.strip()] if deps_str else []
        dedupe_key = fields.get("dedupe", None) or extract_sha_from_payload(payload)

        steps.append(
            {
                "id": step_id,
                "global_id": f"{plan_id}::{step_id}",
                "lane": lane,
                "payload": payload,
                "deps": deps,
                "dedupe_key": dedupe_key,
            }
        )

    return plan_id, steps, policy


def expand_plan(db_path, plan_path):
    """Compile plan into jobs in the DB. Returns (plan_id, step_count)."""
    plan_id, steps, policy = parse_plan(plan_path)

    if not steps:
        raise RuntimeError(f"No steps found in {plan_path}")

    # Build step_id -> global_id map
    id_map = {s["id"]: s["global_id"] for s in steps}

    with db_conn(db_path) as conn:
        for step in steps:
            enqueue_job(
                conn,
                step["global_id"],
                step["lane"],
                step["payload"],
                dedupe_key=step["dedupe_key"],
                max_attempts=MAX_ATTEMPTS,
            )
        conn.commit()

        # Add deps
        for step in steps:
            for dep_id in step["deps"]:
                if dep_id not in id_map:
                    raise RuntimeError(
                        f"Step '{step['id']}' depends on unknown step '{dep_id}'"
                    )
                add_dep(conn, step["global_id"], id_map[dep_id])
        conn.commit()

    return plan_id, len(steps)


# ─── HTTP Server ─────────────────────────────────────────────────────────────


class CodeHandler(http.server.BaseHTTPRequestHandler):
    """HTTP handler for the scheduler API."""

    db_path = DEFAULT_DB

    def log_message(self, format, *args):
        # Suppress default logging
        pass

    def _json_response(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length:
            return json.loads(self.rfile.read(length))
        return {}

    def _error(self, status, msg):
        self._json_response({"error": msg}, status)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(parsed.query)

        if parsed.path == "/stats":
            with db_conn(self.db_path) as conn:
                self._json_response(get_stats(conn))

        elif parsed.path == "/ready":
            holder = qs.get("holder", ["anon"])[0]
            lane = qs.get("lane", [None])[0]
            batch = int(qs.get("batch", [1])[0])
            if lane is not None:
                lane = int(lane)
            with db_conn(self.db_path) as conn:
                jobs = claim_ready(conn, holder, lane=lane, batch=batch)
                self._json_response({"jobs": jobs})

        elif parsed.path == "/jobs":
            status = qs.get("status", [None])[0]
            limit = int(qs.get("limit", [100])[0])
            with db_conn(self.db_path) as conn:
                self._json_response({"jobs": get_jobs(conn, status=status, limit=limit)})

        elif parsed.path == "/health":
            self._json_response({"status": "ok", "version": VERSION})

        else:
            self._error(404, "not found")

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/enqueue":
            body = self._read_body()
            try:
                with db_conn(self.db_path) as conn:
                    enqueue_job(
                        conn,
                        body["id"],
                        int(body.get("lane", 0)),
                        body["payload"],
                        dedupe_key=body.get("dedupe_key"),
                        max_attempts=int(body.get("max_attempts", MAX_ATTEMPTS)),
                    )
                    deps = body.get("deps", [])
                    for dep_id in deps:
                        add_dep(conn, body["id"], dep_id)
                    conn.commit()
                self._json_response({"ok": True, "id": body["id"]})
            except (KeyError, ValueError) as e:
                self._error(400, str(e))

        elif parsed.path == "/done":
            body = self._read_body()
            with db_conn(self.db_path) as conn:
                mark_done(conn, body["id"], holder=body.get("holder"))
            self._json_response({"ok": True})

        elif parsed.path == "/fail":
            body = self._read_body()
            with db_conn(self.db_path) as conn:
                mark_failed(
                    conn, body["id"], error=body.get("error", ""), holder=body.get("holder")
                )
            self._json_response({"ok": True})

        elif parsed.path == "/heartbeat":
            body = self._read_body()
            with db_conn(self.db_path) as conn:
                ok = heartbeat(conn, body["id"], body["holder"])
            self._json_response({"ok": ok})

        elif parsed.path == "/expand":
            body = self._read_body()
            try:
                plan_id, count = expand_plan(self.db_path, body["plan"])
                self._json_response({"ok": True, "plan_id": plan_id, "steps": count})
            except Exception as e:
                self._error(400, str(e))

        else:
            self._error(404, "not found")


class ThreadedHTTPServer(http.server.ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


def run_server(db_path, host, port):
    init_db(db_path)
    CodeHandler.db_path = db_path
    server = ThreadedHTTPServer((host, port), CodeHandler)
    print(f"[code] server listening on http://{host}:{port}  db={db_path}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[code] server stopped")
        server.shutdown()


def is_server_running(host, port):
    try:
        url = f"http://{host}:{port}/health"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=2) as resp:
            return resp.status == 200
    except Exception:
        return False


def ensure_server(db_path, host, port):
    """Start server in background if not already running. Returns True if started."""
    if is_server_running(host, port):
        return False
    init_db(db_path)
    pid = os.fork()
    if pid == 0:
        # Child: become the server
        os.setsid()
        # Redirect stdout/stderr to log
        log_dir = os.path.dirname(db_path)
        log_path = os.path.join(log_dir, "server.log")
        fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
        os.dup2(fd, 1)
        os.dup2(fd, 2)
        os.close(fd)
        # Close stdin
        devnull = os.open(os.devnull, os.O_RDONLY)
        os.dup2(devnull, 0)
        os.close(devnull)
        run_server(db_path, host, port)
        os._exit(0)
    else:
        # Parent: wait for server to be ready
        for _ in range(40):
            time.sleep(0.15)
            if is_server_running(host, port):
                print(f"[code] server started (pid={pid}) on http://{host}:{port}")
                return True
        print(f"[code] WARNING: server may not have started (pid={pid})")
        return True


# ─── HTTP Client helpers ─────────────────────────────────────────────────────


def api_get(host, port, path):
    url = f"http://{host}:{port}{path}"
    with urllib.request.urlopen(url, timeout=10) as resp:
        return json.loads(resp.read())


def api_post(host, port, path, data):
    url = f"http://{host}:{port}{path}"
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


# ─── Worker ──────────────────────────────────────────────────────────────────

# Safety: only allow commands under repo root
REPO_ROOT = os.getcwd()

# Allowed command prefixes for @cmd: execution
CMD_ALLOWLIST = [
    "echo ", "cat ", "test ", "ls ", "mkdir ", "cp ", "mv ",
    "go test", "go build", "go vet", "go fmt",
    "python", "pip ", "npm ", "npx ", "node ",
    "make", "cargo ", "rustc ",
    "git ", "diff ", "patch ",
    "swift ", "xcodebuild",
    "./code ", "./scripts/code",
    "true", "false",
    "touch ", "rm ",  # careful
    "head ", "tail ", "wc ", "sort ", "uniq ",
    "grep ", "rg ", "fd ",
    "sha1sum", "sha256sum", "md5sum",
    "sleep ",
]

# Blocked patterns
CMD_BLOCKLIST = [
    "rm -rf /", "rm -rf ~", "sudo ", "curl ", "wget ",
    "eval ", "> /dev/", "mkfs", "dd if=", ":(){ ",
]


def is_cmd_safe(cmd):
    cmd_stripped = cmd.strip()
    for blocked in CMD_BLOCKLIST:
        if blocked in cmd_stripped:
            return False
    for prefix in CMD_ALLOWLIST:
        if cmd_stripped.startswith(prefix) or cmd_stripped == prefix.strip():
            return True
    # Allow any command that starts with ./ (repo-local scripts)
    if cmd_stripped.startswith("./"):
        return True
    return False


def execute_cmd(cmd):
    """Execute a shell command locally. Returns (exit_code, stdout, stderr)."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=REPO_ROOT,
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "timeout after 120s"
    except Exception as e:
        return 1, "", str(e)


def apply_patch(path):
    """Apply a .diff file using patch."""
    if not os.path.isfile(path):
        return 1, "", f"patch file not found: {path}"
    return execute_cmd(f"patch -p1 < {path}")


def worker_loop(host, port, holder, lane=None, batch=1, poll_interval=2.0, mode="local"):
    """Poll for ready jobs and execute them."""
    print(f"[code worker] holder={holder} lane={lane} mode={mode} poll={poll_interval}s")

    while True:
        try:
            qs = f"?holder={holder}&batch={batch}"
            if lane is not None:
                qs += f"&lane={lane}"
            result = api_get(host, port, f"/ready{qs}")
            jobs = result.get("jobs", [])

            for job in jobs:
                jid = job["id"]
                payload = job["payload"]
                print(f"[code worker] claimed {jid}: {payload[:80]}")

                if mode == "local":
                    ok = execute_job_local(host, port, jid, payload, holder)
                    if not ok:
                        print(f"[code worker] job {jid} failed")
                else:
                    # LLM mode: just print the job for a human/LLM agent to handle
                    print(f"[code worker] LLM job (manual): {jid} => {payload}")
                    # Don't auto-complete; agent will mark done via API

            if not jobs:
                time.sleep(poll_interval)
            else:
                time.sleep(0.05)

        except KeyboardInterrupt:
            print(f"\n[code worker] {holder} stopped")
            break
        except Exception as e:
            print(f"[code worker] error: {e}")
            time.sleep(poll_interval)


def execute_job_local(host, port, jid, payload, holder):
    """Execute a job locally. Returns True on success."""
    try:
        if payload.startswith("@cmd:"):
            cmd = payload[len("@cmd:"):]
            if not is_cmd_safe(cmd):
                api_post(host, port, "/fail", {"id": jid, "holder": holder, "error": f"blocked command: {cmd[:60]}"})
                return False
            code, stdout, stderr = execute_cmd(cmd)
            if code == 0:
                api_post(host, port, "/done", {"id": jid, "holder": holder})
                if stdout.strip():
                    print(f"  stdout: {stdout.strip()[:200]}")
                return True
            else:
                err_msg = (stderr or stdout or f"exit code {code}")[:500]
                api_post(host, port, "/fail", {"id": jid, "holder": holder, "error": err_msg})
                print(f"  failed: {err_msg[:200]}")
                return False

        elif payload.startswith("@file:") and "#apply" in payload:
            path = payload[len("@file:"):].split("#")[0]
            code, stdout, stderr = apply_patch(path)
            if code == 0:
                api_post(host, port, "/done", {"id": jid, "holder": holder})
                return True
            else:
                api_post(host, port, "/fail", {"id": jid, "holder": holder, "error": (stderr or stdout)[:500]})
                return False

        elif payload.startswith("@file:") and "#test" in payload:
            path = payload[len("@file:"):].split("#")[0]
            cmd = f"test -f {path}"
            code, stdout, stderr = execute_cmd(cmd)
            if code == 0:
                api_post(host, port, "/done", {"id": jid, "holder": holder})
                return True
            else:
                api_post(host, port, "/fail", {"id": jid, "holder": holder, "error": f"test failed: {path}"})
                return False

        elif payload.startswith("@doc:") or payload.startswith("@url:") or payload.startswith("@git:") or payload.startswith("@gh:"):
            # Metadata-only: mark done immediately
            api_post(host, port, "/done", {"id": jid, "holder": holder})
            return True

        elif payload.startswith("@file:"):
            # LLM-required job: in local mode, skip (leave running for LLM worker)
            # Actually in local mode we should not claim these. But if we did, fail gracefully.
            api_post(host, port, "/fail", {"id": jid, "holder": holder, "error": "LLM-required job; not executable in local mode"})
            return False

        else:
            api_post(host, port, "/fail", {"id": jid, "holder": holder, "error": f"unknown payload type: {payload[:40]}"})
            return False

    except Exception as e:
        try:
            api_post(host, port, "/fail", {"id": jid, "holder": holder, "error": str(e)[:500]})
        except Exception:
            pass
        return False


# ─── Hash helper ─────────────────────────────────────────────────────────────


def compute_sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(8192)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


# ─── Contract Blocks ─────────────────────────────────────────────────────────


def worker_contract(host, port, holder="pane-N"):
    return f"""
╔══════════════════════════════════════════════════════════════╗
║  WORKER CONTRACT — paste into any Cursor agent/terminal     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  You are a code worker. Your loop:                           ║
║                                                              ║
║  1. GET http://{host}:{port}/ready?holder={holder}           ║
║     → receive jobs array                                     ║
║  2. For each job:                                            ║
║     a. Read payload pointer (e.g. @file:path/to/spec)        ║
║     b. Do the work described by the pointer                  ║
║     c. POST /done  {{"id":"<job_id>","holder":"{holder}"}}   ║
║        or POST /fail {{"id":"<job_id>","holder":"{holder}",  ║
║                        "error":"reason"}}                    ║
║  3. POST /heartbeat every 15s for long jobs                  ║
║     {{"id":"<job_id>","holder":"{holder}"}}                  ║
║  4. Repeat from step 1                                       ║
║                                                              ║
║  RULES:                                                      ║
║  • Payloads are POINTERS. Read the target, do the work.      ║
║  • NO REFACTOR. Additive changes, adapters, stubs only.      ║
║  • Single-writer: produce .diff OR full file, never both.    ║
║  • ACCRUE ALL IDEAS: capture discoveries as new steps via     ║
║    POST /enqueue                                             ║
║                                                              ║
║  CLI shortcut:                                               ║
║    ./code worker --holder {holder} --poll 2                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"""


def executor_contract(host, port):
    return f"""
╔══════════════════════════════════════════════════════════════╗
║  EXECUTOR CONTRACT — for apply/verify/test jobs              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Run a local worker that auto-executes @cmd: and @file:      ║
║  payloads:                                                   ║
║                                                              ║
║    ./code worker --mode local --holder exec-1 --poll 1       ║
║                                                              ║
║  This worker handles:                                        ║
║  • @cmd:<shell>        → runs shell command                  ║
║  • @file:path#apply    → applies .diff patch                 ║
║  • @file:path#test     → checks file exists                  ║
║  • @doc:/@url:/@git:   → marks done (metadata only)          ║
║                                                              ║
║  It does NOT handle @file: without #apply/#test (LLM work).  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"""


# ─── CLI ─────────────────────────────────────────────────────────────────────


def cmd_server(args):
    run_server(args.db, args.host, args.port)


def cmd_worker(args):
    lane = args.lane
    if lane is not None:
        lane = int(lane)
    worker_loop(
        args.host,
        args.port,
        holder=args.holder,
        lane=lane,
        batch=int(args.batch),
        poll_interval=float(args.poll),
        mode=args.mode,
    )


def cmd_enqueue(args):
    payload = args.payload
    validate_payload(payload)
    data = {
        "id": args.id or f"manual-{int(time.time()*1000)}",
        "lane": int(args.lane),
        "payload": payload,
        "deps": [d.strip() for d in args.deps.split(",") if d.strip()] if args.deps else [],
    }
    if args.dedupe:
        data["dedupe_key"] = args.dedupe
    result = api_post(args.host, args.port, "/enqueue", data)
    print(json.dumps(result, indent=2))


def cmd_done(args):
    result = api_post(args.host, args.port, "/done", {"id": args.id, "holder": args.holder})
    print(json.dumps(result, indent=2))


def cmd_fail(args):
    result = api_post(
        args.host, args.port, "/fail",
        {"id": args.id, "holder": args.holder, "error": args.error or ""},
    )
    print(json.dumps(result, indent=2))


def cmd_heartbeat(args):
    result = api_post(
        args.host, args.port, "/heartbeat",
        {"id": args.id, "holder": args.holder},
    )
    print(json.dumps(result, indent=2))


def cmd_expand(args):
    plan_id, count = expand_plan(args.db, args.plan)
    print(f"[code] expanded plan '{plan_id}' → {count} jobs")


def cmd_stats(args):
    result = api_get(args.host, args.port, "/stats")
    print(json.dumps(result, indent=2))


def cmd_jobs(args):
    result = api_get(args.host, args.port, f"/jobs?status={args.status}&limit={args.limit}" if args.status else f"/jobs?limit={args.limit}")
    for j in result.get("jobs", []):
        status_icon = {"queued": "○", "running": "◉", "done": "✓", "failed": "✗"}.get(j["status"], "?")
        print(f"  {status_icon} [{j['status']:8s}] lane={j['lane']} {j['id']}: {j['payload'][:60]}")


def cmd_join(args):
    print(worker_contract(args.host, args.port, holder=args.holder))


def cmd_exec(args):
    print(executor_contract(args.host, args.port))


def cmd_hash(args):
    h = compute_sha1(args.path)
    print(f"{h}  {args.path}")


def cmd_run(args):
    host = args.host
    port = args.port
    db = args.db

    # 1. Ensure server
    if is_server_running(host, port):
        print(f"[code] server already running on http://{host}:{port}")
    else:
        print(f"[code] starting server on http://{host}:{port} ...")
        ensure_server(db, host, port)

    # 2. Expand plan
    plan_path = args.plan
    print(f"[code] expanding plan: {plan_path}")
    plan_id, count = expand_plan(db, plan_path)
    print(f"[code] plan '{plan_id}' → {count} jobs enqueued")

    # 3. Show stats
    stats = api_get(host, port, "/stats")
    print(f"[code] stats: {json.dumps(stats)}")

    # 4. Print join commands
    agents = int(args.agents)
    print()
    if agents > 0:
        print(f"[code] join commands for {agents} agent pane(s):")
        print("─" * 60)
        for i in range(1, agents + 1):
            print(f"  ./code worker --holder pane-{i} --poll 2")
        print("─" * 60)
        print()

    # 5. Print contracts
    print(worker_contract(host, port, holder="pane-N"))
    print(executor_contract(host, port))

    # 6. Optionally spawn local workers
    if getattr(args, "spawn_local", False) and agents > 0:
        print(f"[code] spawning {agents} local workers ...")
        pids = []
        for i in range(1, agents + 1):
            if i == 1:
                lane = 1
            elif i == agents:
                lane = 3
            else:
                lane = 2
            pid = os.fork()
            if pid == 0:
                # Redirect output
                log_dir = os.path.dirname(db) or "."
                log_path = os.path.join(log_dir, f"worker-{i}.log")
                fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
                os.dup2(fd, 1)
                os.dup2(fd, 2)
                os.close(fd)
                worker_loop(host, port, f"local-{i}", lane=lane, batch=1, poll_interval=0.2, mode="local")
                os._exit(0)
            else:
                pids.append(pid)
                print(f"  spawned worker local-{i} (pid={pid}) lane={lane}")
        print(f"[code] {len(pids)} local workers running")


def main():
    parser = argparse.ArgumentParser(
        prog="code",
        description="Local DAG scheduler + worker for multi-agent collaboration",
    )
    parser.add_argument("--version", action="version", version=f"code {VERSION}")
    sub = parser.add_subparsers(dest="command")

    # server
    p_server = sub.add_parser("server", help="Start HTTP scheduler server")
    p_server.add_argument("--db", default=DEFAULT_DB)
    p_server.add_argument("--host", default=DEFAULT_HOST)
    p_server.add_argument("--port", type=int, default=DEFAULT_PORT)

    # worker
    p_worker = sub.add_parser("worker", help="Start a worker loop")
    p_worker.add_argument("--host", default=DEFAULT_HOST)
    p_worker.add_argument("--port", type=int, default=DEFAULT_PORT)
    p_worker.add_argument("--holder", default=f"worker-{os.getpid()}")
    p_worker.add_argument("--lane", default=None)
    p_worker.add_argument("--batch", default=1)
    p_worker.add_argument("--poll", default="2")
    p_worker.add_argument("--mode", choices=["local", "llm"], default="local")

    # enqueue
    p_enqueue = sub.add_parser("enqueue", help="Enqueue a job")
    p_enqueue.add_argument("payload")
    p_enqueue.add_argument("--id", default=None)
    p_enqueue.add_argument("--lane", default="0")
    p_enqueue.add_argument("--deps", default="")
    p_enqueue.add_argument("--dedupe", default=None)
    p_enqueue.add_argument("--host", default=DEFAULT_HOST)
    p_enqueue.add_argument("--port", type=int, default=DEFAULT_PORT)

    # done
    p_done = sub.add_parser("done", help="Mark a job done")
    p_done.add_argument("id")
    p_done.add_argument("--holder", default=None)
    p_done.add_argument("--host", default=DEFAULT_HOST)
    p_done.add_argument("--port", type=int, default=DEFAULT_PORT)

    # fail
    p_fail = sub.add_parser("fail", help="Mark a job failed")
    p_fail.add_argument("id")
    p_fail.add_argument("--holder", default=None)
    p_fail.add_argument("--error", default="")
    p_fail.add_argument("--host", default=DEFAULT_HOST)
    p_fail.add_argument("--port", type=int, default=DEFAULT_PORT)

    # heartbeat
    p_hb = sub.add_parser("heartbeat", help="Heartbeat a running job")
    p_hb.add_argument("id")
    p_hb.add_argument("--holder", required=True)
    p_hb.add_argument("--host", default=DEFAULT_HOST)
    p_hb.add_argument("--port", type=int, default=DEFAULT_PORT)

    # expand
    p_expand = sub.add_parser("expand", help="Compile a plan into jobs")
    p_expand.add_argument("plan")
    p_expand.add_argument("--db", default=DEFAULT_DB)

    # stats
    p_stats = sub.add_parser("stats", help="Show job stats")
    p_stats.add_argument("--host", default=DEFAULT_HOST)
    p_stats.add_argument("--port", type=int, default=DEFAULT_PORT)

    # jobs
    p_jobs = sub.add_parser("jobs", help="List jobs")
    p_jobs.add_argument("--status", default=None)
    p_jobs.add_argument("--limit", default="100")
    p_jobs.add_argument("--host", default=DEFAULT_HOST)
    p_jobs.add_argument("--port", type=int, default=DEFAULT_PORT)

    # join
    p_join = sub.add_parser("join", help="Print Worker Contract block")
    p_join.add_argument("--holder", default="pane-N")
    p_join.add_argument("--host", default=DEFAULT_HOST)
    p_join.add_argument("--port", type=int, default=DEFAULT_PORT)

    # exec
    p_exec = sub.add_parser("exec", help="Print Executor Contract block")
    p_exec.add_argument("--host", default=DEFAULT_HOST)
    p_exec.add_argument("--port", type=int, default=DEFAULT_PORT)

    # hash
    p_hash = sub.add_parser("hash", help="Compute SHA1 of a file")
    p_hash.add_argument("path")

    # run
    p_run = sub.add_parser("run", help="Ensure server, expand plan, print join commands")
    p_run.add_argument("plan")
    p_run.add_argument("--agents", default="0")
    p_run.add_argument("--spawn-local", action="store_true", dest="spawn_local")
    p_run.add_argument("--db", default=DEFAULT_DB)
    p_run.add_argument("--host", default=DEFAULT_HOST)
    p_run.add_argument("--port", type=int, default=DEFAULT_PORT)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    dispatch = {
        "server": cmd_server,
        "worker": cmd_worker,
        "enqueue": cmd_enqueue,
        "done": cmd_done,
        "fail": cmd_fail,
        "heartbeat": cmd_heartbeat,
        "expand": cmd_expand,
        "stats": cmd_stats,
        "jobs": cmd_jobs,
        "join": cmd_join,
        "exec": cmd_exec,
        "hash": cmd_hash,
        "run": cmd_run,
    }

    fn = dispatch.get(args.command)
    if fn:
        fn(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
