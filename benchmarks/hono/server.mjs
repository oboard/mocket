import { serve } from "@hono/node-server";
import { Hono } from "hono";

const port = Number.parseInt(process.env.PORT ?? "3000", 10);
const app = new Hono();

app.use("/middleware/*", async (_c, next) => {
  await next();
});
app.get("/middleware/plaintext", (c) => c.text("Hello, World!"));
for (let i = 0; i < 1000; i += 1) {
  app.get(`/static/${i}`, (c) => c.text("Hello, World!"));
}
app.get("/plaintext", (c) => c.text("Hello, World!"));
app.get("/api/plaintext", (c) => c.text("Hello, World!"));
app.get("/api/v1/users/current/profile/settings", (c) => c.text("settings"));
app.get("/json", (c) => c.json({ message: "Hello, World!" }));
app.get("/echo/:name", (c) => c.text(c.req.param("name") || "World"));
app.get("/users/:userID/posts/:postID/comments/:commentID", (c) =>
  c.text(c.req.param("commentID") || ""),
);
app.get("/wild/*", (c) => c.text(c.req.path.slice("/wild/".length)));
app.get("/query", (c) => c.text(c.req.query("name") || "moonbit"));
app.get("/headers", (c) => {
  c.header("x-benchmark", "hono");
  return c.text("ok");
});
app.post("/echo", async (c) => {
  return new Response(c.req.raw.body, {
    headers: { "content-type": "application/octet-stream" },
  });
});
app.post("/json-echo", async (c) => {
  return new Response(c.req.raw.body, {
    headers: { "content-type": "application/json; charset=utf-8" },
  });
});
app.post("/consume", async (c) => {
  await c.req.arrayBuffer();
  return c.text("ok");
});

serve({ fetch: app.fetch, hostname: "0.0.0.0", port }, () => {
  console.log(`hono benchmark server listening on ${port}`);
});
