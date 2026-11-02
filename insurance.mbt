// Copyright 2026 hua1104. Apache-2.0.
//
// Net single premiums, net annual premiums and net premium reserves.
//
// Benefits here are discrete: claims are settled at the end of the year of
// death. That matches the CL table convention and Chinese statutory product
// documentation, and keeps the whole library consistent with the commutation
// columns rather than mixing discrete and continuous conventions.

///|
/// Guard against ages outside the table, where the commutation columns vanish
/// and every ratio would be 0/0.
fn require_age(limit : Int32, x : Int32) -> Unit {
  if x < 0 || x > limit {
    abort("valuation: age \{x} is outside the table range 0..\{limit}")
  }
}

///|
/// A_x: net single premium for whole life insurance paying 1 at the end of the
/// year of death. Equals M_x / D_x.
pub fn Valuation::whole_life_insurance(self : Valuation, x : Int32) -> Double {
  require_age(self.limiting_age(), x)
  self.commutation_m(x) / self.commutation_d(x)
}

///|
/// A_{x:n}^1: net single premium for n-year term insurance, paying 1 at the end
/// of the year of death only if death occurs within n years.
pub fn Valuation::term_insurance(
  self : Valuation,
  x : Int32,
  n : Int32,
) -> Double {
  require_age(self.limiting_age(), x)
  if n <= 0 {
    0.0
  } else {
    (self.commutation_m(x) - self.commutation_m(x + n)) / self.commutation_d(x)
  }
}

///|
/// nE_x: net single premium for a pure endowment paying 1 at time n only if
/// (x) survives to age x + n. Equals D_{x+n} / D_x.
pub fn Valuation::pure_endowment(
  self : Valuation,
  x : Int32,
  n : Int32,
) -> Double {
  require_age(self.limiting_age(), x)
  self.commutation_d(x + n) / self.commutation_d(x)
}

///|
/// A_{x:n}: net single premium for an n-year endowment insurance, which pays 1
/// either on death within n years or on survival to age x + n. It decomposes
/// into the term insurance plus the pure endowment.
pub fn Valuation::endowment_insurance(
  self : Valuation,
  x : Int32,
  n : Int32,
) -> Double {
  self.term_insurance(x, n) + self.pure_endowment(x, n)
}

///|
/// u|A_x: net single premium for whole life insurance deferred u years, paying
/// nothing on death during the deferral period.
pub fn Valuation::deferred_insurance(
  self : Valuation,
  x : Int32,
  u : Int32,
) -> Double {
  require_age(self.limiting_age(), x)
  self.commutation_m(x + u) / self.commutation_d(x)
}

///|
/// (IA)_x: increasing whole life insurance paying k + 1 at the end of the year
/// of death, where k is the number of complete years survived. Equals
/// R_x / D_x.
pub fn Valuation::increasing_insurance(self : Valuation, x : Int32) -> Double {
  require_age(self.limiting_age(), x)
  self.commutation_r(x) / self.commutation_d(x)
}

///|
/// (IA)_{x:n}^1: increasing n-year term insurance paying k + 1 at the end of
/// the year of death, where death falls in the (k+1)-th policy year. Equals
/// (R_x - R_{x+n} - n * M_{x+n}) / D_x.
pub fn Valuation::increasing_term_insurance(
  self : Valuation,
  x : Int32,
  n : Int32,
) -> Double {
  require_age(self.limiting_age(), x)
  if n <= 0 {
    0.0
  } else {
    let r_gap = self.commutation_r(x) - self.commutation_r(x + n)
    (r_gap - n.to_double() * self.commutation_m(x + n)) / self.commutation_d(x)
  }
}

///|
/// (DA)_{x:n}^1: decreasing n-year term insurance paying n - k at the end of
/// the year of death, where death falls in the (k+1)-th policy year, so the
/// face amount steps down yearly from n to 1. It relates to the increasing
/// policy by (n + 1) A_{x:n}^1 - (IA)_{x:n}^1.
pub fn Valuation::decreasing_term_insurance(
  self : Valuation,
  x : Int32,
  n : Int32,
) -> Double {
  if n <= 0 {
    0.0
  } else {
    let face = n.to_double() + 1.0
    face * self.term_insurance(x, n) - self.increasing_term_insurance(x, n)
  }
}

///|
/// A-double-dot_x^(m): whole life insurance paying at the moment of death,
/// converted from the end-of-year benefit under UDD by the factor i / delta.
pub fn Valuation::continuous_insurance(self : Valuation, x : Int32) -> Double {
  let i_rate = self.interest.annual()
  let delta = self.interest.force()
  if delta == 0.0 {
    self.whole_life_insurance(x)
  } else {
    i_rate / delta * self.whole_life_insurance(x)
  }
}

///|
/// P_x: net annual premium for whole life insurance, level for life, obtained
/// by the equivalence principle A_x = P * a-double-dot_x.
pub fn Valuation::annual_premium_whole_life(
  self : Valuation,
  x : Int32,
) -> Double {
  self.whole_life_insurance(x) / self.whole_life_annuity(x)
}

