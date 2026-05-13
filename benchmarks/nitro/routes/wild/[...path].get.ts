export default defineEventHandler((event) => {
  setHeader(event, "content-type", "text/plain; charset=utf-8");
  const path = getRouterParam(event, "path");
  return Array.isArray(path) ? path.join("/") : path || "";
});
