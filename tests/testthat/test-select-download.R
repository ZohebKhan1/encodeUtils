test_that("selection keeps presets and replicate policies without field filters", {
    files <- fixture_file_table()
    files <- files[!is.na(files$assembly) & files$assembly == "GRCh38", ]
    selected <- encode_select_files(
        files,
        preset = "chipseq_peaks",
        replicate_policy = "preferred_processed",
        quiet = TRUE
    )

    expect_s3_class(selected, "encode_selected_files")
    expect_equal(selected$files$file_accession, "ENCFF000AAA")
    expect_named(formals(encode_select_files), c(
        "files", "preset", "file_accession", "replicate_policy",
        "prefer_default", "quiet"
    ))
    expect_error(
        encode_select_files(files, replicate_policy = "preferred_processed"),
        "requires.*preset"
    )
})

test_that("replicate and preferred-default selection remain available", {
    files <- data.frame(
        file_accession = c("ENCFFREP001", "ENCFFPOOL01", "ENCFFREP002"),
        experiment_accession = c("ENCSRREP001", "ENCSRREP001", "ENCSRREP002"),
        file_format = "tsv",
        output_type = "gene quantifications",
        href = paste0(
            "/files/",
            c("ENCFFREP001", "ENCFFPOOL01", "ENCFFREP002"),
            "/@@download/file.tsv"
        ),
        biological_replicates = c("1", "1, 2", "1"),
        preferred_default = c(TRUE, FALSE, FALSE)
    )

    selected <- encode_select_files(
        files,
        replicate_policy = "replicate_level",
        prefer_default = TRUE,
        quiet = TRUE
    )
    expect_equal(
        selected$files$file_accession,
        c("ENCFFREP001", "ENCFFREP002")
    )
    expect_match(selected$excluded$reason, "not replicate-level")
})

test_that("download defaults are uncapped and caps remain opt-in", {
    files <- data.frame(
        file_accession = "ENCFFBIG001",
        href = "/files/ENCFFBIG001/@@download/ENCFFBIG001.fastq.gz",
        file_size = 20 * 1024^3,
        md5sum = NA_character_
    )
    expect_null(formals(encode_download)$max_file_size)
    expect_null(formals(encode_download)$max_total_size)

    plan <- encode_download(
        files,
        directory = withr::local_tempdir(),
        dry_run = TRUE,
        quiet = TRUE
    )
    expect_equal(plan$download_status, "planned")
    expect_error(
        encode_download(
            files,
            directory = withr::local_tempdir(),
            max_file_size = "1GB",
            dry_run = TRUE,
            quiet = TRUE
        ),
        "exceed.*max_file_size"
    )
})

test_that("downloads accept exact files rather than experiment filters", {
    expect_named(formals(encode_download), c(
        "x", "directory", "max_file_size", "max_total_size",
        "allow_unknown_size", "overwrite", "dry_run", "prefer_cloud",
        "verify", "quiet"
    ))
    expect_error(
        encode_download("ENCSR000AAA", dry_run = TRUE, quiet = TRUE),
        "ENCFF"
    )
})

test_that("failed replacement verification preserves an existing file", {
    directory <- withr::local_tempdir()
    path <- file.path(directory, "ENCFF000AAA.txt")
    writeBin(charToRaw("old"), path)
    files <- data.frame(
        file_accession = "ENCFF000AAA",
        href = "/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",
        file_size = 4,
        md5sum = "755f85c2723bb39381c7379a604160d8"
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
    expect_false(any(grepl("[.]part", list.files(directory))))
})

test_that("verified replacement is installed atomically", {
    directory <- withr::local_tempdir()
    path <- file.path(directory, "ENCFF000AAA.txt")
    writeBin(charToRaw("old"), path)
    files <- data.frame(
        file_accession = "ENCFF000AAA",
        href = "/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",
        file_size = 3,
        md5sum = "22af645d1859cb5ca6da0c484f1f37ea"
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
})

test_that("existing files and missing checksums are reported accurately", {
    directory <- withr::local_tempdir()
    path <- file.path(directory, "ENCFFNOMD501.txt")
    writeBin(charToRaw("new"), path)
    files <- data.frame(
        file_accession = "ENCFFNOMD501",
        href = "/files/ENCFFNOMD501/@@download/ENCFFNOMD501.txt",
        file_size = 3,
        md5sum = NA_character_
    )

    result <- encode_download(files, directory = directory, quiet = TRUE)
    expect_equal(result$download_status, "exists")
    expect_true(result$size_verified)
    expect_true(is.na(result$md5_verified))
    expect_equal(result$observed_md5, unname(tools::md5sum(path)))
})

test_that("download controls validate values", {
    files <- fixture_file_table()[1L, ]
    expect_error(encode_download(files, dry_run = "yes"), "dry_run")
    expect_error(encode_download(files, overwrite = NA), "overwrite")
    expect_error(encode_download(files, directory = character()), "directory")
    expect_error(
        encode_download(files, max_total_size = "large", dry_run = TRUE),
        "max_total_size"
    )
})
