// Copyright 2026 hua1104. Apache-2.0.
//
// Commutation functions and life annuities.
//
// Chinese actuarial practice prices products from commutation columns D, C, M,
// N, R and S built once per (table, interest) pair, after which every net
// single premium and every net annual premium is a single ratio. We build those
// columns eagerly: they cost 106 additions and make subsequent queries O(1).

///|
/// The six classical commutation columns over ages 0 through omega.
pub struct Commutation {
  /// D_x = v^x l_x, the discounted survivors attaining age x.
  d : Array[Double]
  /// C_x = v^(x+1) d_x, the discounted deaths between ages x and x+1.
  c : Array[Double]
  /// M_x = sum of C_k for k >= x.
  m : Array[Double]
  /// N_x = sum of D_k for k >= x.
  n : Array[Double]
  /// R_x = sum of M_k for k >= x.
  r : Array[Double]
  /// S_x = sum of N_k for k >= x.
  s : Array[Double]
}

///|
/// A mortality table paired with an interest assumption. Every actuarial
/// function in this library is a method on `Valuation`, so premiums and
/// reserves computed together always agree on discounting and mortality.
pub struct Valuation {
  table : LifeTable
  interest : Interest
  comm : Commutation
}

///|
/// Build the commutation columns for a table and interest pair.
pub fn Valuation::of(table~ : LifeTable, interest~ : Interest) -> Valuation {
  let size = table.limiting_age() + 1
  let v = interest.discount_factor()
  let d = Array::make(size, 0.0)
  let c = Array::make(size, 0.0)
  let m = Array::make(size, 0.0)
  let n = Array::make(size, 0.0)
  let r = Array::make(size, 0.0)
  let s = Array::make(size, 0.0)
  // Forward pass: powers of v are accumulated rather than exponentiated, which
  // keeps neighbouring ages in exact geometric relation to one another.
  let mut discount = 1.0
  for x in 0..<size {
    discount = discount * v
    d[x] = discount * table.lx(x)
    c[x] = discount * v * table.dx(x)
  }
  // Backward pass: each column is a running tail sum, so a single reversed
  // sweep fills all four derived columns at once.
  let mut sum_c = 0.0
  let mut sum_d = 0.0
  let mut sum_r = 0.0
  let mut sum_s = 0.0
  for back in 0..<size {
    let x = size - 1 - back
    sum_c = sum_c + c[x]
    sum_d = sum_d + d[x]
    m[x] = sum_c
    n[x] = sum_d
    sum_r = sum_r + m[x]
    sum_s = sum_s + n[x]
    r[x] = sum_r
    s[x] = sum_s
  }
  let comm = Commutation::{ d, c, m, n, r, s, }
  Valuation::{ table, interest, comm, }
}

///|
/// The mortality table this valuation was built from.
pub fn Valuation::life_table(self : Valuation) -> LifeTable {
  self.table
}

///|
/// The interest assumption this valuation was built from.
pub fn Valuation::interest(self : Valuation) -> Interest {
  self.interest
}

///|
/// The limiting age omega; no life survives past it.
pub fn Valuation::limiting_age(self : Valuation) -> Int32 {
  self.table.limiting_age()
}

///|
/// D_x = v^x l_x.
pub fn Valuation::commutation_d(self : Valuation, x : Int32) -> Double {
  column(self.comm.d, x)
}

///|
/// C_x = v^(x+1) d_x.
pub fn Valuation::commutation_c(self : Valuation, x : Int32) -> Double {
  column(self.comm.c, x)
}

///|
/// M_x = sum of C_k over k >= x.
pub fn Valuation::commutation_m(self : Valuation, x : Int32) -> Double {
  column(self.comm.m, x)
}

///|
/// N_x = sum of D_k over k >= x.
pub fn Valuation::commutation_n(self : Valuation, x : Int32) -> Double {
  column(self.comm.n, x)
}

///|
/// R_x = sum of M_k over k >= x.
pub fn Valuation::commutation_r(self : Valuation, x : Int32) -> Double {
  column(self.comm.r, x)
}

///|
/// S_x = sum of N_k over k >= x.
pub fn Valuation::commutation_s(self : Valuation, x : Int32) -> Double {
  column(self.comm.s, x)
}

///|
/// Read a commutation column at age `x`, treating ages past omega as zero.
fn column(values : Array[Double], x : Int32) -> Double {
  if x < 0 || x >= values.length() {
    0.0
  } else {
    values[x]
  }
}

///|
/// a-double-dot_x: expected present value of a whole life annuity-due paying 1
/// at the start of every year while (x) survives. Equals N_x / D_x.
pub fn Valuation::whole_life_annuity(self : Valuation, x : Int32) -> Double {
  self.commutation_n(x) / self.commutation_d(x)
}

///|
/// a-double-dot_{x:n}: an n-year temporary annuity-due, paying at most n times
/// at the start of each year while (x) survives. Equals (N_x - N_{x+n}) / D_x.
pub fn Valuation::temporary_annuity(
  self : Valuation,
  x : Int32,
  n : Int32,
) -> Double {
  if n <= 0 {
    0.0
  } else {
    (self.commutation_n(x) - self.commutation_n(x + n)) / self.commutation_d(x)
  }
}

///|
/// u|a-double-dot_x: an annuity-due deferred u years, first payment at age
/// x + u. Equals N_{x+u} / D_x.
pub fn Valuation::deferred_annuity(
  self : Valuation,
  x : Int32,
  u : Int32,
) -> Double {
  self.commutation_n(x + u) / self.commutation_d(x)
}

///|
/// a_x: the whole life annuity-immediate, paying at the end of each completed
/// year survived. It is always exactly one payment less than the annuity-due.
pub fn Valuation::whole_life_annuity_immediate(
  self : Valuation,
  x : Int32,
) -> Double {
  self.whole_life_annuity(x) - 1.0
}

///|
/// (Ia-double-dot)_x: increasing whole life annuity-due paying 1 in the first
/// year, 2 in the second, and so on. Equals S_x / D_x.
pub fn Valuation::increasing_annuity(self : Valuation, x : Int32) -> Double {
  self.commutation_s(x) / self.commutation_d(x)
}

///|
/// a-bar_x: a continuous whole life annuity paying at rate 1 per year for as
/// long as (x) survives. Derived from the continuous insurance Ā_x under the
/// UDD assumption using the identity 1 = Ā_x + delta * a-bar_x, with
/// Ā_x = (i / delta) * A_x. Falls back to the discrete annuity when the force
/// of interest degenerates to zero.
pub fn Valuation::continuous_annuity(self : Valuation, x : Int32) -> Double {
  let i_rate = self.interest.annual()
  let delta = self.interest.force()
  if delta == 0.0 {
    self.whole_life_annuity(x)
  } else {
    let continuous_insurance = i_rate / delta * self.whole_life_insurance(x)
    (1.0 - continuous_insurance) / delta
  }
}

///|
/// Check the universal identity 1 = A_x + d * a-double-dot_x, which must hold
/// for any valuation regardless of table or interest rate. Returns the residual
/// rather than a Boolean so a caller can judge its own tolerance.
pub fn Valuation::insurance_annuity_identity(
  self : Valuation,
  x : Int32,
) -> Double {
  let d = self.interest.discount_rate()
  self.whole_life_insurance(x) + d * self.whole_life_annuity(x) - 1.0
}
