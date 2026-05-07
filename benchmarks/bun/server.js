const port = Number.parseInt(Bun.env.PORT ?? "3000", 10);

Bun.serve({
  hostname: "0.0.0.0",
  port,
  async fetch(request) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/plaintext") {
      return new Response("Hello, World!", {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    if (request.method === "GET" && url.pathname === "/json") {
      return Response.json({ message: "Hello, World!" });
    }

    if (request.method === "GET" && url.pathname.startsWith("/echo/")) {
      return new Response(
        decodeURIComponent(url.pathname.slice("/echo/".length)) || "World",
        { headers: { "content-type": "text/plain; charset=utf-8" } },
      );
    }

    if (request.method === "POST" && url.pathname === "/echo") {
      return new Response(request.body, {
        headers: { "content-type": "application/octet-stream" },
      });
    }

    return new Response("Not Found", { status: 404 });
  },
});

console.log(`bun benchmark server listening on ${port}`);
