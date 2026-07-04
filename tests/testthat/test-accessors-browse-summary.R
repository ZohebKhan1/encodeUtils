test_that("fixture-backed search results exercise accessors and facets", {
  local_encode_test_options()
  result <- httr2::with_mocked_responses(
    function(req) fixture_json_response("search-embedded-experiments.json"),
    encode_search(limit = 2, quiet = TRUE)
  )

  expect_s3_class(result, "encode_search_result")
  expect_equal(result$total, 128)
  expect_equal(nrow(result$results), 2)
  expect_equal(encode_results(result), result$results)
  expect_equal(names(result), c("results", "total_results", "query_url", "metadata", "requested_limit"))
  expect_false("raw" %in% names(result))
  expect_false("facets" %in% names(result))
  expect_true(length(unclass(result)$raw$`@graph`) > 0)
  expect_equal(encode_query_url(result), result$query_url)
  expect_equal(encode_query_url(result$results), result$query_url)
  expect_true(all(c("field", "value") %in% names(encode_filters(result))))
  expect_equal(encode_facets(result)$term[[1]], "total RNA-seq")
  expect_equal(encode_facets(list())$count, integer())
})

test_that("file search results print as compact file tables without losing metadata", {
  local_encode_test_options()
  result <- httr2::with_mocked_responses(
    function(req) fixture_json_response("file-search-mixed.json"),
    encode_search(type = "File", limit = 3, quiet = TRUE)
  )
  files <- result$results

  expect_s3_class(files, "encode_file_table")
  expect_true(all(c("file_size", "file_size_pretty", "download_url", "md5sum") %in% names(files)))

  output <- utils::capture.output(
    utils::capture.output(print(files), type = "message")
  )
  expect_true(any(grepl("ENCODE files", output, fixed = TRUE)))
  expect_true(any(grepl("experiment", output, fixed = TRUE)))
  expect_true(any(grepl("dataset_type", output, fixed = TRUE)))
  expect_true(any(grepl("organism", output, fixed = TRUE)))
  expect_true(any(grepl("biosample_type", output, fixed = TRUE)))
  expect_true(any(grepl("lab", output, fixed = TRUE)))
  expect_true(any(grepl("project", output, fixed = TRUE)))
  expect_true(any(grepl("analysis", output, fixed = TRUE)))
  expect_true(any(grepl("file_size", output, fixed = TRUE)))
  expect_false(any(grepl("file_size_pretty", output, fixed = TRUE)))
  expect_false(any(grepl("biosample_summary", output, fixed = TRUE)))
  expect_false(any(grepl("output_category", output, fixed = TRUE)))
  expect_false(any(grepl("download_url", output, fixed = TRUE)))
})

test_that("experiment search results print with ENCODE-style display columns", {
  local_encode_test_options()
  result <- httr2::with_mocked_responses(
    function(req) fixture_json_response("search-embedded-experiments.json"),
    encode_search(type = "Experiment", limit = 2, quiet = TRUE)
  )
  experiments <- result$results

  expect_s3_class(experiments, "encode_experiment_table")
  output <- utils::capture.output(
    utils::capture.output(print(experiments), type = "message")
  )
  expect_true(any(grepl("ENCODE experiments", output, fixed = TRUE)))
  expect_true(any(grepl("experiment", output, fixed = TRUE)))
  expect_true(any(grepl("organism", output, fixed = TRUE)))
  expect_true(any(grepl("biosample_type", output, fixed = TRUE)))
  expect_true(any(grepl("date_released", output, fixed = TRUE)))
  expect_false(any(grepl("biosample_classification", output, fixed = TRUE)))
})

test_that("nested ENCODE list fields collapse to stable identifiers", {
  collapse <- getFromNamespace("encode_collapse_vector", "encodeUtils")
  nested <- list(
    list(accession = "ENCAN000AAA", `@id` = "/analyses/ENCAN000AAA/"),
    list(`@id` = "/analyses/ENCAN000AAB/", nested = list(c("x", "y")))
  )

  expect_equal(collapse(nested), "ENCAN000AAA, /analyses/ENCAN000AAB/")
})

