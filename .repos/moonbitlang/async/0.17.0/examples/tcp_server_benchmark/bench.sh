set -e

moon build -C examples
go build -o examples/_build/tcp_echo_server_go examples/tcp_echo_server/tcp_echo_server.go

server=./examples/_build/native/release/build/tcp_echo_server/tcp_echo_server.exe
client=./examples/_build/native/release/build/tcp_server_benchmark/tcp_server_benchmark.exe

run_moonbit() {
  $server &
  server_pid=$!
  trap "kill $server_pid; exit" INT
  sleep 0.5
  $client $* 127.0.0.1:4200
  kill $server_pid
}

run_node() {
  node examples/tcp_echo_server/tcp_echo_server.js &
  server_pid=$!
  trap "kill $server_pid; exit" INT
  sleep 0.5
  $client $* 127.0.0.1:4201
  kill $server_pid
}

run_go() {
  ./examples/_build/tcp_echo_server_go &
  server_pid=$!
  trap "kill $server_pid; exit" INT
  sleep 0.5
  $client $* 127.0.0.1:4202
  kill $server_pid
}

suite=$1
if [ "$suite" != "" ]; then
  shift 1
fi
if [ "$1" == "--moonbit-only" ]; then
  moonbit_only="true"
  shift 1
fi

for n in 1 5 10 20 50 100 200 500 1000; do
  echo "====== $n parallel connection ======"
  echo "moonbit:"
  ( run_moonbit -max-concurrent $n -total-conn $((n * 10)) -conn-duration 500 )
  if [ "$moonbit_only" != "true" ]; then
    echo "nodejs:"
    ( run_node -max-concurrent $n -total-conn $((n * 10)) -conn-duration 500 )
    echo "Go:"
    ( run_go -max-concurrent $n -total-conn $((n * 10)) -conn-duration 500 )
  fi
done
