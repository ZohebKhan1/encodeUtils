test_that("transient HTTP failures retry and retain diagnostics", {
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
  expect_equal(result$total, 128)

  withr::local_options(list(encodeUtils.max_tries = 2L))
  error <- expect_error(
    httr2::with_mocked_responses(
      function(req) stop("network unavailable"),
      encode_search(limit = 1, quiet = TRUE)
    ),
    "ENCODE request failed"
  )
  expect_match(conditionMessage(error), "after 2 attempts")
  expect_match(conditionMessage(error), "Last error: network unavailable")
})

test_that("retry delays are capped and option values are validated", {
  retry_sleep <- getFromNamespace("encode_retry_sleep", "encodeUtils")
  response <- httr2::response(
    429,
    headers = c("retry-after: 120", "content-type: application/json"),
    body = charToRaw("{}")
  )
  withr::local_options(list(encodeUtils.max_retry_seconds = 0))
  expect_equal(retry_sleep(1L, response), 0)

  withr::local_options(list(
    encodeUtils.retry_base_seconds = "invalid",
    encodeUtils.max_retry_seconds = 1
  ))
  expect_error(retry_sleep(1L), "retry_base_seconds")

  withr::local_options(list(encodeUtils.rate_per_second = "invalid"))
  expect_error(
    httr2::with_mocked_responses(
      function(req) fixture_json_response("search-embedded-experiments.json"),
      encode_search(quiet = TRUE)
    ),
    "rate_per_second"
  )
})

test_that("empty searches and JSON errors are distinguished", {
  local_encode_test_options()
  empty <- httr2::with_mocked_responses(
    function(req) httr2::response(
      404,
      headers = "Content-Type: application/json",
      body = charToRaw('{"@graph":[],"total":0,"title":"Search"}')
    ),
    encode_search(quiet = TRUE)
  )
  expect_equal(empty$total, 0)
  expect_equal(nrow(empty$results), 0L)

  expect_error(
    httr2::with_mocked_responses(
      function(req) httr2::response(
        400,
        headers = "Content-Type: application/json",
        body = charToRaw('{"title":"Bad request","detail":"Unknown field"}')
      ),
      encode_search(quiet = TRUE)
    ),
    "HTTP 400.*Bad request.*Unknown field"
  )
})
