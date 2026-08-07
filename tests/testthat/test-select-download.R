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
    expect_error(encode_file_presets(NA_character_), "must be one of")
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

test_that("public messaging functions use quiet consistently", {
    messaging_functions <- c(
        "encode_search", "encode_list_files", "encode_select_files",
        "encode_download"
    )
    parameters <- lapply(messaging_functions, function(name) {
        names(formals(getExportedValue("encodeUtils", name)))
    })

    expect_true(all(vapply(parameters, function(x) "quiet" %in% x, logical(1L))))
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
    expect_true(all(c(
        "download_status", "downloaded_at", "downloaded_size", "observed_md5",
        "size_verified", "md5_verified", "failure_reason"
    ) %in% names(planned)))
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
    expect_equal(result$observed_md5, result$md5sum)
    expect_equal(readChar(path, nchars = 3L), "new")
    expect_length(list.files(directory, pattern = "backup", all.files = TRUE), 0L)
})

test_that("transfer errors retain a complete result schema", {
    files <- data.frame(
        file_accession = "ENCFF000AAA",
        href = "/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",
        file_size = 3,
        md5sum = "22af645d1859cb5ca6da0c484f1f37ea",
        stringsAsFactors = FALSE
    )
    testthat::local_mocked_bindings(
        encode_perform_file = function(url, path, timeout = NULL) {
            stop("network unavailable")
        },
        .package = "encodeUtils"
    )

    expect_warning(
        result <- encode_download(
            files,
            directory = withr::local_tempdir(),
            quiet = TRUE
        ),
        "Failed to download or verify"
    )
    expect_equal(result$download_status, "failed")
    expect_match(result$failure_reason, "network unavailable")
    expect_true(is.na(result$downloaded_size))
    expect_true(is.na(result$observed_md5))
    expect_true(is.na(result$size_verified))
    expect_true(is.na(result$md5_verified))
})

test_that("selection and download flags require logical values", {
    files <- fixture_file_table()
    expect_error(encode_select_files(files, prefer_default = 1, quiet = TRUE), "prefer_default")
    expect_error(encode_select_files(files, require_href = NA, quiet = TRUE), "require_href")
    expect_error(encode_download(files[1L, ], dry_run = "yes", quiet = TRUE), "dry_run")
    expect_error(encode_download(files[1L, ], overwrite = NA, quiet = TRUE), "overwrite")
    expect_error(encode_download(files[1L, ], directory = character(), quiet = TRUE), "directory")
    expect_error(encode_download(files[1L, ], max_file_size = "large", quiet = TRUE), "max_file_size")
})

test_that("preferred defaults are applied within experiments", {
    files <- data.frame(
        file_accession = c("ENCFFPREF01", "ENCFFPREF02", "ENCFFFALL01"),
        experiment_accession = c("ENCSRPREF01", "ENCSRPREF01", "ENCSRPREF02"),
        file_format = "tsv",
        output_type = "gene quantifications",
        assembly = "mm10",
        status = "released",
        href = paste0("/files/", c("ENCFFPREF01", "ENCFFPREF02", "ENCFFFALL01"), "/@@download/file.tsv"),
        preferred_default = c(TRUE, FALSE, FALSE),
        stringsAsFactors = FALSE
    )

    selected <- encode_select_files(files, prefer_default = TRUE, quiet = TRUE)

    expect_equal(
        selected$files$file_accession,
        c("ENCFFPREF01", "ENCFFFALL01")
    )
})

test_that("replicate-level selection excludes pooled replicate labels", {
    files <- data.frame(
        file_accession = c("ENCFFREP001", "ENCFFPOOL01"),
        experiment_accession = "ENCSRREP001",
        file_format = "tsv",
        output_type = "gene quantifications",
        assembly = "mm10",
        status = "released",
        href = paste0("/files/", c("ENCFFREP001", "ENCFFPOOL01"), "/@@download/file.tsv"),
        biological_replicates = c("1", "1, 2"),
        stringsAsFactors = FALSE
    )

    selected <- encode_select_files(
        files,
        replicate_policy = "replicate_level",
        quiet = TRUE
    )

    expect_equal(selected$files$file_accession, "ENCFFREP001")
    expect_match(selected$excluded$reason, "not replicate-level")
})

test_that("selection records all applicable exclusions and tolerates unknown status", {
    files <- data.frame(
        file_accession = "ENCFFUNKNOWN",
        file_format = "bed",
        output_type = "peaks",
        assembly = "hg19",
        href = NA_character_,
        stringsAsFactors = FALSE
    )

    selected <- encode_select_files(
        files,
        file_format = "tsv",
        assembly = "mm10",
        quiet = TRUE
    )

    expect_false(selected$criteria$status_filter_applied)
    expect_match(selected$excluded$reason, "wrong file format")
    expect_match(selected$excluded$reason, "wrong assembly")
    expect_match(selected$excluded$reason, "missing download URL")
    expect_false(grepl("wrong status", selected$excluded$reason))
})

test_that("observed MD5 is recorded without portal checksum metadata", {
    directory <- withr::local_tempdir()
    files <- data.frame(
        file_accession = "ENCFFNOMD501",
        href = "/files/ENCFFNOMD501/@@download/file.txt",
        file_size = 3,
        md5sum = NA_character_,
        stringsAsFactors = FALSE
    )
    testthat::local_mocked_bindings(
        encode_perform_file = function(url, path, timeout = NULL) {
            writeBin(charToRaw("new"), path)
            list(retrieved_at = Sys.time())
        },
        .package = "encodeUtils"
    )

    result <- encode_download(files, directory = directory, quiet = TRUE)

    expect_equal(result$observed_md5, unname(tools::md5sum(result$local_path)))
    expect_true(is.na(result$md5_verified))
})
