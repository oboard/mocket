import { serve } from "@hono/node-server";
import { Hono } from "hono";

const port = Number.parseInt(process.env.PORT ?? "3000", 10);
const app = new Hono();

app.get("/plaintext", (c) => c.text("Hello, World!"));
app.get("/json", (c) => c.json({ message: "Hello, World!" }));
app.get("/echo/:name", (c) => c.text(c.req.param("name") || "World"));
app.post("/echo", async (c) => {
  return new Response(c.req.raw.body, {
    headers: { "content-type": "application/octet-stream" },
  });
});

serve({ fetch: app.fetch, hostname: "0.0.0.0", port }, () => {
  console.log(`hono benchmark server listening on ${port}`);
});
