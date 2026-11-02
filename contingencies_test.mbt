// Copyright 2026 hua1104. Apache-2.0.
//
// Blackbox tests for the survivorship model and the insurance functions,
// concentrating on the edges the textbook examples do not reach: out-of-range
// ages, the three fractional age assumptions, degenerate terms, and the
// continuous and varying benefits that only appear in the more exotic products.

///|
fn contingency_near(
  actual : Double,
  expected : Double,
  tol : Double,
) -> Unit raise {
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
/// A short table with a mortality rate anyone can check by hand: 10% a year at
/// every age, from a radix of 1,000, so l0 l1 l2 = 1000 900 810.
fn flat_qx() -> Array[Double] {
  [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 1.0]
}

///|
test "out of range ages are handled without indexing past the table" {
  let t = @moonactuary.LifeTable::from_qx(qx=flat_qx())
  let omega = t.limiting_age()
  contingency_near(t.qx(-1), 0.0, 0.0)
  contingency_near(t.qx(omega + 1), 1.0, 0.0)
  contingency_near(t.lx(-1), 0.0, 0.0)
  contingency_near(t.lx(omega + 1), 0.0, 0.0)
  contingency_near(t.dx(-1), 0.0, 0.0)
  contingency_near(t.dx(omega + 1), 0.0, 0.0)
  contingency_near(t.person_years(-1), 0.0, 0.0)
  contingency_near(t.person_years(omega + 1), 0.0, 0.0)
  contingency_near(t.total_person_years(-1), 0.0, 0.0)
  contingency_near(t.total_person_years(omega + 1), 0.0, 0.0)
  contingency_near(t.expectation(-1), 0.0, 0.0)
  contingency_near(t.expectation(omega + 1), 0.0, 0.0)
  contingency_near(t.curtate_expectation(-1), 0.0, 0.0)
  contingency_near(t.survival(-1, 5), 0.0, 0.0)
  contingency_near(t.survival(omega + 1, 5), 0.0, 0.0)
  // Survival over a horizon that runs past omega is impossible.
  contingency_near(t.survival(omega - 1, 5), 0.0, 0.0)
  // And a non-positive horizon leaves the life untouched.
  contingency_near(t.survival(0, 0), 1.0, 0.0)
  contingency_near(t.survival(0, -3), 1.0, 0.0)
}

///|
test "the survivorship recursion is exactly the one from the definitions" {
  let t = @moonactuary.LifeTable::from_qx(qx=flat_qx(), radix=1000.0)
  contingency_near(t.lx(0), 1000.0, 1.0e-9)
  contingency_near(t.lx(1), 900.0, 1.0e-9)
  contingency_near(t.lx(2), 810.0, 1.0e-9)
  contingency_near(t.dx(0), 100.0, 1.0e-9)
  contingency_near(t.dx(1), 90.0, 1.0e-9)
  contingency_near(t.px(0), 0.9, 1.0e-12)
  contingency_near(t.radix(), 1000.0, 0.0)
  // Under UDD the person-years of a year are the survivors minus half the deaths.
  contingency_near(t.person_years(0), 950.0, 1.0e-9)
  contingency_near(t.person_years(1), 855.0, 1.0e-9)
}

///|
test "survival and death probabilities compose" {
  let t = @moonactuary.ChinaTable::of_code("CL1").unwrap().table()
  contingency_near(t.survival(40, 1), t.px(40), 1.0e-12)
  contingency_near(t.death_probability(40, 0), 0.0, 0.0)
  contingency_near(t.death_probability(40, 1), t.qx(40), 1.0e-12)
  // Dying within two years is dying in the first year or surviving it and
  // dying in the second.
  let two_year = t.qx(40) + t.px(40) * t.qx(41)
  contingency_near(t.death_probability(40, 2), two_year, 1.0e-12)
  contingency_near(
    t.deferred_death_probability(40, 3),
    t.survival(40, 3) * t.qx(43),
    1.0e-12,
  )
  // Probabilities stay inside the unit interval across the whole table.
  for x in 0..<(t.limiting_age() + 1) {
    let p = t.survival(x, 10)
    assert_true(
      p >= 0.0 && p <= 1.0,
      msg="survival probability \{p} out of range",
    )
    let q = t.death_probability(x, 10)
    assert_true(q >= 0.0 && q <= 1.0, msg="death probability \{q} out of range")
  }
}

///|
test "the three fractional age assumptions order the person-years" {
  let qx = flat_qx()
  let udd = @moonactuary.FractionalAge::parse("udd").unwrap()
  let cfm = @moonactuary.FractionalAge::parse("cfm").unwrap()
  let hyperbolic = @moonactuary.FractionalAge::parse("balducci").unwrap()
  let udd_table = @moonactuary.LifeTable::from_qx(qx~, fraction=udd)
  let cfm_table = @moonactuary.LifeTable::from_qx(qx~, fraction=cfm)
  let balducci_table = @moonactuary.LifeTable::from_qx(qx~, fraction=hyperbolic)
  // Person-years must always lie between the survivors at the two year ends.
  for x in [0, 1, 2] {
    let hi = udd_table.lx(x)
    let lo = udd_table.lx(x + 1)
    for t in [udd_table, cfm_table, balducci_table] {
      let l = t.person_years(x)
      assert_true(
        l <= hi && l >= lo,
        msg="person years \{l} outside [\{lo},\{hi}]",
      )
    }
    // Uniform deaths spreads deaths evenly and so gives the largest total; the
    // hyperbolic assumption concentrates them latest and gives the least.
    assert_true(
      udd_table.person_years(x) > cfm_table.person_years(x),
      msg="UDD person years should exceed constant force",
    )
    assert_true(
      cfm_table.person_years(x) > balducci_table.person_years(x),
      msg="constant force person years should exceed hyperbolic",
    )
  }
  // Each table records the assumption it was built under.
  assert_true(
    udd_table.fraction() is @moonactuary.FractionalAge::UniformDeaths,
    msg="the assumption should be recorded on the table",
  )
  assert_true(
    cfm_table.fraction() is @moonactuary.FractionalAge::ConstantForce,
    msg="the assumption should be recorded on the table",
  )
  assert_true(
    balducci_table.fraction() is @moonactuary.FractionalAge::Hyperbolic,
    msg="the assumption should be recorded on the table",
  )
}

///|
test "fractional age assumptions are parsed by name" {
  let parse = @moonactuary.FractionalAge::parse
  assert_true(parse("udd") is Some(_), msg="udd should parse")
  assert_true(parse("UDD") is Some(_), msg="parsing should ignore case")
  assert_true(parse("uniform") is Some(_), msg="uniform should parse")
  assert_true(parse("cfm") is Some(_), msg="cfm should parse")
  assert_true(
    parse("constant_force") is Some(_),
    msg="constant force should parse",
  )
  assert_true(parse("balducci") is Some(_), msg="balducci should parse")
  assert_true(parse("hyperbolic") is Some(_), msg="hyperbolic should parse")
  assert_true(
    parse("not an assumption") is None,
    msg="unknown names should not parse",
  )
}

///|
test "curtate expectation trails the complete expectation by half a year" {
  let t = @moonactuary.ChinaTable::of_code("CL1").unwrap().table()
  for x in [0, 20, 45, 70] {
    // Under UDD the complete expectation exceeds the curtate one by exactly
    // half a year of the survivors who die in their final partial year; the
    // gap approaches a half from above at younger ages.
    let gap = t.expectation(x) - t.curtate_expectation(x)
    assert_true(
      gap > 0.4 && gap < 0.6,
      msg="gap \{gap} at age \{x} is not near a half",
    )
  }
}

///|
test "pension tables are flagged as such" {
  let mut pensions = 0
  let mut protection = 0
  for c in @moonactuary.all_china_tables() {
    if c.is_pension() {
      pensions = pensions + 1
    } else {
      protection = protection + 1
    }
    assert_true(c.code().length() == 3, msg="table codes are three characters")
    assert_true(
      c.chinese_name().length() > 0,
      msg="every table has a Chinese name",
    )
    assert_true(
      c.english_name().length() > 0,
      msg="every table has an English name",
    )
    assert_true(
      c.qx().length() > 100,
      msg="every table spans the whole lifetime",
    )
  }
  assert_eq(pensions, 2)
  assert_eq(protection, 4)
  assert_true(
    @moonactuary.ChinaTable::of_code("CL5").unwrap().is_pension(),
    msg="CL5 is the male pension table",
  )
  assert_true(
    !@moonactuary.ChinaTable::of_code("CL1").unwrap().is_pension(),
    msg="CL1 is a protection table",
  )
  assert_true(
    @moonactuary.ChinaTable::of_code("CL7") is None,
    msg="there is no seventh table",
  )
}

///|
test "commutation columns hold their defining relations" {
  let china = @moonactuary.ChinaTable::of_code("CL3").unwrap()
  let table = china.table()
  let i = @moonactuary.Interest::of(0.025)
  let v = @moonactuary.Valuation::of(table~, interest=i)
  let v_factor = i.discount_factor()
  // C_x is the discounted deaths of the year, and S_x the tail sum of N.
  for x in [0, 30, 60] {
    contingency_near(
      v.commutation_c(x),
      @math.pow(v_factor, x.to_double() + 2.0) * table.dx(x),
      1.0e-6,
    )
    let mut tail = 0.0
    for k in x..<(v.limiting_age() + 1) {
      tail = tail + v.commutation_n(k)
    }
    contingency_near(v.commutation_s(x), tail, 1.0e-3)
  }
  // An increasing annuity pays 1, 2, 3, ... and so is worth more than a level
  // one, but no more than its own final payment times a level one.
  let level = v.whole_life_annuity(40)
  let rising = v.increasing_annuity(40)
  assert_true(
    rising > level,
    msg="an increasing annuity should exceed a level one",
  )
  let summed = summed_increasing_annuity(v, 40)
  contingency_near(rising, summed, 1.0e-3)
}

///|
/// (Ia)_x summed from the definition: payment t+1 at time t, discounted and
/// weighted by the chance of being alive to receive it.
fn summed_increasing_annuity(v : @moonactuary.Valuation, x : Int32) -> Double {
  let table = v.life_table()
  let i = v.interest()
  let mut total = 0.0
  for t in 0..<(v.limiting_age() - x + 1) {
    total = total +
      (t.to_double() + 1.0) *
      i.discount(t.to_double()) *
      table.lx(x + t) /
      table.lx(x)
  }
  total
}

///|
test "continuous functions agree with their discrete counterparts" {
  let china = @moonactuary.ChinaTable::of_code("CL1").unwrap()
  let v = @moonactuary.Valuation::of(
    table=china.table(),
    interest=@moonactuary.Interest::of(0.03),
  )
  let i = v.interest()
  // A continuous whole life insurance is the discrete one scaled by i/delta.
  contingency_near(
    v.continuous_insurance(35),
    i.annual() / i.force() * v.whole_life_insurance(35),
    1.0e-9,
  )
  // And the continuous annuity satisfies its own version of the identity.
  contingency_near(
    v.continuous_annuity(35),
    (1.0 - v.continuous_insurance(35)) / i.force(),
    1.0e-9,
  )
  // Paying continuously rather than yearly is worth about half a payment less:
  // each year's income arrives on average half a year later than at the start
  // of the year, which is what the due annuity assumes.
  let gap = v.continuous_annuity(35) - v.whole_life_annuity(35)
  assert_true(
    gap < 0.0 && gap > -1.0,
    msg="continuous annuity gap \{gap} is implausible",
  )
  // At zero interest the force is zero too and the formulas degenerate to the
  // discrete values rather than dividing by zero.
  let flat = @moonactuary.Valuation::of(
    table=china.table(),
    interest=@moonactuary.Interest::of(0.0),
  )
  contingency_near(
    flat.continuous_insurance(35),
    flat.whole_life_insurance(35),
    1.0e-9,
  )
  contingency_near(
    flat.continuous_annuity(35),
    flat.whole_life_annuity(35),
    1.0e-9,
  )
  contingency_near(flat.whole_life_insurance(35), 1.0, 1.0e-9)
}

///|
test "varying insurances degenerate and telescope correctly" {
  let china = @moonactuary.ChinaTable::of_code("CL1").unwrap()
  let v = @moonactuary.Valuation::of(
    table=china.table(),
    interest=@moonactuary.Interest::of(0.025),
  )
  // A term of no length insures nothing, whether the benefit rises or falls.
  contingency_near(v.increasing_term_insurance(30, 0), 0.0, 0.0)
  contingency_near(v.decreasing_term_insurance(30, 0), 0.0, 0.0)
  // A decreasing and an increasing term of the same length sum to that many
  // level terms of one more unit of face amount.
  let n = 10
  let rising = v.increasing_term_insurance(30, n)
  let falling = v.decreasing_term_insurance(30, n)
  let level = v.term_insurance(30, n)
  contingency_near(rising + falling, (n.to_double() + 1.0) * level, 1.0e-9)
  assert_true(
    rising > level,
    msg="an increasing benefit costs more than a level one",
  )
}

///|
test "a reserve past the end of the term is nothing" {
  let china = @moonactuary.ChinaTable::of_code("CL1").unwrap()
  let v = @moonactuary.Valuation::of(
    table=china.table(),
    interest=@moonactuary.Interest::of(0.025),
  )
  let premium = v.annual_premium_endowment(30, 20)
  contingency_near(v.reserve_term(30, 20, 20, premium), 0.0, 0.0)
  contingency_near(v.reserve_term(30, 20, 25, premium), 0.0, 0.0)
  // The Fackler step at the limiting age, where death is certain, leaves no
  // survivors to hold a reserve for.
  let omega = v.limiting_age()
  contingency_near(v.reserve_step(0.4, premium, omega, 1.0), 0.0, 0.0)
}

///|
test "formatting helpers behave at their edges" {
  near_text(@moonactuary.fixed(-0.0000001, 2), "-0.00")
  near_text(@moonactuary.fixed(1234.5678, 0), "1235")
  near_text(@moonactuary.fixed(0.5, 3), "0.500")
  near_text(@moonactuary.percent(0.025, 2), "2.50%")
  near_text(@moonactuary.pad_left("7", 3), "  7")
  near_text(@moonactuary.pad_right("ab", 4), "ab  ")
  // Padding never truncates content longer than the field.
  near_text(@moonactuary.pad_left("abcdef", 3), "abcdef")
  near_text(@moonactuary.rule(4, '-'), "----")
  near_text(@moonactuary.rule(0, '='), "")
}

///|
fn near_text(actual : String, expected : String) -> Unit raise {
  assert_eq(actual, expected)
}
