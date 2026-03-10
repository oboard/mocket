#include "mongoose.h"
#include "moonbit.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#if defined(_WIN32)
#include <windows.h>
#else
#include <pthread.h>
#include <sched.h>
#endif


#define MAX_WS_CLIENTS 1024
#define MAX_CHANNELS 256

typedef struct {
  struct mg_connection *c;
  char id[64];
} ws_client_t;

typedef struct {
  char name[128];
  char client_ids[MAX_WS_CLIENTS][64];
  int cid_count;
} channel_t;

static ws_client_t WS_CLIENTS[MAX_WS_CLIENTS];
static int WS_CLIENT_COUNT = 0;
static channel_t CHANNELS[MAX_CHANNELS];
static int CHANNEL_COUNT = 0;

// Last received binary WS message buffer
static uint8_t *WS_LAST_MSG = NULL;
static size_t WS_LAST_MSG_LEN = 0;

void ws_set_last_msg(const unsigned char *data, size_t len) {
  if (WS_LAST_MSG) {
    free(WS_LAST_MSG);
    WS_LAST_MSG = NULL;
    WS_LAST_MSG_LEN = 0;
  }
  if (data && len > 0) {
    WS_LAST_MSG = (uint8_t *) malloc(len);
    if (WS_LAST_MSG) {
      memcpy(WS_LAST_MSG, data, len);
      WS_LAST_MSG_LEN = len;
    }
  }
}

uint8_t *ws_msg_body(void) { return WS_LAST_MSG; }
size_t ws_msg_body_len(void) { return WS_LAST_MSG_LEN; }

size_t ws_msg_copy(uint8_t *dst, size_t max_len) {
  if (!dst || WS_LAST_MSG_LEN == 0 || WS_LAST_MSG == NULL) return 0;
  size_t n = WS_LAST_MSG_LEN;
  if (n > max_len) n = max_len;
  memcpy(dst, WS_LAST_MSG, n);
  return n;
}

typedef void (*ws_emit_cb_t)(const char *type, const char *id, const char *payload);
static ws_emit_cb_t WS_EMIT_CB = NULL;
void set_ws_emit(ws_emit_cb_t cb) { WS_EMIT_CB = cb; }

static ws_client_t *find_client_by_conn(struct mg_connection *c) {
  for (int i = 0; i < WS_CLIENT_COUNT; i++) {
    if (WS_CLIENTS[i].c == c) return &WS_CLIENTS[i];
  }
  return NULL;
}

static ws_client_t *find_client_by_id(const char *id) {
  for (int i = 0; i < WS_CLIENT_COUNT; i++) {
    if (strncmp(WS_CLIENTS[i].id, id, sizeof(WS_CLIENTS[i].id)) == 0) return &WS_CLIENTS[i];
  }
  return NULL;
}

static const char *gen_id(struct mg_connection *c) {
  static char buf[64];
  snprintf(buf, sizeof(buf), "%p-%llu", (void *) c, (unsigned long long) mg_millis());
  return buf;
}

static void register_client(struct mg_connection *c) {
  if (WS_CLIENT_COUNT >= MAX_WS_CLIENTS) return;
  const char *id = gen_id(c);
  ws_client_t *slot = &WS_CLIENTS[WS_CLIENT_COUNT++];
  slot->c = c;
  snprintf(slot->id, sizeof(slot->id), "%s", id);
  if (WS_EMIT_CB) WS_EMIT_CB("open", slot->id, "");
}

static void unregister_client(ws_client_t *cl) {
  if (!cl) return;
  if (WS_EMIT_CB) WS_EMIT_CB("close", cl->id, "");
  for (int i = 0; i < CHANNEL_COUNT; i++) {
    int w = 0;
    for (int j = 0; j < CHANNELS[i].cid_count; j++) {
      if (strcmp(CHANNELS[i].client_ids[j], cl->id) != 0) {
        if (w != j) strncpy(CHANNELS[i].client_ids[w], CHANNELS[i].client_ids[j], sizeof(CHANNELS[i].client_ids[w]));
        w++;
      }
    }
    CHANNELS[i].cid_count = w;
  }
  int idx = -1;
  for (int i = 0; i < WS_CLIENT_COUNT; i++) {
    if (&WS_CLIENTS[i] == cl) { idx = i; break; }
  }
  if (idx >= 0) {
    if (idx != WS_CLIENT_COUNT - 1) WS_CLIENTS[idx] = WS_CLIENTS[WS_CLIENT_COUNT - 1];
    WS_CLIENT_COUNT--;
  }
}

