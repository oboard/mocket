package benchmark;

import java.util.Map;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
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

  @GetMapping(value = "/json", produces = MediaType.APPLICATION_JSON_VALUE)
  public Map<String, String> json() {
    return Map.of("message", "Hello, World!");
  }

  @GetMapping(value = "/echo/{name}", produces = MediaType.TEXT_PLAIN_VALUE)
  public String echoPath(@PathVariable String name) {
    return name;
  }

  @PostMapping(value = "/echo", produces = MediaType.APPLICATION_OCTET_STREAM_VALUE)
  public byte[] echoBody(@RequestBody byte[] body) {
    return body;
  }
}
