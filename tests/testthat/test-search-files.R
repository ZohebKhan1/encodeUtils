test_that("public API stays focused", {
    exports <- getNamespaceExports("encodeUtils")
    expect_setequal(
        exports,
        c(
            "encode_search", "encode_results", "encode_list_files",
            "encode_file_presets", "encode_select_files", "encode_download",
            "encode_read", "encode_manifest"
        )
    )
})

test_that("experiment searches flatten fixture metadata and preserve request context", {
    local_encode_test_options()
    result <- httr2::with_mocked_responses(
        function(req) fixture_json_response("search-embedded-experiments.json"),
        encode_search(limit = 2, metadata = "full", quiet = TRUE)
    )

    expect_s3_class(result, "encode_search_result")
    expect_equal(result$total, 128)
    expect_equal(nrow(encode_results(result)), 2L)
    expect_equal(result$results$accession[[1L]], "ENCSRREAL01")
    expect_equal(result$results$organism[[1L]], "Homo sapiens")
    expect_equal(result$facets$term[[1L]], "total RNA-seq")
    expect_match(result$query_url, "frame=embedded", fixed = TRUE)
    expect_true(all(c("results", "raw", "filters", "request") %in% names(result)))
    expect_named(result, c(
        "results", "raw", "total", "filters", "facets", "columns",
        "query_url", "encode_base_url", "frame", "metadata", "limit", "request",
        "request_history"
    ))
    expect_length(result$request_history, 1L)
    expect_equal(result$request_history[[1L]]$role, "search")
})

test_that("limited biological File searches expand small parent sets", {
    local_encode_test_options()
    withr::local_options(encodeUtils.file_search_chunk_size = 1L)
    observed_urls <- character()

    result <- httr2::with_mocked_responses(
        function(req) {
            observed_urls <<- c(observed_urls, req$url)
            if (grepl("type=Experiment", req$url, fixed = TRUE)) {
                body <- sub(
                    '"total": 128',
                    '"total": 2',
                    fixture_text("search-embedded-experiments.json"),
                    fixed = TRUE
                )
                return(httr2::response(
                    200L,
                    headers = "Content-Type: application/json",
                    body = charToRaw(body)
                ))
            }
            fixture_json_response("file-search-mixed.json")
        },
        encode_search(
            type = "File",
            organism = "human",
            organ = "heart",
            file_format = "fastq",
            limit = 2,
            quiet = TRUE
        )
    )

    expect_equal(nrow(encode_results(result)), 2L)
    expect_equal(result$total, 6L)
    expect_length(result$request_history, 3L)
    expect_equal(
        vapply(result$request_history, `[[`, character(1L), "role"),
        c("parent_experiments", "file_chunk", "file_chunk")
    )
    expect_true(grepl("limit=26", observed_urls[[1L]], fixed = TRUE))
    expect_equal(sum(grepl("type=File", observed_urls, fixed = TRUE)), 2L)
    expect_true(any(result$filters$field == "biosample_ontology.organ_slims"))
    expect_true(any(result$filters$field == "file_format"))
})

test_that("limited biological File searches refuse broad parent expansion", {
    local_encode_test_options()
    observed_urls <- character()

    expect_error(
        httr2::with_mocked_responses(
            function(req) {
                observed_urls <<- c(observed_urls, req$url)
                fixture_json_response("search-embedded-experiments.json")
            },
            encode_search(
                type = "File",
                organism = "human",
                limit = 1,
                quiet = TRUE
            )
        ),
        "matched 128 parent experiments"
    )

    expect_length(observed_urls, 1L)
    expect_true(grepl("type=Experiment", observed_urls[[1L]], fixed = TRUE))
    expect_true(grepl("limit=26", observed_urls[[1L]], fixed = TRUE))
})

test_that("search arguments reject ambiguous values", {
    expect_error(encode_search(type = character(), quiet = TRUE), "type")
    expect_error(encode_search(search = c("heart", "brain"), quiet = TRUE), "search")
    expect_error(encode_search(file_format = 1, quiet = TRUE), "file_format")
    expect_error(encode_search(include_facets = NA, quiet = TRUE), "include_facets")
    expect_error(encode_search(quiet = 0), "quiet")
})