static channel_t *get_channel(const char *name, int create) {
  for (int i = 0; i < CHANNEL_COUNT; i++) {
    if (strncmp(CHANNELS[i].name, name, sizeof(CHANNELS[i].name)) == 0) return &CHANNELS[i];
  }
  if (!create || CHANNEL_COUNT >= MAX_CHANNELS) return NULL;
  channel_t *ch = &CHANNELS[CHANNEL_COUNT++];
  snprintf(ch->name, sizeof(ch->name), "%s", name);
  ch->cid_count = 0;
  return ch;
}

void ws_send(const char *id, const char *msg) {
  ws_client_t *cl = find_client_by_id(id);
  if (!cl || !cl->c) return;
  if (!msg) msg = "";
  mg_ws_send(cl->c, msg, strlen(msg), WEBSOCKET_OP_TEXT);
}

// Send binary WebSocket message with explicit length
void ws_send_bytes_len(const char *id, const uint8_t *msg, size_t msg_len) {
  ws_client_t *cl = find_client_by_id(id);
  if (!cl || !cl->c) return;
  const char *data = msg ? (const char *) msg : "";
  size_t len = msg ? msg_len : 0;
  mg_ws_send(cl->c, data, len, WEBSOCKET_OP_BINARY);
}

// Send PONG frame
void ws_pong(const char *id) {
  ws_client_t *cl = find_client_by_id(id);
  if (!cl || !cl->c) return;
  mg_ws_send(cl->c, "", 0, WEBSOCKET_OP_PONG);
}

void ws_subscribe(const char *id, const char *channel) {
  if (!id || !channel) return;
  channel_t *ch = get_channel(channel, 1);
  if (!ch) return;
  for (int i = 0; i < ch->cid_count; i++) {
    if (strcmp(ch->client_ids[i], id) == 0) return;
  }
  if (ch->cid_count < MAX_WS_CLIENTS) {
    snprintf(ch->client_ids[ch->cid_count], sizeof(ch->client_ids[ch->cid_count]), "%s", id);
    ch->cid_count++;
  }
}

void ws_unsubscribe(const char *id, const char *channel) {
  if (!id || !channel) return;
  channel_t *ch = get_channel(channel, 0);
  if (!ch) return;
  int w = 0;
  for (int i = 0; i < ch->cid_count; i++) {
    if (strcmp(ch->client_ids[i], id) != 0) {
      if (w != i) strncpy(ch->client_ids[w], ch->client_ids[i], sizeof(ch->client_ids[w]));
      w++;
    }
  }
  ch->cid_count = w;
}

void ws_publish(const char *channel, const char *msg) {
  if (!channel) return;
  channel_t *ch = get_channel(channel, 0);
  if (!ch) return;
  for (int i = 0; i < ch->cid_count; i++) {
    ws_send(ch->client_ids[i], msg);
  }
}

typedef struct
{
  char key[128];
  char value[256];
} header_t;

#define MAX_HEADERS 32
// =================== Request / Response 封装 ===================

typedef struct request request_t;
typedef struct response response_t;

// 分阶段回调函数类型定义
typedef void (*on_headers_cb)(request_t *req);
typedef void (*on_body_chunk_cb)(request_t *req, struct mg_str chunk);
typedef void (*on_complete_cb)(request_t *req);
typedef void (*on_error_cb)(request_t *req, const char *error_msg);

struct request
{
  struct mg_http_message *hm; // 头信息
  struct mg_str body;         // 当前 body 缓冲

  // 分阶段回调函数
  on_headers_cb on_headers;       // 头部解析完成回调
  on_body_chunk_cb on_body_chunk; // body 数据块回调
  on_complete_cb on_complete;     // 请求完成回调
  on_error_cb on_error;           // 错误回调
};

struct response
{
  struct mg_connection *c;
  int status;
  header_t headers[MAX_HEADERS];
  int header_count;
};

// 设置 header (追加)
void res_set_header(response_t *res, const char *key, const char *value)
{
  if (res->header_count < MAX_HEADERS)
  {
    snprintf(res->headers[res->header_count].key, sizeof(res->headers[res->header_count].key), "%s", key);
    snprintf(res->headers[res->header_count].value, sizeof(res->headers[res->header_count].value), "%s", value);
    res->header_count++;
  }
}

// 写头（一次性调用，类似 Node.js 的 writeHead）
void res_status(response_t *res, int status_code)
{
  res->status = status_code;
}

