///|
async fn main {
  try {
    let str : String = @fetch.get("https://api64.ipify.org/").read_body()
    println(str)
  } catch {
    e => println(e)
  }
}
