test_that("public API is explicit and focused", {
    expect_setequal(
        getNamespaceExports("encodeUtils"),
        c(
            "encode_search", "encode_results", "encode_list_files",
            "encode_file_presets", "encode_select_files", "encode_download",
            "encode_read", "encode_read_all", "encode_prepare_quant",
            "encode_as_summarized_experiment", "encode_manifest"
        )
    )
    expect_named(formals(encode_search), c(
        "type", "filters", "search", "status", "limit", "quiet"
    ))
})

test_that("search uses exact Portal filters and keeps compact provenance", {
    local_encode_test_options()
    observed_url <- NULL
    result <- httr2::with_mocked_responses(
        function(req) {
            observed_url <<- req$url
            fixture_json_response("search-embedded-experiments.json")
        },
        encode_search(
            filters = list(
                "replicates.library.biosample.organism.scientific_name" =
                    "Mus musculus",
                assay_title = "microRNA-seq"
            ),
            search = "5xFAD",
            limit = 2L,
            quiet = TRUE
        )
    )

    expect_s3_class(result, "encode_search_result")
    expect_equal(result$total, 128)
    expect_equal(nrow(encode_results(result)), 2L)
    expect_named(result, c(
        "results", "total", "filters", "facets", "query_url",
        "encode_base_url", "request", "request_history"
    ))
    expect_match(observed_url, "Mus%20musculus", fixed = TRUE)
    expect_match(observed_url, "assay_title=microRNA-seq", fixed = TRUE)
    expect_match(observed_url, "searchTerm=5xFAD", fixed = TRUE)
    expect_false("raw" %in% names(result))
})

test_that("search does not expand aliases or make hidden parent requests", {
    local_encode_test_options()
    calls <- 0L
    result <- httr2::with_mocked_responses(
        function(req) {
            calls <<- calls + 1L
            fixture_json_response("file-search-mixed.json")
        },
        encode_search(
            type = "File",
            filters = list("dataset.assay_title" = "RNA-seq"),
            status = NULL,
            quiet = TRUE
        )
    )

    expect_equal(calls, 1L)
    expect_s3_class(result$results, "encode_file_table")
    expect_equal(result$results$dataset_type, c(
        "Experiment", "Experiment", "Annotation"
    ))
    expect_error(
        encode_search(filters = list(status = "released"), quiet = TRUE),
        "reserved"
    )
})

test_that("file listing applies server filters and chunks many experiments", {
    local_encode_test_options()
    observed_urls <- character()
    accessions <- sprintf("ENCSR%06d", seq_len(26L))
    files <- httr2::with_mocked_responses(
        function(req) {
            observed_urls <<- c(observed_urls, req$url)
            fixture_json_response("file-search-mixed.json")
        },
        encode_list_files(
            accessions,
            file_format = "tsv",
            assembly = "mm10",
            status = NULL,
            quiet = TRUE
        )
    )

    expect_length(observed_urls, 2L)
    expect_equal(nrow(files), 6L)
    expect_true(all(grepl("type=File", observed_urls, fixed = TRUE)))
    expect_true(all(grepl("file_format=tsv", observed_urls, fixed = TRUE)))
    expect_length(encode_request_history(files), 2L)
})

test_that("file-table row subsetting preserves provenance", {
    files <- fixture_file_table()
    class(files) <- c("encode_file_table", "data.frame")
    attr(files, "query_url") <- "https://encode.example/search/?type=File"
    attr(files, "filters") <- data.frame(field = "status", value = "released")
    attr(files, "request_history") <- list(list(role = "search"))

    subset <- files[1:2, ]
    expect_s3_class(subset, "encode_file_table")
    expect_equal(encode_query_url(subset), attr(files, "query_url"))
    expect_equal(encode_filters(subset), attr(files, "filters"))
    expect_equal(encode_request_history(subset), attr(files, "request_history"))
})

test_that("search and listing arguments reject ambiguous values", {
    expect_error(encode_search(type = character(), quiet = TRUE), "type")
    expect_error(encode_search(filters = list(), search = c("a", "b")), "search")
    expect_error(encode_search(filters = c(a = "b")), "filters")
    expect_error(encode_list_files("ENCSRREAL01", assembly = 1), "assembly")
    expect_error(encode_list_files("not-an-accession"), "Expected")
})
