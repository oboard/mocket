const port = Number.parseInt(Bun.env.PORT ?? "3000", 10);
const manyRoutes = new Set(Array.from({ length: 1000 }, (_, i) => `/static/${i}`));

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

    if (request.method === "GET" && url.pathname === "/api/plaintext") {
      return new Response("Hello, World!", {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    if (
      request.method === "GET" &&
      url.pathname === "/api/v1/users/current/profile/settings"
    ) {
      return new Response("settings", {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    if (request.method === "GET" && manyRoutes.has(url.pathname)) {
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

    const multiParamMatch = url.pathname.match(
      /^\/users\/([^/]+)\/posts\/([^/]+)\/comments\/([^/]+)$/,
    );
    if (request.method === "GET" && multiParamMatch) {
      return new Response(decodeURIComponent(multiParamMatch[3]), {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    if (request.method === "GET" && url.pathname.startsWith("/wild/")) {
      return new Response(
        decodeURIComponent(url.pathname.slice("/wild/".length)),
        { headers: { "content-type": "text/plain; charset=utf-8" } },
      );
    }

    if (request.method === "GET" && url.pathname === "/query") {
      return new Response(url.searchParams.get("name") || "moonbit", {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    if (request.method === "GET" && url.pathname === "/headers") {
      return new Response("ok", {
        headers: {
          "content-type": "text/plain; charset=utf-8",
          "x-benchmark": "bun",
        },
      });
    }

    if (request.method === "POST" && url.pathname === "/echo") {
      return new Response(request.body, {
        headers: { "content-type": "application/octet-stream" },
      });
    }

    if (request.method === "POST" && url.pathname === "/json-echo") {
      return new Response(request.body, {
        headers: { "content-type": "application/json; charset=utf-8" },
      });
    }

    if (request.method === "POST" && url.pathname === "/consume") {
      await request.arrayBuffer();
      return new Response("ok", {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    return new Response("Not Found", { status: 404 });
  },
});

console.log(`bun benchmark server listening on ${port}`);
