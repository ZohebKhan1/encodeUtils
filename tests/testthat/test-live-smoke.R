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

  files <- encode_search(
    type = "File",
    organism = "human",
    assay = "RNA-seq",
    file_format = "fastq",
    limit = 2,
    metadata = "basic",
    quiet = TRUE
  )
  expect_s3_class(files, "encode_search_result")
  file_table <- encode_results(files)
  expect_gt(nrow(file_table), 0)
  expect_true(all(c("file_accession", "experiment_accession", "organism") %in% names(file_table)))
  expect_true(all(file_table$file_format == "fastq"))
  expect_true(any(file_table$organism == "Homo sapiens"))

  chip_files <- encode_search(
    type = "File",
    organism = "human",
    assay = "ChIP-seq",
    file_format = "bed",
    limit = 2,
    metadata = "basic",
    quiet = TRUE
  )
  chip_table <- encode_results(chip_files)
  expect_gt(nrow(chip_table), 0)
  expect_true(all(chip_table$file_format == "bed"))
  expect_true(any(chip_table$organism == "Homo sapiens"))

  schema <- encode_get_schema("Experiment", quiet = TRUE)
  expect_s3_class(schema, "encode_schema_result")
  expect_true("accession" %in% schema$properties$property)
})
