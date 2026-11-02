#!/usr/bin/env bash
set -euo pipefail

moon info
git diff --exit-code -- '*.mbti'
moon fmt --check
moon check --target all
moon test --target all
moon build --target all
moon run cmd/main verify | tee acceptance.txt
grep -q 'PASS：全部核心精算路径交叉校核通过' acceptance.txt
rm -f acceptance.txt

printf 'moonactuary acceptance: PASS\n'
