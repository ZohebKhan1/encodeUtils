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
    read_values = c("raw_counts", "TPM"),
    quiet = TRUE
  )

  expect_s3_class(loaded, "encode_loaded_files")
  expect_equal(names(loaded$data), names(payloads))
  expect_s3_class(loaded$data$ENCFFLOAD001, "data.frame")
  expect_equal(loaded$data$ENCFFLOAD001$raw_counts, c(10L, 20L))
  expect_equal(
    loaded$matrices$raw_counts,
    data.frame(
      gene_symbol = c("Gata4", "Tbx5"),
      ensembl_id = c(NA_character_, NA_character_),
      entrez_id = c(NA_character_, NA_character_),
      ENCFFLOAD001 = c(10L, 20L),
      ENCFFLOAD002 = c(12L, 25L),
      row.names = c("Gata4", "Tbx5"),
      check.names = FALSE
    )
  )
  expect_equal(loaded$raw_counts, loaded$matrices$raw_counts)
  expect_equal(names(loaded$by_experiment), "ENCSRLOAD001")
  expect_equal(
    loaded$by_experiment$ENCSRLOAD001$matrices$raw_counts,
    data.frame(
      gene_symbol = c("Gata4", "Tbx5"),
      ensembl_id = c(NA_character_, NA_character_),
      entrez_id = c(NA_character_, NA_character_),
      ENCFFLOAD001 = c(10L, 20L),
      ENCFFLOAD002 = c(12L, 25L),
      row.names = c("Gata4", "Tbx5"),
      check.names = FALSE
    )
  )
  expect_equal(loaded$by_experiment$ENCSRLOAD001$raw_counts, loaded$matrices$raw_counts)
  expect_equal(encode_results(loaded)$file_accession, names(payloads))
  expect_equal(loaded$files, loaded$metadata)
  expect_false("download_url" %in% names(loaded$files))
})

test_that("loaded RNA matrices keep gene symbols as annotation columns", {
  local_encode_test_options()
  destination <- withr::local_tempdir()
  payloads <- c(
    ENCFFLOADSYM1 = "gene_id\tgene_symbol\texpected_count\tTPM\nENSMUSG1\tGata4\t10\t1.5\nENSMUSG2\tTbx5\t20\t2.5\n",
    ENCFFLOADSYM2 = "gene_id\tgene_symbol\texpected_count\tTPM\nENSMUSG1\tGata4\t12\t1.7\nENSMUSG2\tTbx5\t25\t2.9\nENSMUSG3\tNkx2-5\t5\t0.9\n"
  )
  files <- data.frame(
    file_accession = names(payloads),
    experiment_accession = "ENCSRLOADSYM",
    file_format = "tsv",
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
    read_values = c("raw_counts", "TPM"),
    quiet = TRUE
  )

  expect_equal(
    loaded$raw_counts,
    data.frame(
      gene_symbol = c("Gata4", "Tbx5", "Nkx2-5"),
      ensembl_id = c("ENSMUSG1", "ENSMUSG2", "ENSMUSG3"),
      entrez_id = c(NA_character_, NA_character_, NA_character_),
      ENCFFLOADSYM1 = c(10L, 20L, NA),
      ENCFFLOADSYM2 = c(12L, 25L, 5L),
      row.names = c("Gata4", "Tbx5", "Nkx2-5"),
      check.names = FALSE
    )
  )
  expect_equal(loaded$tpm$gene_symbol, c("Gata4", "Tbx5", "Nkx2-5"))
  expect_equal(loaded$tpm$gene_symbol[loaded$tpm$ensembl_id == "ENSMUSG3"], "Nkx2-5")
})

