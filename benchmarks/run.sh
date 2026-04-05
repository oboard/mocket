#!/bin/bash
set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REQUESTS=10000
CONCURRENCY=100

# Bypass any HTTP proxy for local benchmarking
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY

echo "=========================================="
echo "  Mocket vs Node.js Benchmark"
echo "  $REQUESTS requests, $CONCURRENCY concurrent"
echo "=========================================="
echo ""

cleanup() {
  echo "Cleaning up..."
  kill $MOCKET_PID $NODE_PID $EXPRESS_PID 2>/dev/null || true
  wait $MOCKET_PID $NODE_PID $EXPRESS_PID 2>/dev/null || true
}
trap cleanup EXIT

# Build and start Mocket server
echo "[1/3] Building and starting Mocket server..."
cd "$ROOT_DIR"
moon build benchmarks/mocket_bench --target native --release 2>&1 | tail -1
"$ROOT_DIR/_build/native/release/build/benchmarks/mocket_bench/mocket_bench.exe" &
MOCKET_PID=$!

# Start Node.js server
echo "[2/3] Starting Node.js HTTP server..."
node "$SCRIPT_DIR/node_server.js" &
NODE_PID=$!

# Start Express server
echo "[3/3] Starting Express server..."
cd "$ROOT_DIR"
NODE_PATH="$ROOT_DIR/node_modules" node "$SCRIPT_DIR/express_server.js" &
EXPRESS_PID=$!

# Wait for servers to be ready
sleep 3

# Verify servers are running
echo "Verifying servers..."
curl -sf http://127.0.0.1:3001/text > /dev/null && echo "  Mocket: OK" || echo "  Mocket: FAILED"
curl -sf http://127.0.0.1:3002/text > /dev/null && echo "  Node.js: OK" || echo "  Node.js: FAILED"
curl -sf http://127.0.0.1:3003/text > /dev/null && echo "  Express: OK" || echo "  Express: FAILED"
echo ""

HEY="$HOME/go/bin/hey"

run_bench() {
  local label="$1"
  local url="$2"
  echo "--- $label ---"
  $HEY -n $REQUESTS -c $CONCURRENCY -q 100000 "$url" 2>&1 | grep -E "Requests/sec|Total:|Fastest:|Average:|Slowest:|requests done|Status code"
  echo ""
}

echo "=========================================="
echo "  Benchmark 1: Plain Text (GET /text)"
echo "=========================================="
echo ""
run_bench "Mocket (MoonBit)" "http://127.0.0.1:3001/text"
run_bench "Node.js (http)" "http://127.0.0.1:3002/text"
run_bench "Express.js" "http://127.0.0.1:3003/text"

echo "=========================================="
echo "  Benchmark 2: JSON Response (GET /json)"
echo "=========================================="
echo ""
run_bench "Mocket (MoonBit)" "http://127.0.0.1:3001/json"
run_bench "Node.js (http)" "http://127.0.0.1:3002/json"
run_bench "Express.js" "http://127.0.0.1:3003/json"

echo "=========================================="
echo "  Benchmark 3: Dynamic Route (GET /user/42)"
echo "=========================================="
echo ""
run_bench "Mocket (MoonBit)" "http://127.0.0.1:3001/user/42"
run_bench "Node.js (http)" "http://127.0.0.1:3002/user/42"
run_bench "Express.js" "http://127.0.0.1:3003/user/42"

echo "=========================================="
echo "  Benchmark Complete"
echo "=========================================="
