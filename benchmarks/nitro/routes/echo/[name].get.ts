export default defineEventHandler((event) => {
  setHeader(event, "content-type", "text/plain; charset=utf-8");
  return getRouterParam(event, "name") || "World";
});