// 构建 HTTP headers 字符串
static void build_headers(response_t *res, char *header_buf, size_t buf_size)
{
  header_buf[0] = '\0'; // 确保字符串为空
  for (int i = 0; i < res->header_count; i++)
  {
    strncat(header_buf, res->headers[i].key, buf_size - strlen(header_buf) - 1);
    strncat(header_buf, ": ", buf_size - strlen(header_buf) - 1);
    strncat(header_buf, res->headers[i].value, buf_size - strlen(header_buf) - 1);
    strncat(header_buf, "\r\n", buf_size - strlen(header_buf) - 1);
  }
}

// 结束并写 body
void res_end(response_t *res, const char *body)
{
  char header_buf[2048];
  build_headers(res, header_buf, sizeof(header_buf));

  mg_http_reply(res->c, res->status,
                strlen(header_buf) > 0 ? header_buf : "",
                "%s", body ? body : "");
}

// 结束并写二进制 body
void res_end_bytes(response_t *res, uint8_t *body, size_t body_len)
{
  char header_buf[2048];
  build_headers(res, header_buf, sizeof(header_buf));

  mg_http_reply(res->c, res->status,
                strlen(header_buf) > 0 ? header_buf : "",
                "%.*s", (int)body_len, body ? (char *)body : "");
}

// =================== FFI Functions for MoonBit ===================

// Get request method
const char *req_method(request_t *req)
{
  if (req && req->hm)
  {
    static char http_methodbuf[16];
    size_t len = req->hm->method.len < 15 ? req->hm->method.len : 15;
    strncpy(http_methodbuf, req->hm->method.buf, len);
    http_methodbuf[len] = '\0';
    return http_methodbuf;
  }
  return "GET";
}

// Get request URL
const char *req_url(request_t *req)
{
  if (req && req->hm)
  {
    static char url_buf[512];
    size_t len = req->hm->uri.len < 511 ? req->hm->uri.len : 511;
    strncpy(url_buf, req->hm->uri.buf, len);
    url_buf[len] = '\0';
    return url_buf;
  }
  return "/";
}

// Get request headers (simplified)
const char *req_headers(request_t *req)
{
  if (req && req->hm)
  {
    static char headers_buf[4096];
    headers_buf[0] = '\0';
    size_t buf_len = 0;
    size_t buf_cap = sizeof(headers_buf);

    for (int i = 0; i < MG_MAX_HTTP_HEADERS; i++) {
      struct mg_http_header *h = &req->hm->headers[i];
      if (h->name.len == 0) break;

      // Check if we have enough space: name.len + 2 (": ") + value.len + 2 ("\r\n") + 1 (null terminator)
      size_t needed = h->name.len + 2 + h->value.len + 2 + 1;
      if (buf_len + needed > buf_cap) break;

      strncat(headers_buf, h->name.buf, h->name.len);
      strcat(headers_buf, ": ");
      strncat(headers_buf, h->value.buf, h->value.len);
      strcat(headers_buf, "\r\n");
      
      buf_len += needed - 1; // -1 because null terminator is overwritten/handled by strcat
    }

    return headers_buf;
  }
  return "";
}

// Get complete request body as MoonBit Bytes object
moonbit_bytes_t req_body(request_t *req)
{
  if (!req || !req->hm || !req->hm->body.buf || req->hm->body.len == 0)
  {
    return moonbit_empty_int8_array;
  }

  size_t len = req->hm->body.len;
  if (len > INT32_MAX)
  {
    len = INT32_MAX;
  }
  moonbit_bytes_t buf = moonbit_make_bytes_raw((int32_t)len);
  memcpy(buf, req->hm->body.buf, len);
  return buf;
}

int32_t req_body_len(request_t *req)
{
  if (!req || !req->hm)
  {
    return 0;
  }
  size_t len = req->hm->body.len;
  return len > INT32_MAX ? INT32_MAX : (int32_t)len;
}

// Set response header (wrapper for res_set_header)
void res_set_header_line(response_t *res, const char *header_line)
{
  if (!res || !header_line)
    return;

  // Parse "key: value" format
  char *colon = strchr(header_line, ':');
  if (colon)
  {
    char key[128], value[256];
    size_t key_len = colon - header_line;
    if (key_len < 127)
    {
      strncpy(key, header_line, key_len);
      key[key_len] = '\0';

      // Skip ": " and get value
      const char *val_start = colon + 1;
      while (*val_start == ' ')
        val_start++; // Skip spaces
      strncpy(value, val_start, 255);
      value[255] = '\0';

      if (res->header_count < MAX_HEADERS)
      {
        strncpy(res->headers[res->header_count].key, key, 127);
        strncpy(res->headers[res->header_count].value, value, 255);
        res->header_count++;
      }
    }
  }
}

// =================== Server 封装 ===================

typedef void (*request_handler_t)(int port, request_t *req, response_t *res);

typedef struct
{
  struct mg_mgr mgr;
  request_handler_t handler;
  int port;
} server_t;

