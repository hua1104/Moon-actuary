// Copyright 2026 hua1104. Apache-2.0.
//
// Theory of interest: rates, discount factors and annuities-certain. All
// formulas follow the notation of the Society of Actuaries exam syllabus, and
// every function is continuous and exact rather than tabulated.

///|
/// A compound interest environment described by its effective annual rate i.
///
/// Every other quantity used in actuarial mathematics derives from i: the
/// discount factor v, the effective annual discount rate d, the force of
/// interest delta, and nominal rates convertible m times per year. Modelling
/// these conversions explicitly is what keeps reserve recursion and premium
/// algebra consistent with each other.
pub struct Interest {
  rate : Double
}

///|
/// An interest environment at effective annual rate `rate`. A rate of 0.025
/// means 2.5% (预定利率); negative rates are rejected as they have no
/// actuarial reading and make accumulation ill-behaved.
pub fn Interest::of(rate : Double) -> Interest {
  if rate <= -1.0 {
    abort("interest: rate must exceed -1, got \{rate}")
  }
  Interest::{ rate, }
}

///|
/// The effective annual interest rate i.
pub fn Interest::annual(self : Interest) -> Double {
  self.rate
}

///|
/// The annual accumulation factor 1 + i.
pub fn Interest::accumulation_factor(self : Interest) -> Double {
  1.0 + self.rate
}

///|
/// The annual discount factor v = 1 / (1 + i).
pub fn Interest::discount_factor(self : Interest) -> Double {
  1.0 / (1.0 + self.rate)
}

///|
/// The effective annual discount rate d = i / (1 + i) = i * v.
pub fn Interest::discount_rate(self : Interest) -> Double {
  self.rate / (1.0 + self.rate)
}

///|
/// The constant force of interest delta = ln(1 + i) equivalent to i.
pub fn Interest::force(self : Interest) -> Double {
  @math.ln(1.0 + self.rate)
}

///|
/// The nominal rate i^(m) convertible `m` times per year. Twelve is the
/// monthly conversion used by Chinese products that collect premiums monthly.
pub fn Interest::nominal(self : Interest, m : Int32) -> Double {
  let m_f = m.to_double()
  m_f * (@math.pow(1.0 + self.rate, 1.0 / m_f) - 1.0)
}

///|
/// The nominal discount rate d^(m) convertible `m` times per year.
pub fn Interest::nominal_discount(self : Interest, m : Int32) -> Double {
  let m_f = m.to_double()
  m_f * (1.0 - @math.pow(1.0 + self.rate, -1.0 / m_f))
}

///|
/// Given a nominal rate i^(m) convertible `m` times per year, recover the
/// effective annual rate. Inverse of `nominal`.
pub fn Interest::of_nominal(nominal : Double, m : Int32) -> Interest {
  let m_f = m.to_double()
  Interest::of(@math.pow(1.0 + nominal / m_f, m_f) - 1.0)
}

///|
/// Given a discount rate d convertible once per year, recover the effective
/// annual interest rate i = d / (1 - d).
pub fn Interest::of_discount_rate(d : Double) -> Interest {
  Interest::of(d / (1.0 - d))
}

///|
/// Given a constant force of interest delta, recover the effective annual
/// rate i = e^delta - 1.
pub fn Interest::of_force(delta : Double) -> Interest {
  Interest::of(@math.exp(delta) - 1.0)
}

///|
/// Accumulation a(t) = (1 + i)^t from time 0 to time `t`. Accepts fractional
/// years, and extrapolates backwards for negative t.
pub fn Interest::accumulate(self : Interest, t : Double) -> Double {
  @math.pow(1.0 + self.rate, t)
}

///|
/// Discount v^t = (1 + i)^(-t): the value at time 0 of one unit payable at
/// time `t`.
pub fn Interest::discount(self : Interest, t : Double) -> Double {
  @math.pow(1.0 + self.rate, -t)
}

///|
/// a_n: present value of an annuity-immediate paying 1 at the end of each of
/// `n` years. Payments stop at year n.
pub fn Interest::annuity_immediate(self : Interest, n : Int32) -> Double {
  if n <= 0 {
    0.0
  } else if self.rate == 0.0 {
    // Without interest every payment is worth its face amount.
    n.to_double()
  } else {
    (1.0 - self.discount(n.to_double())) / self.rate
  }
}

