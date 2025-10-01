///|
test "Object::extend_object" {
  let obj = @js.Object::from_value_unchecked(
    @json.from_json({ "a": 1, "b": 2, "c": 3 }),
  )
  let obj1 = @js.Object::from_value_unchecked(
    @json.from_json({ "b": [6, 7], "d": 44, "a": 55 }),
  )
  @json.inspect(obj.extend_object(obj1).0.to_json(), content={
    "a": 55,
    "b": [6, 7],
    "c": 3,
    "d": 44,
  })
}