static void ev_handler(struct mg_connection *c, int ev, void *ev_data)
{
  server_t *srv = (server_t *)c->fn_data;

  if (ev == MG_EV_HTTP_MSG)
  {
    struct mg_http_message *hm = (struct mg_http_message *)ev_data;
    struct mg_str *upgrade = mg_http_get_header(hm, "Upgrade");
    if (upgrade && mg_strcasecmp(*upgrade, mg_str("websocket")) == 0) {
      mg_ws_upgrade(c, hm, NULL);
      return;
    }

    request_t req = {hm, hm->body, NULL, NULL, NULL, NULL};
    response_t res = {c, 200, "", 0};

    if (srv->handler)
    {
      if (req.on_headers)
      {
        req.on_headers(&req);
      }

      if (req.on_body_chunk && hm->body.len > 0)
      {
        req.on_body_chunk(&req, hm->body);
      }

      srv->handler(srv->port, &req, &res);

      if (req.on_complete)
      {
        req.on_complete(&req);
      }
    }
    else
    {
      if (req.on_error)
      {
        req.on_error(&req, "Handler not found");
      }
      mg_http_reply(c, 404, "", "Not Found\n");
    }
  }
  else if (ev == MG_EV_WS_OPEN)
  {
    register_client(c);
  }
  else if (ev == MG_EV_WS_MSG)
  {
    struct mg_ws_message *wm = (struct mg_ws_message *) ev_data;
    ws_client_t *cl = find_client_by_conn(c);
    if (!cl) return;
    unsigned char op = wm->flags & 0x0F;
    if (op == WEBSOCKET_OP_TEXT) {
      size_t len = wm->data.len;
      char *tmp = (char *) malloc(len + 1);
      if (!tmp) return;
      memcpy(tmp, wm->data.buf, len);
      tmp[len] = '\0';
      if (WS_EMIT_CB) WS_EMIT_CB("message", cl->id, tmp);
      free(tmp);
    } else if (op == WEBSOCKET_OP_BINARY) {
      ws_set_last_msg((const unsigned char *) wm->data.buf, wm->data.len);
      if (WS_EMIT_CB) WS_EMIT_CB("binary", cl->id, "");
    } else if (op == WEBSOCKET_OP_PING) {
      if (WS_EMIT_CB) WS_EMIT_CB("ping", cl->id, "");
    }
  }
  else if (ev == MG_EV_CLOSE)
  {
    ws_client_t *cl = find_client_by_conn(c);
    if (cl) unregister_client(cl);
  }
}

// 创建 server
server_t *create_server(request_handler_t handler)
{
  server_t *srv = (server_t *)malloc(sizeof(server_t));
  mg_log_set(MG_LL_NONE);
  mg_mgr_init(&srv->mgr);
  srv->handler = handler;
  return srv;
}

// 开始监听
void server_listen(server_t *srv, int port)
{
  char url[32];
  srv->port = port;
  snprintf(url, sizeof(url), "http://0.0.0.0:%d", port);
  if (mg_http_listen(&srv->mgr, url, ev_handler, srv) == NULL)
  {
    fprintf(stderr, "Cannot listen on %s\n", url);
    exit(1);
  }

  for (;;)
  {
    mg_mgr_poll(&srv->mgr, 1000);
  }
}

// 设置头部解析完成回调
void set_on_headers(request_t *req, on_headers_cb cb)
{
  if (req)
  {
    req->on_headers = cb;
  }
}

// 设置 body 数据块回调
void set_on_body_chunk(request_t *req, on_body_chunk_cb cb)
{
  if (req)
  {
    req->on_body_chunk = cb;
  }
}

// 设置请求完成回调
void set_on_complete(request_t *req, on_complete_cb cb)
{
  if (req)
  {
    req->on_complete = cb;
  }
}

// 设置错误回调
void set_on_error(request_t *req, on_error_cb cb)
{
  if (req)
  {
    req->on_error = cb;
  }
}

// =================== HTTP Client(fetch) ===================

static int fetch_append_bytes(uint8_t **buf, size_t *len, size_t *cap, const void *data, size_t n) {
  if (n == 0) return 0;
  if (*cap < *len + n + 1) {
    size_t new_cap = *cap == 0 ? 1024 : *cap;
    while (new_cap < *len + n + 1) new_cap *= 2;
    uint8_t *new_buf = (uint8_t *) realloc(*buf, new_cap);
    if (!new_buf) return -1;
    *buf = new_buf;
    *cap = new_cap;
  }
  memcpy(*buf + *len, data, n);
  *len += n;
  (*buf)[*len] = '\0';
  return 0;
}

