test_that("manifests preserve provenance after ordinary row subsetting", {
    files <- fixture_file_table()
    class(files) <- c("encode_file_table", "data.frame")
    attr(files, "query_url") <- "https://encode.example/search/?type=File"
    attr(files, "retrieved_at") <- as.POSIXct(
        "2026-08-07 12:00:00", tz = "UTC"
    )
    attr(files, "filters") <- data.frame(
        field = "status", value = "released"
    )
    attr(files, "request_history") <- list(list(
        role = "search", url = attr(files, "query_url")
    ))

    manifest <- encode_manifest(files[1:2, ], include_session = FALSE)
    expect_equal(manifest$retrieval$query_url, attr(files, "query_url"))
    expect_equal(manifest$retrieval$retrieved_at, "2026-08-07T12:00:00Z")
    expect_equal(manifest$filters, attr(files, "filters"))
    expect_equal(manifest$requests, attr(files, "request_history"))
    expect_equal(nrow(manifest$files), 2L)
})

test_that("manifests round-trip to JSON without API requests", {
    path <- withr::local_tempfile(fileext = ".json")
    testthat::local_mocked_bindings(
        encode_perform_json = function(...) stop("unexpected API request"),
        .package = "encodeUtils"
    )

    manifest <- encode_manifest(
        c("ENCFF000AAA", "ENCSR000AAA"),
        path = path,
        include_session = FALSE
    )
    parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)

    expect_s3_class(manifest, "encode_manifest")
    expect_equal(parsed$package$name, "encodeUtils")
    expect_equal(length(parsed$accessions), 2L)
    expect_equal(attr(manifest, "path"), path)
})

test_that("selection, download, and loading retain one provenance chain", {
    directory <- withr::local_tempdir()
    local_path <- file.path(directory, "ENCFFLOCAL01.tsv")
    writeLines(c("gene_id\texpected_count", "Gata4\t10"), local_path)
    files <- data.frame(
        file_accession = "ENCFFLOCAL01",
        experiment_accession = "ENCSRLOCAL01",
        file_format = "tsv",
        output_type = "gene quantifications",
        href = "/files/ENCFFLOCAL01/@@download/ENCFFLOCAL01.tsv",
        file_size = as.numeric(file.info(local_path)$size),
        md5sum = unname(tools::md5sum(local_path))
    )
    attr(files, "query_url") <- "https://encode.example/search/?type=File"
    attr(files, "filters") <- data.frame(
        field = "dataset", value = "ENCSRLOCAL01"
    )
    attr(files, "request_history") <- list(list(role = "search"))

    selected <- encode_select_files(
        files,
        preset = "rnaseq_gene_quant",
        quiet = TRUE
    )
    downloaded <- encode_download(
        selected,
        directory = directory,
        quiet = TRUE
    )
    loaded <- encode_read_all(downloaded, quiet = TRUE)
    manifest <- encode_manifest(loaded, include_session = FALSE)

    expect_equal(downloaded$download_status, "exists")
    expect_equal(manifest$retrieval$query_url, attr(files, "query_url"))
    expect_equal(manifest$filters, attr(files, "filters"))
    expect_equal(manifest$selection_criteria, selected$criteria)
    expect_equal(manifest$loaded_objects$name, "ENCFFLOCAL01")
})

test_that("search-result manifests distinguish files from generic records", {
    file_results <- fixture_file_table()[1L, ]
    class(file_results) <- c("encode_file_table", "data.frame")
    file_search <- structure(
        list(results = file_results),
        class = c("encode_search_result", "list")
    )
    generic_search <- structure(
        list(results = data.frame(accession = "ENCBS000AAA")),
        class = c("encode_search_result", "list")
    )

    expect_true("files" %in% names(encode_manifest(
        file_search, include_session = FALSE
    )))
    expect_true("records" %in% names(encode_manifest(
        generic_search, include_session = FALSE
    )))
})

test_that("manifest arguments and unsupported objects fail clearly", {
    expect_error(
        encode_manifest(list(unrelated = TRUE), include_session = FALSE),
        "not a supported"
    )
    expect_error(
        encode_manifest(fixture_file_table(), include_session = NA),
        "include_session"
    )
    expect_error(
        encode_manifest(fixture_file_table(), path = character()),
        "path"
    )
})
