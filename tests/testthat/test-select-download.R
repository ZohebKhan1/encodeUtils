test_that("selection presets are canonical and selection records exclusions", {
    expect_equal(
        encode_file_presets(),
        c(
            "raw_reads", "alignments", "chipseq_peaks", "chipseq_signal",
            "atacseq_peaks", "rnaseq_gene_quant", "rnaseq_transcript_quant",
            "metadata"
        )
    )
    expect_error(encode_file_presets("peaks"), "must be one of")
    expect_error(encode_select_files(), "argument.*files.*missing")

    files <- fixture_file_table()
    selected <- encode_select_files(
        files,
        preset = "chipseq_peaks",
        assembly = "GRCh38",
        replicate_policy = "preferred_processed",
        quiet = TRUE
    )

    expect_s3_class(selected, "encode_selected_files")
    expect_equal(selected$files$file_accession, "ENCFF000AAA")
    expect_true(all(c("files", "excluded", "criteria") %in% names(selected)))
    expect_true(any(grepl("wrong assembly", selected$excluded$reason)))
    expect_true(any(grepl("wrong file format", selected$excluded$reason)))

    output <- capture_print(selected)
    expect_true(any(grepl("- excluded:", output, fixed = TRUE)))
})

test_that("public messaging parameters use quiet consistently", {
    messaging_functions <- c(
        "encode_search", "encode_list_files", "encode_select_files",
        "encode_download"
    )
    parameters <- lapply(messaging_functions, function(name) {
        names(formals(getExportedValue("encodeUtils", name)))
    })

    expect_true(all(vapply(parameters, function(x) "quiet" %in% x, logical(1L))))
    expect_false(any(vapply(parameters, function(x) "explain" %in% x, logical(1L))))
})

test_that("download planning is bounded and uses explicit limit naming", {
    files <- fixture_file_table()[1:2, ]
    directory <- withr::local_tempdir()
    planned <- encode_download(
        files,
        limit = 1L,
        directory = directory,
        dry_run = TRUE,
        quiet = TRUE
    )

    expect_s3_class(planned, "encode_download_result")
    expect_equal(nrow(planned), 1L)
    expect_equal(planned$download_status, "planned")
    expect_true(startsWith(planned$local_path, directory))

    output <- capture_print(planned)
    expect_true(any(grepl("ENCODE download", output, fixed = TRUE)))
    expect_true(any(grepl("planned", output, fixed = TRUE)))
    expect_true(any(grepl("path", output, fixed = TRUE)))

    expect_error(
        encode_download(files, file_accession = files$file_accession[[1L]], limit = 1L, dry_run = TRUE),
        "either.*file_accession.*limit"
    )
    expect_error(
        encode_download(data.frame(accession = "ENCSR000AAA"), dry_run = TRUE),
        "could not be converted"
    )
})

test_that("failed replacement verification preserves the existing file", {
    directory <- withr::local_tempdir()
    path <- file.path(directory, "ENCFF000AAA.txt")
    writeBin(charToRaw("old"), path)
    files <- data.frame(
        file_accession = "ENCFF000AAA",
        href = "/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",
        file_size = 4,
        md5sum = "755f85c2723bb39381c7379a604160d8",
        stringsAsFactors = FALSE
    )
    testthat::local_mocked_bindings(
        encode_perform_file = function(url, path, timeout = NULL) {
            writeBin(charToRaw("bad"), path)
            list(retrieved_at = Sys.time())
        },
        .package = "encodeUtils"
    )

    expect_warning(
        result <- encode_download(
            files,
            directory = directory,
            overwrite = TRUE,
            quiet = TRUE
        ),
        "Failed to download or verify"
    )
    expect_equal(result$download_status, "failed")
    expect_equal(readChar(path, nchars = 3L), "old")
    expect_false(file.exists(paste0(path, ".part")))
})

test_that("verified replacement is installed atomically", {
    directory <- withr::local_tempdir()
    path <- file.path(directory, "ENCFF000AAA.txt")
    writeBin(charToRaw("old"), path)
    files <- data.frame(
        file_accession = "ENCFF000AAA",
        href = "/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",
        file_size = 3,
        md5sum = "22af645d1859cb5ca6da0c484f1f37ea",
        stringsAsFactors = FALSE
    )
    testthat::local_mocked_bindings(
        encode_perform_file = function(url, path, timeout = NULL) {
            writeBin(charToRaw("new"), path)
            list(retrieved_at = Sys.time())
        },
        .package = "encodeUtils"
    )

    result <- encode_download(
        files,
        directory = directory,
        overwrite = TRUE,
        quiet = TRUE
    )
    expect_equal(result$download_status, "downloaded")
    expect_true(result$size_verified)
    expect_true(result$md5_verified)
    expect_equal(readChar(path, nchars = 3L), "new")
    expect_length(list.files(directory, pattern = "backup", all.files = TRUE), 0L)
})
