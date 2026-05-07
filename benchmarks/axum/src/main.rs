use axum::{
    body::Bytes,
    extract::Path,
    routing::{get, post},
    Json, Router,
};
use serde::Serialize;
use std::{env, net::SocketAddr};

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

async fn echo_path(Path(name): Path<String>) -> String {
    name
}

async fn echo_body(body: Bytes) -> Bytes {
    body
}

#[tokio::main]
async fn main() {
    let port = env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let addr: SocketAddr = format!("0.0.0.0:{port}").parse().unwrap();
    let app = Router::new()
        .route("/plaintext", get(plaintext))
        .route("/json", get(json))
        .route("/echo/:name", get(echo_path))
        .route("/echo", post(echo_body));

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
