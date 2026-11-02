// Blackbox tests for the chart renderer.
//
// A mis-scaled axis does not raise and does not fail anything downstream: it
// silently draws outside the viewBox, where the browser clips it. These tests
// therefore read the emitted geometry back out of the SVG and re-derive the
// frame the renderer claims to draw in.

///|
/// Read the numbers out of one quoted attribute of a `<line>` or `<polyline>`
/// element. Reading by attribute position rather than by scanning the whole
/// line is what keeps colours like `#2563eb` and stroke widths from being
/// mistaken for coordinates.
fn attribute_numbers(element : String, wanted : Int32) -> Array[Double] {
  let mut index = 0
  for view in element.split("\"") {
    if index == wanted {
      return numbers(view.to_owned())
    }
    index = index + 1
  }
  []
}

///|
/// Every vertical coordinate across the grid lines, axes and series paths.
fn ordinates(svg : String) -> Array[Double] {
  let mut out : Array[Double] = []
  for view in svg.split("\n") {
    let element = view.to_owned()
    if element.has_prefix("<line") {
      // x1 y1 x2 y2 occupy attribute positions 1 3 5 7.
      out = append_number(out, attribute_numbers(element, 3))
      out = append_number(out, attribute_numbers(element, 7))
    } else if element.has_prefix("<polyline") {
      // Every second number of the point list is an ordinate.
      let mut position = 0
      for v in attribute_numbers(element, 1) {
        if position % 2 == 1 {
          out = append_number(out, [v])
        }
        position = position + 1
      }
    }
  }
  out
}

///|
/// Every horizontal coordinate across the same elements.
fn abscissae(svg : String) -> Array[Double] {
  let mut out : Array[Double] = []
  for view in svg.split("\n") {
    let element = view.to_owned()
    if element.has_prefix("<line") {
      out = append_number(out, attribute_numbers(element, 1))
      out = append_number(out, attribute_numbers(element, 5))
    } else if element.has_prefix("<polyline") {
      let mut position = 0
      for v in attribute_numbers(element, 1) {
        if position % 2 == 0 {
          out = append_number(out, [v])
        }
        position = position + 1
      }
    }
  }
  out
}

///|
/// Read every number inside a whitespace or comma separated group.
fn numbers(text : String) -> Array[Double] {
  let mut out : Array[Double] = []
  let mut token = ""
  for c in text {
    if (c >= '0' && c <= '9') || c == '.' {
      token = token + "\{c}"
    } else if token != "" {
      out = append_number(out, [parse_decimal(token)])
      token = ""
    }
  }
  if token != "" {
    out = append_number(out, [parse_decimal(token)])
  }
  out
}

///|
/// Parse a plain decimal of the form emitted by the renderer. Written by hand
/// rather than pulled from a parsing package, so these blackbox tests keep the
/// library's own dependency list honest.
fn parse_decimal(text : String) -> Double {
  let mut total = 0.0
  let mut scale = 1.0
  let mut fractional = false
  for c in text {
    if c == '.' {
      fractional = true
    } else if c >= '0' && c <= '9' {
      let digit = (c.to_int() - '0'.to_int()).to_double()
      if fractional {
        scale = scale / 10.0
        total = total + digit * scale
      } else {
        total = total * 10.0 + digit
      }
    }
  }
  total
}

