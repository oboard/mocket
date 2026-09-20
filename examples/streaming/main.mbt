///|
/// A response body that writes each chunk directly to Mocket's response writer.
struct EventStream {
  messages : Array[String]
}

///|
fn EventStream::EventStream(messages : Array[String]) -> EventStream {
  { messages, }
}

///|
async fn EventStream::write_response(
  self : EventStream,
  writer : &@io.Writer,
) -> Unit {
  for index, message in self.messages {
    writer.write("data: message \{index + 1}: \{message}\n\n")
    @async.sleep(1000)
  }
  writer.write("event: done\ndata: stream finished\n\n")
}

///|
impl @mocket.Responder for EventStream with fn options(_, response) -> Unit {
  response.headers["Content-Type"] = "text/event-stream; charset=utf-8"
  response.headers["Cache-Control"] = "no-cache"
  response.headers["Connection"] = "keep-alive"
}

///|
impl @mocket.Responder for EventStream with fn output(self, writer) {
  self.write_response(writer)
}

///|
async fn main {
  let app = @mocket.App()
  app.get("/events", _ => EventStream([ for i in 0..<=10 => "message \{i}" ]))
  app.get("/", _ => {
    @mocket.html(
      (
        #|<!doctype html>
        #|<html>
        #|  <body>
        #|    <pre id="events">Connecting…</pre>
        #|    <script>
        #|      const output = document.getElementById("events");
        #|      const stream = new EventSource("/events");
        #|      stream.onmessage = (event) => output.textContent += `\n${event.data}`;
        #|      stream.addEventListener("done", (event) => {
        #|        output.textContent += `\n${event.data}`;
        #|        stream.close();
        #|      });
        #|    </script>
        #|  </body>
        #|</html>
      ),
    )
  })

  println("Open http://localhost:4000 for a Server-Sent Events stream.")
  app.listen("0.0.0.0:4000")
}
