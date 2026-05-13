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
    "plaintext": {
        "method": "GET",
        "path": "/plaintext",
        "description": "static text response",
    },
    "api_plaintext": {
        "method": "GET",
        "path": "/api/plaintext",
        "description": "static text response behind /api middleware path",
    },
    "middleware_plaintext": {
        "method": "GET",
        "path": "/middleware/plaintext",
        "description": "text response through a real middleware stack",
        "targets": ["mocket", "gin", "axum", "hono"],
        "target_overrides": { "mocket": "mocket-middleware" },
    },
    "deep_static": {
        "method": "GET",
        "path": "/api/v1/users/current/profile/settings",
        "description": "deep static route",
    },
    "many_routes": {
        "method": "GET",
        "path": "/static/999",
        "description": "lookup in a router with 1000 registered static routes",
    },
    "json": {
        "method": "GET",
        "path": "/json",
        "description": "small JSON response",
    },
    "echo": {
        "method": "GET",
        "path": "/echo/moonbit",
        "description": "single path parameter",
    },
    "multi_param": {
        "method": "GET",
        "path": "/users/42/posts/99/comments/7",
        "description": "multiple path parameters",
    },
    "wildcard": {
        "method": "GET",
        "path": "/wild/a/b/c/d",
        "description": "multi-segment wildcard route",
    },
    "query": {
        "method": "GET",
        "path": "/query?name=moonbit&repeat=4",
        "description": "routing with query string",
    },
    "headers": {
        "method": "GET",
        "path": "/headers",
        "description": "response header mutation",
    },
    "notfound": {
        "method": "GET",
        "path": "/missing",
        "description": "404 route miss",
        "expected_status": 404,
    },
    "post_small": {
        "method": "POST",
        "path": "/echo",
        "body": "hello moonbit",
        "headers": ["content-type: text/plain; charset=utf-8"],
        "description": "small request body echo",
    },
    "post_json": {
        "method": "POST",
        "path": "/json-echo",
        "body": "{\"message\":\"Hello, World!\",\"items\":[1,2,3,4]}",
        "headers": ["content-type: application/json; charset=utf-8"],
        "description": "JSON request body echo",
    },
    "post_large": {
        "method": "POST",
        "path": "/echo",
        "body": "x" * 16384,
        "headers": ["content-type: text/plain; charset=utf-8"],
        "description": "16 KiB request body echo",
    },
    "post_consume": {
        "method": "POST",
        "path": "/consume",
        "body": "x" * 16384,
        "headers": ["content-type: text/plain; charset=utf-8"],
        "description": "16 KiB request body consumed with a tiny response",
    },
}

ROUTE_SUITES = {
    "quick": ["plaintext", "json", "echo"],
    "routing": [
        "plaintext",
        "deep_static",
        "many_routes",
        "echo",
        "multi_param",
        "wildcard",
        "query",
        "notfound",
    ],
    "body": ["post_small", "post_json", "post_large", "post_consume"],
    "middleware": ["middleware_plaintext"],
    "comprehensive": [
        "plaintext",
        "middleware_plaintext",
        "deep_static",
        "many_routes",
        "json",
        "echo",
        "multi_param",
        "wildcard",
        "query",
        "headers",
        "notfound",
        "post_small",
        "post_json",
        "post_large",
        "post_consume",
    ],
}
ROUTE_SUITES["all"] = list(ROUTES)


@dataclass(frozen=True)
class Target:
    name: str
    cwd: Path
    start: list[str]
    prepare: tuple[tuple[str, ...], ...] = ()
    public: bool = True


