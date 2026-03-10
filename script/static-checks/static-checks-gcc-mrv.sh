#!/usr/bin/env bash
#
# Copyright (c) 2025, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# static-checks-gcc-mrv.sh
#
# This script verifies that the GCC toolchain version used by the CI meets the
# Minimum Required Version (MRV) documented in the TF-A prerequisites.

LOG_FILE=$(mktemp -t gcc-mrv-check.XXXX)
EXIT_VALUE=0

DOC_FILE="docs/getting_started/prerequisites.rst"
UTILS_FILE="${CI_ROOT}/utils.sh"

TEST_CASE="GCC Minimum Required Version (MRV) check"

echo "# Check GCC Minimum Required Version"
echo

# Extract minimum required version from TF-A prerequisites.rst
if [ ! -f "${DOC_FILE}" ]; then
	echo "ERROR: Prerequisites file not found: ${DOC_FILE}" | tee -a "${LOG_FILE}"
	EXIT_VALUE=1
fi

if [[ "${EXIT_VALUE}" == 0 ]]; then
	min_version=$(grep -E "^Arm GNU Compiler[[:space:]]" "${DOC_FILE}" | \
		grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?$')

	if [ -z "${min_version}" ]; then
		echo "ERROR: Could not extract minimum GCC version from ${DOC_FILE}" \
			| tee -a "${LOG_FILE}"
		EXIT_VALUE=1
	fi
fi

# Extract CI GCC version from utils.sh
if [[ "${EXIT_VALUE}" == 0 ]]; then
	if [ ! -f "${UTILS_FILE}" ]; then
		echo "ERROR: CI utils file not found: ${UTILS_FILE}" | tee -a "${LOG_FILE}"
		EXIT_VALUE=1
	fi
fi

if [[ "${EXIT_VALUE}" == 0 ]]; then
	# Support both single- and double-quoted assignments and unquoted values
	ci_version=$(grep '^gcc_version=' "${UTILS_FILE}" | \
		sed -E "s/^gcc_version=['\"]?([^'\"[:space:]]+)['\"]?.*$/\1/")

	if [ -z "${ci_version}" ]; then
		echo "ERROR: Could not extract gcc_version from ${UTILS_FILE}" \
			| tee -a "${LOG_FILE}"
		EXIT_VALUE=1
	fi
fi

if [[ "${EXIT_VALUE}" == 0 ]]; then
	# Normalize CI version to major.minor (e.g. "14.3.rel1" -> "14.3")
	ci_ver_normalized=$(echo "${ci_version}" | grep -oE '^[0-9]+\.[0-9]+')

	if [ -z "${ci_ver_normalized}" ]; then
		echo "ERROR: Could not parse major.minor from CI GCC version '${ci_version}'" \
			| tee -a "${LOG_FILE}"
		EXIT_VALUE=1
	fi
fi

if [[ "${EXIT_VALUE}" == 0 ]]; then
	echo "Minimum required GCC version (from ${DOC_FILE}): ${min_version}"
	echo "CI GCC version (from utils.sh): ${ci_version} (normalized: ${ci_ver_normalized})"
	echo

	# Compare versions: check that CI version >= minimum required version.
	# sort -V sorts in version order; the lowest version ends up first.
	if [ "$(printf '%s\n' "${min_version}" "${ci_ver_normalized}" | \
			sort -V | head -1)" != "${min_version}" ]; then
		echo "ERROR: CI GCC version ${ci_ver_normalized} is below the minimum" \
			"required version ${min_version}." | tee -a "${LOG_FILE}"
		EXIT_VALUE=1
	else
		echo "GCC version check passed: ${ci_ver_normalized} >= ${min_version}"
	fi
fi

echo >> "${LOG_TEST_FILENAME}"
echo "****** ${TEST_CASE} ******" >> "${LOG_TEST_FILENAME}"
echo >> "${LOG_TEST_FILENAME}"

if [[ "${EXIT_VALUE}" == 0 ]]; then
	echo "Result : SUCCESS" >> "${LOG_TEST_FILENAME}"
else
	echo "Result : FAILURE" >> "${LOG_TEST_FILENAME}"
fi

echo >> "${LOG_TEST_FILENAME}"
cat "${LOG_FILE}" >> "${LOG_TEST_FILENAME}"
echo >> "${LOG_TEST_FILENAME}"

rm -f "${LOG_FILE}"

exit "${EXIT_VALUE}"
