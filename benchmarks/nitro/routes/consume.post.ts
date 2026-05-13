export default defineEventHandler(async (event) => {
  await readRawBody(event);
  return "ok";
});