TARGETS = {
    "mocket": Target(
        "mocket",
        ROOT,
        ["moon", "run", "--release", "--target", "native", "benchmarks/mocket"],
        (("moon", "build", "--release", "--target", "native", "benchmarks/mocket"),),
    ),
    "mocket-middleware": Target(
        "mocket-middleware",
        ROOT,
        ["moon", "run", "--release", "--target", "native", "benchmarks/mocket_middleware"],
        (
            (
                "moon",
                "build",
                "--release",
                "--target",
                "native",
                "benchmarks/mocket_middleware",
            ),
        ),
        False,
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
    parser.add_argument("targets", nargs="*", choices=sorted(public_targets()))
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--tool", choices=["auto", "oha", "autocannon"], default="auto")
    parser.add_argument("--duration", type=int, default=10)
    parser.add_argument("--warmup", type=int, default=2)
    parser.add_argument("--connections", type=int, default=100)
    parser.add_argument("--port", type=int, default=3000)
    parser.add_argument(
        "--suite",
        choices=sorted(ROUTE_SUITES),
        default="quick",
        help="Named route suite to run when --routes is not provided.",
    )
    parser.add_argument(
        "--routes",
        nargs="+",
        choices=sorted(ROUTES) + ["all"],
        default=None,
    )
    parser.add_argument("--results-dir", type=Path, default=BENCH_ROOT / "results")
    args = parser.parse_args()

    tool = select_tool(args.tool)
    targets = args.targets or public_targets()
    routes = selected_routes(args.routes, args.suite)
    plan = build_run_plan(targets, routes)
    args.results_dir.mkdir(parents=True, exist_ok=True)

    run_id = time.strftime("%Y%m%d-%H%M%S", time.gmtime())
    summary = {
        "run_id": run_id,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "tool": tool,
        "suite": args.suite if args.routes is None else "custom",
        "routes": routes,
        "duration": args.duration,
        "connections": args.connections,
        "results": [],
    }

    for run in plan:
        target = TARGETS[run["execute_target"]]
        if not command_exists(target.start[0]):
            message = f"missing command {target.start[0]}"
            print(f"skip {target.name}: {message}", file=sys.stderr)
            summary["results"].append({
                "target": run["report_target"],
                "execute_target": target.name,
                "error": message,
            })
            continue
        if args.prepare and not run_prepare(target):
            message = "prepare failed or skipped"
            summary["results"].append({
                "target": run["report_target"],
                "execute_target": target.name,
                "error": message,
            })
            continue

        proc = None
        try:
            proc = start_server(target, args.port)
            base_url = f"http://127.0.0.1:{args.port}"
            wait_until_ready(base_url + "/plaintext", proc)
            for route_name in run["routes"]:
                case = ROUTES[route_name]
                url = base_url + case["path"]
                if args.warmup > 0:
                    run_load(
                        tool,
                        url,
                        args.warmup,
                        args.connections,
                        case,
                        discard=True,
                    )
                result = run_load(tool, url, args.duration, args.connections, case)
                result_file = write_result(
                    args.results_dir,
                    target.name,
                    route_name,
                    tool,
                    result,
                )
                summary["results"].append({
                    "target": run["report_target"],
                    "execute_target": target.name,
                    "route": route_name,
                    "method": case["method"],
                    "url": url,
                    "expected_status": case.get("expected_status", 200),
                    "file": display_path(result_file),
                })
                print(f"{run['report_target']} {route_name}: {result_file}")
        except Exception as exc:
            print(f"error {target.name}: {exc}", file=sys.stderr)
            summary["results"].append({
                "target": run["report_target"],
                "execute_target": target.name,
                "error": str(exc),
            })
        finally:
            if proc is not None:
                stop_server(proc)

    summary_file = args.results_dir / f"{run_id}-summary.json"
    summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    (args.results_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"summary: {summary_file}")
    return 0


def command_exists(command: str) -> bool:
    return shutil.which(command) is not None


def public_targets() -> list[str]:
    return [name for name, target in TARGETS.items() if target.public]


def build_run_plan(targets: list[str], routes: list[str]) -> list[dict]:
    planned: list[dict] = []
    by_pair: dict[tuple[str, str], list[str]] = {}
    for target_name in targets:
        for route_name in routes:
            case = ROUTES[route_name]
            supported_targets = case.get("targets")
            if supported_targets is not None and target_name not in supported_targets:
                continue
            execute_target = case.get("target_overrides", {}).get(target_name, target_name)
            key = (target_name, execute_target)
            by_pair.setdefault(key, []).append(route_name)
    for (report_target, execute_target), route_names in by_pair.items():
        planned.append({
            "report_target": report_target,
            "execute_target": execute_target,
            "routes": route_names,
        })
    return planned


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


def selected_routes(routes: list[str] | None, suite: str) -> list[str]:
    if routes is None:
        return ROUTE_SUITES[suite]
    if "all" in routes:
        return ROUTE_SUITES["all"]
    return routes


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


def run_load(
    tool: str,
    url: str,
    duration: int,
    connections: int,
    case: dict,
    discard: bool = False,
) -> str:
    method = case["method"]
    body = case.get("body")
    headers = case.get("headers", [])
    if tool == "oha":
        command = [
            "oha",
            "--json",
            "-z",
            f"{duration}s",
            "-c",
            str(connections),
            "-m",
            method,
        ]
        for header in headers:
            command.extend(["-H", header])
        if body is not None:
            command.extend(["-d", body])
        command.append(url)
    elif command_exists("autocannon"):
        command = autocannon_command(
            "autocannon",
            url,
            duration,
            connections,
            method,
            body,
            headers,
        )
    else:
        command = autocannon_command(
            "npx",
            url,
            duration,
            connections,
            method,
            body,
            headers,
            via_npx=True,
        )
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return "" if discard else result.stdout


def autocannon_command(
    command: str,
    url: str,
    duration: int,
    connections: int,
    method: str,
    body: str | None,
    headers: list[str],
    via_npx: bool = False,
) -> list[str]:
    args = [command]
    if via_npx:
        args.extend(["-y", "autocannon"])
    args.extend([
        "-j",
        "-d",
        str(duration),
        "-c",
        str(connections),
        "-m",
        method,
    ])
    for header in headers:
        args.extend(["-H", header])
    if body is not None:
        args.extend(["-b", body])
    args.append(url)
    return args


def write_result(results_dir: Path, target: str, route: str, tool: str, output: str) -> Path:
    stamp = time.strftime("%Y%m%d-%H%M%S", time.gmtime())
    path = results_dir / f"{stamp}-{target}-{route}-{tool}.json"
    path.write_text(output)
    return path


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


if __name__ == "__main__":
    raise SystemExit(main())
