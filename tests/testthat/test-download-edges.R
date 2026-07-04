test_that("download planning uses cache/temp defaults without project-root writes", {
  files <- fixture_download_files()[1, , drop = FALSE]

  temp_plan <- encode_download(
    files,
    directory = NULL,
    cache = FALSE,
    dry_run = TRUE,
    quiet = TRUE
  )
  expect_true(startsWith(temp_plan$local_path[[1]], tempdir()))
  expect_false(startsWith(temp_plan$local_path[[1]], getwd()))

  cache_plan <- encode_download(
    files,
    directory = NULL,
    cache = TRUE,
    dry_run = TRUE,
    quiet = TRUE
  )
  expect_match(cache_plan$local_path[[1]], "encodeUtils", fixed = TRUE)
  expect_false(startsWith(cache_plan$local_path[[1]], getwd()))
})

test_that("download dry-run can limit rows with n", {
  files <- fixture_download_files()
  destination <- withr::local_tempdir()

  dry <- encode_download(
    files,
    n = 2,
    directory = destination,
    dry_run = TRUE,
    quiet = TRUE
  )
  expect_equal(nrow(dry), 2)
  expect_equal(dry$file_accession, files$file_accession[1:2])

  expect_error(
    encode_download(files, n = 1.5, directory = destination, dry_run = TRUE, quiet = TRUE),
    "positive whole number"
  )
})

test_that("download dry-run can select exact file accessions", {
  files <- fixture_download_files()
  destination <- withr::local_tempdir()
  wanted <- rev(files$file_accession[1:2])

  dry <- encode_download(
    files,
    file_accession = wanted,
    directory = destination,
    dry_run = TRUE,
    quiet = TRUE
  )
  expect_equal(dry$file_accession, wanted)

  expect_error(
    encode_download(
      files,
      file_accession = "ENCFFDOESNOTEXIST",
      directory = destination,
      dry_run = TRUE,
      quiet = TRUE
    ),
    "not found"
  )
  expect_error(
    encode_download(
      files,
      file_accession = wanted,
      n = 1,
      directory = destination,
      dry_run = TRUE,
      quiet = TRUE
    ),
    "either"
  )
})

test_that("download validates directory, accession, and missing URL inputs", {
  files <- fixture_download_files()[1, , drop = FALSE]
  expect_error(
    encode_download(files, directory = c("a", "b"), dry_run = TRUE, quiet = TRUE),
    "one non-empty path"
  )
  expect_error(
    encode_download(files, directory = "", dry_run = TRUE, quiet = TRUE),
    "one non-empty path"
  )
  expect_error(
    encode_download(data.frame(href = files$href), dry_run = TRUE, quiet = TRUE),
    "file_accession"
  )
  expect_error(
    encode_download(
      data.frame(file_accession = "ENCFFNOURL", href = NA_character_),
      dry_run = TRUE,
      quiet = TRUE
    ),
    "download"
  )
})

test_that("download enforces total-size limits across multiple files", {
  files <- fixture_download_files()[1:2, , drop = FALSE]
  expect_error(
    encode_download(
      files,
      directory = withr::local_tempdir(),
      max_total_size = "5B",
      dry_run = TRUE,
      quiet = TRUE
    ),
    "max_total_size"
  )
})

test_that("overwrite replaces mismatched existing files through the transfer path", {
  local_encode_test_options()
  destination <- withr::local_tempdir()
  files <- fixture_download_files()[1, , drop = FALSE]
  existing <- encode_download(files, directory = destination, dry_run = TRUE, quiet = TRUE)
  writeBin(charToRaw("bad"), existing$local_path[[1]])

  expect_warning(
    failed <- encode_download(files, directory = destination, quiet = TRUE),
    "Failed to download or verify"
  )
  expect_equal(failed$download_status[[1]], "failed")
  expect_match(failed$failure_reason[[1]], "Existing file does not match")

  calls <- 0L
  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      calls <<- calls + 1L
      writeBin(charToRaw("abc"), path)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )
  replaced <- encode_download(
    files,
    directory = destination,
    overwrite = TRUE,
    quiet = TRUE
  )
  expect_equal(calls, 1L)
  expect_equal(replaced$download_status[[1]], "downloaded")
  expect_equal(readChar(replaced$local_path[[1]], nchars = 3L), "abc")
})

test_that("verify = NULL records unverified downloads without false failures", {
  local_encode_test_options()
  files <- fixture_download_files()[1, , drop = FALSE]
  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      writeBin(charToRaw("bad"), path)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )

  result <- encode_download(
    files,
    directory = withr::local_tempdir(),
    verify = NULL,
    quiet = TRUE
  )
  expect_equal(result$download_status[[1]], "downloaded")
  expect_true(is.na(result$size_verified[[1]]))
  expect_true(is.na(result$md5_verified[[1]]))
  expect_true(is.na(result$failure_reason[[1]]))
})

