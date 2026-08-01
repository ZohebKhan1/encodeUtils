test_that("local paths return native reader output", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("gene,value", "MYC,2.5"), path)
  result <- encode_read(path)

  expect_s3_class(result, "data.frame")
  expect_equal(result$gene, "MYC")
  expect_equal(result$value, 2.5)
})

test_that("table input always returns a stable loaded-file collection", {
  directory <- withr::local_tempdir()
  paths <- file.path(directory, c("a.tsv", "b.tsv"))
  writeLines(c("gene_id\texpected_count\tTPM", "Gata4\t10\t2.5", "Tbx5\t0\t1.5"), paths[[1L]])
  writeLines(c("gene_id\texpected_count\tTPM", "Gata4\t20\t3.5", "Tbx5\t5\t2.0"), paths[[2L]])
  files <- data.frame(
    file_accession = c("ENCFFLOAD01", "ENCFFLOAD02"),
    experiment_accession = "ENCSRLOAD01",
    file_format = "tsv",
    output_type = "gene quantifications",
    local_path = paths,
    download_status = "downloaded",
    provenance_note = c("first", "second"),
    stringsAsFactors = FALSE
  )

  one <- encode_read(files[1L, ], values = c("raw_counts", "tpm"))
  loaded <- encode_read(files, values = c("raw_counts", "TPM"))

  expect_s3_class(one, "encode_loaded_files")
  expect_s3_class(loaded, "encode_loaded_files")
  expect_equal(names(loaded), c("metadata", "data", "row_data", "matrices"))
  expect_equal(loaded$metadata$provenance_note, c("first", "second"))
  expect_equal(names(loaded$matrices), c("raw_counts", "tpm"))
  expect_true(all(vapply(loaded$matrices, is.matrix, logical(1L))))
  expect_true(all(vapply(loaded$matrices, is.numeric, logical(1L))))
  expect_equal(colnames(loaded$matrices$raw_counts), files$file_accession)
  expect_equal(unname(loaded$matrices$raw_counts["Gata4", ]), c(10, 20))
  expect_equal(row.names(loaded$row_data), row.names(loaded$matrices$raw_counts))
  expect_equal(encode_results(loaded), loaded$metadata)
})

test_that("simplify_quant false preserves raw table columns", {
  path <- withr::local_tempfile(fileext = ".tsv")
  writeLines(c("gene_id\texpected_count\tTPM", "Gata4\t10\t2.5"), path)
  files <- data.frame(
    file_accession = "ENCFFRAW001",
    file_format = "tsv",
    local_path = path,
    download_status = "downloaded",
    stringsAsFactors = FALSE
  )

  loaded <- encode_read(
    files,
    values = "all",
    simplify_quant = FALSE,
    row_names = "none"
  )
  expect_equal(names(loaded$data[[1L]]), c("gene_id", "expected_count", "TPM"))
  expect_false("raw_counts" %in% names(loaded$data[[1L]]))
  expect_equal(names(loaded$matrices), "tpm")
})

test_that("loaded print output is compact", {
  path <- withr::local_tempfile(fileext = ".tsv")
  writeLines(c("gene_id\texpected_count", "Gata4\t10"), path)
  files <- data.frame(
    file_accession = "ENCFFPRINT1",
    file_format = "tsv",
    local_path = path,
    download_status = "downloaded",
    stringsAsFactors = FALSE
  )
  loaded <- encode_read(files)
  output <- capture_print(loaded)

  expect_true(any(grepl("ENCODE loaded files", output, fixed = TRUE)))
  expect_true(any(grepl("feature rows", output, fixed = TRUE)))
  expect_false(any(grepl("by_experiment", output, fixed = TRUE)))
})
