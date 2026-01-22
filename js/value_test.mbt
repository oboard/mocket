///|
let json : Json = {
  "_id": "67a6c712bc218526d5e1b516",
  "index": 0,
  "guid": "74e69a18-680a-4a74-a401-e386c30d0a35",
  "isActive": false,
  "balance": "$3,140.03",
  "picture": "http://placehold.it/32x32",
  "age": 33,
  "eyeColor": "blue",
  "name": "Burt Dominguez",
  "gender": "male",
  "company": "GEEKWAGON",
  "email": "burtdominguez@geekwagon.com",
  "phone": "+1 (913) 583-3488",
  "address": "379 Essex Street, Fresno, Minnesota, 5304",
  "about": "Proident velit ullamco cillum occaecat irure eu proident commodo consectetur est ut elit consectetur.",
  "registered": "2020-12-06T01:54:20 -08:00",
  "latitude": 71.680916,
  "longitude": -88.552886,
  "tags": ["aute", "occaecat", "qui", "esse", "commodo", "sint", "proident"],
  "friends": [
    { "id": 0, "name": "Gilliam Mcgowan" },
    { "id": 1, "name": "Bryan Stanton" },
    { "id": 2, "name": "Jenifer Elliott" },
  ],
  "greeting": "Hello, Burt Dominguez! You have 4 unread messages.",
  "favoriteFruit": "apple",
}

///|
let json_str_pretty =
  #|{
  #|  "_id": "67a6c712bc218526d5e1b516",
  #|  "index": 0,
  #|  "guid": "74e69a18-680a-4a74-a401-e386c30d0a35",
  #|  "isActive": false,
  #|  "balance": "$3,140.03",
  #|  "picture": "http://placehold.it/32x32",
  #|  "age": 33,
  #|  "eyeColor": "blue",
  #|  "name": "Burt Dominguez",
  #|  "gender": "male",
  #|  "company": "GEEKWAGON",
  #|  "email": "burtdominguez@geekwagon.com",
  #|  "phone": "+1 (913) 583-3488",
  #|  "address": "379 Essex Street, Fresno, Minnesota, 5304",
  #|  "about": "Proident velit ullamco cillum occaecat irure eu proident commodo consectetur est ut elit consectetur.",
  #|  "registered": "2020-12-06T01:54:20 -08:00",
  #|  "latitude": 71.680916,
  #|  "longitude": -88.552886,
  #|  "tags": ["aute", "occaecat", "qui", "esse", "commodo", "sint", "proident"],
  #|  "friends": [
  #|    { "id": 0, "name": "Gilliam Mcgowan" },
  #|    { "id": 1, "name": "Bryan Stanton" },
  #|    { "id": 2, "name": "Jenifer Elliott" }
  #|  ],
  #|  "greeting": "Hello, Burt Dominguez! You have 4 unread messages.",
  #|  "favoriteFruit": "apple"
  #|}

///|
let json_val : @js.Value = (try? @js.Value::from_json_string(json_str_pretty)).unwrap()

///|
test "Value::to_json_string" {
  inspect(
    json_val.to_json_string(),
    content=(
      #|{"_id":"67a6c712bc218526d5e1b516","index":0,"guid":"74e69a18-680a-4a74-a401-e386c30d0a35","isActive":false,"balance":"$3,140.03","picture":"http://placehold.it/32x32","age":33,"eyeColor":"blue","name":"Burt Dominguez","gender":"male","company":"GEEKWAGON","email":"burtdominguez@geekwagon.com","phone":"+1 (913) 583-3488","address":"379 Essex Street, Fresno, Minnesota, 5304","about":"Proident velit ullamco cillum occaecat irure eu proident commodo consectetur est ut elit consectetur.","registered":"2020-12-06T01:54:20 -08:00","latitude":71.680916,"longitude":-88.552886,"tags":["aute","occaecat","qui","esse","commodo","sint","proident"],"friends":[{"id":0,"name":"Gilliam Mcgowan"},{"id":1,"name":"Bryan Stanton"},{"id":2,"name":"Jenifer Elliott"}],"greeting":"Hello, Burt Dominguez! You have 4 unread messages.","favoriteFruit":"apple"}
    ),
  )
}

///|
test "Value::to_json" {
  assert_eq(json_val.to_json(), json)
}

///|
test "Value::from_json" {
  assert_eq(
    @js.Value::from_json(json).to_json_string(),
    json_val.to_json_string(),
  )
}
