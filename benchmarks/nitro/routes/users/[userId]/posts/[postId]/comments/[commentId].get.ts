export default defineEventHandler((event) => {
  return getRouterParam(event, "commentId") || "";
});
