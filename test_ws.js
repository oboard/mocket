const ws = new WebSocket("ws://localhost:8080/ws");
ws.addEventListener("open", () => {
  console.log("connected");
  ws.send("hello mocket");
  console.log("sent");

  // binary test
  const buffer = Buffer.from([0x01, 0x02, 0x03, 0x04]);
  ws.send(buffer);
  console.log("sent binary");
});
ws.addEventListener("message", (ev) => {
  console.log("msg:", ev.data);
  ws.close();
});
ws.addEventListener("close", () => console.log("closed"));
ws.addEventListener("error", (err) => console.log("error", err));
ws.addEventListener("pong", () => console.log("received pong"));
