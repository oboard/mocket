///|
fn main {
  let app = @crescent.Mocket::new()
  app.ws("/ws", event => {
    match event {
      Open(peer) => println("WS open: " + peer.to_string())
      Message(peer, msg) =>
        match msg {
          Text(s) => {
            println("WS message: " + s)
            peer.text(s)
          }
          Binary(bytes) => {
            println("WS binary: " + bytes.length().to_string() + " bytes")
            peer.binary(bytes)
          }
        }
      Close(peer) => println("WS close: " + peer.to_string())
    }
  })
  println("WebSocket echo server listening on ws://localhost:8080/ws")
  app.serve_blocking(port=8080)
}
