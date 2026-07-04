test_that("retry loop returns successful response after a transient failure", {
  local_encode_test_options()
  calls <- 0L
  result <- httr2::with_mocked_responses(
    function(req) {
      calls <<- calls + 1L
      if (calls == 1L) {
        return(httr2::response(
          503,
          headers = "Content-Type: application/json",
          body = charToRaw('{"description":"try again"}')
        ))
      }
      fixture_json_response("search-embedded-experiments.json")
    },
    encode_search(limit = 2, quiet = TRUE)
  )

  expect_equal(calls, 2L)
  expect_s3_class(result, "encode_search_result")
  expect_equal(result$total, 128)
})
