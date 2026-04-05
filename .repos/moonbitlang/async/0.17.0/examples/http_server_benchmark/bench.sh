#!/bin/bash

set -e

moon build -C examples
go build -o examples/_build/http_server_benchmark_go examples/http_server_benchmark/http_server_benchmark.go

server=./examples/_build/native/release/build/http_server_benchmark/http_server_benchmark.exe

run_moonbit() {
  $server &
  server_pid=$!
  trap "kill $server_pid; exit" INT
  sleep 0.5
  wrk $* http://127.0.0.1:3001/
  kill $server_pid
}

run_node() {
  node examples/http_server_benchmark/http_server_benchmark.js &
  server_pid=$!
  trap "kill $server_pid; exit" INT
  sleep 0.5
  wrk $* http://127.0.0.1:3002/
  kill $server_pid
}

run_go() {
  GOMAXPROCS=1 ./examples/_build/http_server_benchmark_go &
  server_pid=$!
  trap "kill $server_pid; exit" INT
  sleep 0.5
  wrk $* http://127.0.0.1:3003/
  kill $server_pid
}

if [ "$1" == "--moonbit-only" ]; then
  moonbit_only="true"
  shift 1
fi

for n in 64 128 256; do
  echo "====== $n parallel connection ======"
  echo "moonbit:"
  ( run_moonbit -t 8 -d 15 -c $n )
  if [ "$moonbit_only" != "true" ]; then
    echo "nodejs:"
    ( run_node -t 8 -d 15 -c $n )
    echo "Go (GOMAXPROCS=1):"
    ( run_go -t 8 -d 15 -c $n )
  fi
done
