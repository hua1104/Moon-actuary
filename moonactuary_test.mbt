// Blackbox tests. These pin the library against values published alongside
// CL(2010-2013), so a regression in the survivorship recursion cannot pass
// unnoticed.

///|
/// Assert that `actual` sits within `tol` of `expected`.
fn close(actual : Double, expected : Double, tol : Double) -> Unit raise {
  let diff = if actual > expected {
    actual - expected
  } else {
    expected - actual
  }
  assert_true(
    diff <= tol,
    msg="expected \{expected} within \{tol}, got \{actual}",
  )
}

///|
/// Assert that `actual` agrees with `expected` to `places` decimal places.
fn agrees(actual : Double, expected : Double, places : Int32) -> Unit raise {
  let scale = @math.pow(10.0, places.to_double())
  close(actual, expected, 0.5 / scale)
}

///|
/// The survivorship columns of CL1 published in 《保险学》 teaching material
/// (see https://cjxy.sdust.edu.cn/info/1111/2891.htm), tabulated from qx at
/// radix 1,000,000 under the uniform distribution of deaths.
test "CL1 reproduces the published survivorship columns" {
  let t = @moonactuary.ChinaTable::of_code("CL1").unwrap().table()
  // Head of the table: lx, dx, Lx, Tx and ex match the textbook row for row.
  close(t.lx(0), 1000000.0, 0.5)
  close(t.dx(0), 867.0, 0.5)
  close(t.person_years(0), 999567.0, 1.0)
  close(t.total_person_years(0), 76420142.0, 1.0)
  agrees(t.expectation(0), 76.42, 2)
  close(t.lx(1), 999133.0, 1.0)
  close(t.dx(1), 614.0, 0.5)
  close(t.person_years(1), 998826.0, 1.0)
  close(t.total_person_years(1), 75420575.0, 1.0)
  agrees(t.expectation(1), 75.49, 2)
  close(t.lx(2), 998519.0, 1.0)
  close(t.dx(2), 444.0, 0.5)
  close(t.person_years(2), 998296.0, 1.0)
  close(t.total_person_years(2), 74421750.0, 1.0)
  agrees(t.expectation(2), 74.53, 2)
  agrees(t.expectation(3), 73.57, 2)
  agrees(t.expectation(4), 72.59, 2)
  agrees(t.expectation(5), 71.61, 2)
  // Tail of the table, where rounding in the published lx is most visible.
  close(t.lx(101), 1658.0, 1.0)
  close(t.dx(101), 790.0, 1.0)
  close(t.person_years(101), 1263.0, 1.0)
  close(t.total_person_years(101), 2409.0, 1.0)
  agrees(t.expectation(101), 1.45, 2)
  close(t.lx(102), 868.0, 1.0)
  close(t.person_years(102), 648.0, 1.0)
  agrees(t.expectation(102), 1.32, 2)
  close(t.lx(103), 428.0, 1.0)
  close(t.person_years(103), 313.0, 1.0)
  agrees(t.expectation(103), 1.16, 2)
  close(t.lx(104), 198.0, 1.0)
  close(t.person_years(104), 142.0, 1.0)
  agrees(t.expectation(104), 0.93, 2)
  // The limiting age: all 85 survivors die within age 105, contributing half
  // a person-year each.
  close(t.lx(105), 85.0, 1.0)
  close(t.dx(105), 85.0, 1.0)
  close(t.person_years(105), 43.0, 1.0)
  agrees(t.expectation(105), 0.50, 2)
  assert_eq(t.limiting_age(), 105)
}

///|
/// Every life must be dead by omega + 1, so the final row exhausts lx.
test "the table terminates at the limiting age" {
  for c in @moonactuary.all_china_tables() {
    let t = c.table()
    assert_eq(t.limiting_age(), 105)
    assert_true(t.qx(105) == 1.0)
    close(t.lx(105), t.dx(105), 1.0e-9 * t.lx(105) + 1.0e-9)
  }
}

///|
/// l[x+1] = l[x] - d[x] across the whole table.
test "survivorship recurses forward" {
  let t = @moonactuary.ChinaTable::of_code("CL1").unwrap().table()
  for x in 0..<105 {
    close(t.lx(x) - t.dx(x), t.lx(x + 1), 1.0e-6)
  }
}

///|
/// T[x] = L[x] + T[x+1] across the whole table.
test "person-years recurse backward" {
  let t = @moonactuary.ChinaTable::of_code("CL1").unwrap().table()
  for x in 0..<105 {
    close(
      t.person_years(x) + t.total_person_years(x + 1),
      t.total_person_years(x),
      1.0e-6,
    )
  }
}