typedef struct {
  int done;
  int status;
  char error[256];
  const char *url;
  const char *method;
  const char *request_body;
  size_t request_body_len;
  const char *request_headers;
  char *response_headers;
  size_t response_headers_len;
  size_t response_headers_cap;
  uint8_t *response_body;
  size_t response_body_len;
  size_t response_body_cap;
} fetch_ctx_t;

static void fetch_send_request(struct mg_connection *c, fetch_ctx_t *ctx) {
  struct mg_str host = mg_url_host(ctx->url);
  const char *uri = mg_url_uri(ctx->url);
  if (!uri || uri[0] == '\0') uri = "/";
  mg_printf(c, "%s %s HTTP/1.1\r\n", ctx->method, uri);
  if (host.len > 0) {
    mg_printf(c, "Host: %.*s\r\n", (int) host.len, host.buf);
  }
  mg_printf(c, "User-Agent: mocket-fetch/0.1\r\n");
  mg_printf(c, "Accept: */*\r\n");
  mg_printf(c, "Connection: close\r\n");
  if (ctx->request_headers && ctx->request_headers[0] != '\0') {
    mg_printf(c, "%s", ctx->request_headers);
  }
  if (ctx->request_body_len > 0) {
    mg_printf(c, "Content-Length: %zu\r\n", ctx->request_body_len);
  }
  mg_printf(c, "\r\n");
  if (ctx->request_body_len > 0) {
    mg_send(c, ctx->request_body, ctx->request_body_len);
  }
}

static void fetch_set_error(fetch_ctx_t *ctx, const char *msg) {
  if (!ctx || ctx->error[0] != '\0') return;
  if (!msg) msg = "unknown error";
  snprintf(ctx->error, sizeof(ctx->error), "%s", msg);
}

typedef struct {
  int ok;
  int status;
  char *headers;
  uint8_t *body;
  size_t body_len;
  char error[256];
} fetch_result_t;

static void fetch_result_reset(fetch_result_t *r) {
  if (!r) return;
  r->ok = 0;
  r->status = 0;
  r->headers = NULL;
  r->body = NULL;
  r->body_len = 0;
  r->error[0] = '\0';
}

static void fetch_result_free(fetch_result_t *r) {
  if (!r) return;
  if (r->headers) {
    free(r->headers);
    r->headers = NULL;
  }
  if (r->body) {
    free(r->body);
    r->body = NULL;
  }
  r->body_len = 0;
}

static void fetch_ev_handler(struct mg_connection *c, int ev, void *ev_data) {
  fetch_ctx_t *ctx = (fetch_ctx_t *) c->fn_data;
  if (!ctx) return;

  if (ev == MG_EV_CONNECT) {
    int connect_status = 0;
    if (ev_data != NULL) connect_status = *(int *) ev_data;
    if (connect_status != 0) {
      fetch_set_error(ctx, "connect failed");
      ctx->done = 1;
      c->is_closing = 1;
      return;
    }
    if (mg_url_is_ssl(ctx->url)) {
      struct mg_tls_opts opts;
      memset(&opts, 0, sizeof(opts));
      opts.skip_verification = 1;
      opts.name = mg_url_host(ctx->url);  // SNI
      mg_tls_init(c, &opts);
    } else {
      fetch_send_request(c, ctx);
    }
    return;
  }

  if (ev == MG_EV_TLS_HS) {
    fetch_send_request(c, ctx);
    return;
  }

  if (ev == MG_EV_HTTP_MSG) {
    struct mg_http_message *hm = (struct mg_http_message *) ev_data;
    ctx->status = mg_http_status(hm);

    for (int i = 0; i < MG_MAX_HTTP_HEADERS; i++) {
      struct mg_http_header *h = &hm->headers[i];
      if (h->name.len == 0) break;
      if (fetch_append_bytes((uint8_t **) &ctx->response_headers, &ctx->response_headers_len, &ctx->response_headers_cap, h->name.buf, h->name.len) != 0 ||
          fetch_append_bytes((uint8_t **) &ctx->response_headers, &ctx->response_headers_len, &ctx->response_headers_cap, ": ", 2) != 0 ||
          fetch_append_bytes((uint8_t **) &ctx->response_headers, &ctx->response_headers_len, &ctx->response_headers_cap, h->value.buf, h->value.len) != 0 ||
          fetch_append_bytes((uint8_t **) &ctx->response_headers, &ctx->response_headers_len, &ctx->response_headers_cap, "\r\n", 2) != 0) {
        fetch_set_error(ctx, "out of memory while reading headers");
        break;
      }
    }

    if (ctx->error[0] == '\0' && hm->body.len > 0 &&
        fetch_append_bytes(&ctx->response_body, &ctx->response_body_len, &ctx->response_body_cap, hm->body.buf, hm->body.len) != 0) {
      fetch_set_error(ctx, "out of memory while reading body");
    }

    ctx->done = 1;
    c->is_closing = 1;
    return;
  }

  if (ev == MG_EV_ERROR) {
    const char *msg = (const char *) ev_data;
    fetch_set_error(ctx, msg ? msg : "request error");
    ctx->done = 1;
    c->is_closing = 1;
    return;
  }

  if (ev == MG_EV_CLOSE && !ctx->done) {
    if (ctx->error[0] == '\0' && ctx->status <= 0) {
      fetch_set_error(ctx, "connection closed before receiving HTTP response");
    }
    ctx->done = 1;
  }
}

