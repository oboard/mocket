///|
#warnings("-unnecessary_annotation")
struct ResourceItem {
  id : Int
  name : String
} derive(ToJson, FromJson, Eq)

///|
impl Show for ResourceItem with output(self, logger) {
  logger.write_string("ResourceItem { id: \{self.id}, name: \{self.name} }")
}

///|
#warnings("-unnecessary_annotation")
struct CreateItem {
  name : String
} derive(FromJson, ToJson)

///|
async test "resource registers all CRUD routes" {
  let items : Array[ResourceItem] = [
    { id: 1, name: "Alpha" },
    { id: 2, name: "Beta" },
  ]
  let app = @crescent.Mocket()
  app.resource("/api/items", {
    list: Some(_event => @crescent.HttpResponse::ok().json_value(items)),
    get: Some(event => {
      let id = event.require_param_int("id")
      for item in items {
        if item.id == id {
          return @crescent.HttpResponse::ok().json_value(item)
        }
      }
      raise @crescent.HttpError::HttpError(NotFound, "not found")
    }),
    create: Some(event => {
      let input : CreateItem = event.json()
      let item = ResourceItem::{ id: 3, name: input.name }
      items.push(item)
      @crescent.HttpResponse::created().json_value(item)
    }),
    update: Some(event => {
      let id = event.require_param_int("id")
      let input : CreateItem = event.json()
      let item = ResourceItem::{ id, name: input.name }
      @crescent.HttpResponse::ok().json_value(item)
    }),
    delete: Some(event => {
      let _id = event.require_param_int("id")
      @crescent.HttpResponse::no_content()
    }),
  })
  let client = @crescent.TestClient(app)
  // GET /api/items — list
  let res = client.get("/api/items")
  assert_eq(res.status, OK)
  let list : Array[ResourceItem] = res.body_json()
  assert_eq(list.length(), 2)
  // GET /api/items/1 — get single
  let res2 = client.get("/api/items/1")
  assert_eq(res2.status, OK)
  let item : ResourceItem = res2.body_json()
  assert_eq(item, { id: 1, name: "Alpha" })
  // GET /api/items/999 — not found
  let res3 = client.get("/api/items/999")
  assert_eq(res3.status, NotFound)
  // POST /api/items — create
  let body = @utf8.encode(
    ({ name: "Gamma" } : CreateItem).to_json().stringify(),
  )
  let res4 = client.post("/api/items", body~)
  assert_eq(res4.status, Created)
  let created : ResourceItem = res4.body_json()
  assert_eq(created.name, "Gamma")
  // PUT /api/items/1 — update
  let body2 = @utf8.encode(
    ({ name: "Updated" } : CreateItem).to_json().stringify(),
  )
  let res5 = client.put("/api/items/1", body=body2)
  assert_eq(res5.status, OK)
  let updated : ResourceItem = res5.body_json()
  assert_eq(updated.name, "Updated")
  // DELETE /api/items/1
  let res6 = client.delete("/api/items/1")
  assert_eq(res6.status, NoContent)
}

///|
async test "resource with partial config only registers provided handlers" {
  let app = @crescent.Mocket()
  app.resource("/api/readonly", {
    list: Some(_ => @crescent.HttpResponse::ok().json_value([1, 2, 3])),
    get: None,
    create: None,
    update: None,
    delete: None,
  })
  let client = @crescent.TestClient(app)
  // GET works
  let res = client.get("/api/readonly")
  assert_eq(res.status, OK)
  // POST returns 405 (GET exists at this path, but POST doesn't)
  let res2 = client.post("/api/readonly", body=b"{}")
  assert_eq(res2.status, MethodNotAllowed)
}
