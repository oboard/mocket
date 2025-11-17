///|
fn main {
  let app = @mocket.new(logger=@mocket.new_logger())
  app.ws("/ws", fn(event) {
    match event {
      Open(peer) => println("WS open: " + peer.to_string())
      Message(peer, body) => {
        let msg = match body {
          Text(s) => s.to_string()
          _ => ""
        }
        println("WS message: " + msg)
        peer.send(msg)
      }
      Close(peer) => println("WS close: " + peer.to_string())
    }
  })
  println("WebSocket echo server listening on ws://localhost:8080/ws")
  app.serve(port=8080)
}
