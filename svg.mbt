// Copyright 2026 hua1104. Apache-2.0.
//
// A dependency-free SVG renderer for actuarial charts.
//
// Mortality and survivorship are read on a logarithmic axis, and reserve
// trajectories are read linearly, so the renderer supports both. Nothing here
// reads files or shells out: the chart is assembled as text and returned, which
// makes it usable from the CLI, from a WASM host, or from a test.

///|
/// A single plotted observation.
pub struct Point {
  x : Double
  y : Double
}

///|
/// A labelled run of observations drawn as one polyline.
pub struct Series {
  name : String
  colour : String
  points : Array[Point]
}

///|
/// A chart: one or more series sharing axes.
pub struct Chart {
  title : String
  subtitle : String
  x_label : String
  y_label : String
  series : Array[Series]
  /// Whether the vertical axis is drawn with a logarithmic scale.
  logarithmic : Bool
  width : Int32
  height : Int32
}

///|
/// A chart with sensible defaults, all of which can be overridden by rebuilding
/// the value with the builders below.
pub fn Chart::new(title : String) -> Chart {
  Chart::{
    title,
    subtitle: "",
    x_label: "",
    y_label: "",
    series: [],
    logarithmic: false,
    width: 900,
    height: 480,
  }
}

///|
/// Set the chart subtitle.
pub fn Chart::subtitle(self : Chart, text : String) -> Chart {
  Chart::{ ..self, subtitle: text, }
}

///|
/// Label the horizontal axis.
pub fn Chart::x_label(self : Chart, text : String) -> Chart {
  Chart::{ ..self, x_label: text, }
}

///|
/// Label the vertical axis.
pub fn Chart::y_label(self : Chart, text : String) -> Chart {
  Chart::{ ..self, y_label: text, }
}

///|
/// Draw the vertical axis on a logarithmic scale.
pub fn Chart::logarithmic(self : Chart) -> Chart {
  Chart::{ ..self, logarithmic: true, }
}

///|
/// Override the output pixel size.
pub fn Chart::size(self : Chart, width : Int32, height : Int32) -> Chart {
  Chart::{ ..self, width, height, }
}

///|
/// Append a series to the chart.
pub fn Chart::series(
  self : Chart,
  name : String,
  colour : String,
  points : Array[Point],
) -> Chart {
  let mut all = []
  for s in self.series {
    all = concat(all, [s])
  }
  all = concat(all, [Series::{ name, colour, points, }])
  Chart::{ ..self, series: all, }
}

///|
/// Construct a point.
pub fn Point::of(x : Double, y : Double) -> Point {
  Point::{ x, y, }
}

///|
/// Series are built up in order, so append rather than rely on a mutable field.
fn concat(left : Array[Series], right : Array[Series]) -> Array[Series] {
  let out = Array::make(left.length() + right.length(), Series::{
    name: "",
    colour: "",
    points: [],
  })
  let mut i = 0
  for v in left {
    out[i] = v
    i = i + 1
  }
  for v in right {
    out[i] = v
    i = i + 1
  }
  out
}

///|
/// Escape text destined for an XML text node or attribute.
fn escape(text : String) -> String {
  let mut out = ""
  for c in text {
    if c == '&' {
      out = out + "&amp;"
    } else if c == '<' {
      out = out + "&lt;"
    } else if c == '>' {
      out = out + "&gt;"
    } else if c == '"' {
      out = out + "&quot;"
    } else if c == '\'' {
      out = out + "&apos;"
    } else {
      out = out + "\{c}"
    }
  }
  out
}

///|
/// Choose how many decimal places a tick label needs to stay readable. Small
/// ticks need more places than large ones.
fn tick_places(value : Double) -> Int32 {
  let magnitude = value.abs()
  if magnitude == 0.0 {
    0
  } else if magnitude >= 10.0 {
    0
  } else if magnitude >= 1.0 {
    1
  } else {
    let exponent = 0.0 - @math.floor(@math.log10(magnitude))
    let places = exponent.to_int()
    if places > 6 {
      6
    } else {
      places
    }
  }
}