test_that("download can read small tabular files into grouped R objects", {
  local_encode_test_options()
  destination <- withr::local_tempdir()
  payloads <- c(
    ENCFFLOAD001 = "gene_id\tcount\ttpm\nGata4\t10\t1.5\nTbx5\t20\t2.5\n",
    ENCFFLOAD002 = "gene_id\tcount\ttpm\nGata4\t12\t1.7\nTbx5\t25\t2.9\n"
  )
  files <- data.frame(
    file_accession = names(payloads),
    experiment_accession = "ENCSRLOAD001",
    dataset_type = "Experiment",
    assay_title = "total RNA-seq",
    file_format = "tsv",
    output_type = "gene quantifications",
    href = paste0("/files/", names(payloads), "/@@download/", names(payloads), ".tsv"),
    file_size = nchar(payloads, type = "bytes"),
    md5sum = NA_character_,
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      accession <- sub("^.*/(ENCFF[A-Z0-9]+)[.]tsv$", "\\1", url)
      writeLines(payloads[[accession]], path, useBytes = TRUE)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )

  loaded <- encode_download(
    files,
    directory = destination,
    verify = NULL,
    read = TRUE,
    quiet = TRUE
  )

  expect_s3_class(loaded, "encode_loaded_files")
  expect_equal(names(loaded$data), names(payloads))
  expect_s3_class(loaded$data$ENCFFLOAD001, "data.frame")
  expect_equal(loaded$data$ENCFFLOAD001$count, c(10L, 20L))
  expect_equal(
    loaded$matrices$count,
    data.frame(
      gene_id = c("Gata4", "Tbx5"),
      ENCFFLOAD001 = c(10L, 20L),
      ENCFFLOAD002 = c(12L, 25L),
      check.names = FALSE
    )
  )
  expect_equal(names(loaded$by_experiment), "ENCSRLOAD001")
  expect_equal(
    loaded$by_experiment$ENCSRLOAD001$matrices$count,
    data.frame(
      gene_id = c("Gata4", "Tbx5"),
      ENCFFLOAD001 = c(10L, 20L),
      ENCFFLOAD002 = c(12L, 25L),
      check.names = FALSE
    )
  )
  expect_equal(encode_results(loaded)$file_accession, names(payloads))
})

test_that("downloaded rows can be read later without typing file paths", {
  local_encode_test_options()
  destination <- withr::local_tempdir()
  payload <- "gene_id\tcount\nGata4\t10\n"
  files <- data.frame(
    file_accession = "ENCFFLOAD003",
    experiment_accession = "ENCSRLOAD003",
    file_format = "tsv",
    href = "/files/ENCFFLOAD003/@@download/ENCFFLOAD003.tsv",
    file_size = nchar(payload, type = "bytes"),
    md5sum = NA_character_,
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      writeLines(payload, path, useBytes = TRUE)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )

  downloaded <- encode_download(
    files,
    directory = destination,
    verify = NULL,
    quiet = TRUE
  )
  plain_rows <- as.data.frame(rbind(downloaded, downloaded))
  loaded <- encode_read(plain_rows, format = "tsv")

  expect_s3_class(loaded, "encode_loaded_files")
  expect_equal(length(loaded$data), 2L)
  expect_equal(loaded$data[[1]]$gene_id, "Gata4")
})

test_that("download read mode is explicit about dry-run and assignment", {
  local_encode_test_options()
  destination <- withr::local_tempdir()
  payload <- "gene_id\tcount\nGata4\t10\n"
  files <- data.frame(
    file_accession = "ENCFFLOAD004",
    experiment_accession = "ENCSRLOAD004",
    file_format = "tsv",
    href = "/files/ENCFFLOAD004/@@download/ENCFFLOAD004.tsv",
    file_size = nchar(payload, type = "bytes"),
    md5sum = NA_character_,
    stringsAsFactors = FALSE
  )
  expect_error(
    encode_download(files, directory = destination, dry_run = TRUE, read = TRUE, quiet = TRUE),
    "dry_run"
  )
  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      writeLines(payload, path, useBytes = TRUE)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )
  env <- new.env(parent = emptyenv())
  loaded <- encode_download(
    files,
    directory = destination,
    verify = NULL,
    read = TRUE,
    assign = TRUE,
    envir = env,
    quiet = TRUE
  )

  expect_s3_class(loaded, "encode_loaded_files")
  expect_true(exists("ENCFFLOAD004", envir = env, inherits = FALSE))
  expect_true(exists("ENCSRLOAD004", envir = env, inherits = FALSE))
})
