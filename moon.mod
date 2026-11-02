// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "hua1104/moonactuary"

version = "0.1.1"

readme = "README.md"

repository = "https://github.com/hua1104/moonactuary"

license = "Apache-2.0"

keywords = [
  "actuarial",
  "actuarial-science",
  "life-insurance",
  "life-table",
  "mortality",
  "china",
  "cl2010-2013",
  "reserves",
]

preferred_target = "wasm"

description = "Actuarial library for the China Life Insurance Mortality Table (CL 2010-2013): survivorship, commutation columns, net single and annual premiums, and reserves by three independent methods, with a command line tool and a dependency-free SVG chart renderer."
