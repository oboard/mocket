///|
#cfg(target="js")
pub using @cmd {perform, attempt, effect, delay}

///|
pub using @cmd {none, batch}

///|
pub type Cmd = @cmd.Cmd

///|
pub type Html = @html.Html

///|
/// Create an application from a root `Cell`.
///
/// Use `simple_cell()`, `static_cell()`, `cell()`, `cell_with_dispatch()` to create a cell.
/// Call `mount` to attach it to a DOM element.
/// Optionally call `with_route` to install routing callbacks.
/// 
/// **For beginners, `simple_cell` is recommended. See its documentation for more details.**
/// 
/// ## Example
/// 
/// ```moonbit check
/// test "minimal static page" {
///   let app = @rabbita.static_cell(div("hello world"))
///   ignore(app)
///   // use `@rabbita.new(app).mount("id")` in client
/// }
/// ```
#cfg(target="js")
pub fn new(root : Cell) -> App {
  let sandbox = @runtime.Sandbox::new(root.0)
  App::{ sandbox, init_cmd: None }
}

///|
/// Configure routing callbacks for this app.
///
/// - `url_changed` is triggered for browser history navigation and when
///   `push_url` / `replace_url` commands are used.
/// - `url_request` is triggered when captured links `@html.a()` are clicked.
///
/// If the app is already mounted, a `url_changed` command for the current URL
/// will be enqueued immediately.
#cfg(target="js")
pub fn App::with_route(
  self : Self,
  url_changed? : (@url.Url) -> Cmd,
  url_request? : (@url.UrlRequest) -> Cmd,
) -> Unit {
  @dom.window()
  .to_event_target()
  .add_event_listener("popstate", _ => {
    guard (try? @url.parse(@dom.window().current_url())) is Ok(url)
    match url_changed {
      Some(f) => self.sandbox.add_cmds(f(url).to_array())
      None => ()
    }
  })
  self.sandbox.on_url_changed = url_changed.map(f => url => f(url).to_array())
  self.sandbox.on_url_request = url_request.map(f => url => f(url).to_array())
  if self.sandbox.mount != "" {
    self.trigger_initial_url_changed()
  }
}

///|
/// Registers a one-shot command to be queued when `mount` runs.
/// This API is still evolving and may change in future releases.
#cfg(target="js")
#internal(unstable, "Experimental API")
pub fn App::with_init(self : Self, cmd : Cmd) -> Unit {
  self.init_cmd = Some(cmd)
}

///|
/// Mount the app into the DOM element identified by `element_id`.
///
/// This initializes the runtime and schedules the first render flush.
/// If routing is configured, the current URL is also dispatched on mount.
#cfg(target="js")
pub fn App::mount(self : Self, element_id : String) -> Unit {
  self.sandbox.mount = element_id
  self.trigger_initial_url_changed()
  @dom.document()
  .get_element_by_id(element_id)
  .unwrap()
  .set_inner_html("<div></div>")
  if self.init_cmd is Some(cmd) {
    self.sandbox.add_cmds(cmd.to_array())
    self.init_cmd = None
  }
  self.sandbox.initialize()
  self.sandbox.flush()
}

///|
#cfg(target="js")
fn App::trigger_initial_url_changed(self : Self) -> Unit {
  if self.sandbox.on_url_changed is Some(_) {
    guard (try? @url.parse(@dom.window().current_url())) is Ok(url)
    self.sandbox.add_url_changed(url)
  }
}

///|
/// A running Rabbita application.
#cfg(target="js")
struct App {
  sandbox : @runtime.Sandbox
  mut init_cmd : Cmd?
}

///|
/// Render a `Cell` tree into an HTML string.
///
/// This is the server-side rendering entrypoint for Rabbita. It evaluates
/// view and serializes the resulting virtual DOM into static HTML.
///
/// Hydration is currently not supported. If you later call `mount` on the
/// client, Rabbita will do a fresh client-side render instead of attaching to
/// the existing server-rendered DOM.
///
/// ## Example
///
/// ```mbt check
/// #warnings("-alert_unstable")
/// test "render html to string" {
///   enum Msg {}
///   struct Model {
///     todos : Array[String]
///   }
///   let page = @rabbita.simple_cell(
///     model={ todos: ["todo1", "todo2"] },
///     update=(_ : Msg, model) => model,
///     view=(_, model) => ul(model.todos.map(x => li(x))),
///   )
///   inspect(
///     @rabbita.render_to_string(page),
///     content=(
///       #|<ul><li>todo1</li><li>todo2</li></ul>
///     ),
///   )
/// }
/// ```
#internal(unstable, "Experimental API")
pub fn render_to_string(root : Cell) -> String {
  @runtime.server_side_render(root.0)
}
