fixture_path <- function(...) {
  testthat::test_path("fixtures", ...)
}

encode_test_internal <- function(name) {
  getFromNamespace(name, "encodeUtils")
}

encode_browse <- encode_test_internal("encode_browse")
encode_count <- encode_test_internal("encode_count")
encode_facets <- encode_test_internal("encode_facets")
encode_file_preset <- encode_test_internal("encode_file_preset")
encode_file_summary <- encode_test_internal("encode_file_summary")
encode_filter_results <- encode_test_internal("encode_filter_results")
encode_filters <- encode_test_internal("encode_filters")
encode_get_schema <- encode_test_internal("encode_get_schema")
encode_largest_files <- encode_test_internal("encode_largest_files")
encode_query_url <- encode_test_internal("encode_query_url")
encode_search_fields <- encode_test_internal("encode_search_fields")
encode_select <- encode_test_internal("encode_select")
encode_size <- encode_test_internal("encode_size")
encode_summary <- encode_test_internal("encode_summary")

fixture_text <- function(...) {
  paste(readLines(fixture_path(...), warn = FALSE), collapse = "\n")
}

fixture_json_response <- function(name, status = 200) {
  httr2::response(
    status,
    headers = "Content-Type: application/json",
    body = charToRaw(fixture_text(name))
  )
}

fixture_text_response <- function(name, status = 200) {
  httr2::response(
    status,
    headers = "Content-Type: text/tab-separated-values",
    body = charToRaw(fixture_text(name))
  )
}

local_encode_test_options <- function() {
  withr::local_options(list(
    encodeUtils.rate_per_second = FALSE,
    encodeUtils.max_tries = 3,
    encodeUtils.retry_base_seconds = 0
  ))
}

fixture_download_files <- function() {
  data.frame(
    file_accession = c("ENCFFREAL001", "ENCFFREAL002", "ENCFFREAL003"),
    experiment_accession = c("ENCSRREAL01", "ENCSRREAL01", "ENCSRREAL02"),
    file_format = c("txt", "txt", "bigWig"),
    output_type = c("metadata", "metadata", "fold change over control"),
    assembly = c("GRCh38", "GRCh38", "GRCh38"),
    href = c(
      "/files/ENCFFREAL001/@@download/ENCFFREAL001.txt",
      "/files/ENCFFREAL002/@@download/ENCFFREAL002.txt",
      "/files/ENCFFREAL003/@@download/ENCFFREAL003.bigWig"
    ),
    file_size = c(3, 3, NA_real_),
    md5sum = c(
      "900150983cd24fb0d6963f7d28e17f72",
      "900150983cd24fb0d6963f7d28e17f72",
      NA_character_
    ),
    status = "released",
    stringsAsFactors = FALSE
  )
}

fixture_large_file_table <- function(n = 120L) {
  stopifnot(n >= 12L)
  accessions <- sprintf("ENCFF%06d", seq_len(n))
  formats <- rep(c("fastq", "bed", "bigWig", "tsv"), length.out = n)
  output_types <- rep(
    c("reads", "optimal IDR thresholded peaks", "fold change over control", "gene counts"),
    length.out = n
  )
  data.frame(
    file_accession = accessions,
    experiment_accession = sprintf("ENCSR%06d", rep(seq_len(12L), length.out = n)),
    file_format = formats,
    output_type = output_types,
    assembly = rep(c("GRCh38", "hg19", NA_character_), length.out = n),
    status = rep(c("released", "released", "archived"), length.out = n),
    href = paste0("/files/", accessions, "/@@download/shared-name.dat"),
    file_size = c(seq_len(n - 5L) * 1000, rep(NA_real_, 5L)),
    md5sum = NA_character_,
    biological_replicates = rep(c("1", NA_character_), length.out = n),
    preferred_default = rep(c(TRUE, FALSE, NA), length.out = n),
    stringsAsFactors = FALSE
  )
}