///|
/// a-double-dot_n: present value of an annuity-due paying 1 at the start of
/// each of `n` years, first payment immediate.
pub fn Interest::annuity_due(self : Interest, n : Int32) -> Double {
  if n <= 0 {
    0.0
  } else if self.rate == 0.0 {
    n.to_double()
  } else {
    (1.0 - self.discount(n.to_double())) / self.discount_rate()
  }
}

///|
/// a-bar_n: present value of an annuity payable continuously at rate 1 per
/// year for `n` years.
pub fn Interest::annuity_continuous(self : Interest, n : Int32) -> Double {
  if n <= 0 {
    0.0
  } else if self.rate == 0.0 {
    n.to_double()
  } else {
    (1.0 - self.discount(n.to_double())) / self.force()
  }
}

///|
/// a_n^(m): present value of an annuity paying 1/m at the end of each m-th of
/// a year for `n` years.
pub fn Interest::annuity_immediate_mthly(
  self : Interest,
  n : Int32,
  m : Int32,
) -> Double {
  if n <= 0 {
    0.0
  } else if self.rate == 0.0 {
    // Without interest the nominal rate vanishes too, so the closed form would
    // be 0/0. The value is simply the total paid: n units a year for n years.
    n.to_double()
  } else {
    (1.0 - self.discount(n.to_double())) / self.nominal(m)
  }
}

///|
/// a-double-dot_n^(m): present value of an annuity paying 1/m at the start of
/// each m-th of a year for `n` years. This is the shape of a monthly premium
/// annuity, and is what Chinese monthly-pay products are valued from.
pub fn Interest::annuity_due_mthly(
  self : Interest,
  n : Int32,
  m : Int32,
) -> Double {
  if n <= 0 {
    0.0
  } else if self.rate == 0.0 {
    // As for the immediate case: n units a year, paid in advance or not.
    n.to_double()
  } else {
    (1.0 - self.discount(n.to_double())) / self.nominal_discount(m)
  }
}

///|
/// s_n: accumulated value at time n of payments of 1 at the end of each of
/// `n` years.
pub fn Interest::accumulated_immediate(self : Interest, n : Int32) -> Double {
  if n <= 0 {
    0.0
  } else if self.rate == 0.0 {
    // Nothing accumulates, so the closed form is 0/0 and the value is simply
    // the total paid.
    n.to_double()
  } else {
    (self.accumulate(n.to_double()) - 1.0) / self.rate
  }
}

///|
/// s-double-dot_n: accumulated value at time n of payments of 1 at the start
/// of each of `n` years.
pub fn Interest::accumulated_due(self : Interest, n : Int32) -> Double {
  if n <= 0 {
    0.0
  } else if self.rate == 0.0 {
    n.to_double()
  } else {
    (self.accumulate(n.to_double()) - 1.0) / self.discount_rate()
  }
}

///|
/// a_infinity: present value of a perpetuity-immediate paying 1 at the end of
/// every year forever. Only finite when i > 0.
pub fn Interest::perpetuity(self : Interest) -> Double {
  1.0 / self.rate
}

///|
/// a-double-dot_infinity: present value of a perpetuity-due paying 1 at the
/// start of every year forever.
pub fn Interest::perpetuity_due(self : Interest) -> Double {
  1.0 / self.discount_rate()
}

///|
/// (Ia)_n: present value of an increasing annuity-immediate paying 1 at the
/// end of year 1, 2 at the end of year 2, up to n at the end of year n.
pub fn Interest::increasing_annuity(self : Interest, n : Int32) -> Double {
  if n <= 0 {
    0.0
  } else if self.rate == 0.0 {
    // Sum of 1 through n.
    n.to_double() * (n.to_double() + 1.0) / 2.0
  } else {
    (self.annuity_due(n) - n.to_double() * self.discount(n.to_double())) /
    self.rate
  }
}

///|
/// (Da)_n: present value of a decreasing annuity-immediate paying n at the end
/// of year 1, n-1 at the end of year 2, down to 1 at the end of year n.
pub fn Interest::decreasing_annuity(self : Interest, n : Int32) -> Double {
  if n <= 0 {
    0.0
  } else if self.rate == 0.0 {
    n.to_double() * (n.to_double() + 1.0) / 2.0
  } else {
    (n.to_double() - self.annuity_immediate(n)) / self.rate
  }
}
