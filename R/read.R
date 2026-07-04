#' Read a local ENCODE file
#'
#' Read a file that is already on disk. Small tabular and JSON files are loaded
#' directly. Genomic interval and sequence formats use optional Bioconductor
#' readers when they are installed. Large or unsupported formats return a
#' lightweight path object by default instead of being silently loaded into
#' memory.
#'
#' @param path Local file path or one-row download result from
#'   `encode_download()`.
#' @param format Optional file format override.
#' @param max_size Maximum size to read into memory, as bytes or a string.
#' @param region Optional genomic range object passed to `rtracklayer::import()`
#'   as `which` for indexed genomic formats.
#' @param allow_large Whether to allow full import of indexed formats such as
#'   bigWig or bigBed without `region`.
#' @param unsupported What to do for unsupported or deliberately skipped
#'   formats: return a path object or throw an error.
#' @param ... Additional arguments passed to table readers where applicable.
#'
#' @return A data frame, list, optional Bioconductor object, or
#'   `encode_local_file` object.
#' @export
#'
#' @examples
#' csv_path <- tempfile(fileext = ".csv")
#' writeLines(c("gene,value", "MYC,2.5"), csv_path)
#' encode_read(csv_path)
#'
#' bam_path <- tempfile(fileext = ".bam")
#' writeBin(charToRaw("placeholder"), bam_path)
#' # Alignment files are not read wholesale; this returns a path object.
#' encode_read(bam_path)
#'
#' # Typical use after a small dry-run/download result:
#' # downloaded <- encode_download(encode_results(selected)[1, ], directory = tempdir())
#' # encode_read(downloaded[1, ])
encode_read <- function(
                        path,
                        format = NULL,
                        max_size = "100MB",
                        region = NULL,
                        allow_large = FALSE,
                        unsupported = c("return_path", "error"),
                        ...) {
  unsupported <- match.arg(unsupported)
  path <- encode_read_path(path)
  if (!file.exists(path)) {
    cli::cli_abort("File does not exist: {.path {path}}.")
  }
  max_size <- encode_parse_size(max_size, arg = "max_size")
  file_size <- as.numeric(file.info(path)$size)
  if (!is.na(file_size) && file_size > max_size) {
    return(encode_unsupported_local_file(
      path = path,
      reason = "file exceeds max_size",
      unsupported = unsupported
    ))
  }

  format <- format %||% encode_get_extension(path)
  format <- tolower(format)
  if (format %in% c("tsv", "txt")) {
    return(utils::read.delim(path, stringsAsFactors = FALSE, ...))
  }
  if (format %in% c("csv")) {
    return(utils::read.csv(path, stringsAsFactors = FALSE, ...))
  }
  if (format %in% c("json")) {
    return(jsonlite::fromJSON(path, simplifyVector = FALSE))
  }
  if (format %in% c("bw", "bigwig", "bb", "bigbed") && is.null(region) && !isTRUE(allow_large)) {
    return(encode_unsupported_local_file(
      path = path,
      reason = "indexed signal and annotation files require region or allow_large = TRUE",
      unsupported = unsupported
    ))
  }
  if (format %in% c("bed", "gff", "gtf", "bw", "bigwig", "bb", "bigbed", "narrowpeak", "broadpeak")) {
    return(encode_read_with_optional_package(
      package = "rtracklayer",
      fun = "import",
      path = path,
      unsupported = unsupported,
      reason = "rtracklayer is required for genomic interval imports",
      region = region,
      ...
    ))
  }
  if (format %in% c("fa", "fasta")) {
    return(encode_read_with_optional_package(
      package = "Biostrings",
      fun = "readDNAStringSet",
      path = path,
      unsupported = unsupported,
      reason = "Biostrings is required for FASTA imports"
    ))
  }
  if (format %in% c("fq", "fastq")) {
    return(encode_unsupported_local_file(
      path = path,
      reason = "FASTQ files should not be read wholesale by encode_read(); use a read-processing workflow deliberately",
      unsupported = unsupported
    ))
  }
  if (format %in% c("bam", "cram", "sam")) {
    return(encode_unsupported_local_file(
      path = path,
      reason = "alignment files should be opened with Rsamtools or GenomicAlignments for the intended region/workflow",
      unsupported = unsupported
    ))
  }

  encode_unsupported_local_file(
    path = path,
    reason = paste0("unsupported file format: ", format),
    unsupported = unsupported
  )
}

encode_read_path <- function(path) {
  if (inherits(path, "encode_download_result") || inherits(path, "encode_file_table")) {
    if (nrow(path) != 1L) {
      cli::cli_abort("{.arg path} table input must contain exactly one row.")
    }
    if (!"local_path" %in% names(path)) {
      cli::cli_abort("{.arg path} table input must include {.field local_path}.")
    }
    return(path$local_path[[1L]])
  }
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    cli::cli_abort("{.arg path} must be one local file path.")
  }
  path
}

encode_read_with_optional_package <- function(package, fun, path, unsupported, reason, region = NULL, ...) {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(encode_unsupported_local_file(
      path = path,
      reason = reason,
      unsupported = unsupported
    ))
  }
  reader <- getExportedValue(package, fun)
  if (is.null(region)) {
    return(reader(path, ...))
  }
  reader(path, which = region, ...)
}

encode_unsupported_local_file <- function(path, reason, unsupported) {
  if (identical(unsupported, "error")) {
    cli::cli_abort(reason)
  }
  result <- list(
    path = path,
    reason = reason,
    file_size = as.numeric(file.info(path)$size),
    file_size_pretty = encode_pretty_bytes(as.numeric(file.info(path)$size))
  )
  class(result) <- c("encode_local_file", "list")
  result
}