static int mocket_fetch_blocking(
  const char *url,
  const char *method,
  const char *body,
  const char *headers,
  int timeout_ms,
  fetch_result_t *out
) {
  char last_error[256] = "";
  int attempt;
  mg_log_set(MG_LL_NONE);
  fetch_result_reset(out);
  if (!url || url[0] == '\0') {
    snprintf(out->error, sizeof(out->error), "url is empty");
    return -1;
  }
  if (!method || method[0] == '\0') {
    method = "GET";
  }
  if (!body) body = "";
  if (!headers) headers = "";
  if (timeout_ms <= 0) timeout_ms = 30000;
  for (attempt = 0; attempt < 3; attempt++) {
    struct mg_mgr mgr;
    fetch_ctx_t ctx;
    struct mg_connection *conn;
    uint64_t start;

    mg_mgr_init(&mgr);
    memset(&ctx, 0, sizeof(ctx));
    ctx.url = url;
    ctx.method = method;
    ctx.request_body = body;
    ctx.request_body_len = strlen(body);
    ctx.request_headers = headers;

    conn = mg_http_connect(&mgr, url, fetch_ev_handler, &ctx);
    if (conn == NULL) {
      mg_mgr_free(&mgr);
      snprintf(last_error, sizeof(last_error), "failed to create client connection");
      continue;
    }

    start = mg_millis();
    while (!ctx.done && (mg_millis() - start) < (uint64_t) timeout_ms) {
      mg_mgr_poll(&mgr, 50);
    }
    if (!ctx.done) {
      fetch_set_error(&ctx, "request timeout");
    }
    mg_mgr_free(&mgr);

    if (ctx.error[0] != '\0') {
      snprintf(last_error, sizeof(last_error), "%s", ctx.error);
      if (ctx.response_headers) free(ctx.response_headers);
      if (ctx.response_body) free(ctx.response_body);
      continue;
    }

    if (ctx.status <= 0) {
      snprintf(last_error, sizeof(last_error), "invalid response status");
      if (ctx.response_headers) free(ctx.response_headers);
      if (ctx.response_body) free(ctx.response_body);
      continue;
    }

    out->ok = 1;
    out->status = ctx.status;
    out->headers = ctx.response_headers;
    out->body = ctx.response_body;
    out->body_len = ctx.response_body_len;
    if (out->headers == NULL) {
      out->headers = (char *) malloc(1);
      if (out->headers) out->headers[0] = '\0';
    }
    if (out->body == NULL) {
      out->body = (uint8_t *) malloc(1);
      if (out->body) out->body[0] = '\0';
      out->body_len = 0;
    }
    return 0;
  }

  if (last_error[0] == '\0') {
    snprintf(last_error, sizeof(last_error), "request failed");
  }
  snprintf(out->error, sizeof(out->error), "%s", last_error);
  return -1;
}

// ---------- legacy synchronous fetch API ----------
static fetch_result_t FETCH_SYNC_RESULT = {0};

int mocket_fetch(
  const char *url,
  const char *method,
  const char *body,
  const char *headers,
  int timeout_ms
) {
  fetch_result_free(&FETCH_SYNC_RESULT);
  fetch_result_reset(&FETCH_SYNC_RESULT);
  return mocket_fetch_blocking(url, method, body, headers, timeout_ms, &FETCH_SYNC_RESULT);
}

int mocket_fetch_status(void) { return FETCH_SYNC_RESULT.status; }
const char *mocket_fetch_headers(void) { return FETCH_SYNC_RESULT.headers ? FETCH_SYNC_RESULT.headers : ""; }
const char *mocket_fetch_error(void) { return FETCH_SYNC_RESULT.error; }
size_t mocket_fetch_body_len(void) { return FETCH_SYNC_RESULT.body_len; }
size_t mocket_fetch_body_copy(uint8_t *dst, size_t max_len) {
  if (!dst || max_len == 0 || !FETCH_SYNC_RESULT.body || FETCH_SYNC_RESULT.body_len == 0) return 0;
  size_t n = FETCH_SYNC_RESULT.body_len < max_len ? FETCH_SYNC_RESULT.body_len : max_len;
  memcpy(dst, FETCH_SYNC_RESULT.body, n);
  return n;
}

