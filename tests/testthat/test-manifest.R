test_that("manifests capture file provenance and round-trip to JSON", {
    files <- fixture_file_table()[1L, ]
    files$dataset <- "/annotations/ENCSRANN001/"
    files$dataset_accession <- "ENCSRANN001"
    files$dataset_type <- "Annotation"
    attr(files, "query_url") <- "https://www.encodeproject.org/search/?type=File"
    path <- withr::local_tempfile(fileext = ".json")
    manifest <- encode_manifest(
        files,
        include_session = FALSE,
        path = path
    )
    parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)

    expect_s3_class(manifest, "encode_manifest")
    expect_s3_class(manifest$attribution, "encode_attribution_table")
    expect_equal(manifest$attribution$file_accession, "ENCFF000AAA")
    expect_match(manifest$attribution$dataset_url, "/annotations/ENCSRANN001/$")
    expect_match(manifest$attribution$experiment_url, "/experiments/ENCSR000AAA/$")
    expect_equal(manifest$retrieval$query_url, attr(files, "query_url"))
    expect_equal(parsed$package$name, "encodeUtils")
    expect_match(parsed$retrieval$created_at, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
    expect_equal(attr(manifest, "path", exact = TRUE), path)
    output <- capture_print(manifest)
    expect_true(any(grepl("created: [0-9]{4}-[0-9]{2}-[0-9]{2}T", output)))
    expect_false(any(grepl('"encodeUtils"', output, fixed = TRUE)))
})

test_that("manifests support loaded collections and reject unsupported objects", {
    path <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c("gene_id\texpected_count", "Gata4\t10"), path)
    files <- data.frame(
        file_accession = "ENCFFLOAD01",
        experiment_accession = "ENCSRLOAD01",
        file_format = "tsv",
        output_type = "gene quantifications",
        local_path = path,
        download_status = "downloaded",
        stringsAsFactors = FALSE
    )
    loaded <- encode_read(files)
    manifest <- encode_manifest(loaded, include_session = FALSE)

    expect_equal(manifest$files$file_accession, "ENCFFLOAD01")
    expect_equal(manifest$loaded_objects$name, "ENCFFLOAD01")
    expect_error(
        encode_manifest(list(unrelated = TRUE), include_session = FALSE),
        "not a supported"
    )
    expect_error(
        encode_manifest("ENCBS000AAA", include_session = FALSE),
        "supports ENCSR and ENCFF"
    )
})

test_that("manifests fail when requested attribution cannot be constructed", {
    expect_error(
        encode_manifest(data.frame(unrelated = TRUE), include_session = FALSE),
        "converted to ENCODE attribution"
    )
    expect_error(
        encode_manifest(fixture_file_table(), include_session = NA),
        "include_session"
    )
    expect_error(
        encode_manifest(fixture_file_table(), path = character(), include_session = FALSE),
        "path"
    )
})

test_that("file-search manifests label file records accurately", {
    local_encode_test_options()
    result <- httr2::with_mocked_responses(
        function(req) fixture_json_response("file-search-mixed.json"),
        encode_search(type = "File", status = NULL, quiet = TRUE)
    )
    manifest <- encode_manifest(result, include_attribution = FALSE, include_session = FALSE)

    expect_true("files" %in% names(manifest))
    expect_false("experiments" %in% names(manifest))
    expect_equal(manifest$files$file_accession, result$results$file_accession)
})

test_that("other search manifests use a generic record label", {
    results <- data.frame(accession = "ENCBS000AAA")
    result <- structure(
        list(results = results),
        class = c("encode_search_result", "list")
    )
    manifest <- encode_manifest(
        result,
        include_attribution = FALSE,
        include_session = FALSE
    )

    expect_equal(manifest$records$accession, "ENCBS000AAA")
    expect_false("experiments" %in% names(manifest))
})
