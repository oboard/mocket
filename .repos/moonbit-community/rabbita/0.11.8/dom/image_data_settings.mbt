///|
#cfg(target="js")
#external
type ImageDataSettings

///|
#cfg(target="js")
pub extern "js" fn ImageDataSettings::new(
  color_space : PredefinedColorSpace,
) -> ImageDataSettings = "(colorSpace) => ({colorSpace: colorSpace})"
