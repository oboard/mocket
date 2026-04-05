HTTP support for `moonbitlang/async`.

## Making simple HTTP request

Simple HTTP request can be made in just one line:

```moonbit check
///|
#cfg(any(target="native", target="js"))
async test {
  let (response, body) = @http.get("https://www.moonbitlang.com")
  inspect(response.code, content="200")
  assert_true(body.text().has_prefix("<!doctype html>"))
}
```

You can use use `body.text()` to get a `String` (decoded via UTF8)
or `body.json()` for a `Json` from the response body.

## Generic HTTP client
Sometimes, the simple one-time `@http.get` etc. is insufficient,
for example you need to reuse the same connection for multiple requests,
or the request/response body is very large and need to be processed lazily.
In this case, you can use the `@http.Client` type.
`@http.Client` can be created via `@http.Client(uri)`.

The workflow of performing a request with `@http.Client` is:

1. initiate the request via `client.request(..)`
1. send the request body by using `@http.Client` as a `@io.Writer`
1. complete the request and obtain response header from the server
  via `client.end_request()`
1. read the response body by using `@http.Client` as a `@io.Reader`,
  or use `client.read_all()` to obtain the whole response body.
  Yon can also ignore the body via `client.skip_response_body()`

The helpers `client.get(..)`, `client.put(..)` etc.
can be used to perform step (1)-(3) above.

A complete example:

```moonbit check
///|
#cfg(any(target="native", target="js"))
async test {
  let client = @http.Client("https://www.moonbitlang.com")
  defer client.close()
  let response = client..request(Get, "/").end_request()
  inspect(response.code, content="200")
  let body = client.read_all()
  assert_true(body.text().has_prefix("<!doctype html>"))
}
```

All HTTP client API, including the simple request helpers `@http.get` etc.,
are supported on JavaScript backend using `fetch` API,
meaning that you can use these API in browser environment.
Notice that some feature, such as proxy, is not supported on JavaScript backend.

## Writing HTTP servers
The recommended way to create HTTP servers is `@http.Server::run_forever(..)`.
A HTTP server should first get created via `@http.Server(..)`,
after that, `server.run_forever(f)` automatically start and run the server.
The callback function `f` is used to handle HTTP requests.
It receives three parameters:

- the request to process
- a `&@io.Reader` that can be used to read request body
- a `@http.ServerConnection` that can be used to send response.
    The procedure to send a response is:
    1. initiate a response and send response header via `.send_response()`
    2. send response body by using the `@http.ServerConnection` as `@io.Writer`
    3. (optional) complete the response via `.end_response()`.
        If `.end_response()` is not called, it will be called automatically
        after `f` returns normally.

Here's an example server that returns 404 to every request:

```moonbit check
///|
#cfg(target="native")
pub async fn server(listen_addr : @socket.Addr) -> Unit {
  @http.Server(listen_addr).run_forever((request, _body, conn) => {
    conn..send_response(404, "NotFound").write("`\{request.path}` not found")
  })
}
```
