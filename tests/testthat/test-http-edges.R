test_that("Retry-After headers parse bounded delays and ignore malformed values", {
  retry_after <- getFromNamespace("encode_retry_after", "encodeUtils")

  numeric_response <- httr2::response(
    429,
    headers = c("retry-after: 0", "content-type: application/json"),
    body = charToRaw("{}")
  )
  expect_equal(retry_after(numeric_response), 0)

  past_date <- "Sat, 01 Jan 2000 00:00:00 GMT"
  date_response <- httr2::response(
    429,
    headers = c(
      paste0("retry-after: ", past_date),
      "content-type: application/json"
    ),
    body = charToRaw("{}")
  )
  expect_equal(retry_after(date_response), 0)

  malformed_response <- httr2::response(
    429,
    headers = c("retry-after: eventually", "content-type: application/json"),
    body = charToRaw("{}")
  )
  expect_true(is.na(retry_after(malformed_response)))
})

test_that("HTTP 429 retry-after behavior is capped and diagnostic", {
  local_encode_test_options()
  withr::local_options(list(encodeUtils.max_tries = 2))
  calls <- 0L

  err <- tryCatch(
    httr2::with_mocked_responses(
      function(req) {
        calls <<- calls + 1L
        httr2::response(
          429,
          headers = c("retry-after: 0", "content-type: application/json"),
          body = charToRaw('{"title":"Too Many Requests","detail":"rate limit exceeded"}')
        )
      },
      encode_search(quiet = TRUE)
    ),
    error = identity
  )

  expect_equal(calls, 2L)
  expect_s3_class(err, "rlang_error")
  expect_match(conditionMessage(err), "HTTP 429")
  expect_match(conditionMessage(err), "/search/", fixed = TRUE)
  expect_match(conditionMessage(err), "Too Many Requests")
  expect_match(conditionMessage(err), "rate limit exceeded")
})

test_that("ENCODE JSON error payload variants are surfaced in request errors", {
  local_encode_test_options()
  err <- tryCatch(
    httr2::with_mocked_responses(
      function(req) {
        httr2::response(
          400,
          headers = "Content-Type: application/json",
          body = charToRaw(paste0(
            '{"title":"Bad request",',
            '"detail":"Unknown field assay.invalid",',
            '"notification":"Invalid search parameter",',
            '"@type":["HTTPBadRequest"]}'
          ))
        )
      },
      encode_search(filters = list("assay.invalid" = "x"), quiet = TRUE)
    ),
    error = identity
  )

  expect_s3_class(err, "rlang_error")
  expect_match(conditionMessage(err), "HTTP 400")
  expect_match(conditionMessage(err), "Bad request")
  expect_match(conditionMessage(err), "Unknown field assay.invalid")
  expect_match(conditionMessage(err), "Invalid search parameter")
})

test_that("transport exceptions retry and then report bounded exhaustion", {
  local_encode_test_options()
  withr::local_options(list(encodeUtils.max_tries = 2))
  calls <- 0L

  err <- tryCatch(
    httr2::with_mocked_responses(
      function(req) {
        calls <<- calls + 1L
        stop("simulated timeout", call. = FALSE)
      },
      encode_search(quiet = TRUE)
    ),
    error = identity
  )

  expect_equal(calls, 2L)
  expect_s3_class(err, "rlang_error")
  expect_match(conditionMessage(err), "could not be completed after 2 attempts")
})

test_that("zero-result search responses remain successful empty results", {
  local_encode_test_options()
  result <- httr2::with_mocked_responses(
    function(req) {
      httr2::response(
        200,
        headers = "Content-Type: application/json",
        body = charToRaw(paste0(
          '{"@graph":[],"total":0,',
          '"filters":[{"field":"type","term":"Experiment"}],',
          '"facets":[]}'
        ))
      )
    },
    encode_search(quiet = TRUE)
  )

  expect_s3_class(result, "encode_search_result")
  expect_equal(result$total, 0)
  expect_equal(nrow(result$results), 0)
  expect_equal(nrow(result$facets), 0)
  expect_equal(encode_filters(result)$field, "type")
})
