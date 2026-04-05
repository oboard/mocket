# Examples for using `moonbitlang/async`

## `line_processing`
A simple command line program that search from specific pattern from a list of files,
similar to `grep`.

You can learn about how to process files/streams line-by-line incrementally from this example.

## `xargs`
A simple command line utility similar to the famous `xargs`,
which run a command multiple times with arguments read from standard input.

From this example, you can learn about:

- basic usage of task group to spawn multiple tasks
- how to spawn foreign process in the background
- how to limit the max number of concurrent tasks using `@async.Semaphore`

## `curl`
A simple command line utility that download the content of a HTTP URL, similar to `curl`.

From this example, you can learn about:

- how to perform HTTP GET request streamingly
- how to use proxy when performing HTTP request

## `cat`
A simple MoonBit program similar to the famous `cat` command line utility.
It echoes the content of input file or standard input to standard output.

You can learn basic stream operations on files/standard input/standard output from this example.

## `http_file_server`
A simple HTTP file server written in MoonBit,
similar to `python -m http.server`,
with the extra functionality of downloading whole directory as a `.zip` archive.

You can learn about:

- how to write a simple HTTP server
- basic file/directory operations
- spawning foreign process and interact with it by redirecting standard input/output

from this example.

## `websocket_echo_server`
A simple WebSocket echo server written in MoonBit.

You can learn about the basis of writting WebSocket servers in MoonBit from this example.
You can also learn about the basis of writting WebSocket client from the test file
`examples/websocket_echo_server/server_test.mbt`.

## `tcp_echo_server`
A simple TCP echo server written in MoonBit.

You can learn about the basic structure of a TCP server in MoonBit from this example.

## `udp_echo_server`
A simple UDP echo server written in MoonBit.

You can learn about the basic structure of a UDP server in MoonBit from this example.

## `idle_timeout`
A simple toy program that exit automatically if the user have not type anything in the terminal for 5 seconds.

You can learn about the pattern of setting up a idle timeout system in MoonBit from this example.
