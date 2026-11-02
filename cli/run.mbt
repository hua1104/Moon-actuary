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
  match args.subcommand() {
    "tables" => cmd_tables(args)
    "table" => cmd_table(args)
    "premium" => cmd_premium(args)
    "reserve" => cmd_reserve(args)
    "plot" => cmd_plot(args)
    "demo" => cmd_demo(args)
    "help" => usage()
    "" => {
      println(
        "错误：缺少命令，可用 tables | table | premium | reserve | plot | demo",
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
