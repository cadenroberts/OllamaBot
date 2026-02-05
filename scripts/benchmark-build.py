#!/usr/bin/env python3
import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


def run_cmd(cmd, cwd=None):
    start = time.perf_counter()
    proc = subprocess.run(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    elapsed = time.perf_counter() - start
    return elapsed, proc.returncode, proc.stdout


def sysctl_int(name):
    try:
        out = subprocess.check_output(["sysctl", "-n", name], text=True).strip()
        return int(out)
    except Exception:
        return None


def clean_bench_path(bench_path, build_dir_name):
    bench_path.mkdir(parents=True, exist_ok=True)
    build_dir = bench_path / build_dir_name
    if build_dir.exists():
        shutil.rmtree(build_dir, ignore_errors=True)
    build_db = bench_path / "build.db"
    if build_db.exists():
        build_db.unlink()


def build_command(app_name, config, jobs, sandbox, index_store, build_system, bench_path):
    cmd = [
        "swift",
        "build",
        "--configuration",
        config,
        "--product",
        app_name,
        "--scratch-path",
        str(bench_path),
        "--jobs",
        str(jobs),
        "--quiet",
    ]
    if sandbox == "off":
        cmd.append("--disable-sandbox")
    if index_store == "disable":
        cmd.append("--disable-index-store")
    if build_system and build_system != "native":
        cmd += ["--build-system", build_system]
    return cmd


def show_bin_path(config, build_system, bench_path):
    cmd = [
        "swift",
        "build",
        "--show-bin-path",
        "--configuration",
        config,
        "--scratch-path",
        str(bench_path),
    ]
    if build_system and build_system != "native":
        cmd += ["--build-system", build_system]
    elapsed, code, output = run_cmd(cmd)
    if code != 0:
        return None
    return output.strip()


def evaluate_build(
    label,
    app_name,
    config,
    jobs,
    sandbox,
    index_store,
    build_system,
    bench_path,
    build_dir_name,
    touch_file,
    iterations,
):
    clean_bench_path(bench_path, build_dir_name)
    cmd = build_command(app_name, config, jobs, sandbox, index_store, build_system, bench_path)

    clean_s, code, output = run_cmd(cmd)
    result = {
        "label": label,
        "jobs": jobs,
        "sandbox": sandbox,
        "index_store": index_store,
        "build_system": build_system,
        "clean_s": round(clean_s, 3),
        "rebuild_s_avg": None,
        "rebuild_s_min": None,
    }
    if code != 0:
        result["error"] = output.strip()
        return result

    bin_path = show_bin_path(config, build_system, bench_path)
    if not bin_path:
        result["error"] = "Failed to resolve bin path"
        return result
    executable = Path(bin_path) / app_name
    if not executable.exists():
        result["error"] = f"Executable missing after clean build: {executable}"
        return result

    rebuild_times = []
    for _ in range(iterations):
        touch_file.touch()
        rebuild_s, code, output = run_cmd(cmd)
        if code != 0:
            result["error"] = output.strip()
            return result
        if not executable.exists():
            result["error"] = f"Executable missing after rebuild: {executable}"
            return result
        rebuild_times.append(rebuild_s)

    rebuild_avg = sum(rebuild_times) / len(rebuild_times)
    result["rebuild_s_avg"] = round(rebuild_avg, 3)
    result["rebuild_s_min"] = round(min(rebuild_times), 3)
    return result


def is_faster(candidate, reference):
    if not candidate or candidate.get("error") or reference.get("error"):
        return False
    return candidate["rebuild_s_avg"] < reference["rebuild_s_avg"]


def main():
    parser = argparse.ArgumentParser(description="Benchmark SwiftPM build options for OllamaBot.")
    parser.add_argument("--config", choices=["debug", "release"], default="debug")
    parser.add_argument("--iterations", type=int, default=1)
    parser.add_argument("--touch", default="")
    parser.add_argument("--bench-path", default="")
    parser.add_argument("--save", action="store_true")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    project_dir = script_dir.parent
    app_name = "OllamaBot"

    bench_path = Path(args.bench_path) if args.bench_path else project_dir / ".build-bench"
    results_dir = project_dir / "benchmark_results"
    results_dir.mkdir(parents=True, exist_ok=True)

    touch_file = Path(args.touch) if args.touch else project_dir / "Sources" / "OllamaBotApp.swift"
    if not touch_file.exists():
        sources_dir = project_dir / "Sources"
        swift_files = list(sources_dir.rglob("*.swift"))
        if not swift_files:
            print("No Swift files found to touch for rebuild benchmark.", file=sys.stderr)
            sys.exit(1)
        touch_file = swift_files[0]

    machine = platform.machine()
    build_dir_name = f"{machine}-apple-macosx"

    physical = sysctl_int("hw.physicalcpu") or 1
    logical = sysctl_int("hw.logicalcpu") or physical
    perf = sysctl_int("hw.perflevel0.physicalcpu") or physical
    eff = sysctl_int("hw.perflevel1.physicalcpu") or 0
    mem_bytes = sysctl_int("hw.memsize") or 0

    candidates = [perf, physical]
    if logical > physical:
        candidates.append(logical)
    if physical >= 8:
        candidates.append(max(1, physical - 2))
    if physical <= 4:
        candidates.append(physical + 2)
    candidates = sorted({c for c in candidates if c > 0})

    print("OllamaBot Build Benchmark")
    print(f"  CPU: physical={physical}, logical={logical}, perf={perf}, eff={eff}")
    if mem_bytes:
        print(f"  RAM: {mem_bytes // (1024**3)} GB")
    print(f"  Candidates (jobs): {candidates}")
    print(f"  Config: {args.config} | Iterations: {args.iterations}")
    print(f"  Touch file: {touch_file}")
    print(f"  Bench path: {bench_path}")
    print("")

    results = []
    cache = {}

    def get_result(label, jobs, sandbox, index_store, build_system, allow_failure=False):
        key = (jobs, sandbox, index_store, build_system)
        if key in cache:
            return cache[key]
        res = evaluate_build(
            label=label,
            app_name=app_name,
            config=args.config,
            jobs=jobs,
            sandbox=sandbox,
            index_store=index_store,
            build_system=build_system,
            bench_path=bench_path,
            build_dir_name=build_dir_name,
            touch_file=touch_file,
            iterations=args.iterations,
        )
        cache[key] = res
        results.append(res)
        if res.get("error") and not allow_failure:
            print(f"Build failed for {label}. Output:\n{res['error']}", file=sys.stderr)
            sys.exit(1)
        return res

    base_jobs = perf
    baseline = get_result("baseline", base_jobs, "on", "auto", "native")

    sandbox_off = get_result("sandbox_off", base_jobs, "off", "auto", "native")
    sandbox_choice = "off" if is_faster(sandbox_off, baseline) else "on"
    sandbox_ref = sandbox_off if sandbox_choice == "off" else baseline

    build_next = get_result(
        "build_system_next",
        base_jobs,
        sandbox_choice,
        "auto",
        "next",
        allow_failure=True,
    )
    build_system_choice = "next" if is_faster(build_next, sandbox_ref) else "native"
    build_ref = build_next if build_system_choice == "next" else sandbox_ref

    index_disable = get_result(
        "index_store_disable",
        base_jobs,
        sandbox_choice,
        "disable",
        build_system_choice,
    )
    index_choice = "disable" if is_faster(index_disable, build_ref) else "auto"
    index_ref = index_disable if index_choice == "disable" else build_ref

    job_results = []
    for jobs in candidates:
        res = get_result(
            f"jobs_{jobs}",
            jobs,
            sandbox_choice,
            index_choice,
            build_system_choice,
        )
        if not res.get("error"):
            job_results.append(res)

    best_jobs = base_jobs
    best_job_result = index_ref
    if job_results:
        best_job_result = min(job_results, key=lambda r: r["rebuild_s_avg"])
        best_jobs = best_job_result["jobs"]

    print("Results:")
    for res in results:
        if res.get("error"):
            print(f"  {res['label']}: ERROR")
        else:
            print(
                f"  {res['label']}: clean={res['clean_s']}s "
                f"rebuild={res['rebuild_s_avg']}s "
                f"(jobs={res['jobs']}, sandbox={res['sandbox']}, "
                f"index={res['index_store']}, build={res['build_system']})"
            )
    print("")

    best = {
        "jobs": best_jobs,
        "sandbox": sandbox_choice,
        "index_store": index_choice,
        "build_system": build_system_choice,
        "rebuild_s_avg": best_job_result.get("rebuild_s_avg"),
    }
    print("Best options:")
    print(
        f"  jobs={best['jobs']}, sandbox={best['sandbox']}, "
        f"index_store={best['index_store']}, build_system={best['build_system']}"
    )

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    report = {
        "timestamp": timestamp,
        "config": args.config,
        "iterations": args.iterations,
        "project_dir": str(project_dir),
        "bench_path": str(bench_path),
        "touch_file": str(touch_file),
        "hardware": {
            "machine": machine,
            "physical_cores": physical,
            "logical_cores": logical,
            "perf_cores": perf,
            "efficiency_cores": eff,
            "mem_bytes": mem_bytes,
        },
        "jobs_candidates": candidates,
        "tests": results,
        "best": best,
    }

    report_path = results_dir / f"build-benchmark-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}.json"
    with report_path.open("w") as f:
        json.dump(report, f, indent=2)
    latest_path = results_dir / "build-benchmark-latest.json"
    shutil.copyfile(report_path, latest_path)

    if args.save:
        config_dir = Path.home() / ".config" / "ollamabot"
        config_dir.mkdir(parents=True, exist_ok=True)
        config_path = config_dir / "build.conf"
        with config_path.open("w") as f:
            f.write("# Autogenerated by scripts/benchmark-build.py\n")
            f.write(f'BUILD_JOBS={best_jobs}\n')
            f.write(f'BUILD_DISABLE_SANDBOX={"1" if sandbox_choice == "off" else "0"}\n')
            f.write(f'BUILD_DISABLE_INDEX_STORE={"1" if index_choice == "disable" else "0"}\n')
            f.write(f'BUILD_SYSTEM="{build_system_choice}"\n')
            f.write(f'BUILD_BENCHMARK_AT="{timestamp}"\n')
            f.write(f'BUILD_BENCHMARK_MACHINE="{machine}"\n')
            f.write(f'BUILD_BENCHMARK_CPU_PHYSICAL={physical}\n')
            f.write(f'BUILD_BENCHMARK_CPU_PERF={perf}\n')
            f.write(f'BUILD_BENCHMARK_CPU_EFFICIENCY={eff}\n')
        print(f"\nSaved build config: {config_path}")

    print(f"Saved report: {report_path}")


if __name__ == "__main__":
    main()
