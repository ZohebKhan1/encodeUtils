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

test_that("retry exhaustion reports URL and last connection error", {
  local_encode_test_options()
  error <- expect_error(
    httr2::with_mocked_responses(
      function(req) stop("network unavailable"),
      encode_search(limit = 1, quiet = TRUE)
    ),
    "ENCODE request failed"
  )
  expect_match(conditionMessage(error), "URL:")
  expect_match(conditionMessage(error), "search")
  expect_match(conditionMessage(error), "Last error: network unavailable")
})
