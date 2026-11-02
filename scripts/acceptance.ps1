$ErrorActionPreference = "Stop"

moon info
git diff --exit-code -- "*.mbti"
moon fmt --check
moon check --target all
moon test
moon build --target wasm
moon build --target wasm-gc
moon build --target js

$verification = moon run cmd/main verify
$verification
if (-not ($verification | Select-String -SimpleMatch "PASS" -Quiet)) {
  throw "moonactuary numerical verification failed"
}

Write-Output "moonactuary acceptance: PASS"