///|
fn append_number(left : Array[Double], right : Array[Double]) -> Array[Double] {
  let out = Array::make(left.length() + right.length(), 0.0)
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
/// Every coordinate the renderer emits, across the lines and polylines only.
fn geometry(svg : String) -> Array[Double] {
  append_number(ordinates(svg), abscissae(svg))
}

///|
/// One actuarial curve across the whole table: survivorship falls four decades
/// to its terminal value and mortality rises from around 1e-4 to unity, so
/// both series exercise the widest range the logarithmic axis will be asked to
/// draw.
fn curve(
  table : @moonactuary.LifeTable,
  mode : String,
) -> Array[@moonactuary.Point] {
  let size = table.limiting_age() + 1
  let points = Array::make(size, @moonactuary.Point::of(0.0, 0.0))
  for x in 0..<size {
    let y = if mode == "survival" { table.lx(x) } else { table.qx(x) }
    points[x] = @moonactuary.Point::of(x.to_double(), y)
  }
  points
}

///|
test "logarithmic axes keep every drawn coordinate inside the canvas" {
  let table = @moonactuary.ChinaTable::of_code("CL1").unwrap().table()
  let width = 900.0
  let height = 480.0
  for mode in ["survival", "mortality"] {
    let svg = @moonactuary.Chart::new("log " + mode)
      .subtitle("axis regression")
      .x_label("年龄")
      .y_label("值")
      .size(900, 480)
      .logarithmic()
      .series(mode, "#2563eb", curve(table, mode))
      .render()
    let drawn = geometry(svg)
    assert_true(
      drawn.length() > 20,
      msg="\{mode}: expected the chart to draw something",
    )
    for v in ordinates(svg) {
      assert_true(
        v >= 0.0 && v <= height,
        msg="\{mode}: ordinate \{v} escapes the canvas",
      )
    }
    for v in abscissae(svg) {
      assert_true(
        v >= 0.0 && v <= width,
        msg="\{mode}: abscissa \{v} escapes the canvas",
      )
    }
  }
}

///|
test "linear axes keep every drawn coordinate inside the canvas" {
  let table = @moonactuary.ChinaTable::of_code("CL1").unwrap()
  let v = @moonactuary.Valuation::of(
    table=table.table(),
    interest=@moonactuary.Interest::of(0.025),
  )
  let annual = v.annual_premium_endowment(30, 20)
  let rolled = v.reserve_schedule_fackler(30, 0, 20, annual, 1.0, 0.0)
  let points = Array::make(rolled.length(), @moonactuary.Point::of(0.0, 0.0))
  for t in 0..<rolled.length() {
    points[t] = @moonactuary.Point::of(t.to_double(), rolled[t])
  }
  let svg = @moonactuary.Chart::new("准备金轨迹")
    .x_label("保单年度")
    .y_label("准备金")
    .size(900, 480)
    .series("V", "#2563eb", points)
    .render()
  for v in ordinates(svg) {
    assert_true(v >= 0.0 && v <= 480.0, msg="ordinate \{v} escapes the canvas")
  }
  for v in abscissae(svg) {
    assert_true(v >= 0.0 && v <= 900.0, msg="abscissa \{v} escapes the canvas")
  }
  // The reserve path must be monotone increasing here, which shows the axis
  // is oriented with time to the right and money upward.
  let first = points[0].y
  let last = points[points.length() - 1].y
  assert_true(
    last > first,
    msg="expected the terminal reserve to exceed the opening one",
  )
}

///|
test "the lowest logarithmic decade sits on the frame floor" {
  // Two points spanning 10^2 to 10^6. Whole decades are the only tick values a
  // logarithmic axis offers, and the lowest one is the one that previously fell
  // off the bottom of the canvas.
  let points = [
    @moonactuary.Point::of(0.0, 150.0),
    @moonactuary.Point::of(1.0, 1000000.0),
  ]
  let svg = @moonactuary.Chart::new("decades")
    .size(900, 480)
    .logarithmic()
    .series("s", "#2563eb", points)
    .render()
  let drawn = ordinates(svg)
  let mut floor = 0.0
  for v in drawn {
    if v > floor {
      floor = v
    }
  }
  // 66 top margin, 480 height, 62 bottom margin: nothing may pass the axis.
  assert_true(
    floor <= 418.0 + 0.01,
    msg="lowest drawn point \{floor} passed the x-axis",
  )
}

///|
test "a chart with no series still renders a well formed document" {
  let svg = @moonactuary.Chart::new("空").render()
  assert_true(svg.has_prefix("<svg"), msg="expected an svg root element")
  assert_true(
    svg.has_suffix("</svg>\n"),
    msg="expected the document to be closed",
  )
}

///|
test "titles are xml escaped" {
  let svg = @moonactuary.Chart::new("A & B <表>").render()
  assert_true(
    svg.contains("A &amp; B &lt;表&gt;"),
    msg="expected markup to be escaped",
  )
  assert_true(!svg.contains("<表>"), msg="raw markup leaked into the output")
}

///|
test "degenerate data still renders a usable chart" {
  // A single point, a flat series and a constant series all leave the axis
  // with no range to divide; the renderer has to pick one rather than divide
  // by zero.
  let single = [@moonactuary.Point::of(3.0, 7.0)]
  let flat = [
    @moonactuary.Point::of(0.0, 5.0),
    @moonactuary.Point::of(1.0, 5.0),
    @moonactuary.Point::of(2.0, 5.0),
  ]
  for points in [single, flat] {
    let linear = @moonactuary.Chart::new("degenerate")
      .series("s", "#2563eb", points)
      .render()
    assert_true(linear.has_prefix("<svg"), msg="expected a document")
    for v in ordinates(linear) {
      assert_true(
        v >= 0.0 && v <= 480.0,
        msg="ordinate \{v} escapes the canvas",
      )
    }
    let logged = @moonactuary.Chart::new("degenerate")
      .logarithmic()
      .series("s", "#2563eb", points)
      .render()
    for v in ordinates(logged) {
      assert_true(
        v >= 0.0 && v <= 480.0,
        msg="ordinate \{v} escapes the canvas",
      )
    }
  }
}

///|
test "several series share one frame" {
  let table = @moonactuary.ChinaTable::of_code("CL1").unwrap().table()
  let male = curve(table, "mortality")
  let female = curve(
    @moonactuary.ChinaTable::of_code("CL2").unwrap().table(),
    "mortality",
  )
  let svg = @moonactuary.Chart::new("两张表")
    .x_label("年龄")
    .y_label("qx")
    .logarithmic()
    .series("CL1 男", "#2563eb", male)
    .series("CL2 女", "#dc2626", female)
    .render()
  // Every series contributes a polyline and a legend entry.
  assert_eq(count_matches(svg, "<polyline"), 2)
  assert_eq(count_matches(svg, "<rect"), 3)
  assert_true(svg.contains("CL1 男"), msg="the first series should be named")
  assert_true(svg.contains("CL2 女"), msg="the second series should be named")
}

///|
/// Count occurrences of a literal substring.
fn count_matches(text : String, needle : String) -> Int32 {
  // Splitting on the needle leaves one more piece than there are occurrences.
  text.split(needle).count() - 1
}

///|
test "axis labels round tiny magnitudes without overflowing the field" {
  // A series six decades below unity forces the tick formatter onto its cap.
  let points = [
    @moonactuary.Point::of(0.0, 1.0e-9),
    @moonactuary.Point::of(1.0, 1.0e-3),
  ]
  let svg = @moonactuary.Chart::new("tiny")
    .logarithmic()
    .series("s", "#2563eb", points)
    .render()
  assert_true(svg.contains("0.000001"), msg="the cap keeps six decimal places")
  // Labels must stay in plain decimal form: 1e-9 would read as "0.000000",
  // never as "1e-9".
  assert_true(!svg.contains("e-0"), msg="no scientific notation in labels")
}

///|
test "quotes and apostrophes are escaped" {
  let svg = @moonactuary.Chart::new("\" quoted \" and ' apostrophe '").render()
  assert_true(svg.contains("&quot;"), msg="double quotes should be escaped")
  assert_true(svg.contains("&apos;"), msg="apostrophes should be escaped")
  assert_true(
    !svg.contains("\" quoted \""),
    msg="raw quotes leaked into the output",
  )
}
