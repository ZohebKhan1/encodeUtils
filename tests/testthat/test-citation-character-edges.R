test_that("encode_cite handles mixed file and experiment character inputs", {
  local_encode_test_options()
  observed_urls <- character()

  citation <- httr2::with_mocked_responses(
    function(req) {
      observed_urls <<- c(observed_urls, req$url)
      if (grepl("/search/", req$url, fixed = TRUE) &&
        grepl("type=File", req$url, fixed = TRUE)) {
        return(fixture_json_response("file-search-mixed.json"))
      }
      if (grepl("/search/", req$url, fixed = TRUE) &&
        grepl("type=Experiment", req$url, fixed = TRUE)) {
        return(fixture_json_response("search-embedded-experiments.json"))
      }
      if (grepl("/experiments/ENCSRREAL01/", req$url, fixed = TRUE)) {
        return(fixture_json_response("experiment-object.json"))
      }
      httr2::response(
        404,
        headers = "Content-Type: application/json",
        body = charToRaw('{"title":"unexpected test URL"}')
      )
    },
    encode_cite(c("ENCFFREAL001", "ENCSRREAL01"), quiet = TRUE)
  )

  expect_s3_class(citation, "encode_citation_table")
  expect_true(any(citation$file_accession == "ENCFFREAL001", na.rm = TRUE))
  expect_true(any(is.na(citation$file_accession) & citation$dataset_accession == "ENCSRREAL01"))
  expect_true(all(citation$dataset_type[!is.na(citation$file_accession)] %in% c("Experiment", "Annotation")))
  expect_true(any(grepl("type=File", observed_urls, fixed = TRUE)))
  expect_true(any(grepl("/experiments/ENCSRREAL01/", observed_urls, fixed = TRUE)))
})

test_that("encode_cite rejects unsupported character accessions before web requests", {
  expect_error(
    encode_cite("ENCBSREAL01", quiet = TRUE),
    "supports ENCSR and ENCFF"
  )
})