test_that("loaded RNA tables keep zero-only numeric rows", {
  local_encode_test_options()
  destination <- withr::local_tempdir()
  payload <- paste(
    "gene_id\tgene_symbol\texpected_count\tTPM\tFPKM",
    "10000\t10000\t0\t0\t0",
    "31383\t\t2\t1.5\t1.1",
    "11307\tAbcg1\t0\t0\t0",
    "ENSMUSG00000000001.4\tGnai3\t10\t3.5\t2.7",
    sep = "\n"
  )
  files <- data.frame(
    file_accession = "ENCFFLOADMAP1",
    experiment_accession = "ENCSRLOADMAP",
    file_format = "tsv",
    href = "/files/ENCFFLOADMAP1/@@download/ENCFFLOADMAP1.tsv",
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

  loaded <- encode_download(
    files,
    directory = destination,
    verify = NULL,
    read = TRUE,
    read_values = c("raw_counts", "TPM"),
    quiet = TRUE
  )

  expect_true("10000" %in% loaded$data$ENCFFLOADMAP1$entrez_id)
  expect_true("31383" %in% loaded$data$ENCFFLOADMAP1$entrez_id)
  expect_equal(names(loaded$data$ENCFFLOADMAP1)[1:3], c("gene_symbol", "ensembl_id", "entrez_id"))
  expect_equal(names(loaded$tpm)[1:3], c("gene_symbol", "ensembl_id", "entrez_id"))
  expect_true("10000" %in% loaded$tpm$entrez_id)
  expect_true("31383" %in% loaded$tpm$entrez_id)
  expect_true("Abcg1" %in% loaded$tpm$gene_symbol)
  expect_true("Gnai3" %in% loaded$tpm$gene_symbol)
})

test_that("loaded RNA tables keep numeric rows without symbols", {
  local_encode_test_options()
  destination <- withr::local_tempdir()
  payload <- paste(
    "gene_id\texpected_count\tTPM\tFPKM",
    "10000\t0\t0\t0",
    "10001\t0\t0\t0",
    "ENSMUSG00000000001.4\t10\t3.5\t2.7",
    sep = "\n"
  )
  files <- data.frame(
    file_accession = "ENCFFLOADNOSYM1",
    experiment_accession = "ENCSRLOADNOSYM",
    file_format = "tsv",
    href = "/files/ENCFFLOADNOSYM1/@@download/ENCFFLOADNOSYM1.tsv",
    file_size = nchar(payload, type = "bytes"),
    md5sum = NA_character_,
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      writeLines(payload, path, useBytes = TRUE)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    },
    encode_gene_annotation = function(gene_id, file) NULL
  )

  loaded <- encode_download(
    files,
    directory = destination,
    verify = NULL,
    read = TRUE,
    read_values = c("raw_counts", "TPM"),
    quiet = TRUE
  )

  expect_equal(loaded$data$ENCFFLOADNOSYM1$entrez_id[1:2], c("10000", "10001"))
  expect_equal(loaded$data$ENCFFLOADNOSYM1$ensembl_id[[3]], "ENSMUSG00000000001.4")
  expect_equal(loaded$tpm$entrez_id[1:2], c("10000", "10001"))
  expect_equal(loaded$tpm$ensembl_id[[3]], "ENSMUSG00000000001.4")
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
  expect_equal(loaded$data[[1]]$gene_symbol, "Gata4")
  expect_equal(loaded$data[[1]]$raw_counts, 10L)
})

test_that("download can list and read matching files from an experiment accession", {
  local_encode_test_options()
  destination <- withr::local_tempdir()
  payload <- "gene_id\tgene_symbol\texpected_count\tTPM\nENSMUSG1\tGata4\t10\t1.5\n"
  files <- data.frame(
    file_accession = "ENCFFEXPRNA1",
    experiment_accession = "ENCSREXPRNA",
    file_format = "tsv",
    output_type = "gene quantifications",
    assembly = "mm10",
    href = "/files/ENCFFEXPRNA1/@@download/ENCFFEXPRNA1.tsv",
    file_size = nchar(payload, type = "bytes"),
    md5sum = NA_character_,
    stringsAsFactors = FALSE
  )
  class(files) <- c("encode_file_table", "data.frame")
  testthat::local_mocked_bindings(
    encode_list_files = function(x, file_format = NULL, output_type = NULL, assembly = NULL, status = NULL, limit = NULL, quiet = NULL, ...) {
      expect_equal(x, "ENCSREXPRNA")
      expect_equal(file_format, "tsv")
      expect_equal(output_type, "gene quantifications")
      expect_equal(assembly, "mm10")
      files
    },
    encode_perform_file = function(url, path, timeout = NULL) {
      writeLines(payload, path, useBytes = TRUE)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )

  loaded <- encode_download(
    "ENCSREXPRNA",
    file_format = "tsv",
    output_type = "gene quantifications",
    assembly = "mm10",
    directory = destination,
    verify = NULL,
    read = TRUE,
    read_row_names = "none",
    quiet = TRUE
  )

  expect_equal(names(loaded), c("metadata", "data", "raw_counts", "matrices", "by_experiment"))
  expect_equal(loaded$raw_counts$gene_symbol, "Gata4")
  expect_equal(row.names(loaded$raw_counts), "1")
})

test_that("download gives a specific error when experiment file filters match nothing", {
  local_encode_test_options()
  empty <- data.frame(stringsAsFactors = FALSE)
  class(empty) <- c("encode_file_table", "data.frame")
  testthat::local_mocked_bindings(
    encode_list_files = function(x, file_format = NULL, output_type = NULL, assembly = NULL, status = NULL, limit = NULL, quiet = NULL, ...) {
      expect_equal(x, "ENCSRNOFILES")
      expect_equal(file_format, "tsv")
      expect_equal(output_type, "gene quantifications")
      empty
    }
  )

  expect_error(
    encode_download(
      "ENCSRNOFILES",
      file_format = "tsv",
      output_type = "gene quantifications",
      directory = tempdir(),
      quiet = TRUE
    ),
    "No ENCODE files matched this experiment download request"
  )
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
