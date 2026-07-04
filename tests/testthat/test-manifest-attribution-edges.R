test_that("encode_manifest handles mixed file and experiment character inputs", {
  local_encode_test_options()
  observed_urls <- character()

  manifest <- httr2::with_mocked_responses(
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
    encode_manifest(c("ENCFFREAL001", "ENCSRREAL01"), include_session = FALSE)
  )
  attribution <- manifest$attribution

  expect_s3_class(attribution, "encode_attribution_table")
  expect_equal(manifest$accessions$accession, c("ENCFFREAL001", "ENCSRREAL01"))
  expect_true(any(attribution$file_accession == "ENCFFREAL001", na.rm = TRUE))
  expect_true(any(is.na(attribution$file_accession) & attribution$dataset_accession == "ENCSRREAL01"))
  expect_true(all(attribution$dataset_type[!is.na(attribution$file_accession)] %in% c("Experiment", "Annotation")))
  expect_true(any(grepl("type=File", observed_urls, fixed = TRUE)))
  expect_true(any(grepl("/experiments/ENCSRREAL01/", observed_urls, fixed = TRUE)))
})

test_that("encode_manifest rejects unsupported character accessions before web requests", {
  expect_error(
    encode_manifest("ENCBSREAL01", include_session = FALSE),
    "supports ENCSR and ENCFF"
  )
})
