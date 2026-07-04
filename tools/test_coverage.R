#!/usr/bin/env Rscript
# Created:
# 2026-07-04
#
# Inputs:
# - DESCRIPTION: package metadata
# - R/: package source
# - tests/testthat/: package tests
#
# Outputs:
# - Console coverage summary
# - Optional RDS at ENCODEUTILS_COVERAGE_RDS
#
# Purpose:
# Run developer-local test coverage without adding covr to routine package
# check dependencies.
#
# Notes:
# Set ENCODEUTILS_COVERAGE_MIN to a numeric percent to enforce a local
# threshold. Set ENCODEUTILS_COVERAGE_RDS to save the coverage object.

if (!base::requireNamespace("covr", quietly = TRUE)) {
  base::stop(
    "The covr package is required for coverage reports. ",
    "Install it in the development library or use a CI job that provides covr.",
    call. = FALSE
  )
}

threshold_text <- base::Sys.getenv("ENCODEUTILS_COVERAGE_MIN", unset = "")
output_path <- base::Sys.getenv("ENCODEUTILS_COVERAGE_RDS", unset = "")

coverage <- covr::package_coverage()
base::print(coverage)

coverage_percent <- covr::percent_coverage(coverage)
base::cat(base::sprintf("COVERAGE_PERCENT: %.2f\n", coverage_percent))

if (base::nzchar(output_path)) {
  output_dir <- base::dirname(output_path)
  base::dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  base::saveRDS(coverage, output_path)
  base::cat("COVERAGE_RDS: ", output_path, "\n", sep = "")
}

if (base::nzchar(threshold_text)) {
  threshold <- base::suppressWarnings(base::as.numeric(threshold_text))
  if (!base::is.finite(threshold) || threshold < 0 || threshold > 100) {
    base::stop(
      "ENCODEUTILS_COVERAGE_MIN must be a numeric percent between 0 and 100.",
      call. = FALSE
    )
  }
  if (coverage_percent < threshold) {
    base::stop(
      base::sprintf(
        "Coverage %.2f is below ENCODEUTILS_COVERAGE_MIN %.2f.",
        coverage_percent,
        threshold
      ),
      call. = FALSE
    )
  }
}
