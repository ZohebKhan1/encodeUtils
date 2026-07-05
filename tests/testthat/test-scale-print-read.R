test_that("large mixed file tables select and summarize deterministically", {
  files <- fixture_large_file_table(120L)
  selected <- encode_select_files(
    files,
    preset = "raw_fastq",
    replicate_policy = "replicate_level",
    explain = FALSE
  )
  summary <- encode_file_summary(files)
  largest <- encode_largest_files(files, n = 8L)
  planned <- encode_download(
    files,
    n = 25,
    directory = withr::local_tempdir(),
    dry_run = TRUE,
    quiet = TRUE
  )

  expect_true(nrow(selected$files) > 0)
  expect_true(all(selected$files$file_format == "fastq"))
  expect_true(all(selected$files$output_type == "reads"))
  expect_equal(summary$n_files, 120)
  expect_equal(summary$n_experiments, 12)
  expect_true(all(diff(largest$file_size) <= 0))
  expect_equal(length(unique(planned$local_path)), nrow(planned))
})

test_that("print methods expose stable concise diagnostics", {
  local_encode_test_options()
  search <- httr2::with_mocked_responses(
    function(req) fixture_json_response("search-embedded-experiments.json"),
    encode_search(limit = 2, quiet = TRUE)
  )
  selected <- encode_select_files(
    fixture_download_files(),
    file_format = "txt",
    explain = FALSE
  )
  planned <- encode_download(
    fixture_download_files(),
    directory = withr::local_tempdir(),
    dry_run = TRUE,
    quiet = TRUE
  )
  capture_cli <- function(expr) {
    expr <- substitute(expr)
    utils::capture.output(
      utils::capture.output(eval(expr, parent.frame()), type = "message")
    )
  }

  search_output <- capture_cli(print(search))
  search_verbose_output <- capture_cli(print(search, verbose = TRUE))
  selected_output <- capture_cli(print(selected))
  selected_verbose_output <- capture_cli(print(selected, verbose = TRUE))
  planned_output <- capture_cli(print(planned))

  expect_true(any(grepl("ENCODE search", search_output, fixed = TRUE)))
  expect_true(any(grepl("total matches", search_output, fixed = TRUE)))
  expect_false(any(grepl("Active filters", search_output, fixed = TRUE)))
  expect_false(any(grepl("Top facets", search_output, fixed = TRUE)))
  expect_true(any(grepl("Active filters", search_verbose_output, fixed = TRUE)))
  expect_true(any(grepl("Top facets", search_verbose_output, fixed = TRUE)))
  expect_true(any(grepl("ENCODE selected files", selected_output, fixed = TRUE)))
  expect_false(any(grepl("Exclusion reasons", selected_output, fixed = TRUE)))
  expect_false(any(grepl("Exclusion reasons", selected_verbose_output, fixed = TRUE)))
  expect_true(any(grepl("ENCODE files", planned_output, fixed = TRUE)))
  expect_true(any(grepl("file_size", planned_output, fixed = TRUE)))
})

test_that("encode_read validates table input and format overrides", {
  tsv_path <- withr::local_tempfile(fileext = ".not-tsv")
  writeLines(c("gene\tvalue", "MYC\t2"), tsv_path)
  table_input <- data.frame(local_path = tsv_path, stringsAsFactors = FALSE)
  class(table_input) <- c("encode_download_result", "data.frame")

  read_table <- encode_read(table_input, format = "tsv")
  expect_equal(read_table$gene[[1]], "MYC")
  read_one_collection <- encode_read(table_input, format = "tsv", as_collection = TRUE)
  expect_s3_class(read_one_collection, "encode_loaded_files")
  expect_equal(nrow(read_one_collection$metadata), 1L)
  expect_equal(length(read_one_collection$data), 1L)
  read_many <- encode_read(rbind(table_input, table_input), format = "tsv")
  expect_s3_class(read_many, "encode_loaded_files")
  expect_equal(length(read_many$data), 2L)
  expect_equal(names(read_many), c("metadata", "data", "by_experiment"))
  expect_equal(read_many$files, read_many$metadata)
  expect_error(encode_read(tsv_path, as_collection = TRUE), "downloaded-file table")
  expect_error(encode_read(table_input, as_collection = NA), "TRUE.*FALSE")
  missing_local_path <- data.frame(path = tsv_path)
  class(missing_local_path) <- c("encode_download_result", "data.frame")
  expect_error(encode_read(missing_local_path), "local_path")
  expect_error(encode_read(withr::local_tempfile()), "does not exist")
})

