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
if (-not ($verification -match "PASS：全部核心精算路径交叉校核通过")) {
  throw "moonactuary numerical verification failed"
}

Write-Output "moonactuary acceptance: PASS"
