import http from "node:http";

const port = Number.parseInt(process.env.PORT ?? "3000", 10);
const manyRoutes = new Set(Array.from({ length: 1000 }, (_, i) => `/static/${i}`));

const server = http.createServer((req, res) => {
  const url = new URL(req.url ?? "/", "http://127.0.0.1");

  if (req.method === "GET" && url.pathname === "/plaintext") {
    res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
    res.end("Hello, World!");
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/plaintext") {
    res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
    res.end("Hello, World!");
    return;
  }

  if (
    req.method === "GET" &&
    url.pathname === "/api/v1/users/current/profile/settings"
  ) {
    res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
    res.end("settings");
    return;
  }

  if (req.method === "GET" && manyRoutes.has(url.pathname)) {
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

  const multiParamMatch = url.pathname.match(
    /^\/users\/([^/]+)\/posts\/([^/]+)\/comments\/([^/]+)$/,
  );
  if (req.method === "GET" && multiParamMatch) {
    res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
    res.end(decodeURIComponent(multiParamMatch[3]));
    return;
  }

  if (req.method === "GET" && url.pathname.startsWith("/wild/")) {
    res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
    res.end(decodeURIComponent(url.pathname.slice("/wild/".length)));
    return;
  }

  if (req.method === "GET" && url.pathname === "/query") {
    res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
    res.end(url.searchParams.get("name") || "moonbit");
    return;
  }

  if (req.method === "GET" && url.pathname === "/headers") {
    res.writeHead(200, {
      "content-type": "text/plain; charset=utf-8",
      "x-benchmark": "nodejs",
    });
    res.end("ok");
    return;
  }

  if (req.method === "POST" && url.pathname === "/echo") {
    res.writeHead(200, { "content-type": "application/octet-stream" });
    req.pipe(res);
    return;
  }

  if (req.method === "POST" && url.pathname === "/json-echo") {
    res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
    req.pipe(res);
    return;
  }

  if (req.method === "POST" && url.pathname === "/consume") {
    req.resume();
    req.on("end", () => {
      res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
      res.end("ok");
    });
    return;
  }

  res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
  res.end("Not Found");
});

server.listen(port, "0.0.0.0", () => {
  console.log(`nodejs benchmark server listening on ${port}`);
});
