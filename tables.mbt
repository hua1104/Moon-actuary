// Copyright 2026 hua1104. Apache-2.0.
//
// Typed access to the six published CL(2010-2013) tables.

///|
/// One of the six tables published as the China Life Insurance Mortality Table
/// (2010-2013). The three business lines differ substantially in observed
/// longevity and are mandated for different product types: pension business
/// carries the longest expected lifetimes and so the highest reserves.
pub enum ChinaTable {
  /// CL1: 非养老类业务一表（男）, protection-type business, table I, male.
  NonPensionIMale
  /// CL2: 非养老类业务一表（女）, protection-type business, table I, female.
  NonPensionIFemale
  /// CL3: 非养老类业务二表（男）, protection-type business, table II, male.
  NonPensionIIMale
  /// CL4: 非养老类业务二表（女）, protection-type business, table II, female.
  NonPensionIIFemale
  /// CL5: 养老类业务表（男）, pension business, male.
  PensionMale
  /// CL6: 养老类业务表（女）, pension business, female.
  PensionFemale
}

///|
/// All six tables, in publication order.
pub fn all_china_tables() -> Array[ChinaTable] {
  [
    NonPensionIMale,
    NonPensionIFemale,
    NonPensionIIMale,
    NonPensionIIFemale,
    PensionMale,
    PensionFemale,
  ]
}

///|
/// The short code used by the regulator, for example "CL1".
pub fn ChinaTable::code(self : ChinaTable) -> String {
  match self {
    NonPensionIMale => "CL1"
    NonPensionIFemale => "CL2"
    NonPensionIIMale => "CL3"
    NonPensionIIFemale => "CL4"
    PensionMale => "CL5"
    PensionFemale => "CL6"
  }
}

///|
/// The Chinese name of the table.
pub fn ChinaTable::chinese_name(self : ChinaTable) -> String {
  match self {
    NonPensionIMale => "非养老类业务一表（男）"
    NonPensionIFemale => "非养老类业务一表（女）"
    NonPensionIIMale => "非养老类业务二表（男）"
    NonPensionIIFemale => "非养老类业务二表（女）"
    PensionMale => "养老类业务表（男）"
    PensionFemale => "养老类业务表（女）"
  }
}

///|
/// The English name of the table.
pub fn ChinaTable::english_name(self : ChinaTable) -> String {
  match self {
    NonPensionIMale => "Non-pension business table I (Male)"
    NonPensionIFemale => "Non-pension business table I (Female)"
    NonPensionIIMale => "Non-pension business table II (Male)"
    NonPensionIIFemale => "Non-pension business table II (Female)"
    PensionMale => "Pension business table (Male)"
    PensionFemale => "Pension business table (Female)"
  }
}

///|
/// Whether the table is intended for pension (养老) business, which exhibits
/// the longest observed lifetimes of the three business lines.
pub fn ChinaTable::is_pension(self : ChinaTable) -> Bool {
  match self {
    PensionMale | PensionFemale => true
    _ => false
  }
}

///|
/// Look a table up by its regulator code, accepting "CL1" through "CL6" in
/// either case. `all_china_tables` remains the way to enumerate them.
pub fn ChinaTable::of_code(code : String) -> ChinaTable? {
  for candidate in all_china_tables() {
    if candidate.code().to_upper() == code.to_upper() {
      return Some(candidate)
    }
  }
  None
}

///|
/// The raw annual mortality rates qx for ages 0 through 105.
pub fn ChinaTable::qx(self : ChinaTable) -> Array[Double] {
  match self {
    NonPensionIMale => cl1_qx
    NonPensionIFemale => cl2_qx
    NonPensionIIMale => cl3_qx
    NonPensionIIFemale => cl4_qx
    PensionMale => cl5_qx
    PensionFemale => cl6_qx
  }
}

///|
/// Build a full `LifeTable` from this table. The default radix of 1,000,000
/// reproduces the survivorship columns published alongside CL(2010-2013).
pub fn ChinaTable::table(
  self : ChinaTable,
  radix~ : Double = 1000000.0,
  fraction~ : FractionalAge = UniformDeaths,
) -> LifeTable {
  LifeTable::from_qx(
    qx=self.qx(),
    id=self.code(),
    label=self.chinese_name() + " / " + self.english_name(),
    radix~,
    fraction~,
  )
}
