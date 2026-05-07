import http from "node:http";

const port = Number.parseInt(process.env.PORT ?? "3000", 10);

const server = http.createServer((req, res) => {
  const url = new URL(req.url ?? "/", "http://127.0.0.1");

  if (req.method === "GET" && url.pathname === "/plaintext") {
    res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
    res.end("Hello, World!");
    return;
  }

  if (req.method === "GET" && url.pathname === "/json") {
    res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ message: "Hello, World!" }));
    return;
  }

  if (req.method === "GET" && url.pathname.startsWith("/echo/")) {
    res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
    res.end(decodeURIComponent(url.pathname.slice("/echo/".length)) || "World");
    return;
  }

  if (req.method === "POST" && url.pathname === "/echo") {
    res.writeHead(200, { "content-type": "application/octet-stream" });
    req.pipe(res);
    return;
  }

  res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
  res.end("Not Found");
});

server.listen(port, "0.0.0.0", () => {
  console.log(`nodejs benchmark server listening on ${port}`);
});