///|
/// Render the chart to a standalone SVG document.
pub fn Chart::render(self : Chart) -> String {
  let margin_left = 84.0
  let margin_right = 28.0
  let margin_top = 66.0
  let margin_bottom = 62.0
  let width = self.width.to_double()
  let height = self.height.to_double()
  let plot_w = width - margin_left - margin_right
  let plot_h = height - margin_top - margin_bottom
  let bounds = self.bounds()
  let x_min = bounds.0
  let x_max = bounds.1
  let y_min = bounds.2
  let y_max = bounds.3
  let x_span = if x_max > x_min { x_max - x_min } else { 1.0 }
  // Tick generation and point projection must agree on exactly one vertical
  // domain, otherwise the outermost grid line lands off the canvas.
  let (domain_lo, domain_hi) = self.y_axis(y_min, y_max)
  let project_x = fn(v : Double) -> Double {
    margin_left + clamp01((v - x_min) / x_span) * plot_w
  }
  let project_y = fn(v : Double) -> Double {
    let value = if self.logarithmic { @math.log10(max_positive(v)) } else { v }
    let span = domain_hi - domain_lo
    let fraction = if span > 0.0 {
      clamp01((value - domain_lo) / span)
    } else {
      0.5
    }
    margin_top + plot_h - fraction * plot_h
  }
  let mut body = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{self.width}\" height=\"\{self.height}\" viewBox=\"0 0 \{self.width} \{self.height}\" font-family=\"-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif\">\n"
  body = body +
    "<rect width=\"\{self.width}\" height=\"\{self.height}\" fill=\"#ffffff\"/>\n"
  body = body +
    "<text x=\"\{margin_left}\" y=\"30\" font-size=\"17\" font-weight=\"600\" fill=\"#101828\">\{escape(self.title)}</text>\n"
  if self.subtitle != "" {
    body = body +
      "<text x=\"\{margin_left}\" y=\"50\" font-size=\"12.5\" fill=\"#667085\">\{escape(self.subtitle)}</text>\n"
  }
  // Horizontal grid and y tick labels.
  for tick in self.y_ticks(y_min, y_max) {
    let py = project_y(tick)
    body = body +
      "<line x1=\"\{margin_left}\" y1=\"\{fixed(py, 2)}\" x2=\"\{fixed(margin_left + plot_w, 2)}\" y2=\"\{fixed(py, 2)}\" stroke=\"#eaecf0\" stroke-width=\"1\"/>\n"
    body = body +
      "<text x=\"\{fixed(margin_left - 9.0, 2)}\" y=\"\{fixed(py + 4.0, 2)}\" font-size=\"11.5\" fill=\"#667085\" text-anchor=\"end\">\{escape(fixed(tick, tick_places(tick)))}</text>\n"
  }
  // X ticks.
  for tick in linear_ticks(x_min, x_max, 8) {
    let px = project_x(tick)
    body = body +
      "<text x=\"\{fixed(px, 2)}\" y=\"\{fixed(margin_top + plot_h + 22.0, 2)}\" font-size=\"11.5\" fill=\"#667085\" text-anchor=\"middle\">\{escape(fixed(tick, 0))}</text>\n"
  }
  // Axes.
  body = body +
    "<line x1=\"\{margin_left}\" y1=\"\{margin_top}\" x2=\"\{margin_left}\" y2=\"\{fixed(margin_top + plot_h, 2)}\" stroke=\"#475467\" stroke-width=\"1.2\"/>\n"
  body = body +
    "<line x1=\"\{margin_left}\" y1=\"\{fixed(margin_top + plot_h, 2)}\" x2=\"\{fixed(margin_left + plot_w, 2)}\" y2=\"\{fixed(margin_top + plot_h, 2)}\" stroke=\"#475467\" stroke-width=\"1.2\"/>\n"
  if self.x_label != "" {
    body = body +
      "<text x=\"\{fixed(margin_left + plot_w / 2.0, 2)}\" y=\"\{fixed(height - 12.0, 2)}\" font-size=\"12.5\" fill=\"#344054\" text-anchor=\"middle\">\{escape(self.x_label)}</text>\n"
  }
  if self.y_label != "" {
    body = body +
      "<text x=\"18\" y=\"\{fixed(margin_top + plot_h / 2.0, 2)}\" font-size=\"12.5\" fill=\"#344054\" text-anchor=\"middle\" transform=\"rotate(-90 18 \{fixed(margin_top + plot_h / 2.0, 2)})\">\{escape(self.y_label)}</text>\n"
  }
  // Series.
  for s in self.series {
    let mut coords = ""
    for p in s.points {
      if coords != "" {
        coords = coords + " "
      }
      coords = coords +
        "\{fixed(project_x(p.x), 2)},\{fixed(project_y(p.y), 2)}"
    }
    body = body +
      "<polyline points=\"\{coords}\" fill=\"none\" stroke=\"\{s.colour}\" stroke-width=\"2.1\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>\n"
  }
  // Legend, laid out left to right beneath the plot on a second row when wide.
  let mut leg_x = margin_left
  let leg_y = margin_top - 14.0
  for s in self.series {
    body = body +
      "<rect x=\"\{fixed(leg_x, 2)}\" y=\"\{fixed(leg_y - 8.0, 2)}\" width=\"11\" height=\"11\" rx=\"2\" fill=\"\{s.colour}\"/>\n"
    body = body +
      "<text x=\"\{fixed(leg_x + 16.0, 2)}\" y=\"\{fixed(leg_y + 1.5, 2)}\" font-size=\"12\" fill=\"#344054\">\{escape(s.name)}</text>\n"
    leg_x = leg_x + 22.0 + s.name.length().to_double() * 6.6
  }
  body + "</svg>\n"
}

