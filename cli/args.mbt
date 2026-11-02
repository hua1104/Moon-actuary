// Copyright 2026 hua1104. Apache-2.0.
//
// Command line argument handling. Deliberately small: flags are recognised as
// `--key value` pairs and anything else is treated as the subcommand, which is
// enough for a tool whose whole surface is six subcommands.

///|
/// Parsed arguments: one subcommand plus a set of flags.
pub struct Args {
  command : String
  flags : Array[(String, String)]
}

///|
/// Parse `argv` as produced by the host. The first element is the executable
/// path and is skipped.
pub fn Args::parse(argv : Array[String]) -> Args {
  let mut flags : Array[(String, String)] = []
  let mut command = ""
  let mut index = 1
  let limit = argv.length()
  while index < limit {
    let token = argv[index]
    if token.has_prefix("--") {
      let key = token[2:token.length()].to_owned()
      let following = if index + 1 < limit { argv[index + 1] } else { "" }
      if index + 1 < limit && !following.has_prefix("--") {
        flags = append(flags, (key, following))
        index = index + 2
      } else {
        flags = append(flags, (key, "true"))
        index = index + 1
      }
    } else {
      if command == "" {
        command = token
      }
      index = index + 1
    }
  }
  Args::{ command, flags, }
}

///|
/// The subcommand the user asked for, or `""` when they gave none.
pub fn Args::subcommand(self : Args) -> String {
  self.command
}

///|
/// Read a string flag, falling back to `fallback` when absent.
pub fn Args::value(self : Args, key : String, fallback : String) -> String {
  for entry in self.flags {
    let (k, v) = entry
    if k == key {
      return v
    }
  }
  fallback
}

///|
/// Read an integer flag, falling back to `fallback` when absent or unparsable.
pub fn Args::int(self : Args, key : String, fallback : Int32) -> Int32 {
  let raw = self.value(key, "")
  if raw == "" {
    fallback
  } else {
    @strconv.parse_int(raw) catch {
      _ => fallback
    }
  }
}

///|
/// Read a numeric flag. Interest rates are given as percentages, so `--rate 2.5`
/// reads as an effective annual rate of 2.5%.
pub fn Args::number(self : Args, key : String, fallback : Double) -> Double {
  let raw = self.value(key, "")
  if raw == "" {
    fallback
  } else {
    @strconv.parse_double(raw) catch {
      _ => fallback
    }
  }
}

///|
/// Whether a supplied integer flag is syntactically valid. Missing flags are
/// valid because every command has a documented default.
pub fn Args::valid_int(self : Args, key : String) -> Bool {
  let raw = self.value(key, "")
  if raw == "" {
    true
  } else {
    ignore(@strconv.parse_int(raw) catch { _ => return false })
    true
  }
}

///|
/// Whether a supplied floating-point flag is syntactically valid.
pub fn Args::valid_number(self : Args, key : String) -> Bool {
  let raw = self.value(key, "")
  if raw == "" {
    true
  } else {
    ignore(@strconv.parse_double(raw) catch { _ => return false })
    true
  }
}

///|
/// Whether a bare flag was supplied.
pub fn Args::present(self : Args, key : String) -> Bool {
  for entry in self.flags {
    let (k, _v) = entry
    if k == key {
      return true
    }
  }
  false
}

///|
/// Append without mutating, since the flag list is a value inside `Args`.
fn append(
  source : Array[(String, String)],
  entry : (String, String),
) -> Array[(String, String)] {
  let out = Array::make(source.length() + 1, ("", ""))
  let mut i = 0
  for existing in source {
    out[i] = existing
    i = i + 1
  }
  out[i] = entry
  out
}
