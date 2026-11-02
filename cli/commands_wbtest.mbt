// Copyright 2026 hua1104. Apache-2.0.
//
// Whitebox tests for the subcommands. These call the command functions directly
// with a parsed argument set rather than through a process, which is the only
// way to reach the report writers from a test. The point is not to check the
// wording of the output but to be certain that every subcommand, every product
// type and every error branch runs to completion on real tables.

///|
fn invocation(words : Array[String]) -> Array[String] {
  ["moonactuary"] + words
}

///|
fn argv(words : Array[String]) -> Args {
  Args::parse(invocation(words))
}

///|
test "every subcommand completes on the default arguments" {
  // Small ranges and short terms keep the captured output readable while still
  // walking every report writer.
  run(invocation(["tables"]))
  run(invocation(["table", "--from", "0", "--to", "2"]))
  run(invocation(["premium"]))
  run(invocation(["reserve", "--term", "3"]))
  run(invocation(["plot"]))
  run(invocation(["demo", "--term", "3"]))
}

///|
test "subcommands accept their full option surface" {
  for table in ["CL1", "CL2", "CL3", "CL4", "CL5", "CL6"] {
    run(
      invocation([
        "premium", "--table", table, "--age", "40", "--term", "10", "--rate", "3.5",
        "--product", "term",
      ]),
    )
    run(
      invocation([
        "reserve", "--table", table, "--age", "40", "--term", "2", "--rate", "3.5",
        "--product", "whole",
      ]),
    )
    run(invocation(["table", "--table", table, "--from", "60", "--to", "61"]))
  }
  for kind in ["mortality", "survival"] {
    run(invocation(["plot", "--kind", kind, "--table", "CL6"]))
  }
}

///|
test "unknown and missing subcommands fall back to usage" {
  // Neither branch raises: the tool explains itself and stops.
  run(invocation([]))
  run(invocation(["nonsense"]))
  run(invocation(["--help"]))
  run(invocation(["help"]))
  run(invocation(["premium", "--help"]))
}

///|
test "products are named and priced consistently" {
  assert_eq(product_name("whole"), "终身寿险")
  assert_eq(product_name("term"), "定期寿险")
  assert_eq(product_name("endowment"), "两全保险")
  assert_eq(product_name("anything else"), "未知险种")
  let china = @moonactuary.ChinaTable::of_code("CL1").unwrap()
  let v = @moonactuary.Valuation::of(
    table=china.table(),
    interest=@moonactuary.Interest::of(0.025),
  )
  // For each product the single premium is the value of the benefits and the
  // annual premium is that value spread over the premium paying period.
  for name in ["whole", "term", "endowment"] {
    let (single, annual) = single_and_annual(v, 30, 20, name)
    assert_true(single > 0.0, msg="\{name}: a benefit must cost something")
    assert_true(annual > 0.0, msg="\{name}: premiums must be positive")
    assert_true(
      annual < single,
      msg="\{name}: paying yearly costs less up front",
    )
    // The matching forward reserve at issue is zero: nothing has been paid yet
    // and nothing has been earned.
    assert_true(
      forward_reserve(v, 30, 20, 0, annual, name).abs() < 1.0e-9,
      msg="\{name}: the opening reserve should vanish",
    )
  }
  // An endowment pays out either way, so it must cost more than the term
  // insurance covering the same years.
  let (term_single, _) = single_and_annual(v, 30, 20, "term")
  let (endowment_single, _) = single_and_annual(v, 30, 20, "endowment")
  assert_true(
    endowment_single > term_single,
    msg="an endowment outprices a term",
  )
}

///|
test "interest rates are read as percentages" {
  let args = argv(["premium", "--rate", "3.5"])
  assert_eq(pick_interest(args).annual(), 0.035)
  let defaulted = argv(["premium"])
  assert_eq(pick_interest(defaulted).annual(), 0.025)
}

///|
test "min and max are the identity on equal arguments" {
  assert_eq(max_gap(0.4, 0.4), 0.4)
  assert_eq(min_gap(0.4, 0.4), 0.4)
  assert_eq(max_gap(0.1, 0.9), 0.9)
  assert_eq(min_gap(0.1, 0.9), 0.1)
}
