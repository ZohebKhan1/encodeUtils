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
    result <- httr2::with_mocked_responses(
        function(req) {
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
})
