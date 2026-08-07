#' List files for ENCODE experiments
#'
#' Return file metadata for one or more ENCODE experiments. File filters are
#' sent to the Portal; the function does not download file contents.
#'
#' @param x Experiment accession(s), experiment path(s), a search result, or a
#'   data frame containing experiment identifiers.
#' @param file_format Optional file format, such as `"fastq"`, `"bed"`, or
#'   `"tsv"`.
#' @param output_type Optional ENCODE output type, such as `"reads"` or
#'   `"gene quantifications"`.
#' @param assembly Optional genome assembly, such as `"GRCh38"` or `"mm10"`.
#' @param status Optional file status. Use `NULL` to omit.
#' @param limit Number of file records to return, or `"all"`.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return An `encode_file_table` data frame with file metadata and request
#'   provenance.
#' @export
#'
#' @examples
#' files <- encode_list_files(
#'     "ENCSR523CTA",
#'     file_format = "tsv",
#'     output_type = "microRNA quantifications",
#'     assembly = "mm10",
#'     limit = 1,
#'     quiet = TRUE
#' )
#'
#' encode_results(files)
encode_list_files <- function(
    x,
    file_format = NULL,
    output_type = NULL,
    assembly = NULL,
    status = "released",
    limit = "all",
    quiet = FALSE
) {
    file_format <- encode_validate_values(file_format, "file_format")
    output_type <- encode_validate_values(output_type, "output_type")
    assembly <- encode_validate_values(assembly, "assembly")
    status <- encode_validate_values(status, "status")
    quiet <- encode_validate_flag(quiet, "quiet")
    encode_validate_limit(limit)

    experiment_paths <- unique(encode_experiment_paths(x))
    experiment_paths <- experiment_paths[
        !is.na(experiment_paths) & nzchar(experiment_paths)
    ]
    if (length(experiment_paths) == 0L) {
        cli::cli_abort("{.arg x} did not contain experiment accessions or paths.")
    }

    extra_filters <- list(
        file_format = file_format,
        output_type = output_type,
        assembly = assembly
    )
    extra_filters <- extra_filters[!vapply(extra_filters, is.null, logical(1L))]
    chunks <- split(
        experiment_paths,
        ceiling(seq_along(experiment_paths) / 25L)
    )
    searches <- lapply(chunks, function(chunk) {
        encode_search(
            type = "File",
            filters = c(list(dataset = chunk), extra_filters),
            status = status,
            limit = limit,
            quiet = TRUE
        )
    })

    files <- encode_bind_rows(lapply(searches, encode_results))
    if (!identical(limit, "all") && nrow(files) > limit) {
        files <- files[seq_len(limit), , drop = FALSE]
    }
    filters <- unique(do.call(rbind, lapply(searches, `[[`, "filters")))
    request_history <- unlist(
        lapply(searches, `[[`, "request_history"),
        recursive = FALSE
    )
    files <- encode_attach_metadata(
        files,
        query_url = searches[[1L]]$query_url,
        retrieved_at = searches[[1L]]$request$retrieved_at,
        filters = filters,
        request_history = request_history
    )
    class(files) <- c("encode_file_table", "data.frame")
    attr(files, "total") <- sum(vapply(searches, `[[`, numeric(1L), "total"))

    if (!quiet) {
        cli::cli_inform(
            "ENCODE file listing returned {nrow(files)} file record(s) ({encode_pretty_bytes(encode_size(files))} with known sizes)."
        )
    }
    files
}

encode_experiment_paths <- function(x) {
    if (inherits(x, "encode_search_result")) {
        return(encode_experiment_paths(x$results))
    }
    if (is.data.frame(x)) {
        if ("dataset" %in% names(x)) {
            return(vapply(as.character(x$dataset), encode_as_experiment_path, character(1L)))
        }
        if ("id" %in% names(x)) {
            return(vapply(as.character(x$id), encode_as_experiment_path, character(1L)))
        }
        if ("experiment_accession" %in% names(x)) {
            return(vapply(as.character(x$experiment_accession), encode_as_experiment_path, character(1L)))
        }
        if ("accession" %in% names(x)) {
            accessions <- as.character(x$accession)
            accessions <- accessions[encode_is_experiment_accession(accessions)]
            return(vapply(accessions, encode_as_experiment_path, character(1L)))
        }
        cli::cli_abort(
            "{.arg x} data frame must contain dataset, id, experiment_accession, or accession."
        )
    }
    if (is.character(x)) {
        return(vapply(x, encode_as_experiment_path, character(1L)))
    }
    cli::cli_abort(
        "{.arg x} must be experiment identifiers, a search result, or a data frame."
    )
}

encode_as_experiment_path <- function(x) {
    if (is.na(x) || !nzchar(x)) {
        return(NA_character_)
    }
    if (grepl("^https?://", x)) {
        x <- sub("^https?://[^/]+", "", x)
        x <- sub("[?].*$", "", x)
    }
    if (encode_is_experiment_accession(x)) {
        return(paste0("/experiments/", x, "/"))
    }
    if (grepl("^/experiments/[^/]+/?$", x)) {
        return(paste0(sub("/$", "", x), "/"))
    }
    cli::cli_abort(
        "Expected an ENCODE experiment accession or path, not {.val {x}}."
    )
}

encode_file_table_from_input <- function(x) {
    if (inherits(x, "encode_selected_files")) {
        return(x$files)
    }
    if (inherits(x, "encode_loaded_files")) {
        return(x$metadata)
    }
    if (inherits(x, "encode_file_table")) {
        return(x)
    }
    if (inherits(x, "encode_search_result")) {
        if (!"file_accession" %in% names(x$results) &&
            !"href" %in% names(x$results)) {
            cli::cli_abort("{.arg x} search result does not contain file metadata.")
        }
        files <- x$results
        class(files) <- c("encode_file_table", "data.frame")
        return(files)
    }
    if (is.data.frame(x)) {
        accession_is_file <- "accession" %in% names(x) &&
            all(encode_is_file_accession(toupper(as.character(x$accession))))
        if ("href" %in% names(x) || "file_accession" %in% names(x) ||
            accession_is_file || "local_path" %in% names(x)) {
            files <- x
            class(files) <- c("encode_file_table", "data.frame")
            return(files)
        }
    }
    if (is.character(x)) {
        accessions <- vapply(x, encode_normalize_accession, character(1L))
        if (!all(encode_is_file_accession(accessions))) {
            cli::cli_abort(
                "Character input to file operations must contain ENCFF accessions, paths, or URLs."
            )
        }
        files <- encode_results(encode_search(
            type = "File",
            filters = list(accession = accessions),
            status = NULL,
            limit = "all",
            quiet = TRUE
        ))
        class(files) <- c("encode_file_table", "data.frame")
        return(files)
    }
    cli::cli_abort(
        "{.arg x} could not be converted to an ENCODE file metadata table."
    )
}
