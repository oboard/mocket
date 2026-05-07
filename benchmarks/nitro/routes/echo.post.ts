export default defineEventHandler(async (event) => {
  setHeader(event, "content-type", "application/octet-stream");
  return await readRawBody(event);
});
