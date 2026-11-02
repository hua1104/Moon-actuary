// Copyright 2026 hua1104. Apache-2.0.
//
// Classical life table construction: survivorship functions derived from a
// vector of annual death probabilities.

///|
/// An assumption used to interpolate the survivorship function between two
/// consecutive integer ages. The published CL(2010-2013) values of Lx are
/// reproduced exactly by `UniformDeaths`.
pub enum FractionalAge {
  /// Uniform Distribution of Deaths (UDD, 均匀死亡分布). lx is linear between
  /// consecutive ages, so Lx = (lx + l[x+1]) / 2 exactly.
  UniformDeaths
  /// Constant force of mortality within each year of age (死亡力恒定). lx
  /// decays exponentially within the year, so Lx = -dx / ln(px).
  ConstantForce
  /// Balducci / hyperbolic assumption, in which the reciprocal of lx is linear.
  Hyperbolic
}

///|
/// Parse a fractional age assumption by name, accepting the common
/// abbreviations "udd", "cfm" and "balducci" plus their full English names.
/// Used by the command line front end and by callers loading a table from
/// configuration.
pub fn FractionalAge::parse(name : String) -> FractionalAge? {
  match name.to_lower() {
    "udd" | "uniform" | "uniformdeaths" | "uniform_deaths" =>
      Some(UniformDeaths)
    "cfm" | "constantforce" | "constant_force" => Some(ConstantForce)
    "balducci" | "hyperbolic" => Some(Hyperbolic)
    _ => None
  }
}

///|
/// A complete life table. Indices run from 0 to `limiting_age()` inclusive.
///
/// The radix follows the Chinese convention of 1,000,000 lives, matching the
/// published CL(2010-2013) survivorship columns.
pub struct LifeTable {
  id : String
  label : String
  omega : Int32
  radix : Double
  fraction : FractionalAge
  qx : Array[Double]
  lx : Array[Double]
  dx : Array[Double]
  big_lx : Array[Double]
  big_tx : Array[Double]
  ex : Array[Double]
}

///|
/// Build a life table from annual death probabilities `qx`, covering ages 0
/// through `qx.length() - 1` inclusive. The final rate must terminate the
/// table: survivors reaching the limiting age all die within that year, so
/// `qx[omega]` is expected to be 1.0.
pub fn LifeTable::from_qx(
  qx~ : Array[Double],
  id~ : String = "",
  label~ : String = "",
  radix~ : Double = 1000000.0,
  fraction~ : FractionalAge = UniformDeaths,
) -> LifeTable {
  let n = qx.length()
  let lx = Array::make(n, 0.0)
  let dx = Array::make(n, 0.0)
  let big_lx = Array::make(n, 0.0)
  let big_tx = Array::make(n, 0.0)
  let ex = Array::make(n, 0.0)
  // Forward recursion: l[x+1] = l[x] - d[x] with d[x] = l[x] * q[x].
  let mut survivor = radix
  for x in 0..<n {
    lx[x] = survivor
    dx[x] = survivor * qx[x]
    survivor = survivor - dx[x]
  }
  // Person-years Lx spent between x and x+1 by the survivors lx.
  for x in 0..<n {
    let next = if x + 1 < n { lx[x + 1] } else { 0.0 }
    big_lx[x] = integrate_year(lx[x], next, fraction)
  }
  // Backward recursion: T[x] = L[x] + T[x+1] and e[x] = T[x] / l[x].
  let mut total = 0.0
  for back in 0..<n {
    let x = n - 1 - back
    total = total + big_lx[x]
    big_tx[x] = total
    ex[x] = if lx[x] > 0.0 { total / lx[x] } else { 0.0 }
  }
  LifeTable::{
    id,
    label,
    omega: n - 1,
    radix,
    fraction,
    qx,
    lx,
    dx,
    big_lx,
    big_tx,
    ex,
  }
}

///|
/// Person-years lived between ages `x` and `x + 1` by the `l` lives attaining
/// age `x`, of whom `next` survive to age `x + 1`.
fn integrate_year(l : Double, next : Double, f : FractionalAge) -> Double {
  match f {
    UniformDeaths => (l + next) / 2.0
    ConstantForce =>
      if next > 0.0 && l > next {
        let px = next / l
        // L = (l - next) / -ln(px); the trapezoid is only a fallback for a
        // death probability so extreme that ln(px) rounds to zero.
        let mu = -@math.ln(px)
        if mu.abs() > 1.0e-300 {
          (l - next) / mu
        } else {
          (l + next) / 2.0
        }
      } else {
        l / 2.0
      }
    Hyperbolic =>
      if next > 0.0 && l > next {
        // Integral of 1 / ((1-t)/l + t/next) over t in [0, 1].
        l * next * @math.ln(l / next) / (l - next)
      } else {
        l / 2.0
      }
  }
}

