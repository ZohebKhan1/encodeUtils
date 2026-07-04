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
  expect_true("matrix" %in% names(encode_manifest(matrix, include_session = FALSE)))
  expect_true("downloaded_files" %in% names(encode_manifest(download, include_session = FALSE)))

  manifest <- encode_manifest(
    download,
    include_attribution = FALSE,
    include_session = TRUE
  )
  expect_true("session" %in% names(manifest))
  expect_false("attribution" %in% names(manifest))
  expect_equal(manifest$retrieval$query_url, encode_query_url(download))

  path <- withr::local_tempfile(fileext = ".json")
  manifest_written <- encode_manifest(
    download,
    include_attribution = FALSE,
    include_session = TRUE,
    path = path
  )
  parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  expect_s3_class(manifest_written, "encode_manifest")
  expect_equal(attr(manifest_written, "path", exact = TRUE), path)
  expect_equal(parsed$package$name, "encodeUtils")
  expect_equal(parsed$downloaded_files[[1]]$file_accession, "ENCFFREAL001")
})
