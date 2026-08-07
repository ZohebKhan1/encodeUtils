test_that("httr2 owns retry and throttle policies", {
    withr::local_options(list(
        encodeUtils.rate_per_second = FALSE,
        encodeUtils.max_tries = 2L
    ))
    request <- getFromNamespace("encode_build_request", "encodeUtils")(
        "/search/"
    )
    transient <- httr2::response(503L)

    expect_equal(request$policies$retry_max_tries, 2L)
    expect_true(request$policies$retry_on_failure)
    expect_true(request$policies$retry_is_transient(transient))
})

test_that("request policy options are validated", {
    withr::local_options(encodeUtils.rate_per_second = "fast")
    expect_error(encode_search(quiet = TRUE), "rate_per_second")

    withr::local_options(list(
        encodeUtils.rate_per_second = FALSE,
        encodeUtils.max_tries = 0L
    ))
    expect_error(encode_search(quiet = TRUE), "max_tries")
})

test_that("empty searches and HTTP errors are distinct", {
    local_encode_test_options()
    empty <- httr2::with_mocked_responses(
        function(req) httr2::response(
            404L,
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
                400L,
                headers = "Content-Type: application/json",
                body = charToRaw('{"title":"Bad request","detail":"Unknown field"}')
            ),
            encode_search(quiet = TRUE)
        ),
        "HTTP 400.*Bad request.*Unknown field"
    )
})
