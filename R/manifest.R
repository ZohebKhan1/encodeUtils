#' Build an ENCODE reproducibility manifest
#'
#' Capture query provenance, selection criteria, file records, loaded-object
#' classes, and optional R session information. The function uses metadata
#' already present in `x` and never issues an ENCODE request.
#'
#' @param x ENCODE accession(s), result object, file table, selected files,
#'   download result, or loaded-file object.
#' @param path Optional destination JSON path.
#' @param include_session Whether to include `utils::sessionInfo()`.
#'
#' @return An `encode_manifest` list. If `path` is supplied, the same manifest
#'   is written as JSON and the path is stored as an attribute.
#' @export
#'
#' @examples
#' files <- data.frame(
#'     file_accession = "ENCFFLOCAL1",
#'     local_path = tempfile(fileext = ".tsv")
#' )
#' manifest <- encode_manifest(files, include_session = FALSE)
#' names(manifest)
encode_manifest <- function(x, path = NULL, include_session = TRUE) {
    path <- encode_validate_scalar(path, "path")
    include_session <- encode_validate_flag(include_session, "include_session")
    provenance <- if (inherits(x, "encode_loaded_files")) x$metadata else x
    base_url <- attr(provenance, "encode_base_url", exact = TRUE)
    retrieved_at <- attr(provenance, "retrieved_at", exact = TRUE)
    if (is.list(provenance) && !is.data.frame(provenance)) {
        base_url <- base_url %||% provenance$encode_base_url
        retrieved_at <- retrieved_at %||%
            provenance$retrieved_at %||%
            provenance$request$retrieved_at
    }

    manifest <- list(
        package = list(
            name = "encodeUtils",
            version = encode_package_version()
        ),
        retrieval = list(
            created_at = encode_manifest_timestamp(Sys.time()),
            encode_base_url = base_url %||% encode_base_url(),
            query_url = encode_query_url(x),
            retrieved_at = encode_manifest_timestamp(retrieved_at)
        ),
        filters = encode_filters(x),
        object_type = class(x)[[1L]]
    )
    requests <- encode_request_history(x)
    if (length(requests) > 0L) manifest$requests <- requests
    criteria <- encode_selection_criteria(x)
    if (!is.null(criteria)) manifest$selection_criteria <- criteria

    if (inherits(x, "encode_search_result")) {
        name <- if (inherits(x$results, "encode_file_table")) {
            "files"
        } else if (all(c("assay_title", "file_count") %in% names(x$results))) {
            "experiments"
        } else {
            "records"
        }
        manifest[[name]] <- x$results
    } else if (inherits(x, "encode_selected_files")) {
        manifest$selected_files <- x$files
        manifest$excluded_files <- x$excluded
    } else if (inherits(x, "encode_download_result")) {
        manifest$downloaded_files <- as.data.frame(x, stringsAsFactors = FALSE)
    } else if (inherits(x, "encode_loaded_files")) {
        manifest$files <- as.data.frame(x$metadata, stringsAsFactors = FALSE)
        manifest$loaded_objects <- data.frame(
            name = names(x$data),
            class = vapply(
                x$data,
                function(value) paste(class(value), collapse = ", "),
                character(1L)
            ),
            stringsAsFactors = FALSE
        )
    } else if (inherits(x, "encode_file_table") || is.data.frame(x)) {
        manifest$files <- as.data.frame(x, stringsAsFactors = FALSE)
    } else if (is.character(x)) {
        manifest$accessions <- data.frame(
            accession = vapply(x, encode_normalize_accession, character(1L)),
            stringsAsFactors = FALSE
        )
    } else {
        cli::cli_abort(
            "{.arg x} is not a supported ENCODE result, file table, or accession vector."
        )
    }
    if (include_session) {
        manifest$session <- utils::capture.output(utils::sessionInfo())
    }
    class(manifest) <- c("encode_manifest", "list")
    if (!is.null(path)) {
        encode_write_manifest_json(manifest, path)
        attr(manifest, "path") <- path
    }
    manifest
}

encode_manifest_timestamp <- function(x) {
    if (is.null(x) || length(x) == 0L || all(is.na(x))) {
        return(NA_character_)
    }
    if (!inherits(x, "POSIXt")) return(as.character(x))
    format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

encode_write_manifest_json <- function(manifest, path) {
    directory <- dirname(path)
    if (!dir.exists(directory)) {
        dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    }
    jsonlite::write_json(
        manifest,
        path = path,
        auto_unbox = TRUE,
        pretty = TRUE,
        null = "null"
    )
    invisible(path)
}
