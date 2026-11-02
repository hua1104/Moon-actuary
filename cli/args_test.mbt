// Copyright 2026 hua1104. Apache-2.0.
//
// Blackbox tests for the command line front end. The parser is deliberately
// tiny, so these tests pin the two things a caller can get wrong: which token
// is the subcommand, and what a flag without a value is taken to mean.

///|
test "the subcommand is the first bare token" {
  let args = @cli.Args::parse(["moonactuary", "premium", "--age", "35"])
  assert_eq(args.subcommand(), "premium")
  assert_eq(args.value("age", "30"), "35")
  assert_eq(args.int("age", 30), 35)
}

///|
test "flags read as typed values with fallbacks" {
  let args = @cli.Args::parse([
    "prog", "reserve", "--term", "15", "--rate", "3.5",
  ])
  assert_eq(args.int("term", 20), 15)
  assert_eq(args.number("rate", 2.5), 3.5)
  // Absent flags fall back rather than raising.
  assert_eq(args.value("product", "endowment"), "endowment")
  assert_eq(args.int("age", 30), 30)
  assert_eq(args.number("rate", 2.5), 3.5)
  // A flag that was never given is not present.
  assert_true(!args.present("age"), msg="age was not supplied")
}

///|
test "a bare flag is true and never swallows the next flag" {
  let args = @cli.Args::parse(["prog", "tables", "--verbose", "--table", "CL5"])
  assert_true(args.present("verbose"), msg="a bare flag should be present")
  assert_eq(args.value("verbose", "false"), "true")
  // The following flag stays a flag instead of becoming the value of the first.
  assert_eq(args.value("table", "CL1"), "CL5")
}

///|
test "a flag at the end of the line has no value to take" {
  let args = @cli.Args::parse(["prog", "table", "--from"])
  assert_eq(args.value("from", "0"), "true")
  // An empty value reads as absent, so the fallback is used for numbers.
  let missing = @cli.Args::parse(["prog", "table", "--to", "--from", "3"])
  assert_eq(missing.int("to", 105), 105)
  assert_eq(missing.int("from", 105), 3)
}

///|
test "unparsable numbers fall back instead of failing the run" {
  let args = @cli.Args::parse([
    "prog", "premium", "--age", "thirty", "--rate", "abc",
  ])
  assert_eq(args.int("age", 30), 30)
  assert_eq(args.number("rate", 2.5), 2.5)
  // The raw text is still available for the caller that wants to validate it.
  assert_eq(args.value("age", ""), "thirty")
  assert_true(!args.valid_int("age"), msg="invalid age must be detectable")
  assert_true(!args.valid_number("rate"), msg="invalid rate must be detectable")
  assert_true(args.valid_int("term"), msg="missing values use defaults")
}

///|
test "no arguments at all leaves an empty subcommand" {
  let args = @cli.Args::parse(["moonactuary"])
  assert_eq(args.subcommand(), "")
  assert_true(!args.present("help"), msg="no flags means no help flag")
}

///|
test "later occurrences of a flag do not override the first" {
  // The parser keeps every occurrence and reads the first, which is the least
  // surprising rule for a tool whose flags are all optional knobs.
  let args = @cli.Args::parse([
    "prog", "plot", "--table", "CL2", "--table", "CL6",
  ])
  assert_eq(args.value("table", "CL1"), "CL2")
}
