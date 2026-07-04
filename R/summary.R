#' Summarize an ENCODE result
#'
#' Return a compact summary of an ENCODE result object or file table. For file
#' tables, the summary includes file count, experiment count, known total size,
#' formats, assemblies, output types, and largest known-size files.
#'
#' @param x An ENCODE result object or table.
#' @param ... Reserved for future methods.
#'
#' @return A compact summary object or data frame, depending on input type.
#' @export
#'
#' @examples
#' files <- data.frame(
#'   file_accession = c("ENCFF000AAA", "ENCFF000AAB"),
#'   experiment_accession = c("ENCSR000AAA", "ENCSR000AAA"),
#'   file_format = c("bed", "bigWig"),
#'   output_type = c("peaks", "signal"),
#'   assembly = c("GRCh38", "GRCh38"),
#'   file_size = c(100, 200)
#' )
#' encode_summary(files)
#'
#' # Search results can also be summarized:
#' # res <- encode_search(type = "Experiment", search = "mouse heart ChIP-seq")
#' # encode_summary(res)
encode_summary <- function(x, ...) {
  if (inherits(x, "encode_object")) {
    return(x$summary)
  }
  if (inherits(x, "encode_search_result")) {
    return(data.frame(
      total_results = x$total,
      returned_results = nrow(x$results),
      query_url = x$query_url,
      stringsAsFactors = FALSE
    ))
  }
  if (inherits(x, "encode_matrix_result")) {
    return(list(
      total_results = x$total,
      assay_summary = x$assay_summary,
      biosample_summary = x$biosample_summary
    ))
  }
  if (inherits(x, "encode_selected_files")) {
    return(encode_file_summary(x$files))
  }
  if (is.data.frame(x) && ("file_accession" %in% names(x) || "href" %in% names(x))) {
    return(encode_file_summary(x))
  }
  cli::cli_abort("{.arg x} cannot be summarized by encodeUtils.")
}

#' Summarize an ENCODE file table
#'
#' @param files File metadata from `encode_list_files()`, `encode_select_files()`,
#'   `encode_download()`, or a compatible data frame.
#'
#' @return A file-summary list.
#'
#' @examples
#' files <- data.frame(
#'   file_accession = c("ENCFF000AAA", "ENCFF000AAB"),
#'   experiment_accession = c("ENCSR000AAA", "ENCSR000AAA"),
#'   file_format = c("bed", "bigWig"),
#'   output_type = c("peaks", "signal"),
#'   assembly = c("GRCh38", "GRCh38"),
#'   file_size = c(100, 200)
#' )
#' encode_file_summary(files)
#' @noRd
encode_file_summary <- function(files) {
  if (inherits(files, "encode_selected_files")) {
    files <- files$files
  }
  files <- as.data.frame(files, stringsAsFactors = FALSE)
  files <- encode_ensure_columns(files, c(
    "file_accession", "experiment_accession", "file_format", "output_type",
    "assembly", "file_size"
  ))
  total_size <- encode_size(files)
  result <- list(
    n_files = nrow(files),
    n_experiments = length(unique(stats::na.omit(files$experiment_accession))),
    total_size = total_size,
    total_size_pretty = encode_pretty_bytes(total_size),
    formats = encode_count_values(files$file_format, "file_format"),
    assemblies = encode_count_values(files$assembly, "assembly"),
    output_types = encode_count_values(files$output_type, "output_type"),
    largest_files = encode_largest_files(files, n = min(10L, nrow(files)))
  )
  class(result) <- c("encode_file_summary", "list")
  result
}

#' Sum known ENCODE file sizes
#'
#' @param files A file metadata table.
#'
#' @return Total known size in bytes.
#'
#' @examples
#' encode_size(data.frame(file_size = c(100, NA, 50)))
#' @noRd
encode_size <- function(files) {
  files <- as.data.frame(files, stringsAsFactors = FALSE)
  if (!"file_size" %in% names(files)) {
    return(0)
  }
  sum(encode_as_file_size(files$file_size), na.rm = TRUE)
}

#' Return the largest files in an ENCODE file table
#'
#' @param files A file metadata table.
#' @param n Number of rows to return.
#'
#' @return A data frame sorted by descending known file size.
#'
#' @examples
#' files <- data.frame(file_accession = c("a", "b"), file_size = c(1, 10))
#' encode_largest_files(files, n = 1)
#' @noRd
encode_largest_files <- function(files, n = 10L) {
  files <- as.data.frame(files, stringsAsFactors = FALSE)
  if (!"file_size" %in% names(files) || nrow(files) == 0L) {
    return(files[0L, , drop = FALSE])
  }
  sizes <- encode_as_file_size(files$file_size)
  files$file_size <- sizes
  if ("file_size_pretty" %in% names(files)) {
    files$file_size_pretty <- encode_pretty_bytes(sizes)
  }
  files <- files[order(sizes, decreasing = TRUE, na.last = TRUE), , drop = FALSE]
  utils::head(files, n)
}

encode_count_values <- function(values, name) {
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) {
    return(data.frame(value = character(), n = integer()))
  }
  counts <- sort(table(values), decreasing = TRUE)
  out <- data.frame(
    value = names(counts),
    n = as.integer(counts),
    stringsAsFactors = FALSE
  )
  names(out)[[1L]] <- name
  out
}
