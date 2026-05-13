use axum::{
    body::Bytes,
    extract::{Path, Query, Request},
    http::HeaderMap,
    middleware::{self, Next},
    response::Response,
    routing::{get, post},
    Json, Router,
};
use serde::Serialize;
use std::{collections::HashMap, env, net::SocketAddr};

#[derive(Serialize)]
struct Payload {
    message: &'static str,
}

async fn plaintext() -> &'static str {
    "Hello, World!"
}

async fn json() -> Json<Payload> {
    Json(Payload {
        message: "Hello, World!",
    })
}

async fn query(Query(params): Query<HashMap<String, String>>) -> String {
    params
        .get("name")
        .cloned()
        .unwrap_or_else(|| "moonbit".to_string())
}

async fn echo_path(Path(name): Path<String>) -> String {
    name
}

async fn comment_path(
    Path((_user_id, _post_id, comment_id)): Path<(String, String, String)>,
) -> String {
    comment_id
}

async fn wildcard(Path(path): Path<String>) -> String {
    path
}

async fn headers() -> (HeaderMap, &'static str) {
    let mut headers = HeaderMap::new();
    headers.insert("x-benchmark", "axum".parse().unwrap());
    headers.insert("content-type", "text/plain; charset=utf-8".parse().unwrap());
    (headers, "ok")
}

async fn echo_body(body: Bytes) -> Bytes {
    body
}

async fn consume_body(body: Bytes) -> &'static str {
    let _ = body.len();
    "ok"
}

async fn noop_middleware(request: Request, next: Next) -> Response {
    next.run(request).await
}

#[tokio::main]
async fn main() {
    let port = env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let addr: SocketAddr = format!("0.0.0.0:{port}").parse().unwrap();
    let mut app = Router::new()
        .route("/plaintext", get(plaintext))
        .route("/api/plaintext", get(plaintext))
        .route(
            "/middleware/plaintext",
            get(plaintext).route_layer(middleware::from_fn(noop_middleware)),
        )
        .route(
            "/api/v1/users/current/profile/settings",
            get(|| async { "settings" }),
        )
        .route("/json", get(json))
        .route("/echo/:name", get(echo_path))
        .route(
            "/users/:user_id/posts/:post_id/comments/:comment_id",
            get(comment_path),
        )
        .route("/wild/*path", get(wildcard))
        .route("/query", get(query))
        .route("/headers", get(headers))
        .route("/echo", post(echo_body))
        .route("/json-echo", post(echo_body))
        .route("/consume", post(consume_body));
    for i in 0..1000 {
        app = app.route(&format!("/static/{i}"), get(plaintext));
    }

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
