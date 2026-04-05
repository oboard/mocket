///|
/// https://developer.mozilla.org/en-US/docs/Web/API/HTMLElement
#cfg(target="js")
#external
type HTMLElement

///|
#cfg(target="js")
#external
type ElementInternals

///|
#cfg(target="js")
#external
type EditContext

///|
#cfg(target="js")
pub trait IsHtmlElement: IsElement {
  as_html_element(Self) -> HTMLElement = _
  // Properties
  get_access_key(Self) -> String = _
  set_access_key(Self, String) -> Unit = _
  get_access_key_label(Self) -> String = _
  get_anchor_element(Self) -> Element? = _
  get_attribute_style_map(Self) -> StylePropertyMap = _
  get_auto_capitalize(Self) -> String = _
  set_auto_capitalize(Self, String) -> Unit = _
  get_auto_focus(Self) -> Bool = _
  set_auto_focus(Self, Bool) -> Unit = _
  get_auto_correct(Self) -> Bool = _
  set_auto_correct(Self, Bool) -> Unit = _
  get_content_editable(Self) -> String = _
  set_content_editable(Self, String) -> Unit = _
  get_dataset(Self) -> DOMStringMap = _
  get_dir(Self) -> String = _
  set_dir(Self, String) -> Unit = _
  get_draggable(Self) -> Bool = _
  set_draggable(Self, Bool) -> Unit = _
  get_edit_context(Self) -> EditContext? = _
  set_edit_context(Self, EditContext?) -> Unit = _
  get_enter_key_hint(Self) -> String = _
  set_enter_key_hint(Self, String) -> Unit = _
  get_hidden(Self) -> @js.Value = _
  set_hidden(Self, @js.Value) -> Unit = _
  get_inert(Self) -> Bool = _
  set_inert(Self, Bool) -> Unit = _
  get_inner_text(Self) -> String = _
  set_inner_text(Self, String) -> Unit = _
  get_input_mode(Self) -> String = _
  set_input_mode(Self, String) -> Unit = _
  get_is_content_editable(Self) -> Bool = _
  get_lang(Self) -> String = _
  set_lang(Self, String) -> Unit = _
  get_nonce(Self) -> String = _
  set_nonce(Self, String) -> Unit = _
  get_offset_height(Self) -> Double = _
  get_offset_left(Self) -> Double = _
  get_offset_parent(Self) -> Element? = _
  get_offset_top(Self) -> Double = _
  get_offset_width(Self) -> Double = _
  get_outer_text(Self) -> String = _
  set_outer_text(Self, String) -> Unit = _
  get_popover(Self) -> String? = _
  set_popover(Self, String?) -> Unit = _
  get_spellcheck(Self) -> Bool = _
  set_spellcheck(Self, Bool) -> Unit = _
  get_style(Self) -> CSSStyleDeclaration = _
  set_style_declaration(Self, CSSStyleDeclaration) -> Unit = _
  get_tab_index(Self) -> Int = _
  set_tab_index(Self, Int) -> Unit = _
  get_title(Self) -> String = _
  set_title(Self, String) -> Unit = _
  get_translate(Self) -> Bool = _
  set_translate(Self, Bool) -> Unit = _
  get_virtual_keyboard_policy(Self) -> String = _
  set_virtual_keyboard_policy(Self, String) -> Unit = _
  get_writing_suggestions(Self) -> String = _
  set_writing_suggestions(Self, String) -> Unit = _

  // Methods
  attach_internals(Self) -> ElementInternals = _
  blur(Self) -> Unit = _
  click(Self) -> Unit = _
  focus(Self) -> Unit = _
  hide_popover(Self) -> Unit = _
  show_popover(Self) -> Unit = _
  toggle_popover(Self, Bool?) -> Bool = _
}

///|
#cfg(target="js")
pub impl IsEventTarget for HTMLElement

///|
#cfg(target="js")
pub impl @js.Cast for HTMLElement with into(value) {
  value |> ffi_to_html_element |> y => { y.to_option() }
}

///|
#cfg(target="js")
pub impl @js.Cast for HTMLElement with from(value) {
  value |> js_identity
}

///|
#cfg(target="js")
pub impl IsNode for HTMLElement

///|
#cfg(target="js")
pub impl IsElement for HTMLElement

///|
#cfg(target="js")
pub impl IsHtmlElement for HTMLElement