// ---------- asynchronous fetch API ----------
typedef void (*fetch_done_cb_t)(int req_id);

typedef struct fetch_task_result fetch_task_result_t;
struct fetch_task_result {
  int req_id;
  fetch_result_t result;
  fetch_task_result_t *next;
};

typedef struct {
  int req_id;
  char *url;
  char *method;
  char *body;
  char *headers;
  int timeout_ms;
  fetch_done_cb_t done_cb;
  volatile int ready_to_callback;
} fetch_job_t;

static fetch_task_result_t *FETCH_TASK_RESULTS = NULL;

#if defined(_WIN32)
static CRITICAL_SECTION FETCH_TASK_MUTEX;
static int FETCH_TASK_MUTEX_INIT = 0;
static LONG NEXT_FETCH_REQ_ID = 1;
#else
static pthread_mutex_t FETCH_TASK_MUTEX = PTHREAD_MUTEX_INITIALIZER;
static int FETCH_TASK_MUTEX_INIT = 1;
static int NEXT_FETCH_REQ_ID = 1;
#endif

static void fetch_task_mutex_init_once(void) {
#if defined(_WIN32)
  if (!FETCH_TASK_MUTEX_INIT) {
    InitializeCriticalSection(&FETCH_TASK_MUTEX);
    FETCH_TASK_MUTEX_INIT = 1;
  }
#else
  (void) FETCH_TASK_MUTEX_INIT;
#endif
}

static void fetch_task_lock(void) {
  fetch_task_mutex_init_once();
#if defined(_WIN32)
  EnterCriticalSection(&FETCH_TASK_MUTEX);
#else
  pthread_mutex_lock(&FETCH_TASK_MUTEX);
#endif
}

static void fetch_task_unlock(void) {
#if defined(_WIN32)
  LeaveCriticalSection(&FETCH_TASK_MUTEX);
#else
  pthread_mutex_unlock(&FETCH_TASK_MUTEX);
#endif
}

static int next_fetch_req_id(void) {
#if defined(_WIN32)
  return (int) InterlockedIncrement(&NEXT_FETCH_REQ_ID);
#else
  fetch_task_lock();
  int id = NEXT_FETCH_REQ_ID++;
  fetch_task_unlock();
  return id;
#endif
}

static fetch_task_result_t *fetch_task_find_locked(int req_id) {
  fetch_task_result_t *cur = FETCH_TASK_RESULTS;
  while (cur) {
    if (cur->req_id == req_id) return cur;
    cur = cur->next;
  }
  return NULL;
}

static char *fetch_strdup(const char *s) {
  if (!s) s = "";
  size_t n = strlen(s);
  char *out = (char *) malloc(n + 1);
  if (!out) return NULL;
  memcpy(out, s, n + 1);
  return out;
}

static void fetch_job_free(fetch_job_t *job) {
  if (!job) return;
  if (job->url) free(job->url);
  if (job->method) free(job->method);
  if (job->body) free(job->body);
  if (job->headers) free(job->headers);
  free(job);
}

#if defined(_WIN32)
static DWORD WINAPI fetch_worker_thread(LPVOID arg)
#else
static void *fetch_worker_thread(void *arg)
#endif
{
  fetch_job_t *job = (fetch_job_t *) arg;
  if (!job) {
#if defined(_WIN32)
    return 0;
#else
    return NULL;
#endif
  }
  fetch_task_result_t *node = (fetch_task_result_t *) calloc(1, sizeof(fetch_task_result_t));
  if (!node) {
    if (job->done_cb) job->done_cb(job->req_id);
    fetch_job_free(job);
#if defined(_WIN32)
    return 0;
#else
    return NULL;
#endif
  }
  node->req_id = job->req_id;
  fetch_result_reset(&node->result);
  mocket_fetch_blocking(job->url, job->method, job->body, job->headers, job->timeout_ms, &node->result);

  fetch_task_lock();
  node->next = FETCH_TASK_RESULTS;
  FETCH_TASK_RESULTS = node;
  fetch_task_unlock();

  while (!job->ready_to_callback) {
#if defined(_WIN32)
    Sleep(0);
#else
    sched_yield();
#endif
  }

  if (job->done_cb) {
    job->done_cb(job->req_id);
  }
  fetch_job_free(job);
#if defined(_WIN32)
  return 0;
#else
  return NULL;
#endif
}