///|
/// P_{x:n}^1: net annual premium for n-year term insurance, payable for the
/// full term.
pub fn Valuation::annual_premium_term(
  self : Valuation,
  x : Int32,
  n : Int32,
) -> Double {
  self.term_insurance(x, n) / self.temporary_annuity(x, n)
}

///|
/// P_{x:n}: net annual premium for n-year endowment insurance, payable for the
/// full term.
pub fn Valuation::annual_premium_endowment(
  self : Valuation,
  x : Int32,
  n : Int32,
) -> Double {
  self.endowment_insurance(x, n) / self.temporary_annuity(x, n)
}

///|
/// m P_x: net annual premium for whole life insurance payable for at most m
/// years, after which the policy is paid up. This limited-payment structure is
/// common in Chinese whole life products.
pub fn Valuation::annual_premium_limited(
  self : Valuation,
  x : Int32,
  m : Int32,
) -> Double {
  self.whole_life_insurance(x) / self.temporary_annuity(x, m)
}

///|
/// t V: the net level terminal reserve at duration t for a whole life policy
/// issued at age x charging net annual premium `premium`. Computed
/// prospectively as A_{x+t} - P * a-double-dot_{x+t}.
pub fn Valuation::reserve_whole_life(
  self : Valuation,
  x : Int32,
  t : Int32,
  premium : Double,
) -> Double {
  self.whole_life_insurance(x + t) - premium * self.whole_life_annuity(x + t)
}

///|
/// t V: the net level terminal reserve at duration t of an n-year endowment
/// policy, with n - t years remaining at that point.
pub fn Valuation::reserve_endowment(
  self : Valuation,
  x : Int32,
  n : Int32,
  t : Int32,
  premium : Double,
) -> Double {
  // Maturity behaviour differs by product and must not be folded into one
  // guard. An endowment still owes its survival benefit at time n, so with no
  // years remaining the reserve is the full unit; a term policy owes nothing.
  self.endowment_insurance(x + t, n - t) -
  premium * self.temporary_annuity(x + t, n - t)
}

///|
/// t V: the net level terminal reserve at duration t of an n-year term policy.
pub fn Valuation::reserve_term(
  self : Valuation,
  x : Int32,
  n : Int32,
  t : Int32,
  premium : Double,
) -> Double {
  let remaining = n - t
  if remaining <= 0 {
    0.0
  } else {
    self.term_insurance(x + t, remaining) -
    premium * self.temporary_annuity(x + t, remaining)
  }
}

///|
/// t V computed retrospectively: accumulated premiums net of accumulated
/// claims, per survivor, grown to duration t. Must agree with the prospective
/// reserve exactly, which makes it a strong cross-check on both directions.
pub fn Valuation::reserve_retrospective(
  self : Valuation,
  x : Int32,
  t : Int32,
  premium : Double,
) -> Double {
  if t <= 0 {
    0.0
  } else {
    let survivors = self.commutation_d(x + t)
    let accumulated_premiums = (
        self.commutation_n(x) - self.commutation_n(x + t)
      ) /
      survivors
    let accumulated_claims = (self.commutation_m(x) - self.commutation_m(x + t)) /
      survivors
    premium * accumulated_premiums - accumulated_claims
  }
}

///|
/// One step of the Fackler recursion: roll a terminal reserve forward one
/// policy year. Given the reserve V_t held at duration t, a premium collected
/// at the start of year t + 1, mortality q_{x+t} and a unit benefit paid at the
/// end of the year of death,
///
///   (V_t + P) (1 + i) = p_{x+t} V_{t+1} + q_{x+t} b
///
/// so the recursion recovers V_{t+1} without referring to any future year.
pub fn Valuation::reserve_step(
  self : Valuation,
  held : Double,
  premium : Double,
  age : Int32,
  benefit : Double,
) -> Double {
  let q = self.table.qx(age)
  let p = 1.0 - q
  let growth = (held + premium) * self.interest.accumulation_factor()
  if p <= 0.0 {
    0.0
  } else {
    (growth - q * benefit) / p
  }
}

///|
/// Roll a level net premium reserve forward from duration `from` to duration
/// `to` using only the Fackler recursion, starting from `opening`. Because the
/// recursion never looks past the coming year, running it to the end of the
/// contract and comparing against the prospective reserve validates the entire
/// premium basis: if the premium is wrong, the two will disagree.
pub fn Valuation::reserve_schedule_fackler(
  self : Valuation,
  x : Int32,
  from : Int32,
  to : Int32,
  premium : Double,
  benefit : Double,
  opening : Double,
) -> Array[Double] {
  let steps = to - from
  let out = Array::make(steps + 1, 0.0)
  out[0] = opening
  for k in 0..<steps {
    let duration = from + k
    out[k + 1] = self.reserve_step(out[k], premium, x + duration, benefit)
  }
  out
}
