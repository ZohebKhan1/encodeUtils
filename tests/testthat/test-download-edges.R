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

test_that("preview and download can limit rows with n", {
  files <- fixture_download_files()
  destination <- withr::local_tempdir()

  plan <- encode_preview_download(
    files,
    n = 2,
    directory = destination,
    quiet = TRUE
  )
  expect_equal(plan$summary$n_files, 2)
  expect_equal(nrow(plan$files), 2)
  expect_equal(plan$files$file_accession, files$file_accession[1:2])

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
    encode_preview_download(files, n = 1.5, directory = destination, quiet = TRUE),
    "positive whole number"
  )
})

test_that("preview and download can select exact file accessions", {
  files <- fixture_download_files()
  destination <- withr::local_tempdir()
  wanted <- rev(files$file_accession[1:2])

  plan <- encode_preview_download(
    files,
    file_accession = wanted,
    directory = destination,
    quiet = TRUE
  )
  expect_equal(plan$summary$n_files, 2)
  expect_equal(plan$files$file_accession, wanted)

  dry <- encode_download(
    files,
    file_accession = wanted,
    directory = destination,
    dry_run = TRUE,
    quiet = TRUE
  )
  expect_equal(dry$file_accession, wanted)

  expect_error(
    encode_preview_download(
      files,
      file_accession = "ENCFFDOESNOTEXIST",
      directory = destination,
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
