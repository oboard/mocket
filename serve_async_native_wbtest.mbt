///|
test "native request body limit helpers handle int max boundaries" {
  let max_int = 2_147_483_647
  inspect(next_native_request_body_chunk_size(max_int, 0), content="1024")
  inspect(
    native_request_body_chunk_exceeds_limit(max_int, max_int, 1),
    content="true",
  )
  inspect(
    native_request_body_chunk_exceeds_limit(max_int, max_int - 1, 1),
    content="false",
  )
}