///|
#cfg(target="js")
impl IsHtmlElement with as_html_element(s) {
  js_identity(s)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_access_key(s) {
  ffi_html_element_get_access_key(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_access_key(s, value) {
  ffi_html_element_set_access_key(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_access_key_label(s) {
  ffi_html_element_get_access_key_label(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with get_anchor_element(s) {
  ffi_html_element_get_anchor_element(s.as_html_element()).to_option()
}

///|
#cfg(target="js")
impl IsHtmlElement with get_attribute_style_map(s) {
  ffi_html_element_get_attribute_style_map(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with get_auto_capitalize(s) {
  ffi_html_element_get_autocapitalize(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_auto_capitalize(s, value) {
  ffi_html_element_set_autocapitalize(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_auto_focus(s) {
  ffi_html_element_get_autofocus(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_auto_focus(s, value) {
  ffi_html_element_set_autofocus(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_auto_correct(s) {
  ffi_html_element_get_autocorrect(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_auto_correct(s, value) {
  ffi_html_element_set_autocorrect(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_content_editable(s) {
  ffi_html_element_get_content_editable(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_content_editable(s, value) {
  ffi_html_element_set_content_editable(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_dataset(s) {
  ffi_html_element_get_dataset(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with get_dir(s) {
  ffi_html_element_get_dir(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_dir(s, value) {
  ffi_html_element_set_dir(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_draggable(s) {
  ffi_html_element_get_draggable(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_draggable(s, value) {
  ffi_html_element_set_draggable(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_edit_context(s) {
  ffi_html_element_get_edit_context(s.as_html_element()).to_option()
}

///|
#cfg(target="js")
impl IsHtmlElement with set_edit_context(s, value) {
  ffi_html_element_set_edit_context(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_enter_key_hint(s) {
  ffi_html_element_get_enter_key_hint(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_enter_key_hint(s, value) {
  ffi_html_element_set_enter_key_hint(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_hidden(s) {
  ffi_html_element_get_hidden(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_hidden(s, value) {
  ffi_html_element_set_hidden(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_inert(s) {
  ffi_html_element_get_inert(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_inert(s, value) {
  ffi_html_element_set_inert(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_inner_text(s) {
  ffi_html_element_get_inner_text(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_inner_text(s, value) {
  ffi_html_element_set_inner_text(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_input_mode(s) {
  ffi_html_element_get_input_mode(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_input_mode(s, value) {
  ffi_html_element_set_input_mode(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_is_content_editable(s) {
  ffi_html_element_get_is_content_editable(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with get_lang(s) {
  ffi_html_element_get_lang(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_lang(s, value) {
  ffi_html_element_set_lang(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_nonce(s) {
  ffi_html_element_get_nonce(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_nonce(s, value) {
  ffi_html_element_set_nonce(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_offset_height(s) {
  ffi_html_element_get_offset_height(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with get_offset_left(s) {
  ffi_html_element_get_offset_left(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with get_offset_parent(s) {
  ffi_html_element_get_offset_parent(s.as_html_element()).to_option()
}

///|
#cfg(target="js")
impl IsHtmlElement with get_offset_top(s) {
  ffi_html_element_get_offset_top(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with get_offset_width(s) {
  ffi_html_element_get_offset_width(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with get_outer_text(s) {
  ffi_html_element_get_outer_text(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_outer_text(s, value) {
  ffi_html_element_set_outer_text(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_popover(s) {
  ffi_html_element_get_popover(s.as_html_element()).to_option()
}

///|
#cfg(target="js")
impl IsHtmlElement with set_popover(s, value) {
  ffi_html_element_set_popover(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_spellcheck(s) {
  ffi_html_element_get_spellcheck(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_spellcheck(s, value) {
  ffi_html_element_set_spellcheck(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_style(s) {
  ffi_html_element_get_style(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_style_declaration(s, value) {
  ffi_html_element_set_style_declaration(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_tab_index(s) {
  ffi_html_element_get_tab_index(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_tab_index(s, value) {
  ffi_html_element_set_tab_index(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_title(s) {
  ffi_html_element_get_title(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_title(s, value) {
  ffi_html_element_set_title(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_translate(s) {
  ffi_html_element_get_translate(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_translate(s, value) {
  ffi_html_element_set_translate(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_virtual_keyboard_policy(s) {
  ffi_html_element_get_virtual_keyboard_policy(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_virtual_keyboard_policy(s, value) {
  ffi_html_element_set_virtual_keyboard_policy(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with get_writing_suggestions(s) {
  ffi_html_element_get_writing_suggestions(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with set_writing_suggestions(s, value) {
  ffi_html_element_set_writing_suggestions(s.as_html_element(), value)
}

///|
#cfg(target="js")
impl IsHtmlElement with attach_internals(s) {
  ffi_html_element_attach_internals(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with blur(s) {
  ffi_html_element_blur(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with click(s) {
  ffi_html_element_click(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with focus(s) {
  ffi_html_element_focus(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with hide_popover(s) {
  ffi_html_element_hide_popover(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with show_popover(s) {
  ffi_html_element_show_popover(s.as_html_element())
}

///|
#cfg(target="js")
impl IsHtmlElement with toggle_popover(s, force) {
  ffi_html_element_toggle_popover(s.as_html_element(), force)
}

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_access_key(s : HTMLElement) -> String = "(s) => s.accessKey"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_access_key(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.accessKey = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_access_key_label(s : HTMLElement) -> String = "(s) => s.accessKeyLabel"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_anchor_element(
  s : HTMLElement,
) -> @js.Nullable[Element] = "(s) => s.anchorElement"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_attribute_style_map(
  s : HTMLElement,
) -> StylePropertyMap = "(s) => s.attributeStyleMap"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_autocapitalize(s : HTMLElement) -> String = "(s) => s.autocapitalize"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_autocapitalize(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.autocapitalize = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_autofocus(s : HTMLElement) -> Bool = "(s) => s.autofocus"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_autofocus(
  s : HTMLElement,
  value : Bool,
) -> Unit = "(s, value) => s.autofocus = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_autocorrect(s : HTMLElement) -> Bool = "(s) => s.autocorrect"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_autocorrect(
  s : HTMLElement,
  value : Bool,
) -> Unit = "(s, value) => s.autocorrect = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_content_editable(s : HTMLElement) -> String = "(s) => s.contentEditable"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_content_editable(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.contentEditable = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_dataset(s : HTMLElement) -> DOMStringMap = "(s) => s.dataset"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_dir(s : HTMLElement) -> String = "(s) => s.dir"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_dir(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.dir = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_draggable(s : HTMLElement) -> Bool = "(s) => s.draggable"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_draggable(
  s : HTMLElement,
  value : Bool,
) -> Unit = "(s, value) => s.draggable = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_edit_context(
  s : HTMLElement,
) -> @js.Nullable[EditContext] = "(s) => s.editContext"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_edit_context(
  s : HTMLElement,
  value : EditContext?,
) -> Unit = "(s, value) => s.editContext = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_enter_key_hint(s : HTMLElement) -> String = "(s) => s.enterKeyHint"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_enter_key_hint(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.enterKeyHint = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_hidden(s : HTMLElement) -> @js.Value = "(s) => s.hidden"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_hidden(
  s : HTMLElement,
  value : @js.Value,
) -> Unit = "(s, value) => s.hidden = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_inert(s : HTMLElement) -> Bool = "(s) => s.inert"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_inert(
  s : HTMLElement,
  value : Bool,
) -> Unit = "(s, value) => s.inert = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_inner_text(s : HTMLElement) -> String = "(s) => s.innerText"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_inner_text(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.innerText = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_input_mode(s : HTMLElement) -> String = "(s) => s.inputMode"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_input_mode(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.inputMode = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_is_content_editable(
  s : HTMLElement,
) -> Bool = "(s) => s.isContentEditable"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_lang(s : HTMLElement) -> String = "(s) => s.lang"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_lang(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.lang = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_nonce(s : HTMLElement) -> String = "(s) => s.nonce"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_nonce(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.nonce = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_offset_height(s : HTMLElement) -> Double = "(s) => s.offsetHeight"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_offset_left(s : HTMLElement) -> Double = "(s) => s.offsetLeft"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_offset_parent(
  s : HTMLElement,
) -> @js.Nullable[Element] = "(s) => s.offsetParent"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_offset_top(s : HTMLElement) -> Double = "(s) => s.offsetTop"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_offset_width(s : HTMLElement) -> Double = "(s) => s.offsetWidth"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_outer_text(s : HTMLElement) -> String = "(s) => s.outerText"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_outer_text(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.outerText = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_popover(
  s : HTMLElement,
) -> @js.Nullable[String] = "(s) => s.popover"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_popover(
  s : HTMLElement,
  value : String?,
) -> Unit = "(s, value) => s.popover = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_spellcheck(s : HTMLElement) -> Bool = "(s) => s.spellcheck"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_spellcheck(
  s : HTMLElement,
  value : Bool,
) -> Unit = "(s, value) => s.spellcheck = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_style(
  s : HTMLElement,
) -> CSSStyleDeclaration = "(s) => s.style"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_style_declaration(
  s : HTMLElement,
  value : CSSStyleDeclaration,
) -> Unit = "(s, value) => s.style = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_tab_index(s : HTMLElement) -> Int = "(s) => s.tabIndex"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_tab_index(
  s : HTMLElement,
  value : Int,
) -> Unit = "(s, value) => s.tabIndex = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_title(s : HTMLElement) -> String = "(s) => s.title"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_title(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.title = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_translate(s : HTMLElement) -> Bool = "(s) => s.translate"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_translate(
  s : HTMLElement,
  value : Bool,
) -> Unit = "(s, value) => s.translate = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_virtual_keyboard_policy(
  s : HTMLElement,
) -> String = "(s) => s.virtualKeyboardPolicy"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_virtual_keyboard_policy(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.virtualKeyboardPolicy = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_get_writing_suggestions(
  s : HTMLElement,
) -> String = "(s) => s.writingSuggestions"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_set_writing_suggestions(
  s : HTMLElement,
  value : String,
) -> Unit = "(s, value) => s.writingSuggestions = value"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_attach_internals(
  s : HTMLElement,
) -> ElementInternals = "(s) => s.attachInternals()"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_blur(s : HTMLElement) -> Unit = "(s) => s.blur()"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_click(s : HTMLElement) -> Unit = "(s) => s.click()"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_focus(s : HTMLElement) -> Unit = "(s) => s.focus()"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_hide_popover(s : HTMLElement) -> Unit = "(s) => s.hidePopover()"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_show_popover(s : HTMLElement) -> Unit = "(s) => s.showPopover()"

///|
#cfg(target="js")
extern "js" fn ffi_html_element_toggle_popover(
  s : HTMLElement,
  force : Bool?,
) -> Bool = "(s, force) => s.togglePopover(force)"
