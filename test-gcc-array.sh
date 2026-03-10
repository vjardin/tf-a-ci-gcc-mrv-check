#!/bin/bash
#
# Test script for GCC -Warray-bounds= false positive on low MMIO addresses.
# Reproduces the mv-ddr-marvell / TF-A CI build failure and validates the fix.
#
# Usage: ./test-gcc-array.sh [aarch64-linux-gnu-gcc|aarch64-none-elf-gcc|...]
#

CC="${1:-aarch64-linux-gnu-gcc}"

if ! command -v "$CC" >/dev/null 2>&1; then
	echo "ERROR: $CC not found in PATH"
	exit 1
fi

echo "Compiler: $($CC --version | head -1)"
echo ""

CFLAGS="-Wall -Werror -Os -march=armv8-a -ffreestanding"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SRCDIR/test-gcc.c"

pass=0
fail=0

run_test() {
	local desc="$1"
	local expect="$2"
	shift 2

	echo "--- $desc ---"
	echo "  \$ $CC $* -c $SRC -o /dev/null"
	output=$("$CC" "$@" -c "$SRC" -o /dev/null 2>&1)
	rc=$?

	if [ "$expect" = "pass" ] && [ "$rc" -eq 0 ]; then
		echo "  PASS (exit=$rc)"
		pass=$((pass + 1))
	elif [ "$expect" = "fail" ] && [ "$rc" -ne 0 ]; then
		echo "  PASS (expected failure, exit=$rc)"
		echo "$output" | sed 's/^/  | /'
		pass=$((pass + 1))
	else
		echo "  FAIL (expected=$expect, exit=$rc)"
		echo "$output" | sed 's/^/  | /'
		fail=$((fail + 1))
	fi
	echo ""
}

# Test 1: original code with strict -Werror : must fail
run_test \
	"Original code, strict -Werror (reproduces CI failure)" \
	"fail" \
	$CFLAGS

# Test 2: original code with -Wno-error=array-bounds (current mv-ddr Makefile workaround)
run_test \
	"Original code, -Wno-error=array-bounds (mv-ddr Makefile workaround)" \
	"pass" \
	$CFLAGS -Wno-error=array-bounds

# Test 3: original code with --param=min-pagesize=0 (tells GCC address 0 is valid)
run_test \
	"Original code, --param=min-pagesize=0 (no source change needed)" \
	"pass" \
	$CFLAGS --param=min-pagesize=0

# Test 4: volatile fix with strict -Werror : must pass with no warnings
run_test \
	"Volatile fix, strict -Werror (proposed source fix)" \
	"pass" \
	$CFLAGS -DTEST_VOLATILE_FIX

# Test 5: volatile fix + --param=min-pagesize=0 : must pass
run_test \
	"Volatile fix + --param=min-pagesize=0 (belt and suspenders)" \
	"pass" \
	$CFLAGS -DTEST_VOLATILE_FIX --param=min-pagesize=0

echo "========================="
echo "Results: $pass passed, $fail failed"
echo "========================="
exit "$fail"