test_that("loaded objects print compact summaries instead of nested tables", {
  tsv_path <- withr::local_tempfile(fileext = ".tsv")
  writeLines(c("gene_id\tcount", "Gata4\t10", "Tbx5\t20"), tsv_path)
  table_input <- data.frame(
    file_accession = c("ENCFFPRINT1", "ENCFFPRINT2"),
    experiment_accession = "ENCSRPRINT1",
    file_format = "tsv",
    local_path = tsv_path,
    download_status = "downloaded",
    stringsAsFactors = FALSE
  )
  class(table_input) <- c("encode_download_result", "data.frame")

  loaded <- encode_read(table_input)
  capture_print <- function(expr) {
    stdout <- capture.output(messages <- capture.output(force(expr), type = "message"))
    c(messages, stdout)
  }
  loaded_output <- capture_print(print(loaded))
  data_output <- capture_print(print(loaded$data))
  matrix_output <- capture_print(print(loaded$matrices))
  experiment_output <- capture_print(print(loaded$by_experiment$ENCSRPRINT1))

  expect_true(any(grepl("ENCODE loaded files", loaded_output, fixed = TRUE)))
  expect_true(any(grepl("ENCODE loaded data", data_output, fixed = TRUE)))
  expect_true(any(grepl("ENCODE matrices", matrix_output, fixed = TRUE)))
  expect_true(any(grepl("ENCODE loaded experiment", experiment_output, fixed = TRUE)))
  expect_false(any(grepl("Gata4", data_output, fixed = TRUE)))
  expect_false(any(grepl("Gata4", matrix_output, fixed = TRUE)))
  expect_false(any(grepl("Gata4", experiment_output, fixed = TRUE)))
})

test_that("file table printing avoids long sample strings and paths by default", {
  files <- data.frame(
    file_accession = "ENCFFNOISY1",
    experiment_accession = "ENCSRNOISY1",
    assay_title = "Histone ChIP-seq",
    organism = "Homo sapiens",
    biosample_term_name = "HepG2",
    sample_summary = paste(rep("genetically modified CRISPR sample description", 4), collapse = " "),
    file_format = "bed",
    output_type = "IDR thresholded peaks",
    assembly = "GRCh38",
    file_size_pretty = "1 MB",
    status = "released",
    local_path = file.path(tempdir(), paste(rep("long_path_component", 6), collapse = "_")),
    stringsAsFactors = FALSE
  )
  class(files) <- c("encode_file_table", "data.frame")
  output <- capture.output(
    messages <- capture.output(print(files), type = "message")
  )
  output <- c(messages, output)

  expect_false(any(grepl("genetically modified", output, fixed = TRUE)))
  expect_false(any(grepl("long_path_component", output, fixed = TRUE)))
  expect_true(max(nchar(output, type = "width")) < 140)
})

test_that("encode_read optional genomic readers either load or explain clearly", {
  bed_path <- withr::local_tempfile(fileext = ".bed")
  fasta_path <- withr::local_tempfile(fileext = ".fa")
  writeLines("chr1\t0\t10\tpeak1", bed_path)
  writeLines(c(">seq1", "ACGT"), fasta_path)

  bed <- encode_read(bed_path)
  fasta <- encode_read(fasta_path)

  if (requireNamespace("rtracklayer", quietly = TRUE)) {
    expect_s4_class(bed, "GRanges")
  } else {
    expect_s3_class(bed, "data.frame")
  }
  bed_table <- encode_read(bed_path, as = "data.frame")
  expect_s3_class(bed_table, "data.frame")
  expect_equal(names(bed_table)[1:4], c("chrom", "start", "end", "name"))

  if (requireNamespace("Biostrings", quietly = TRUE)) {
    expect_s4_class(fasta, "DNAStringSet")
  } else {
    expect_s3_class(fasta, "encode_local_file")
    expect_match(fasta$reason, "Biostrings")
  }
})

test_that("downloaded bigBed peak rows keep indexed binary format over file_type labels", {
  bigbed_path <- withr::local_tempfile(fileext = ".bigBed")
  writeBin(as.raw(c(0xeb, 0xf2, 0x89, 0x87, 0x04)), bigbed_path)
  row <- data.frame(
    file_accession = "ENCFFBIGBED1",
    file_format = "bigBed",
    file_type = "bigBed narrowPeak",
    local_path = bigbed_path,
    stringsAsFactors = FALSE
  )
  class(row) <- c("encode_download_result", "data.frame")

  expect_equal(encode_row_read_format(row, NULL), "bigBed")
  result <- encode_read(row)
  expect_s3_class(result, "encode_local_file")
  expect_match(result$reason, "indexed signal and annotation files require region")
})
