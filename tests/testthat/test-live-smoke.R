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

test_that("opt-in live ENCODE smoke checks cover one small download/read/manifest workflow", {
  testthat::skip_on_cran()
  testthat::skip_if_not(
    identical(Sys.getenv("ENCODEUTILS_LIVE_TESTS"), "true"),
    "Set ENCODEUTILS_LIVE_TESTS=true to run live ENCODE smoke tests."
  )

  files <- encode_search(
    type = "File",
    organism = "mouse",
    assay = "RNA-seq",
    file_format = "tsv",
    output_type = "gene quantifications",
    status = "released",
    limit = 10,
    metadata = "basic",
    quiet = TRUE
  )
  table <- encode_results(files)
  table <- table[!is.na(table$file_size) & table$file_size <= 10 * 1024^2, , drop = FALSE]
  testthat::skip_if(nrow(table) == 0L, "No size-capped live RNA-seq TSV file found.")
  table <- table[order(table$file_size), , drop = FALSE][1, , drop = FALSE]
  directory <- withr::local_tempdir()

  plan <- encode_download(
    table,
    directory = directory,
    dry_run = TRUE,
    max_file_size = "10MB",
    max_total_size = "10MB",
    quiet = TRUE
  )
  expect_s3_class(plan, "encode_download_result")
  expect_lte(plan$file_size[[1]], 10 * 1024^2)

  downloaded <- encode_download(
    table,
    directory = directory,
    max_file_size = "10MB",
    max_total_size = "10MB",
    quiet = TRUE
  )
  loaded <- encode_read(downloaded, row_names = "none")
  manifest <- encode_manifest(downloaded, include_session = FALSE)

  expect_s3_class(downloaded, "encode_download_result")
  expect_true(file.exists(downloaded$local_path[[1]]))
  expect_s3_class(loaded, "data.frame")
  expect_true(any(c("gene_id", "gene_symbol", "raw_counts", "counts") %in% names(loaded)))
  expect_s3_class(manifest, "encode_manifest")
  expect_true("downloaded_files" %in% names(manifest))
})
