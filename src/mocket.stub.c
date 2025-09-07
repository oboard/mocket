#include "mongoose.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
    static char headers_buf[1024];
    headers_buf[0] = '\0';

    // Extract some common headers
    struct mg_str *content_type = mg_http_get_header(req->hm, "Content-Type");
    if (content_type)
    {
      strncat(headers_buf, "Content-Type: ", sizeof(headers_buf) - strlen(headers_buf) - 1);
      strncat(headers_buf, content_type->buf,
              content_type->len < (sizeof(headers_buf) - strlen(headers_buf) - 1) ? content_type->len : (sizeof(headers_buf) - strlen(headers_buf) - 1));
      strncat(headers_buf, "\r\n", sizeof(headers_buf) - strlen(headers_buf) - 1);
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
    // HTTP 请求完整到达
    struct mg_http_message *hm = (struct mg_http_message *)ev_data;

    request_t req = {hm, hm->body, NULL, NULL, NULL, NULL};
    response_t res = {c, 200, "", 0};

    if (srv->handler)
    {
      // 1. 头部解析完成回调
      if (req.on_headers)
      {
        req.on_headers(&req);
      }

      // 2. body 数据块回调（如果有 body）
      if (req.on_body_chunk && hm->body.len > 0)
      {
        req.on_body_chunk(&req, hm->body);
      }

      srv->handler(srv->port, &req, &res);

      // 3. 请求完成回调
      if (req.on_complete)
      {
        req.on_complete(&req);
      }
    }
    else
    {
      // 触发错误回调
      if (req.on_error)
      {
        req.on_error(&req, "Handler not found");
      }
      mg_http_reply(c, 404, "", "Not Found\n");
    }
  }
}

// 创建 server
server_t *create_server(request_handler_t handler)
{
  server_t *srv = (server_t *)malloc(sizeof(server_t));
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
  printf("Listening on %s\n", url);

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