///|
/// The data extent across all series, expanded slightly so the extremes are not
/// drawn flush against the frame.
fn Chart::bounds(self : Chart) -> (Double, Double, Double, Double) {
  let mut x_min = 0.0
  let mut x_max = 1.0
  let mut y_min = 0.0
  let mut y_max = 1.0
  let mut started = false
  for s in self.series {
    for p in s.points {
      if started {
        if p.x < x_min {
          x_min = p.x
        }
        if p.x > x_max {
          x_max = p.x
        }
        if p.y < y_min {
          y_min = p.y
        }
        if p.y > y_max {
          y_max = p.y
        }
      } else {
        x_min = p.x
        x_max = p.x
        y_min = p.y
        y_max = p.y
        started = true
      }
    }
  }
  if !started {
    (0.0, 1.0, 0.0, 1.0)
  } else if x_min == x_max {
    (x_min - 0.5, x_max + 0.5, y_min, y_max)
  } else {
    (x_min, x_max, y_min, y_max)
  }
}

///|
/// The vertical domain actually plotted. On a logarithmic axis this is widened
/// out to whole decades so that ticks are round powers of ten; on a linear axis
/// the degenerate single-valued case is given room to breathe. Every consumer
/// of the vertical axis goes through here.
fn Chart::y_axis(self : Chart, lo : Double, hi : Double) -> (Double, Double) {
  if self.logarithmic {
    let low = @math.floor(@math.log10(max_positive(lo)))
    let high = @math.ceil(@math.log10(max_positive(hi)))
    if high > low {
      (low, high)
    } else {
      (low, low + 1.0)
    }
  } else if hi > lo {
    (lo, hi)
  } else {
    (lo - 0.5, lo + 0.5)
  }
}

///|
/// Keep a projection ratio inside the unit interval, so nothing is ever drawn
/// outside the plot frame however extreme the data.
fn clamp01(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
/// Vertical tick positions, either by decade on a log axis or evenly spaced.
fn Chart::y_ticks(self : Chart, lo : Double, hi : Double) -> Array[Double] {
  let (domain_lo, domain_hi) = self.y_axis(lo, hi)
  if self.logarithmic {
    let mut out : Array[Double] = []
    let mut k = domain_lo
    while k <= domain_hi + 0.5 {
      out = push(out, @math.pow(10.0, k))
      k = k + 1.0
    }
    out
  } else {
    linear_ticks(domain_lo, domain_hi, 7)
  }
}

///|
/// Evenly spaced ticks snapped to a 1-2-5 step so labels stay round numbers.
fn linear_ticks(lo : Double, hi : Double, target : Int32) -> Array[Double] {
  let span = hi - lo
  if span <= 0.0 {
    return [lo]
  }
  let raw = span / target.to_double()
  let magnitude = @math.pow(10.0, @math.floor(@math.log10(raw)))
  let norm = raw / magnitude
  let step = if norm <= 1.0 {
    magnitude
  } else if norm <= 2.0 {
    2.0 * magnitude
  } else if norm <= 5.0 {
    5.0 * magnitude
  } else {
    10.0 * magnitude
  }
  let mut out : Array[Double] = []
  let mut v = @math.ceil(lo / step) * step
  while v <= hi + step * 0.001 {
    out = push(out, v)
    v = v + step
  }
  out
}

///|
/// A logarithmic axis cannot plot non-positive values, so clamp upward before
/// taking a log.
fn max_positive(value : Double) -> Double {
  if value > 1.0e-12 {
    value
  } else {
    1.0e-12
  }
}

///|
/// Append to an array without mutating the original.
fn push(source : Array[Double], value : Double) -> Array[Double] {
  let out = Array::make(source.length() + 1, 0.0)
  let mut i = 0
  for v in source {
    out[i] = v
    i = i + 1
  }
  out[i] = value
  out
}
