test_that("opt-in live ENCODE smoke checks cover API drift for tiny queries", {
  testthat::skip_on_cran()
  testthat::skip_if_not(
    identical(Sys.getenv("ENCODEUTILS_LIVE_TESTS"), "true"),
    "Set ENCODEUTILS_LIVE_TESTS=true to run live ENCODE smoke tests."
  )

  count <- encode_count(
    filters = list(assay_title = "total RNA-seq"),
    quiet = TRUE
  )
  expect_s3_class(count, "encode_count_result")
  expect_true(is.numeric(count$total))
  expect_match(count$query_url, "/search/", fixed = TRUE)

  search <- encode_search(
    filters = list(assay_title = "total RNA-seq"),
    limit = 1,
    metadata = "basic",
    quiet = TRUE
  )
  expect_s3_class(search, "encode_search_result")
  expect_lte(nrow(search$results), 1)
  expect_true(all(c("accession", "id", "status") %in% names(search$results)))

  schema <- encode_get_schema("Experiment", quiet = TRUE)
  expect_s3_class(schema, "encode_schema_result")
  expect_true("accession" %in% schema$properties$property)
})
