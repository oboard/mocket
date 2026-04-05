package main

import (
  "net"
  "log"
)

func main() {
  l, err := net.Listen("tcp", "0.0.0.0:4202")
  if err != nil {
    log.Panicln(err)
  }
  defer l.Close()

  for {
    conn, err := l.Accept()
    if err != nil {
      log.Panicln(err)
    }

    go handleRequest(conn)
  }
}

func handleRequest(conn net.Conn) {
  defer conn.Close()

  buf := make([]byte, 1024)
  for {
    size, err := conn.Read(buf)
    if err != nil {
      return
    }
    conn.Write(buf[:size])
  }
}
