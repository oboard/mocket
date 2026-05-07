#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH_ROOT = ROOT / "benchmarks"

ROUTES = {
    "plaintext": "/plaintext",
    "json": "/json",
    "echo": "/echo/moonbit",
}


@dataclass(frozen=True)
class Target:
    name: str
    cwd: Path
    start: list[str]
    prepare: tuple[tuple[str, ...], ...] = ()


TARGETS = {
    "mocket": Target(
        "mocket",
        ROOT,
        ["moon", "run", "--release", "--target", "native", "benchmarks/mocket"],
        (("moon", "build", "--release", "--target", "native", "benchmarks/mocket"),),
    ),
    "nodejs": Target("nodejs", BENCH_ROOT / "nodejs", ["node", "server.mjs"]),
    "bun": Target("bun", BENCH_ROOT / "bun", ["bun", "server.js"]),
    "deno": Target(
        "deno",
        BENCH_ROOT / "deno",
        ["deno", "run", "--allow-net", "--allow-env", "server.ts"],
    ),
    "gin": Target(
        "gin",
        BENCH_ROOT / "gin",
        ["go", "run", "."],
        (("go", "mod", "tidy"),),
    ),
    "axum": Target(
        "axum",
        BENCH_ROOT / "axum",
        ["cargo", "run", "--release", "--quiet"],
        (("cargo", "fetch"), ("cargo", "build", "--release")),
    ),
    "springboot": Target(
        "springboot",
        BENCH_ROOT / "springboot",
        ["java", "-jar", "target/mocket-benchmark-springboot-0.1.0.jar"],
        (("mvn", "-q", "-DskipTests", "package"),),
    ),
    "hono": Target(
        "hono",
        BENCH_ROOT / "hono",
        ["node", "server.mjs"],
        (("npm", "install"),),
    ),
    "nitro": Target(
        "nitro",
        BENCH_ROOT / "nitro",
        ["node", ".output/server/index.mjs"],
        (("npm", "install"), ("npm", "run", "build"),),
    ),
    "php": Target(
        "php",
        BENCH_ROOT / "php",
        ["php", "-S", "0.0.0.0:{port}", "index.php"],
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Mocket HTTP benchmarks.")
    parser.add_argument("targets", nargs="*", choices=sorted(TARGETS))
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--tool", choices=["auto", "oha", "autocannon"], default="auto")
    parser.add_argument("--duration", type=int, default=10)
    parser.add_argument("--warmup", type=int, default=2)
    parser.add_argument("--connections", type=int, default=100)
    parser.add_argument("--port", type=int, default=3000)
    parser.add_argument("--routes", nargs="+", choices=sorted(ROUTES), default=list(ROUTES))
    parser.add_argument("--results-dir", type=Path, default=BENCH_ROOT / "results")
    args = parser.parse_args()

    tool = select_tool(args.tool)
    targets = args.targets or list(TARGETS)
    args.results_dir.mkdir(parents=True, exist_ok=True)

    summary = {
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "tool": tool,
        "duration": args.duration,
        "connections": args.connections,
        "results": [],
    }

    for target_name in targets:
        target = TARGETS[target_name]
        if not command_exists(target.start[0]):
            message = f"missing command {target.start[0]}"
            print(f"skip {target.name}: {message}", file=sys.stderr)
            summary["results"].append({ "target": target.name, "error": message })
            continue
        if args.prepare and not run_prepare(target):
            message = "prepare failed or skipped"
            summary["results"].append({ "target": target.name, "error": message })
            continue

        proc = None
        try:
            proc = start_server(target, args.port)
            base_url = f"http://127.0.0.1:{args.port}"
            wait_until_ready(base_url + "/plaintext", proc)
            for route_name in args.routes:
                url = base_url + ROUTES[route_name]
                if args.warmup > 0:
                    run_load(tool, url, args.warmup, args.connections, discard=True)
                result = run_load(tool, url, args.duration, args.connections)
                result_file = write_result(
                    args.results_dir,
                    target.name,
                    route_name,
                    tool,
                    result,
                )
                summary["results"].append({
                    "target": target.name,
                    "route": route_name,
                    "url": url,
                    "file": str(result_file.relative_to(ROOT)),
                })
                print(f"{target.name} {route_name}: {result_file}")
        except Exception as exc:
            print(f"error {target.name}: {exc}", file=sys.stderr)
            summary["results"].append({
                "target": target.name,
                "error": str(exc),
            })
        finally:
            if proc is not None:
                stop_server(proc)

    summary_file = args.results_dir / "summary.json"
    summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"summary: {summary_file}")
    return 0


def command_exists(command: str) -> bool:
    return shutil.which(command) is not None


def run_prepare(target: Target) -> bool:
    for command in target.prepare:
        if not command_exists(command[0]):
            print(f"skip {target.name}: missing prepare command {command[0]}", file=sys.stderr)
            return False
        print(f"prepare {target.name}: {' '.join(command)}")
        subprocess.run(command, cwd=target.cwd, check=True)
    return True


def select_tool(requested: str) -> str:
    if requested != "auto":
        if requested == "oha" and not command_exists("oha"):
            raise SystemExit("oha is not installed")
        if requested == "autocannon" and not (command_exists("npx") or command_exists("autocannon")):
            raise SystemExit("autocannon or npx is not installed")
        return requested
    if command_exists("oha"):
        return "oha"
    if command_exists("autocannon") or command_exists("npx"):
        return "autocannon"
    raise SystemExit("Install oha or provide autocannon/npx before running benchmarks")


def start_server(target: Target, port: int) -> subprocess.Popen:
    env = os.environ.copy()
    env["PORT"] = str(port)
    command = [part.format(port=port) for part in target.start]
    return subprocess.Popen(
        command,
        cwd=target.cwd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        preexec_fn=os.setsid if hasattr(os, "setsid") else None,
    )


def stop_server(proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    if hasattr(os, "killpg"):
        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    else:
        proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()


def wait_until_ready(url: str, proc: subprocess.Popen) -> None:
    deadline = time.time() + 30
    last_error = None
    while time.time() < deadline:
        if proc.poll() is not None:
            output = proc.stdout.read() if proc.stdout else ""
            raise RuntimeError(f"server exited early with code {proc.returncode}\n{output}")
        try:
            with urllib.request.urlopen(url, timeout=1) as response:
                if response.status == 200:
                    return
        except Exception as exc:
            last_error = exc
        time.sleep(0.2)
    raise TimeoutError(f"server did not become ready at {url}: {last_error}")


def run_load(tool: str, url: str, duration: int, connections: int, discard: bool = False) -> str:
    if tool == "oha":
        command = ["oha", "--json", "-z", f"{duration}s", "-c", str(connections), url]
    elif command_exists("autocannon"):
        command = ["autocannon", "-j", "-d", str(duration), "-c", str(connections), url]
    else:
        command = ["npx", "-y", "autocannon", "-j", "-d", str(duration), "-c", str(connections), url]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return "" if discard else result.stdout


def write_result(results_dir: Path, target: str, route: str, tool: str, output: str) -> Path:
    stamp = time.strftime("%Y%m%d-%H%M%S", time.gmtime())
    path = results_dir / f"{stamp}-{target}-{route}-{tool}.json"
    path.write_text(output)
    return path


if __name__ == "__main__":
    raise SystemExit(main())
