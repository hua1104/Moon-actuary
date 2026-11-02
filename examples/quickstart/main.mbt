// Copyright 2026 hua1104. Apache-2.0.
//
// The smallest useful program: one table, one interest rate, the five numbers
// a pricing actuary asks for first. Run it with
//
//   moon run examples/quickstart

///|
fn main {
  let china = @moonactuary.ChinaTable::of_code("CL1").unwrap()
  let table = china.table()
  let v = @moonactuary.Valuation::of(
    table~,
    interest=@moonactuary.Interest::of(0.025),
  )
  let premium = v.annual_premium_endowment(30, 20)
  println(china.code() + " " + china.chinese_name())
  println(
    "  30 岁生存人数 l30        " + @moonactuary.fixed(table.lx(30), 0),
  )
  println(
    "  30 岁平均余命 e30        " +
    @moonactuary.fixed(table.expectation(30), 2),
  )
  println(
    "  两全保险趸缴纯保费 A     " +
    @moonactuary.fixed(v.endowment_insurance(30, 20), 6),
  )
  println("  年缴均衡纯保费 P         " + @moonactuary.fixed(premium, 6))
  println(
    "  第 10 年末准备金 V       " +
    @moonactuary.fixed(v.reserve_endowment(30, 20, 10, premium), 6),
  )
}
