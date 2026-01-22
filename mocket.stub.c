#include "mongoose.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


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

// Get complete request body as uint8_t*
uint8_t *req_body(request_t *req)
{
  if (req && req->hm && req->hm->body.len > 0)
  {
    return (uint8_t *)req->hm->body.buf;
  }
  return NULL;
}

size_t req_body_len(request_t *req)
{
  if (req && req->hm)
  {
    return req->hm->body.len;
  }
  return 0;
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
