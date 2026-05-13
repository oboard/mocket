<?php
$path = parse_url($_SERVER["REQUEST_URI"], PHP_URL_PATH);
$method = $_SERVER["REQUEST_METHOD"];

if ($method === "GET" && $path === "/plaintext") {
    header("content-type: text/plain; charset=utf-8");
    echo "Hello, World!";
    return;
}

if ($method === "GET" && $path === "/api/plaintext") {
    header("content-type: text/plain; charset=utf-8");
    echo "Hello, World!";
    return;
}

if ($method === "GET" && $path === "/api/v1/users/current/profile/settings") {
    header("content-type: text/plain; charset=utf-8");
    echo "settings";
    return;
}

if ($method === "GET" && $path === "/middleware/plaintext") {
    header("content-type: text/plain; charset=utf-8");
    echo "Hello, World!";
    return;
}

if ($method === "GET" && preg_match("#^/static/([0-9]+)$#", $path, $matches) && (int) $matches[1] < 1000) {
    header("content-type: text/plain; charset=utf-8");
    echo "Hello, World!";
    return;
}

if ($method === "GET" && $path === "/json") {
    header("content-type: application/json; charset=utf-8");
    echo json_encode(["message" => "Hello, World!"]);
    return;
}

if ($method === "GET" && str_starts_with($path, "/echo/")) {
    header("content-type: text/plain; charset=utf-8");
    echo rawurldecode(substr($path, strlen("/echo/"))) ?: "World";
    return;
}

if ($method === "GET" && preg_match("#^/users/([^/]+)/posts/([^/]+)/comments/([^/]+)$#", $path, $matches)) {
    header("content-type: text/plain; charset=utf-8");
    echo rawurldecode($matches[3]);
    return;
}

if ($method === "GET" && str_starts_with($path, "/wild/")) {
    header("content-type: text/plain; charset=utf-8");
    echo rawurldecode(substr($path, strlen("/wild/")));
    return;
}

if ($method === "GET" && $path === "/query") {
    header("content-type: text/plain; charset=utf-8");
    echo $_GET["name"] ?? "moonbit";
    return;
}

if ($method === "GET" && $path === "/headers") {
    header("content-type: text/plain; charset=utf-8");
    header("x-benchmark: php");
    echo "ok";
    return;
}

if ($method === "POST" && $path === "/echo") {
    header("content-type: application/octet-stream");
    echo file_get_contents("php://input");
    return;
}

if ($method === "POST" && $path === "/json-echo") {
    header("content-type: application/json; charset=utf-8");
    echo file_get_contents("php://input");
    return;
}

if ($method === "POST" && $path === "/consume") {
    file_get_contents("php://input");
    header("content-type: text/plain; charset=utf-8");
    echo "ok";
    return;
}

http_response_code(404);
header("content-type: text/plain; charset=utf-8");
echo "Not Found";
