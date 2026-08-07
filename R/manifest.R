#' Build an ENCODE reproducibility manifest
#'
#' Capture the query, selected files, download records, ENCODE attribution
#' metadata, and optional R session information. Provide `path` to save the
#' manifest as JSON.
#'
#' @param x ENCODE accession(s), result object, file table, selected files, or
#'   download result.
#' @param include_attribution Whether to include ENCODE dataset and file
#'   attribution metadata when supported. Result objects and file tables reuse
#'   metadata already held by `x` and issue no further requests. Character
#'   ENCSR or ENCFF input first retrieves the required ENCODE metadata. `lab`,
#'   `institution`, and `project` describe the record that produced each file.
#'   For processed ENCODE files that is the processing pipeline rather than the
#'   originating laboratory; use the parent experiment table when citing data
#'   producers. Attribution `retrieval_date` is `NA` when the input has no
#'   recorded retrieval timestamp; manifest `created_at` remains separate.
#' @param include_session Whether to include `utils::sessionInfo()`.
#' @param path Optional destination JSON path. If supplied, the manifest is also
#'   written to disk.
#' @param pretty Whether to pretty-print JSON when `path` is supplied.
#'
#' @return An `encode_manifest` list. Components include `package`,
#'   `retrieval`, `filters`, and `object_type`. Available request history and
#'   file-selection criteria are stored in `requests` and
#'   `selection_criteria`. Depending on input, the manifest also includes
#'   experiments, records, selected or excluded files, downloaded or loaded
#'   files, loaded-object classes, matrix dimensions, or accessions. When
#'   requested and available, it includes ENCODE `attribution` and captured R
#'   `session` information. If `path` is supplied, the same manifest is written
#'   as JSON and the path is stored as an attribute.
#' @export
#'
#' @examples
#' files <- data.frame(
#'     file_accession = "ENCFFLOCAL1",
#'     local_path = tempfile(fileext = ".tsv")
#' )
#'
#' manifest <- encode_manifest(files, include_attribution = FALSE,
#'                             include_session = FALSE)
#'
#' names(manifest)
encode_manifest <- function(
    x,
    include_attribution = TRUE,
    include_session = TRUE,
    path = NULL,
    pretty = TRUE
) {
    include_attribution <- encode_validate_flag(include_attribution, "include_attribution")
    include_session <- encode_validate_flag(include_session, "include_session")
    path <- encode_validate_scalar(path, "path")
    pretty <- encode_validate_flag(pretty, "pretty")

    # Loaded collections keep request provenance on their metadata table.
    provenance <- if (inherits(x, "encode_loaded_files")) x$metadata else x
    base_url <- attr(provenance, "encode_base_url", exact = TRUE)
    retrieved_at <- attr(provenance, "retrieved_at", exact = TRUE)
    if (is.list(provenance)) {
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
    request_history <- encode_request_history(x)
    if (length(request_history) > 0L) {
        manifest$requests <- request_history
    }
    selection_criteria <- encode_selection_criteria(x)
    if (!is.null(selection_criteria)) {
        manifest$selection_criteria <- selection_criteria
    }

    if (inherits(x, "encode_search_result")) {
        if (inherits(x$results, "encode_file_table")) {
            manifest$files <- x$results
        } else if (inherits(x$results, "encode_experiment_table")) {
            manifest$experiments <- x$results
        } else {
            manifest$records <- x$results
        }
    } else if (inherits(x, "encode_selected_files")) {
        manifest$selected_files <- x$files
        manifest$excluded_files <- x$excluded
        manifest$criteria <- x$criteria
    } else if (inherits(x, "encode_download_result")) {
        manifest$downloaded_files <- as.data.frame(x, stringsAsFactors = FALSE)
    } else if (inherits(x, "encode_loaded_files")) {
        manifest$files <- as.data.frame(x$metadata, stringsAsFactors = FALSE)
        manifest$loaded_objects <- data.frame(
            name = names(x$data),
            class = vapply(x$data, function(value) {
                paste(class(value), collapse = ", ")
            }, character(1L)),
            stringsAsFactors = FALSE
        )
        if (length(x$matrices) > 0L) {
            manifest$matrices <- data.frame(
                name = names(x$matrices),
                rows = vapply(x$matrices, nrow, integer(1L)),
                columns = vapply(x$matrices, ncol, integer(1L)),
                stringsAsFactors = FALSE
            )
        }
    } else if (inherits(x, "encode_file_table") || is.data.frame(x)) {
        manifest$files <- as.data.frame(x, stringsAsFactors = FALSE)
    } else if (is.character(x)) {
        manifest$accessions <- data.frame(
            accession = vapply(x, encode_normalize_accession, character(1L)),
            stringsAsFactors = FALSE
        )
    } else {
        cli::cli_abort("{.arg x} is not a supported ENCODE result, file table, or accession vector.")
    }

    if (isTRUE(include_attribution)) {
        manifest$attribution <- encode_attribution(x, enrich = FALSE, quiet = TRUE)
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

encode_manifest_timestamp <- function(x) {
    if (is.null(x) || length(x) == 0L || all(is.na(x))) {
        return(NA_character_)
    }
    if (!inherits(x, "POSIXt")) {
        return(as.character(x))
    }
    format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
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