///|
/// The limiting age omega: every life attaining it dies within that year.
pub fn LifeTable::limiting_age(self : LifeTable) -> Int32 {
  self.omega
}

///|
/// The radix l[0] the table was built from.
pub fn LifeTable::radix(self : LifeTable) -> Double {
  self.radix
}

///|
/// The fractional age assumption the table was built under.
pub fn LifeTable::fraction(self : LifeTable) -> FractionalAge {
  self.fraction
}

///|
/// The identifier of the table source, for example "CL1".
pub fn LifeTable::id(self : LifeTable) -> String {
  self.id
}

///|
/// A human readable name for the table.
pub fn LifeTable::label(self : LifeTable) -> String {
  self.label
}

///|
/// The annual death probability qx at exact integral age `x`. Ages past omega
/// report certainty of death; negative ages report zero mortality.
pub fn LifeTable::qx(self : LifeTable, x : Int32) -> Double {
  if x < 0 {
    0.0
  } else if x > self.omega {
    1.0
  } else {
    self.qx[x]
  }
}

///|
/// The annual survival probability px = 1 - qx.
pub fn LifeTable::px(self : LifeTable, x : Int32) -> Double {
  1.0 - self.qx(x)
}

///|
/// Survivors lx attaining exact age `x`.
pub fn LifeTable::lx(self : LifeTable, x : Int32) -> Double {
  if x < 0 || x > self.omega {
    0.0
  } else {
    self.lx[x]
  }
}

///|
/// Deaths dx occurring between ages `x` and `x + 1`.
pub fn LifeTable::dx(self : LifeTable, x : Int32) -> Double {
  if x < 0 || x > self.omega {
    0.0
  } else {
    self.dx[x]
  }
}

///|
/// Person-years Lx lived jointly by survivors of age `x` over the next year.
pub fn LifeTable::person_years(self : LifeTable, x : Int32) -> Double {
  if x < 0 || x > self.omega {
    0.0
  } else {
    self.big_lx[x]
  }
}

///|
/// Total future person-years Tx yet to be lived by survivors of age `x`.
pub fn LifeTable::total_person_years(self : LifeTable, x : Int32) -> Double {
  if x < 0 || x > self.omega {
    0.0
  } else {
    self.big_tx[x]
  }
}

///|
/// The complete expectation of life ex（平均余命）at exact age `x`, counting
/// fractional years.
pub fn LifeTable::expectation(self : LifeTable, x : Int32) -> Double {
  if x < 0 || x > self.omega {
    0.0
  } else {
    self.ex[x]
  }
}

///|
/// The curtate expectation of life（取整余命）at age `x`: the expected number
/// of whole future years survived, excluding the final partial year. Under the
/// uniform distribution of deaths this sits exactly half a year below the
/// complete expectation.
pub fn LifeTable::curtate_expectation(self : LifeTable, x : Int32) -> Double {
  if x < 0 || x > self.omega {
    0.0
  } else if self.lx[x] == 0.0 {
    0.0
  } else {
    let mut acc = 0.0
    for k in (x + 1)..<(self.omega + 1) {
      acc = acc + self.lx[k]
    }
    acc / self.lx[x]
  }
}

///|
/// t p x: the probability that a life aged `x` survives at least `t` more
/// whole years.
pub fn LifeTable::survival(self : LifeTable, x : Int32, t : Int32) -> Double {
  if x < 0 || x > self.omega {
    0.0
  } else if t <= 0 {
    1.0
  } else {
    let target = x + t
    if target > self.omega {
      0.0
    } else if self.lx[x] == 0.0 {
      0.0
    } else {
      self.lx[target] / self.lx[x]
    }
  }
}

///|
/// t q x: the probability that a life aged `x` dies within the next `t` years.
pub fn LifeTable::death_probability(
  self : LifeTable,
  x : Int32,
  t : Int32,
) -> Double {
  1.0 - self.survival(x, t)
}

///|
/// t | q x: the probability that a life aged `x` survives `t` years and then
/// dies during the following year.
pub fn LifeTable::deferred_death_probability(
  self : LifeTable,
  x : Int32,
  t : Int32,
) -> Double {
  self.survival(x, t) * self.qx(x + t)
}
