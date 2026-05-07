<?php
$path = parse_url($_SERVER["REQUEST_URI"], PHP_URL_PATH);
$method = $_SERVER["REQUEST_METHOD"];

if ($method === "GET" && $path === "/plaintext") {
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

if ($method === "POST" && $path === "/echo") {
    header("content-type: application/octet-stream");
    echo file_get_contents("php://input");
    return;
}

http_response_code(404);
header("content-type: text/plain; charset=utf-8");
echo "Not Found";
