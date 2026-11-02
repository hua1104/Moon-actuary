// Copyright 2026 hua1104. Apache-2.0.
//
// Process entry point. Everything else lives in the `cli` package, so the
// subcommands can be exercised without starting a process.

///|
fn main {
  @cli.run(@env.args())
}
