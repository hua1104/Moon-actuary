// Copyright 2026 hua1104. Apache-2.0.
//
// Blackbox tests for interest theory, aimed at the branches the worked examples
// never reach: zero interest, empty terms, and the conversion functions that
// only appear inside monthly annuities. Every closed form is checked against an
// explicit sum taken from the definition, so a formula and its implementation
// would both have to be wrong in the same way for a defect to slip through.

///|
fn interest_near(
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
/// Summed straight from the definition: a_n is the value of one unit at the
/// end of each year for n years.
fn summed_immediate(rate : Double, n : Int32) -> Double {
  let i = @moonactuary.Interest::of(rate)
  let mut total = 0.0
  for k in 1..<(n + 1) {
    total = total + i.discount(k.to_double())
  }
  total
}

///|
/// An annuity payable m times a year, summed payment by payment.
fn summed_mthly(rate : Double, n : Int32, m : Int32) -> Double {
  let i = @moonactuary.Interest::of(rate)
  let mut total = 0.0
  for k in 1..<(n * m + 1) {
    total = total + i.discount(k.to_double() / m.to_double())
  }
  total / m.to_double()
}

///|
test "rate conversions agree with their definitions" {
  let i = @moonactuary.Interest::of(0.06)
  interest_near(i.annual(), 0.06, 1.0e-12)
  interest_near(i.discount_factor(), 1.0 / 1.06, 1.0e-12)
  interest_near(i.discount_rate(), 0.06 / 1.06, 1.0e-12)
  interest_near(i.force(), @math.ln(1.06), 1.0e-12)
  interest_near(i.accumulation_factor(), 1.06, 1.0e-12)
  // Nominal rates convertible monthly, and their discount counterparts.
  let i12 = i.nominal(12)
  interest_near(i12, 12.0 * (@math.pow(1.06, 1.0 / 12.0) - 1.0), 1.0e-12)
  let d12 = i.nominal_discount(12)
  interest_near(d12, 12.0 * (1.0 - @math.pow(1.06, -1.0 / 12.0)), 1.0e-12)
  // Round tripping through the constructors must land back on the same rate.
  interest_near(
    @moonactuary.Interest::of_force(i.force()).annual(),
    0.06,
    1.0e-10,
  )
  interest_near(
    @moonactuary.Interest::of_discount_rate(i.discount_rate()).annual(),
    0.06,
    1.0e-10,
  )
  interest_near(
    @moonactuary.Interest::of_nominal(i12, 12).annual(),
    0.06,
    1.0e-10,
  )
}

///|
test "accumulation and discounting are inverses" {
  let i = @moonactuary.Interest::of(0.045)
  for t in [0.5, 1.0, 3.5, 10.0, 27.25] {
    interest_near(i.accumulate(t), @math.pow(1.045, t), 1.0e-9)
    interest_near(i.discount(t), @math.pow(1.045, 0.0 - t), 1.0e-9)
    interest_near(i.accumulate(t) * i.discount(t), 1.0, 1.0e-12)
  }
}

///|
test "annuities match their payment-by-payment sums" {
  for rate in [0.0, 0.025, 0.06] {
    let i = @moonactuary.Interest::of(rate)
    for n in [1, 5, 20] {
      interest_near(i.annuity_immediate(n), summed_immediate(rate, n), 1.0e-9)
      // Due annuities lead the immediate ones by one accumulation period.
      interest_near(
        i.annuity_due(n),
        summed_immediate(rate, n) * (1.0 + rate),
        1.0e-9,
      )
      interest_near(
        i.accumulated_immediate(n),
        summed_immediate(rate, n) * @math.pow(1.0 + rate, n.to_double()),
        1.0e-9,
      )
      interest_near(
        i.accumulated_due(n),
        i.annuity_due(n) * @math.pow(1.0 + rate, n.to_double()),
        1.0e-9,
      )
      for m in [2, 4, 12] {
        interest_near(
          i.annuity_immediate_mthly(n, m),
          summed_mthly(rate, n, m),
          1.0e-9,
        )
      }
    }
  }
}

///|
test "monthly annuities approach the continuous annuity" {
  let i = @moonactuary.Interest::of(0.05)
  let continuous = i.annuity_continuous(10)
  let monthly = i.annuity_immediate_mthly(10, 12)
  let quarterly = i.annuity_immediate_mthly(10, 4)
  // Refining the payment frequency moves towards the continuous limit, and
  // always from below for an immediate annuity.
  assert_true(quarterly < monthly, msg="monthly should exceed quarterly")
  assert_true(monthly < continuous, msg="continuous should exceed monthly")
  interest_near(continuous - monthly, monthly - quarterly, 0.05)
}

///|
test "an empty term is worth nothing" {
  let i = @moonactuary.Interest::of(0.04)
  interest_near(i.annuity_immediate(0), 0.0, 0.0)
  interest_near(i.annuity_due(0), 0.0, 0.0)
  interest_near(i.annuity_continuous(0), 0.0, 0.0)
  interest_near(i.annuity_immediate_mthly(0, 12), 0.0, 0.0)
  interest_near(i.annuity_due_mthly(0, 12), 0.0, 0.0)
  interest_near(i.accumulated_immediate(0), 0.0, 0.0)
  interest_near(i.accumulated_due(0), 0.0, 0.0)
  interest_near(i.increasing_annuity(0), 0.0, 0.0)
  interest_near(i.decreasing_annuity(0), 0.0, 0.0)
}

///|
test "at zero interest every payment is worth its face amount" {
  let i = @moonactuary.Interest::of(0.0)
  interest_near(i.annuity_immediate(12), 12.0, 1.0e-12)
  interest_near(i.annuity_due(12), 12.0, 1.0e-12)
  interest_near(i.annuity_continuous(12), 12.0, 1.0e-12)
  // 1 + 2 + ... + n, whether the payments increase or decrease.
  interest_near(i.increasing_annuity(12), 78.0, 1.0e-12)
  interest_near(i.decreasing_annuity(12), 78.0, 1.0e-12)
  // A perpetuity has no finite value once nothing is earned: both diverge.
  assert_true(
    i.perpetuity() > 1.0e300,
    msg="a zero rate perpetuity should diverge",
  )
  assert_true(
    i.perpetuity_due() > 1.0e300,
    msg="a zero rate perpetuity due should diverge",
  )
}

///|
test "increasing and decreasing annuities sum to a level one" {
  let i = @moonactuary.Interest::of(0.035)
  let n = 15
  let rising = i.increasing_annuity(n)
  let falling = i.decreasing_annuity(n)
  let level = (n.to_double() + 1.0) * i.annuity_immediate(n)
  interest_near(rising + falling, level, 1.0e-9)
  // An increasing annuity is also the sum of deferred level annuities.
  let mut deferred = 0.0
  for k in 0..<n {
    let remaining = n - k
    deferred = deferred +
      i.discount(k.to_double()) * i.annuity_immediate(remaining)
  }
  interest_near(rising, deferred, 1.0e-9)
}

///|
test "perpetuities are the limit of the term annuities" {
  let i = @moonactuary.Interest::of(0.05)
  interest_near(i.perpetuity(), 1.0 / 0.05, 1.0e-12)
  interest_near(i.perpetuity_due(), 1.0 / i.discount_rate(), 1.0e-12)
  // A long term annuity must sit just under the perpetuity.
  let long = i.annuity_immediate(400)
  assert_true(
    long < i.perpetuity(),
    msg="a term annuity cannot exceed a perpetuity",
  )
  interest_near(i.perpetuity() - long, i.discount(400.0) / 0.05, 1.0e-9)
}
