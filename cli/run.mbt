// Copyright 2026 hua1104. Apache-2.0.
//
// Entry point for the command line front end. The subcommand surface is
// enumerated in exactly one place; `cmd/main` is a three line wrapper whose
// only job is to hand over `argv`.

///|
/// Run the tool: parse `argv` and dispatch to the requested subcommand.
pub fn run(argv : Array[String]) -> Unit {
  let args = Args::parse(argv)
  if args.present("help") {
    usage()
    return
  }
  if !validate_args(args) {
    return
  }
  match args.subcommand() {
    "tables" => cmd_tables(args)
    "table" => cmd_table(args)
    "premium" => cmd_premium(args)
    "reserve" => cmd_reserve(args)
    "plot" => cmd_plot(args)
    "demo" => cmd_demo(args)
    "verify" => cmd_verify(args)
    "help" => usage()
    "" => {
      println(
        "错误：缺少命令，可用 tables | table | premium | reserve | plot | demo | verify",
      )
      println("")
      usage()
    }
    other => {
      println("错误：未知命令 " + other)
      println("")
      usage()
    }
  }
}

///|
/// Validate user-controlled CLI values before they reach array indexing or
/// actuarial ratios. Invalid input becomes a normal command-line error.
fn validate_args(args : Args) -> Bool {
  let command = args.subcommand()
  if command == "" ||
    command == "help" ||
    command == "tables" ||
    command == "verify" {
    return true
  }
  if command != "table" &&
    command != "premium" &&
    command != "reserve" &&
    command != "plot" &&
    command != "demo" {
    return true
  }
  let code = args.value("table", "CL1")
  let table = match @moonactuary.ChinaTable::of_code(code) {
    Some(found) => found.table()
    None => {
      println(
        "错误：未知经验表 " + code + "，可选 CL1 CL2 CL3 CL4 CL5 CL6",
      )
      return false
    }
  }
  if command == "plot" {
    let kind = args.value("kind", "mortality")
    if kind != "mortality" && kind != "survival" {
      println(
        "错误：未知曲线 " + kind + "，可选 mortality | survival",
      )
      return false
    }
    return true
  }
  if command == "table" {
    if !args.valid_int("from") || !args.valid_int("to") {
      println("错误：--from 和 --to 必须是整数")
      return false
    }
    let low = args.int("from", 0)
    let high = args.int("to", table.limiting_age())
    if low < 0 || high > table.limiting_age() || low > high {
      println(
        "错误：年龄区间必须满足 0 <= from <= to <= \{table.limiting_age()}",
      )
      return false
    }
    return true
  }
  if !args.valid_int("age") ||
    !args.valid_int("term") ||
    !args.valid_number("rate") {
    println("错误：--age、--term 必须是整数，--rate 必须是数字")
    return false
  }
  let product = args.value("product", "endowment")
  if product != "whole" && product != "term" && product != "endowment" {
    println(
      "错误：未知险种 " + product + "，可选 whole | term | endowment",
    )
    return false
  }
  let age = args.int("age", 30)
  let term = args.int("term", 20)
  let rate = args.number("rate", 2.5)
  if age < 0 || age >= table.limiting_age() {
    println(
      "错误：投保年龄必须在 0..\{table.limiting_age() - 1} 之间",
    )
    return false
  }
  if term <= 0 || age + term > table.limiting_age() {
    println(
      "错误：保险期间必须为正，且投保年龄 + 期间不能超过 \{table.limiting_age()}",
    )
    return false
  }
  if rate <= -100.0 || rate > 100.0 {
    println("错误：预定利率必须大于 -100% 且不超过 100%")
    return false
  }
  true
}
