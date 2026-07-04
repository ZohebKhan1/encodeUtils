test_that("schema lookup normalizes identifiers and preserves property detail", {
  local_encode_test_options()
  observed_urls <- character()
  schema <- httr2::with_mocked_responses(
    function(req) {
      observed_urls <<- c(observed_urls, req$url)
      fixture_json_response("schema-file.json")
    },
    encode_get_schema("AnalysisStepVersion", quiet = TRUE)
  )

  expect_s3_class(schema, "encode_schema_result")
  expect_match(observed_urls[[1]], "/profiles/analysis_step_version.json", fixed = TRUE)
  expect_equal(schema$title, "File")
  expect_true("accession" %in% schema$required)
  expect_true(schema$properties$required[schema$properties$property == "dataset"])
  expect_equal(schema$properties$type[schema$properties$property == "dataset"], "Dataset")
  expect_match(schema$properties$enum[schema$properties$property == "file_format"], "fastq")

  observed_url <- NULL
  fields <- httr2::with_mocked_responses(
    function(req) {
      observed_url <<- req$url
      fixture_json_response("schema-file.json")
    },
    encode_search_fields("/profiles/file.json")
  )
  expect_match(observed_url, "/profiles/file.json", fixed = TRUE)
  expect_true(all(c("property", "type", "required") %in% names(fields)))
})

test_that("report endpoint validates field input and TSV shape", {
  local_encode_test_options()
  expect_error(encode_report(fields = character(), quiet = TRUE), "non-empty")
  expect_error(encode_report(fields = "", quiet = TRUE), "non-empty")

  observed_url <- NULL
  report <- httr2::with_mocked_responses(
    function(req) {
      observed_url <<- req$url
      fixture_text_response("report-small.tsv")
    },
    encode_report(
      fields = c("accession", "assay_title"),
      endpoint = "report",
      allow_large = TRUE,
      filters = list(assay_title = "total RNA-seq"),
      quiet = TRUE
    )
  )
  expect_s3_class(report, "encode_report_result")
  expect_equal(nrow(report$report), 2)
  expect_match(observed_url, "field=accession", fixed = TRUE)
  expect_match(observed_url, "field=assay_title", fixed = TRUE)
  expect_match(observed_url, "assay_title=total%20RNA-seq", fixed = TRUE)

  expect_error(
    httr2::with_mocked_responses(
      function(req) fixture_text_response("report-empty.tsv"),
      encode_report(
        fields = "accession",
        endpoint = "report",
        allow_large = TRUE,
        quiet = TRUE
      )
    ),
    "did not include a table"
  )
})

test_that("report search endpoint collapses list-valued fields deterministically", {
  local_encode_test_options()
  report <- httr2::with_mocked_responses(
    function(req) fixture_json_response("search-embedded-experiments.json"),
    encode_report(
      fields = c("accession", "files", "biosample_ontology.term_name"),
      limit = 2,
      quiet = TRUE
    )
  )

  expect_equal(report$report$accession[[1]], "ENCSRREAL01")
  expect_match(report$report$files[[1]], "/files/ENCFFREAL001/", fixed = TRUE)
  expect_equal(report$report$biosample_ontology.term_name[[1]], "heart")
  expect_true(is.na(report$report$biosample_ontology.term_name[[2]]))
})

test_that("encode_list_files validates input variants and many-experiment guard", {
  many <- data.frame(accession = sprintf("ENCSR%06d", seq_len(26L)))
  expect_error(encode_list_files(many, quiet = TRUE), "Refusing to list files")
  expect_error(encode_list_files("not-an-accession", quiet = TRUE), "Expected")

  search_result <- httr2::with_mocked_responses(
    function(req) fixture_json_response("search-embedded-experiments.json"),
    encode_search(limit = 2, quiet = TRUE)
  )
  observed_url <- NULL
  files <- httr2::with_mocked_responses(
    function(req) {
      observed_url <<- req$url
      fixture_json_response("file-search-mixed.json")
    },
    encode_list_files(search_result, status = NULL, quiet = TRUE)
  )
  expect_s3_class(files, "encode_file_table")
  expect_equal(nrow(files), 3)
  expect_match(observed_url, "dataset=%2Fexperiments%2FENCSRREAL01%2F", fixed = TRUE)
})

test_that("manifests preserve branch-specific payloads and JSON round trips", {
  local_encode_test_options()
  search <- httr2::with_mocked_responses(
    function(req) fixture_json_response("search-embedded-experiments.json"),
    encode_search(limit = 2, quiet = TRUE)
  )
  object <- httr2::with_mocked_responses(
    function(req) fixture_json_response("experiment-object.json"),
    encode_get("ENCSRREAL01", quiet = TRUE)
  )
  report <- httr2::with_mocked_responses(
    function(req) fixture_text_response("report-small.tsv"),
    encode_report(
      fields = "accession",
      endpoint = "report",
      allow_large = TRUE,
      quiet = TRUE
    )
  )
  matrix <- httr2::with_mocked_responses(
    function(req) fixture_json_response("matrix-small.json"),
    encode_matrix(quiet = TRUE)
  )
  download <- encode_download(
    fixture_download_files()[1, , drop = FALSE],
    directory = withr::local_tempdir(),
    dry_run = TRUE,
    quiet = TRUE
  )

  expect_true("experiments" %in% names(encode_manifest(search, include_session = FALSE)))
  expect_true("object" %in% names(encode_manifest(object, include_session = FALSE)))
  expect_true("report" %in% names(encode_manifest(report, include_session = FALSE)))
  expect_true("matrix" %in% names(encode_manifest(matrix, include_session = FALSE)))
  expect_true("downloaded_files" %in% names(encode_manifest(download, include_session = FALSE)))

  manifest <- encode_manifest(
    download,
    include_citation = FALSE,
    include_session = TRUE
  )
  expect_true("session" %in% names(manifest))
  expect_false("citation" %in% names(manifest))
  expect_equal(manifest$retrieval$query_url, encode_query_url(download))

  path <- withr::local_tempfile(fileext = ".json")
  expect_identical(encode_write_manifest(manifest, path), path)
  parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  expect_equal(parsed$package$name, "encodeUtils")
  expect_equal(parsed$downloaded_files[[1]]$file_accession, "ENCFFREAL001")
})