int mocket_fetch_async(
  const char *url,
  const char *method,
  const char *body,
  const char *headers,
  int timeout_ms,
  fetch_done_cb_t done_cb
) {
  fetch_job_t *job = (fetch_job_t *) calloc(1, sizeof(fetch_job_t));
  if (!job) return 0;
  job->req_id = next_fetch_req_id();
  job->url = fetch_strdup(url);
  job->method = fetch_strdup(method && method[0] ? method : "GET");
  job->body = fetch_strdup(body ? body : "");
  job->headers = fetch_strdup(headers ? headers : "");
  job->timeout_ms = timeout_ms > 0 ? timeout_ms : 30000;
  job->done_cb = done_cb;

  if (!job->url || !job->method || !job->body || !job->headers) {
    fetch_job_free(job);
    return 0;
  }

#if defined(_WIN32)
  HANDLE th = CreateThread(NULL, 0, fetch_worker_thread, job, 0, NULL);
  if (th == NULL) {
    fetch_job_free(job);
    return 0;
  }
  CloseHandle(th);
#else
  pthread_t tid;
  if (pthread_create(&tid, NULL, fetch_worker_thread, job) != 0) {
    fetch_job_free(job);
    return 0;
  }
  pthread_detach(tid);
#endif

  job->ready_to_callback = 1;
  return job->req_id;
}

int mocket_fetch_async_ok(int req_id) {
  int ok = 0;
  fetch_task_lock();
  fetch_task_result_t *node = fetch_task_find_locked(req_id);
  if (node) ok = node->result.ok;
  fetch_task_unlock();
  return ok;
}

int mocket_fetch_async_status(int req_id) {
  int status = 0;
  fetch_task_lock();
  fetch_task_result_t *node = fetch_task_find_locked(req_id);
  if (node) status = node->result.status;
  fetch_task_unlock();
  return status;
}

const char *mocket_fetch_async_headers(int req_id) {
  const char *headers = "";
  fetch_task_lock();
  fetch_task_result_t *node = fetch_task_find_locked(req_id);
  if (node && node->result.headers) headers = node->result.headers;
  fetch_task_unlock();
  return headers;
}

const char *mocket_fetch_async_error(int req_id) {
  const char *err = "fetch result not found";
  fetch_task_lock();
  fetch_task_result_t *node = fetch_task_find_locked(req_id);
  if (node) err = node->result.error[0] ? node->result.error : "request failed";
  fetch_task_unlock();
  return err;
}

size_t mocket_fetch_async_body_len(int req_id) {
  size_t n = 0;
  fetch_task_lock();
  fetch_task_result_t *node = fetch_task_find_locked(req_id);
  if (node) n = node->result.body_len;
  fetch_task_unlock();
  return n;
}

size_t mocket_fetch_async_body_copy(int req_id, uint8_t *dst, size_t max_len) {
  size_t copied = 0;
  fetch_task_lock();
  fetch_task_result_t *node = fetch_task_find_locked(req_id);
  if (node && dst && max_len > 0 && node->result.body && node->result.body_len > 0) {
    copied = node->result.body_len < max_len ? node->result.body_len : max_len;
    memcpy(dst, node->result.body, copied);
  }
  fetch_task_unlock();
  return copied;
}

void mocket_fetch_async_free(int req_id) {
  fetch_task_lock();
  fetch_task_result_t *prev = NULL;
  fetch_task_result_t *cur = FETCH_TASK_RESULTS;
  while (cur) {
    if (cur->req_id == req_id) {
      if (prev) prev->next = cur->next;
      else FETCH_TASK_RESULTS = cur->next;
      fetch_result_free(&cur->result);
      free(cur);
      break;
    }
    prev = cur;
    cur = cur->next;
  }
  fetch_task_unlock();
}

// // =================== 示例 ===================

// // data 回调
// void handle_data(request_t *req, struct mg_str data)
// {
//   printf("[on_data] got %zu\n", data.len);
// }

// // end 回调
// void handle_end(request_t *req)
// {
//   printf("[on_end] request finished\n");
// }

// // handler
// void my_handler(request_t *req, response_t *res)
// {
//   // 挂载回调
//   req->on_data = handle_data;
//   req->on_end = handle_end;

//   res_write_head(res, 200, "Content-Type: text/plain\r\n");
//   res_end(res, "Streaming style OK\n");
// }

// int main(void)
// {
//   server_t *srv = create_server(my_handler);
//   server_listen(srv, "http://0.0.0.0:4000");
//   return 0;
// }
