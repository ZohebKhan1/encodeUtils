#' Build an ENCODE reproducibility manifest
#'
#' Capture the query, selected files, download records, citation metadata, and
#' optional R session information for an ENCODE workflow. The manifest is a
#' regular R list that can be written to JSON with `encode_write_manifest()`.
#'
#' @param x ENCODE result object, file table, selected files, or download result.
#' @param include_citation Whether to include `encode_cite(x)` when supported.
#' @param include_session Whether to include `utils::sessionInfo()`.
#'
#' @return A manifest list.
#' @export
#'
#' @examples
#' files <- data.frame(
#'   file_accession = "ENCFF000AAA",
#'   experiment_accession = "ENCSR000AAA",
#'   file_format = "txt",
#'   output_type = "metadata",
#'   status = "released"
#' )
#' manifest <- encode_manifest(files, include_session = FALSE)
#' names(manifest)
#'
#' # Typical use:
#' # manifest <- encode_manifest(selected, include_session = FALSE)
#' # encode_write_manifest(manifest, "encode-manifest.json")
encode_manifest <- function(
                            x,
                            include_citation = TRUE,
                            include_session = TRUE) {
  manifest <- list(
    package = list(
      name = "encodeUtils",
      version = encode_package_version()
    ),
    retrieval = list(
      date = as.character(Sys.time()),
      encode_base_url = attr(x, "encode_base_url", exact = TRUE) %||% encode_base_url(),
      query_url = encode_query_url(x),
      retrieved_at = as.character(attr(x, "retrieved_at", exact = TRUE) %||% NA_character_)
    ),
    filters = encode_filters(x),
    object_type = class(x)[[1L]]
  )

  if (inherits(x, "encode_search_result")) {
    manifest$experiments <- x$results
  } else if (inherits(x, "encode_selected_files")) {
    manifest$selected_files <- x$files
    manifest$excluded_files <- x$excluded
    manifest$criteria <- x$criteria
  } else if (inherits(x, "encode_download_result")) {
    manifest$downloaded_files <- as.data.frame(x, stringsAsFactors = FALSE)
  } else if (inherits(x, "encode_file_table") || is.data.frame(x)) {
    manifest$files <- as.data.frame(x, stringsAsFactors = FALSE)
  } else if (inherits(x, "encode_object")) {
    manifest$object <- x$summary
  } else if (inherits(x, "encode_report_result")) {
    manifest$report <- x$report
  } else if (inherits(x, "encode_matrix_result")) {
    manifest$matrix <- x$matrix
    manifest$assay_summary <- x$assay_summary
    manifest$biosample_summary <- x$biosample_summary
  }

  if (isTRUE(include_citation)) {
    manifest$citation <- tryCatch(
      encode_cite(x, enrich = FALSE, quiet = TRUE),
      error = function(cnd) NULL
    )
  }
  if (isTRUE(include_session)) {
    manifest$session <- utils::capture.output(utils::sessionInfo())
  }
  class(manifest) <- c("encode_manifest", "list")
  manifest
}

#' Write an ENCODE manifest
#'
#' Save the list returned by `encode_manifest()` as JSON. The destination
#' directory is created if needed.
#'
#' @param manifest An object returned by `encode_manifest()`.
#' @param path Destination JSON path.
#' @param pretty Whether to pretty-print JSON.
#'
#' @return The written path, invisibly.
#' @export
#'
#' @examples
#' files <- data.frame(file_accession = "ENCFF000AAA")
#' manifest <- encode_manifest(files, include_session = FALSE)
#' path <- tempfile(fileext = ".json")
#' encode_write_manifest(manifest, path)
encode_write_manifest <- function(manifest, path, pretty = TRUE) {
  if (!inherits(manifest, "encode_manifest")) {
    cli::cli_abort("{.arg manifest} must come from {.fun encode_manifest}.")
  }
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    cli::cli_abort("{.arg path} must be one non-empty JSON path.")
  }
  directory <- dirname(path)
  if (!dir.exists(directory)) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  }
  jsonlite::write_json(
    manifest,
    path = path,
    auto_unbox = TRUE,
    pretty = pretty,
    null = "null"
  )
  invisible(path)
}
