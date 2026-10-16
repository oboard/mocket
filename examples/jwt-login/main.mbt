///|
using @mocket {type HttpResponse}

///|
/// A 32-byte HMAC-SHA256 secret. In a real application, load this from an
/// environment variable or a secret manager — never hard-code it.
let secret : Bytes = b"0123456789abcdef0123456789abcdef"

///|
/// Demo user database: username -> password.
let users : Map[String, String] = { "alice": "password123", "bob": "hunter2" }

///|
/// Issues a JWT for the given username, valid for one hour.
fn issue_token(username : String) -> String raise @jwt.JwtError {
  let exp = @env.now().to_double() / 1000.0 + 3600.0
  let claims : Json = {
    "sub": username,
    "exp": exp,
    "iss": "mocket-jwt-example",
  }
  @jwt.encode(claims, key=secret, algorithm=@jwt.HS256)
}

///|
/// Extracts and verifies the bearer token from the Authorization header.
/// Returns the decoded claims on success, or `None` when the header is missing
/// or malformed.
fn verify_token(req : @mocket.HttpRequest) -> Json? raise @jwt.JwtError {
  guard req.headers.get("Authorization") is Some(value) else { return None }
  guard value is [.. "Bearer ", .. token_view] else { return None }
  let token = token_view.to_owned()
  Some(
    @jwt.decode(
      token,
      key=secret,
      algorithm=@jwt.HS256,
      issuer="mocket-jwt-example",
    ),
  )
}

///|
/// Auth middleware: rejects requests without a valid JWT.
///
/// Public routes (`/login`, `/`) are registered before this middleware so they
/// are unaffected. Protected routes registered afterwards require a valid
/// `Authorization: Bearer <token>` header.
async fn require_auth(
  event : @mocket.MocketEvent,
  next : @mocket.MiddlewareNext,
) -> &@mocket.Responder {
  if event.req.url is ("/login" | "/") {
    return next()
  }
  try {
    match verify_token(event.req) {
      None =>
        HttpResponse(
          Unauthorized,
          body="missing or invalid Authorization header",
        ).to_responder()
      Some(claims) => {
        // Make the decoded username available to downstream handlers.
        event.res.headers["X-User"] = match claims {
          { "sub": String(username), .. } => username
          _ => ""
        }
        next()
      }
    }
  } catch {
    @jwt.JwtError::Expired => HttpResponse(Unauthorized, body="token expired")
    @jwt.JwtError::InvalidToken(_) =>
      HttpResponse(Unauthorized, body="invalid token")
    _ => HttpResponse(Unauthorized, body="unauthorized")
  }
}

///|
async fn main {
  let app = @mocket.App()

  // POST /login — public route: exchange credentials for a JWT.
  //   curl -X POST http://localhost:4000/login \
  //     -H 'Content-Type: application/json' \
  //     -d '{"username":"alice","password":"password123"}'
  app.post("/login", event => {
    let payload : Json = event.req.json() catch {
      _ => return HttpResponse(BadRequest, body="invalid JSON")
    }
    guard payload
      is { "username": String(username), "password": String(password), .. } else {
      return HttpResponse(BadRequest, body="missing username or password")
    }
    match users.get(username) {
      Some(expected) if expected == password =>
        try {
          let token = issue_token(username)
          HttpResponse(OK).json({ "token": token })
        } catch {
          _ => HttpResponse(InternalServerError, body="failed to issue token")
        }
      _ => HttpResponse(Unauthorized, body="invalid credentials")
    }
  })

  // GET / — public route: a small HTML page with a login form and instructions.
  app.get("/", _ => {
    @mocket.html(
      (
        #|<!doctype html>
        #|<html>
        #|  <body>
        #|    <h1>JWT Login Example</h1>
        #|    <form id="login">
        #|      <label>Username <input name="username" value="alice"></label>
        #|      <label>Password <input name="password" value="password123"></label>
        #|      <button type="submit">Login</button>
        #|    </form>
        #|    <p id="token"></p>
        #|    <button id="profile" disabled>Fetch /profile</button>
        #|    <p id="result"></p>
        #|    <script>
        #|      let token = null;
        #|      document.getElementById('login').onsubmit = async (e) => {
        #|        e.preventDefault();
        #|        const f = new FormData(e.target);
        #|        const res = await fetch('/login', {
        #|          method: 'POST',
        #|          headers: {'Content-Type': 'application/json'},
        #|          body: JSON.stringify({username: f.get('username'), password: f.get('password')})
        #|        });
        #|        const data = await res.json();
        #|        if (data.token) {
        #|          token = data.token;
        #|          document.getElementById('token').textContent = 'Token: ' + token.slice(0, 20) + '...';
        #|          document.getElementById('profile').disabled = false;
        #|        } else {
        #|          document.getElementById('token').textContent = 'Login failed';
        #|        }
        #|      };
        #|      document.getElementById('profile').onclick = async () => {
        #|        const res = await fetch('/profile', {
        #|          headers: {'Authorization': 'Bearer ' + token}
        #|        });
        #|        document.getElementById('result').textContent = await res.text();
        #|      };
        #|    </script>
        #|  </body>
        #|</html>
      ),
    )
  })

  // ── Everything below this line requires a valid JWT ────────────────────

  app.use_middleware(require_auth)

  // GET /profile — protected route.
  //   curl http://localhost:4000/profile \
  //     -H 'Authorization: Bearer <token>'
  app.get("/profile", event => {
    let username = event.res.headers.get("X-User").unwrap_or("").to_owned()
    HttpResponse(OK, body=({ "username": username } : Json))
  })

  // Print Server URL
  for path in app.mappings.keys() {
    println("\{path.0} http://localhost:4000\{path.1}")
  }

  // Serve
  app.listen("0.0.0.0:4000")
}
