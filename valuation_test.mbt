// Blackbox tests for interest theory and life contingencies.
//
// Two strategies are used together. The first pins interest formulas against
// values that can be checked by hand. The second checks every commutation-based
// closed form against a direct summation taken straight from the definition, so
// a mistake in the columns would have to be mirrored by an exactly equal
// mistake in the summation to survive undetected.

///|
fn close_enough(actual : Double, expected : Double, tol : Double) -> Unit raise {
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
/// Assert agreement to `places` decimal places.
fn same_to(actual : Double, expected : Double, places : Int32) -> Unit raise {
  let scale = @math.pow(10.0, places.to_double())
  close_enough(actual, expected, 0.5 / scale)
}

///|
/// A valuation used repeatedly below: CL3 protection male at 2.5% effective
/// annual interest.
fn sample() -> @moonactuary.Valuation {
  @moonactuary.Valuation::of(
    table=@moonactuary.ChinaTable::of_code("CL3").unwrap().table(),
    interest=@moonactuary.Interest::of(0.025),
  )
}

///|
/// A_x computed directly from its definition: sum over k of v^(k+1) * k|q_x.
fn summed_insurance(v : @moonactuary.Valuation, x : Int32, n : Int32) -> Double {
  let interest = v.interest()
  let mut acc = 0.0
  for k in 0..<n {
    let discount = interest.discount((k + 1).to_double())
    acc = acc + discount * v.life_table().deferred_death_probability(x, k)
  }
  acc
}

///|
/// a-double-dot_{x:n} computed directly from its definition: sum over k of
/// v^k * k p_x.
fn summed_annuity(v : @moonactuary.Valuation, x : Int32, n : Int32) -> Double {
  let interest = v.interest()
  let mut acc = 0.0
  for k in 0..<n {
    let discount = interest.discount(k.to_double())
    acc = acc + discount * v.life_table().survival(x, k)
  }
  acc
}

///|
/// Interest formulas checked against hand-computable cases. At i = 6%, v is
/// 1/1.06 and d is i*v.
test "interest conversions agree with their definitions" {
  let i6 = @moonactuary.Interest::of(0.06)
  same_to(i6.discount_factor(), 1.0 / 1.06, 12)
  same_to(i6.discount_rate(), 0.06 / 1.06, 12)
  same_to(i6.force(), @math.ln(1.06), 12)
  same_to(i6.accumulate(10.0), @math.pow(1.06, 10.0), 10)
  same_to(i6.discount(10.0), @math.pow(1.06, -10.0), 12)
  // A monthly-convertible nominal rate must compound back to i.
  let m12 = i6.nominal(12)
  same_to(@math.pow(1.0 + m12 / 12.0, 12.0) - 1.0, 0.06, 12)
  same_to(@moonactuary.Interest::of_nominal(m12, 12).annual(), 0.06, 12)
  same_to(
    @moonactuary.Interest::of_discount_rate(i6.discount_rate()).annual(),
    0.06,
    12,
  )
  same_to(@moonactuary.Interest::of_force(i6.force()).annual(), 0.06, 12)
  // Annuity-due is the annuity-immediate grown one period.
  same_to(i6.annuity_due(20), i6.annuity_immediate(20) * 1.06, 12)
  // A 10-payment annuity-immediate at 0% is worth exactly 10.
  same_to(@moonactuary.Interest::of(0.0).annuity_immediate(10), 10.0, 12)
  // Perpetuity at 5% pays 20 per unit of present value.
  same_to(@moonactuary.Interest::of(0.05).perpetuity(), 20.0, 12)
  same_to(@moonactuary.Interest::of(0.05).perpetuity_due(), 21.0, 12)
  // Accumulated and consumed versions must agree through discounting.
  let acc = i6.accumulated_immediate(20)
  same_to(acc * i6.discount(20.0), i6.annuity_immediate(20), 10)
  same_to(i6.accumulated_due(20), acc * 1.06, 10)
}

///|
/// Increasing and decreasing annuities against their payment schedules,
/// summed term by term.
test "varying annuities match their explicit payment streams" {
  let i6 = @moonactuary.Interest::of(0.06)
  let mut increasing = 0.0
  let mut decreasing = 0.0
  for k in 1..<=20 {
    increasing = increasing + k.to_double() * i6.discount(k.to_double())
    decreasing = decreasing + (21 - k).to_double() * i6.discount(k.to_double())
  }
  same_to(i6.increasing_annuity(20), increasing, 10)
  same_to(i6.decreasing_annuity(20), decreasing, 10)
  // Together they are n+1 level annuities.
  same_to(
    i6.increasing_annuity(20) + i6.decreasing_annuity(20),
    21.0 * i6.annuity_immediate(20),
    10,
  )
}

///|
/// The single most important identity in life contingency mathematics:
/// 1 = A_x + d * a-double-dot_x must hold for every table, every rate and every
/// age, because it is just the equivalence principle applied to a unit of
/// capital. A violation anywhere means the two halves disagree.
test "the identity 1 = A_x + d * annuity holds everywhere" {
  for code in ["CL1", "CL2", "CL3", "CL4", "CL5", "CL6"] {
    for rate in [0.025, 0.03, 0.035] {
      let v = @moonactuary.Valuation::of(
        table=@moonactuary.ChinaTable::of_code(code).unwrap().table(),
        interest=@moonactuary.Interest::of(rate),
      )
      for x in [0, 1, 10, 25, 40, 55, 70, 90] {
        same_to(v.insurance_annuity_identity(x), 0.0, 9)
      }
    }
  }
}

///|
/// Commutation closed forms agree with direct summation from the definitions.
test "commutation results equal direct summation" {
  let v = sample()
  for x in [0, 30, 45, 60] {
    same_to(v.term_insurance(x, 20), summed_insurance(v, x, 20), 10)
    same_to(v.whole_life_insurance(x), summed_insurance(v, x, 105 - x + 1), 10)
    same_to(v.temporary_annuity(x, 20), summed_annuity(v, x, 20), 10)
    same_to(v.whole_life_annuity(x), summed_annuity(v, x, 105 - x + 1), 10)
  }
}

///|
/// Product decompositions that any premium basis must satisfy.
test "policies decompose into their component benefits" {
  let v = sample()
  let x = 35
  let n = 20
  // An endowment is a term insurance plus a pure endowment.
  same_to(
    v.endowment_insurance(x, n),
    v.term_insurance(x, n) + v.pure_endowment(x, n),
    12,
  )
  // Whole life splits into the n-year term plus the deferred remainder.
  same_to(
    v.whole_life_insurance(x),
    v.term_insurance(x, n) + v.deferred_insurance(x, n),
    12,
  )
  // A whole life annuity splits the same way.
  same_to(
    v.whole_life_annuity(x),
    v.temporary_annuity(x, n) + v.deferred_annuity(x, n),
    12,
  )
  // An annuity-immediate is one payment less than an annuity-due.
  same_to(v.whole_life_annuity_immediate(x), v.whole_life_annuity(x) - 1.0, 12)
  // A pure endowment maturing at the limiting age still pays, because the
  // table carries survivors into age 105; one maturing beyond it cannot pay.
  assert_true(v.pure_endowment(x, 105 - x) > 0.0)
  same_to(v.pure_endowment(x, 106 - x), 0.0, 12)
  same_to(v.pure_endowment(x, 0), 1.0, 12)
}

///|
/// The equivalence principle: net annual premium times annuity must reproduce
/// the net single premium, whatever the payment structure.
test "annual premiums reproduce net single premiums" {
  let v = sample()
  for x in [25, 40, 55] {
    same_to(
      v.annual_premium_whole_life(x) * v.whole_life_annuity(x),
      v.whole_life_insurance(x),
      12,
    )
    let n = 20
    same_to(
      v.annual_premium_term(x, n) * v.temporary_annuity(x, n),
      v.term_insurance(x, n),
      12,
    )
    same_to(
      v.annual_premium_endowment(x, n) * v.temporary_annuity(x, n),
      v.endowment_insurance(x, n),
      12,
    )
    same_to(
      v.annual_premium_limited(x, 10) * v.temporary_annuity(x, 10),
      v.whole_life_insurance(x),
      12,
    )
  }
  // Premiums rise steeply with age and are higher for term than for the
  // matching whole life annuity only because cover is far from certain.
  assert_true(v.annual_premium_whole_life(60) > v.annual_premium_whole_life(30))
}

///|
/// Reserves: the net premium terminal reserve at issue is zero, it matches when
/// computed prospectively, retrospectively, and by Fackler recursion, and for an
/// endowment it matures at exactly the face amount.
test "reserves agree across three methods" {
  let v = sample()
  let x = 30
  let premium = v.annual_premium_endowment(x, 20)
  // Issue: nothing has been collected and nothing has been paid.
  same_to(v.reserve_endowment(x, 20, 0, premium), 0.0, 10)
  same_to(v.reserve_retrospective(x, 0, premium), 0.0, 12)
  for t in 1..<=20 {
    let prospective = v.reserve_endowment(x, 20, t, premium)
    same_to(v.reserve_retrospective(x, t, premium), prospective, 9)
    let rolled = v.reserve_schedule_fackler(x, 0, t, premium, 1.0, 0.0)
    same_to(rolled[t], prospective, 9)
  }
  // Maturity: the reserve equals the survival benefit, since no claim is paid.
  same_to(v.reserve_endowment(x, 20, 20, premium), 1.0, 9)
}

///|
/// Whole life reserves likewise agree across all three methods, and the Fackler
/// recursion can carry them all the way to the limiting age.
test "whole life reserves agree across three methods" {
  let v = sample()
  let x = 40
  let premium = v.annual_premium_whole_life(x)
  same_to(v.reserve_whole_life(x, 0, premium), 0.0, 10)
  let rolled = v.reserve_schedule_fackler(x, 0, 40, premium, 1.0, 0.0)
  for t in 1..<=40 {
    let prospective = v.reserve_whole_life(x, t, premium)
    same_to(v.reserve_retrospective(x, t, premium), prospective, 9)
    same_to(rolled[t], prospective, 9)
  }
  // At the limiting age death within the year is certain, so the whole life
  // benefit is a single discounted unit and the annuity is a single immediate
  // payment. Both follow without consulting any future year of the table.
  same_to(v.whole_life_insurance(105), v.interest().discount_factor(), 12)
  same_to(v.whole_life_annuity(105), 1.0, 12)
}

///|
/// Increasing and decreasing insurities: the two must telescope to n + 1 level
/// term policies, and both stay above zero.
test "varying insurances telescope as expected" {
  let v = sample()
  let x = 40
  for n in [5, 10, 20] {
    let inc = v.increasing_term_insurance(x, n)
    let dec = v.decreasing_term_insurance(x, n)
    same_to(inc + dec, (n.to_double() + 1.0) * v.term_insurance(x, n), 12)
    assert_true(inc > 0.0)
    assert_true(dec > 0.0)
    // A decreasing policy with one step is a plain one-year term.
    same_to(v.decreasing_term_insurance(x, 1), v.term_insurance(x, 1), 12)
  }
  // An increasing whole life policy costs more than the level one.
  assert_true(v.increasing_insurance(x) > v.whole_life_insurance(x))
}

///|
/// Comparisons across tables and rates that follow from first principles.
test "premiums move in the direction mortality and discounting dictate" {
  let cl1 = @moonactuary.Valuation::of(
    table=@moonactuary.ChinaTable::of_code("CL1").unwrap().table(),
    interest=@moonactuary.Interest::of(0.025),
  )
  let cl5 = @moonactuary.Valuation::of(
    table=@moonactuary.ChinaTable::of_code("CL5").unwrap().table(),
    interest=@moonactuary.Interest::of(0.025),
  )
  let hot = @moonactuary.Valuation::of(
    table=@moonactuary.ChinaTable::of_code("CL1").unwrap().table(),
    interest=@moonactuary.Interest::of(0.035),
  )
  // Pension lives survive longer, so a life annuity costs more on CL5.
  assert_true(cl5.whole_life_annuity(40) > cl1.whole_life_annuity(40))
  // and death benefits cost less, since claims arrive later.
  assert_true(cl5.whole_life_insurance(40) < cl1.whole_life_insurance(40))
  // A higher discount rate lowers both.
  assert_true(hot.whole_life_insurance(40) < cl1.whole_life_insurance(40))
  assert_true(hot.whole_life_annuity(40) < cl1.whole_life_annuity(40))
  // Term cover never costs more than whole life cover of the same face.
  assert_true(cl1.term_insurance(40, 10) <= cl1.whole_life_insurance(40))
}
