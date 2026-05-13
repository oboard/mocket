package benchmark;

import java.util.Map;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class App {
  public static void main(String[] args) {
    String port = System.getenv().getOrDefault("PORT", "3000");
    SpringApplication app = new SpringApplication(App.class);
    app.setDefaultProperties(
        Map.of(
            "server.address", "0.0.0.0",
            "server.port", port));
    app.run(args);
  }

  @GetMapping(value = "/plaintext", produces = MediaType.TEXT_PLAIN_VALUE)
  public String plaintext() {
    return "Hello, World!";
  }

  @GetMapping(value = "/api/plaintext", produces = MediaType.TEXT_PLAIN_VALUE)
  public String apiPlaintext() {
    return "Hello, World!";
  }

  @GetMapping(value = "/api/v1/users/current/profile/settings", produces = MediaType.TEXT_PLAIN_VALUE)
  public String deepStatic() {
    return "settings";
  }

  @GetMapping(value = "/middleware/plaintext", produces = MediaType.TEXT_PLAIN_VALUE)
  public String middlewarePlaintext() {
    return "Hello, World!";
  }

  @GetMapping(value = "/static/{id}", produces = MediaType.TEXT_PLAIN_VALUE)
  public String manyRoutes(@PathVariable String id) {
    return "Hello, World!";
  }

  @GetMapping(value = "/json", produces = MediaType.APPLICATION_JSON_VALUE)
  public Map<String, String> json() {
    return Map.of("message", "Hello, World!");
  }

  @GetMapping(value = "/echo/{name}", produces = MediaType.TEXT_PLAIN_VALUE)
  public String echoPath(@PathVariable String name) {
    return name;
  }

  @GetMapping(
      value = "/users/{userId}/posts/{postId}/comments/{commentId}",
      produces = MediaType.TEXT_PLAIN_VALUE)
  public String commentPath(@PathVariable String commentId) {
    return commentId;
  }

  @GetMapping(value = "/wild/{*path}", produces = MediaType.TEXT_PLAIN_VALUE)
  public String wildcard(@PathVariable String path) {
    return path;
  }

  @GetMapping(value = "/query", produces = MediaType.TEXT_PLAIN_VALUE)
  public String query(@RequestParam(defaultValue = "moonbit") String name) {
    return name;
  }

  @GetMapping(value = "/headers", produces = MediaType.TEXT_PLAIN_VALUE)
  public org.springframework.http.ResponseEntity<String> headers() {
    return org.springframework.http.ResponseEntity.ok()
        .header("x-benchmark", "springboot")
        .body("ok");
  }

  @PostMapping(value = "/echo", produces = MediaType.APPLICATION_OCTET_STREAM_VALUE)
  public byte[] echoBody(@RequestBody byte[] body) {
    return body;
  }

  @PostMapping(value = "/json-echo", produces = MediaType.APPLICATION_JSON_VALUE)
  public byte[] echoJson(@RequestBody byte[] body) {
    return body;
  }

  @PostMapping(value = "/consume", produces = MediaType.TEXT_PLAIN_VALUE)
  public String consume(@RequestBody byte[] body) {
    return "ok";
  }
}