test_that("biological search arguments compile to ENCODE query fields", {
    local_encode_test_options()
    observed_url <- NULL
    httr2::with_mocked_responses(
        function(req) {
            observed_url <<- req$url
            fixture_json_response("search-embedded-experiments.json")
        },
        encode_search(
            organism = "mouse",
            assay = "rna-seq",
            organ = "heart",
            life_stage = "fetal",
            development = TRUE,
            quiet = TRUE
        )
    )

    expect_match(observed_url, "organism.scientific_name=Mus%20musculus", fixed = TRUE)
    expect_match(observed_url, "biosample_ontology.organ_slims=heart", fixed = TRUE)
    expect_match(observed_url, "biosample.life_stage=embryonic", fixed = TRUE)
    expect_match(observed_url, "OrganismDevelopmentSeries", fixed = TRUE)
})

test_that("file searches preserve experiment and annotation dataset provenance", {
    local_encode_test_options()
    observed_urls <- character()
    result <- httr2::with_mocked_responses(
        function(req) {
            observed_urls <<- c(observed_urls, req$url)
            if (grepl("type=Experiment", req$url, fixed = TRUE)) {
                return(fixture_json_response("search-embedded-experiments.json"))
            }
            fixture_json_response("file-search-mixed.json")
        },
        encode_search(type = "File", status = NULL, quiet = TRUE)
    )
    files <- encode_results(result)

    expect_s3_class(files, "encode_file_table")
    expect_equal(files$dataset_type, c("Experiment", "Experiment", "Annotation"))
    expect_equal(files$dataset_accession[[3L]], "ENCSRANN001")
    expect_true(is.na(files$experiment_accession[[3L]]))
    expect_equal(files$organism[[1L]], "Homo sapiens")
    expect_equal(length(result$request_history), length(observed_urls))
    expect_equal(
        vapply(result$request_history, `[[`, character(1L), "role"),
        c("search", "parent_metadata")
    )
    expect_equal(
        vapply(result$request_history, `[[`, character(1L), "url"),
        observed_urls
    )
})

test_that("file listing validates scope and enriches parent experiment metadata", {
    many <- data.frame(accession = sprintf("ENCSR%06d", seq_len(26L)))
    expect_error(encode_list_files(many, quiet = TRUE), "Refusing to list files")
    expect_error(encode_list_files("not-an-accession", quiet = TRUE), "Expected")

    local_encode_test_options()
    observed_urls <- character()
    files <- httr2::with_mocked_responses(
        function(req) {
            observed_urls <<- c(observed_urls, req$url)
            if (grepl("type=Experiment", req$url, fixed = TRUE)) {
                return(fixture_json_response("search-embedded-experiments.json"))
            }
            fixture_json_response("file-search-mixed.json")
        },
        encode_list_files("ENCSRREAL01", status = NULL, quiet = TRUE)
    )

    expect_s3_class(files, "encode_file_table")
    expect_equal(nrow(files), 3L)
    expect_true(any(grepl("dataset=%2Fexperiments%2FENCSRREAL01%2F", observed_urls, fixed = TRUE)))
    expect_true(any(grepl("type=Experiment", observed_urls, fixed = TRUE)))
    expect_equal(sum(grepl("type=Experiment", observed_urls, fixed = TRUE)), 1L)
    expect_equal(length(encode_request_history(files)), length(observed_urls))
    expect_equal(
        vapply(encode_request_history(files), `[[`, character(1L), "role"),
        c("search", "parent_metadata")
    )
    expect_equal(
        vapply(encode_request_history(files), `[[`, character(1L), "url"),
        observed_urls
    )
})

test_that("file listing validates filters and logical controls", {
    expect_error(encode_list_files("ENCSRREAL01", assembly = 1, quiet = TRUE), "assembly")
    expect_error(encode_list_files("ENCSRREAL01", allow_many = NA, quiet = TRUE), "allow_many")
    expect_error(encode_list_files("ENCSRREAL01", quiet = "yes"), "quiet")
})
