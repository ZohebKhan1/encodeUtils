test_that("encode_facets handles alternate ENCODE facet term shapes", {
  raw <- list(facets = list(
    list(
      field = "status",
      title = "Status",
      terms = list(
        list(term = "released", count = 9),
        list(key = "archived", doc_count = 1)
      )
    )
  ))

  facets <- encode_facets(raw)
  expect_equal(facets$field, c("status", "status"))
  expect_equal(facets$term, c("released", "archived"))
  expect_equal(facets$count, c(9L, 1L))
  expect_equal(facets$title, c("Status", "Status"))
  expect_equal(encode_facets(data.frame(field = "x", term = "y")), data.frame(field = "x", term = "y"))
})

test_that("encode_filter_results distinguishes case sensitivity and missing columns", {
  table <- data.frame(
    accession = c("ENCSRREAL01", "ENCSRREAL02", "ENCSRREAL03"),
    assay_title = c("RNA-seq", "rna-seq", "ChIP-seq"),
    status = c("released", "archived", "released"),
    stringsAsFactors = FALSE
  )

  expect_equal(
    encode_filter_results(table, list(assay_title = "rna-seq"))$accession,
    c("ENCSRREAL01", "ENCSRREAL02")
  )
  expect_equal(
    encode_filter_results(table, list(assay_title = "rna-seq"), ignore_case = FALSE)$accession,
    "ENCSRREAL02"
  )
  expect_equal(
    encode_filter_results(table, list(assay_title = c("RNA-seq", "ChIP-seq"), status = "released"))$accession,
    c("ENCSRREAL01", "ENCSRREAL03")
  )
  expect_error(encode_filter_results(table, list(biosample = "heart")), "biosample")
  expect_error(encode_filter_results(list(), list(status = "released")), "search result or data frame")
})

test_that("encode_count exposes limit-zero URLs and omits status when requested", {
  local_encode_test_options()
  observed_url <- NULL

  count <- httr2::with_mocked_responses(
    function(req) {
      observed_url <<- req$url
      httr2::response(
        200,
        headers = "Content-Type: application/json",
        body = charToRaw('{"@graph":[],"total":0}')
      )
    },
    encode_count(
      type = NULL,
      filters = list(assay_title = "RNA-seq"),
      search = "heart",
      status = NULL,
      quiet = TRUE
    )
  )

  expect_s3_class(count, "encode_count_result")
  expect_equal(count$total, 0)
  expect_match(observed_url, "limit=0", fixed = TRUE)
  expect_match(observed_url, "searchTerm=heart", fixed = TRUE)
  expect_match(observed_url, "assay_title=RNA-seq", fixed = TRUE)
  expect_false(grepl("status=", observed_url, fixed = TRUE))
  expect_false(grepl("type=Experiment", observed_url, fixed = TRUE))
  expect_equal(encode_query_url(count), count$query_url)
  expect_true(all(c("format", "frame", "searchTerm", "limit", "assay_title") %in% count$filters$field))
})
