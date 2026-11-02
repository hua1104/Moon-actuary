// Copyright 2026 hua1104. Apache-2.0.
//
// Plain-decimal formatting shared by the report writers and the SVG renderer.
// Actuarial tables are read by eye down their columns, so values stay in fixed
// decimal form and are never abbreviated into scientific notation.

///|
/// Render `value` rounded to `places` decimal places. Negative values keep
/// their sign even when rounding to zero, which matters for small reserves.
pub fn fixed(value : Double, places : Int32) -> String {
  if places <= 0 {
    let rounded = @math.round(value)
    return "\{rounded}"
  }
  let scale = @math.pow(10.0, places.to_double())
  let rounded = @math.round(value * scale)
  // The sign is taken from the input, not from the rounded value: rounding a
  // tiny negative reserve gives negative zero, and negative zero is not
  // negative, so testing `rounded` would silently lose the sign.
  let negative = value < 0.0
  let magnitude = if negative { 0.0 - rounded } else { rounded }
  let whole = @math.floor(magnitude / scale)
  let fraction = magnitude - whole * scale
  let sign = if negative { "-" } else { "" }
  sign + "\{whole}" + "." + fill_zero("\{fraction}", places)
}

///|
/// Left-pad a string with zeros until it reaches `width` characters.
fn fill_zero(text : String, width : Int32) -> String {
  let mut out = text
  while out.length() < width {
    out = "0" + out
  }
  out
}

///|
/// Render a value as a percentage with `places` decimal places.
pub fn percent(value : Double, places : Int32) -> String {
  fixed(value * 100.0, places) + "%"
}

///|
/// Right-align `value` in a field `width` characters wide, growing past it
/// rather than truncating when the content is longer.
pub fn pad_left(value : String, width : Int32) -> String {
  let mut out = value
  while out.length() < width {
    out = " " + out
  }
  out
}

///|
/// Left-align `value` in a field `width` characters wide.
pub fn pad_right(value : String, width : Int32) -> String {
  let mut out = value
  while out.length() < width {
    out = out + " "
  }
  out
}

///|
/// A horizontal rule of `width` characters of the given `pattern`. Used for
/// table rules without depending on Unicode box drawing.
pub fn rule(width : Int32, pattern : Char) -> String {
  let mut out = ""
  for _i in 0..<width {
    out = out + "\{pattern}"
  }
  out
}
