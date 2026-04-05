///|
#cfg(target="js")
#external
type HTMLVideoElement

///|
#cfg(target="js")
pub impl IsEventTarget for HTMLVideoElement

///|
#cfg(target="js")
pub impl IsNode for HTMLVideoElement

///|
#cfg(target="js")
pub impl IsElement for HTMLVideoElement

///|
#cfg(target="js")
pub impl IsHtmlElement for HTMLVideoElement

///|
#cfg(target="js")
pub impl IsHTMLMediaElement for HTMLVideoElement

///|
#cfg(target="js")
pub impl @js.Cast for HTMLVideoElement with into(value) {
  value |> ffi_to_html_video_element |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for HTMLVideoElement with from(value) {
  value |> js_identity
}