///|
/// Under UDD the curtate expectation sits exactly half a year below the
/// complete expectation, the textbook identity e_x = e_x(cur) + 1/2.
test "curtate expectation is half a year below complete under UDD" {
  let t = @moonactuary.ChinaTable::of_code("CL1").unwrap().table()
  for x in [0, 1, 10, 30, 60, 90] {
    close(t.expectation(x) - t.curtate_expectation(x), 0.5, 1.0e-6)
  }
}

///|
/// Business-line ordering. Pension lives are self-selected for longevity and
/// outlive protection business by several years. The SOA report on Chinese
/// occupation-specific tables gives curtate future lifetime at 20 of 56.43,
/// 60.24 and 62.94 years for protection, saving and annuity business, which
/// our construction reproduces exactly.
test "life expectancy orders by business line and sex" {
  let cl1 = @moonactuary.ChinaTable::of_code("CL1").unwrap().table()
  let cl3 = @moonactuary.ChinaTable::of_code("CL3").unwrap().table()
  let cl5 = @moonactuary.ChinaTable::of_code("CL5").unwrap().table()
  let cl2 = @moonactuary.ChinaTable::of_code("CL2").unwrap().table()
  let cl6 = @moonactuary.ChinaTable::of_code("CL6").unwrap().table()
  agrees(cl1.curtate_expectation(20), 56.43, 2)
  agrees(cl3.curtate_expectation(20), 60.24, 2)
  agrees(cl5.curtate_expectation(20), 62.94, 2)
  // Pension outlives non-pension; women outlive men on every business line.
  assert_true(cl5.expectation(0) > cl3.expectation(0))
  assert_true(cl3.expectation(0) > cl1.expectation(0))
  assert_true(cl2.expectation(0) > cl1.expectation(0))
  assert_true(cl6.expectation(0) > cl5.expectation(0))
  // Remaining lifetime declines monotonically with attained age.
  for c in @moonactuary.all_china_tables() {
    let t = c.table()
    for x in 0..<105 {
      assert_true(t.expectation(x) >= t.expectation(x + 1))
    }
  }
}

///|
/// tp_x agrees with the ratio l[x+t]/l[x], and deferred probabilities
/// decompose consistently with it.
test "survival and deferred death probabilities are consistent" {
  let t = @moonactuary.ChinaTable::of_code("CL2").unwrap().table()
  agrees(t.survival(30, 10), t.lx(40) / t.lx(30), 12)
  agrees(t.death_probability(30, 10), 1.0 - t.lx(40) / t.lx(30), 12)
  agrees(
    t.deferred_death_probability(30, 10),
    t.lx(40) / t.lx(30) * t.qx(40),
    12,
  )
  // Reaching age 105 is possible but vanishingly rare, and no one survives a
  // further year beyond the limiting age.
  agrees(t.death_probability(30, 75), 1.0 - t.lx(105) / t.lx(30), 12)
  assert_true(t.survival(30, 76) == 0.0)
  assert_true(t.death_probability(30, 76) == 1.0)
}

///|
/// Fractional age assumptions shift Lx in the direction theory predicts: UDD
/// counts the most person-years, then constant force, then Balducci, because
/// lx is linear under UDD but convex within the year under the other two.
test "fractional age assumptions shift person-years predictably" {
  let udd = @moonactuary.ChinaTable::of_code("CL1")
    .unwrap()
    .table(fraction=@moonactuary.FractionalAge::parse("udd").unwrap())
  let cfm = @moonactuary.ChinaTable::of_code("CL1")
    .unwrap()
    .table(fraction=@moonactuary.FractionalAge::parse("cfm").unwrap())
  let bal = @moonactuary.ChinaTable::of_code("CL1")
    .unwrap()
    .table(fraction=@moonactuary.FractionalAge::parse("balducci").unwrap())
  for x in [0, 20, 60, 100] {
    assert_true(udd.person_years(x) > cfm.person_years(x))
    assert_true(cfm.person_years(x) > bal.person_years(x))
    assert_true(cfm.person_years(x) > 0.0)
    assert_true(udd.person_years(x) <= udd.lx(x))
  }
  // Rescaling the radix scales every survivorship column linearly and leaves
  // the expectation of life untouched.
  let small = @moonactuary.ChinaTable::of_code("CL1")
    .unwrap()
    .table(radix=1000.0)
  agrees(small.lx(40) * 1000.0, udd.lx(40), 6)
  agrees(small.expectation(40), udd.expectation(40), 9)
}