test_that("encode_query_url and encode_filters handle attrs, lists, and empty inputs", {
  table <- data.frame(accession = "ENCSRREAL01")
  attr(table, "query_url") <- "https://www.encodeproject.org/search/?type=Experiment"
  attr(table, "filters") <- data.frame(field = "status", value = "released")
  expect_equal(encode_query_url(table), attr(table, "query_url"))
  expect_equal(encode_filters(table)$field, "status")

  object_like <- list(query_url = "https://example.org/query", filters = table[0, ])
  expect_equal(encode_query_url(object_like), "https://example.org/query")
  expect_equal(nrow(encode_filters(list())), 0)
  expect_true(is.na(encode_query_url(data.frame())))
})

test_that("encode_browse returns searches and delegates interactive selection", {
  local_encode_test_options()
  browsed <- httr2::with_mocked_responses(
    function(req) fixture_json_response("search-embedded-experiments.json"),
    encode_browse(limit = 2, quiet = TRUE)
  )
  expect_s3_class(browsed, "encode_search_result")
  expect_equal(nrow(browsed$results), 2)

  testthat::local_mocked_bindings(
    encode_search = function(...) {
      list(results = data.frame(accession = c("ENCSRREAL01", "ENCSRREAL02"))) |>
        structure(class = c("encode_search_result", "list"))
    },
    encode_select = function(x) {
      x$results[2, , drop = FALSE]
    }
  )
  expect_equal(encode_browse(select = TRUE)$accession, "ENCSRREAL02")
})

test_that("encode_select validates row choices and empty tables", {
  table <- data.frame(accession = c("ENCSRREAL01", "ENCSRREAL02"))
  expect_equal(encode_select(table, rows = c(2, 1))$accession, c("ENCSRREAL02", "ENCSRREAL01"))
  expect_equal(encode_select(table, accession = "ENCSRREAL02")$accession, "ENCSRREAL02")
  expect_error(encode_select(table, rows = 1, accession = "ENCSRREAL01"), "either")
  expect_error(encode_select(table), "rows")
  expect_error(encode_select(table, rows = 0), "valid row numbers")
  expect_error(encode_select(table, rows = 3), "valid row numbers")
  expect_error(encode_select(table, accession = "ENCSRREAL03"), "not found")
  expect_error(encode_select(table[0, , drop = FALSE], rows = 1), "no rows")
  expect_error(encode_select(list(), rows = 1), "ENCODE result or data frame")
})

test_that("encode_summary covers supported result classes and rejects unsupported inputs", {
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
  selected <- encode_select_files(
    fixture_download_files(),
    file_format = "txt",
    explain = FALSE
  )

  expect_equal(encode_summary(search)$returned_results, 2)
  expect_equal(encode_results(object), object$summary)
  expect_equal(encode_results(matrix, component = "assays"), matrix$assay_summary)
  expect_equal(encode_summary(object)$accession[[1]], "ENCSRREAL01")
  expect_equal(encode_summary(matrix)$total_results, 3)
  expect_equal(encode_summary(selected)$n_files, 2)
  expect_equal(encode_summary(fixture_download_files())$n_files, 3)
  expect_error(encode_summary(list()), "cannot be summarized")
})

test_that("result objects expose curated names and table accessors", {
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
  schema <- httr2::with_mocked_responses(
    function(req) fixture_json_response("schema-file.json"),
    encode_get_schema("File", quiet = TRUE)
  )
  selected <- encode_select_files(
    fixture_download_files(),
    file_format = "txt",
    explain = FALSE
  )
  plan <- encode_preview_download(
    selected,
    directory = withr::local_tempdir(),
    quiet = TRUE
  )

  expect_equal(names(search), c("results", "total_results", "query_url", "metadata", "requested_limit"))
  expect_equal(names(object), c("summary", "type", "accession", "query_url", "metadata"))
  expect_equal(names(matrix), c("matrix", "assay_summary", "biosample_summary", "total_results", "query_url"))
  expect_equal(names(schema), c("properties", "title", "id", "query_url"))
  expect_equal(names(selected), c("files", "excluded", "criteria"))
  expect_equal(names(plan), c("files", "summary", "largest_files", "required_overrides"))

  expect_s3_class(encode_results(search), "data.frame")
  expect_s3_class(encode_results(object), "data.frame")
  expect_s3_class(encode_results(matrix, component = "biosamples"), "data.frame")
  expect_s3_class(encode_results(schema), "data.frame")
  expect_s3_class(encode_results(selected), "data.frame")
  expect_s3_class(encode_results(plan), "encode_file_table")
  expect_error(encode_results(list()), "does not contain")
})
