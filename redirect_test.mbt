///|
test "redirect sets location header" {
  let res = HttpResponse::redirect("/new-path")
  inspect(res.status_code, content="MovedPermanently")
  inspect(res.headers.get("Location"), content="Some(\"/new-path\")")
}

///|
test "redirect_temporary sets location header" {
  let res = HttpResponse::redirect_temporary("/temp-path")
  inspect(res.status_code, content="Found")
  inspect(res.headers.get("Location"), content="Some(\"/temp-path\")")
}

///|
test "redirect_307 sets location header" {
  let res = HttpResponse::redirect_307("/preserve-method")
  inspect(res.status_code, content="TemporaryRedirect")
  inspect(res.headers.get("Location"), content="Some(\"/preserve-method\")")
}

///|
test "redirect_308 sets location header" {
  let res = HttpResponse::redirect_308("/permanent-preserve")
  inspect(res.status_code, content="PermanentRedirect")
  inspect(res.headers.get("Location"), content="Some(\"/permanent-preserve\")")
}
