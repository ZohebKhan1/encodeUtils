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

test_that("manifests keep request provenance for loaded collections", {
    path <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c("gene_id\texpected_count", "Gata4\t10"), path)
    files <- data.frame(
        file_accession = "ENCFFLOAD01",
        file_format = "tsv",
        local_path = path,
        download_status = "downloaded",
        stringsAsFactors = FALSE
    )
    attr(files, "query_url") <- "https://www.encodeproject.org/search/?type=File"
    attr(files, "retrieved_at") <- as.POSIXct("2024-01-02 03:04:05", tz = "UTC")
    attr(files, "filters") <- data.frame(field = "status", value = "released")

    loaded <- encode_read(files)
    manifest <- encode_manifest(
        loaded,
        include_attribution = FALSE,
        include_session = FALSE
    )

    expect_equal(manifest$retrieval$query_url, attr(files, "query_url"))
    expect_equal(manifest$retrieval$retrieved_at, "2024-01-02T03:04:05Z")
    expect_equal(manifest$filters$field, "status")
})

test_that("selection and download carry the provenance of their input", {
    retrieved_at <- as.POSIXct("2024-01-02 03:04:05", tz = "UTC")
    files <- fixture_file_table()[1L, ]
    attr(files, "query_url") <- "https://www.encodeproject.org/search/?type=File"
    attr(files, "retrieved_at") <- retrieved_at
    attr(files, "filters") <- data.frame(field = "file_format", value = "bed")
    attr(files, "request_history") <- list(list(
        role = "file_chunk",
        url = attr(files, "query_url")
    ))

    selected <- encode_select_files(files, quiet = TRUE)
    planned <- encode_download(
        selected,
        directory = withr::local_tempdir(),
        dry_run = TRUE,
        quiet = TRUE
    )
    selected_manifest <- encode_manifest(
        selected,
        include_attribution = FALSE,
        include_session = FALSE
    )
    manifest <- encode_manifest(
        planned,
        include_attribution = FALSE,
        include_session = FALSE
    )

    expect_equal(selected_manifest$filters$field, "file_format")
    expect_equal(attr(planned, "retrieved_at", exact = TRUE), retrieved_at)
    expect_equal(manifest$retrieval$retrieved_at, "2024-01-02T03:04:05Z")
    expect_equal(manifest$filters$field, "file_format")
    expect_equal(manifest$requests[[1L]]$role, "file_chunk")
    expect_equal(manifest$selection_criteria, selected$criteria)
})

test_that("search-result manifests keep the recorded request provenance", {
    retrieved_at <- as.POSIXct("2024-02-03 04:05:06", tz = "UTC")
    result <- structure(
        list(
            results = fixture_file_table()[1L, ],
            query_url = "https://encode.example/search/?type=File",
            encode_base_url = "https://encode.example",
            request = list(retrieved_at = retrieved_at),
            filters = data.frame(field = "status", value = "released")
        ),
        class = c("encode_search_result", "list")
    )

    manifest <- encode_manifest(
        result,
        include_attribution = FALSE,
        include_session = FALSE
    )

    expect_equal(manifest$retrieval$encode_base_url, "https://encode.example")
    expect_equal(manifest$retrieval$query_url, result$query_url)
    expect_equal(manifest$retrieval$retrieved_at, "2024-02-03T04:05:06Z")
})

test_that("direct file downloads keep provenance from normalized metadata", {
    retrieved_at <- as.POSIXct("2024-02-03 04:05:06", tz = "UTC")
    files <- fixture_file_table()[1L, ]
    files <- encode_attach_metadata(
        files,
        query_url = "https://encode.example/search/?type=File",
        retrieved_at = retrieved_at,
        filters = data.frame(field = "accession", value = "ENCFF000AAA"),
        base_url = "https://encode.example"
    )
    class(files) <- c("encode_file_table", "data.frame")
    testthat::local_mocked_bindings(
        encode_search = function(...) {
            structure(list(results = files), class = c("encode_search_result", "list"))
        },
        .package = "encodeUtils"
    )

    planned <- encode_download(
        "ENCFF000AAA",
        directory = withr::local_tempdir(),
        dry_run = TRUE,
        quiet = TRUE
    )
    manifest <- encode_manifest(
        planned,
        include_attribution = FALSE,
        include_session = FALSE
    )

    expect_equal(attr(planned, "retrieved_at", exact = TRUE), retrieved_at)
    expect_equal(attr(planned, "encode_base_url", exact = TRUE), "https://encode.example")
    expect_equal(manifest$retrieval$retrieved_at, "2024-02-03T04:05:06Z")
    expect_equal(manifest$retrieval$encode_base_url, "https://encode.example")
})

test_that("selected local files complete the download-read-manifest workflow", {
    directory <- withr::local_tempdir()
    path <- file.path(directory, "ENCFFLOCAL01.tsv")
    writeLines(c("gene_id\texpected_count", "Gata4\t10", "Tbx5\t20"), path)
    files <- data.frame(
        file_accession = "ENCFFLOCAL01",
        experiment_accession = "ENCSRLOCAL01",
        file_format = "tsv",
        output_type = "gene quantifications",
        assembly = "mm10",
        status = "released",
        href = "/files/ENCFFLOCAL01/@@download/ENCFFLOCAL01.tsv",
        file_size = as.numeric(file.info(path)$size),
        md5sum = unname(tools::md5sum(path)),
        stringsAsFactors = FALSE
    )
    selected <- encode_select_files(
        files,
        preset = "rnaseq_gene_quant",
        assembly = "mm10",
        quiet = TRUE
    )
    plan <- encode_download(
        selected,
        directory = directory,
        dry_run = TRUE,
        quiet = TRUE
    )
    downloaded <- encode_download(selected, directory = directory, quiet = TRUE)
    loaded <- encode_read(downloaded)
    manifest <- encode_manifest(
        loaded,
        include_attribution = FALSE,
        include_session = FALSE
    )

    expect_equal(plan$local_path, path)
    expect_equal(downloaded$download_status, "exists")
    expect_true(downloaded$size_verified)
    expect_true(downloaded$md5_verified)
    expect_equal(loaded$matrices$raw_counts["Gata4", "ENCFFLOCAL01"], 10)
    expect_equal(manifest$files$file_accession, "ENCFFLOCAL01")
    expect_equal(manifest$matrices$name, "raw_counts")
    observed_dimensions <- manifest$matrices[, c("rows", "columns")]
    row.names(observed_dimensions) <- NULL
    expect_equal(observed_dimensions, data.frame(
        rows = 2L,
        columns = 1L
    ))
    expect_equal(manifest$selection_criteria, selected$criteria)
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
