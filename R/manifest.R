#' Build an ENCODE reproducibility manifest
#'
#' Capture the query, selected files, download records, ENCODE attribution
#' metadata, and optional R session information. Provide `path` to save the
#' manifest as JSON.
#'
#' @param x ENCODE accession(s), result object, file table, selected files, or
#'   download result.
#' @param include_attribution Whether to include ENCODE dataset and file
#'   attribution metadata when supported.
#' @param include_session Whether to include `utils::sessionInfo()`.
#' @param path Optional destination JSON path. If supplied, the manifest is also
#'   written to disk.
#' @param pretty Whether to pretty-print JSON when `path` is supplied.
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
#' path <- tempfile(fileext = ".json")
#' manifest <- encode_manifest(files, include_session = FALSE, path = path)
#' names(manifest)
encode_manifest <- function(x,
                            include_attribution = TRUE,
                            include_session = TRUE,
                            path = NULL,
                            pretty = TRUE) {
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
  } else if (is.character(x)) {
    manifest$accessions <- data.frame(
      accession = vapply(x, encode_normalize_accession, character(1L)),
      stringsAsFactors = FALSE
    )
  }

  if (isTRUE(include_attribution)) {
    manifest$attribution <- tryCatch(
      encode_attribution(x, enrich = FALSE, quiet = TRUE),
      error = function(cnd) {
        if (is.character(x)) {
          cli::cli_abort(conditionMessage(cnd))
        }
        NULL
      }
    )
  }
  if (isTRUE(include_session)) {
    manifest$session <- utils::capture.output(utils::sessionInfo())
  }
  class(manifest) <- c("encode_manifest", "list")
  if (!is.null(path)) {
    encode_write_manifest_json(manifest, path = path, pretty = pretty)
    attr(manifest, "path") <- path
  }
  manifest
}

encode_write_manifest_json <- function(manifest, path, pretty = TRUE) {
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
