#' List files for ENCODE experiments
#'
#' Return file metadata for one or more ENCODE experiments. The table includes
#' file accessions, formats, output types, assemblies, sizes, checksums, and
#' download links. It does not download file contents.
#'
#' The default `limit = "all"` requests the complete file list for the selected
#' experiments.
#'
#' @param x Experiment accession(s), experiment path(s), a search result from
#'   `encode_search()`, or a data frame containing experiment identifiers.
#' @param file_format Optional file format filter, such as `"fastq"`, `"bed"`,
#'   `"bigWig"`, or `"tsv"`.
#' @param output_type Optional ENCODE output type filter, such as `"reads"` or
#'   `"gene quantifications"`.
#' @param assembly Optional genome assembly filter, such as `"GRCh38"` or
#'   `"mm10"`.
#' @param status Optional file status filter. Use `NULL` to omit.
#' @param limit Number of file records to request, or `"all"`.
#' @param metadata Amount of linked metadata to request. `"basic"` keeps
#'   responses smaller. `"full"` adds more display columns.
#' @param allow_many Whether to allow many experiment datasets in one query.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return An `encode_file_table` data frame. Common columns include
#'   `file_accession`, `experiment_accession`, `dataset_accession`,
#'   `file_format`, `output_type`, `assembly`, `file_size`, `md5sum`, `href`,
#'   `cloud_url`, and parent experiment metadata when available. The function
#'   lists metadata only; it does not download file contents.
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
    metadata = c("basic", "full"),
    allow_many = FALSE,
    quiet = FALSE
) {
    file_format <- encode_validate_values(file_format, "file_format")
    output_type <- encode_validate_values(output_type, "output_type")
    assembly <- encode_validate_values(assembly, "assembly")
    status <- encode_validate_values(status, "status")
    allow_many <- encode_validate_flag(allow_many, "allow_many")
    quiet <- encode_validate_flag(quiet, "quiet")
    metadata_request <- encode_metadata_request(metadata)
    frame <- metadata_request$frame
    metadata <- metadata_request$metadata
    encode_validate_limit(limit)
    experiment_paths <- encode_experiment_paths(x)
    experiment_paths <- unique(experiment_paths[!is.na(experiment_paths) & nzchar(experiment_paths)])
    if (length(experiment_paths) == 0L) {
        cli::cli_abort("{.arg x} did not contain experiment accessions or paths.")
    }
    if (length(experiment_paths) > 25L && !isTRUE(allow_many)) {
        cli::cli_abort(
            c(
                "Refusing to list files for {length(experiment_paths)} experiments at once.",
                "i" = "Use {.code allow_many = TRUE} after narrowing the experiment set."
            )
        )
    }

    filters <- list(dataset = experiment_paths)
    if (!is.null(file_format)) {
        filters$file_format <- file_format
    }
    if (!is.null(output_type)) {
        filters$output_type <- output_type
    }
    if (!is.null(assembly)) {
        filters$assembly <- assembly
    }

    search_result <- encode_search(
        type = "File",
        filters = filters,
        status = status,
        limit = limit,
        metadata = metadata,
        include_facets = TRUE,
        quiet = TRUE
    )
    files <- encode_results(search_result)
    files <- encode_attach_metadata(
        files,
        query_url = search_result$query_url,
        retrieved_at = search_result$request$retrieved_at,
        filters = search_result$filters,
        request_history = search_result$request_history
    )
    class(files) <- c("encode_file_table", "data.frame")
    attr(files, "total") <- search_result$total
    attr(files, "query_url") <- search_result$query_url
    attr(files, "retrieved_at") <- search_result$request$retrieved_at
    attr(files, "metadata") <- metadata
    attr(files, "frame") <- frame

    if (!isTRUE(quiet)) {
        known_size <- encode_size(files)
        if (nrow(files) == 0L) {
            cli::cli_inform(c(
                "ENCODE file listing found no matching file records.",
                "i" = "Try loosening {.arg file_format}, {.arg output_type}, {.arg assembly}, or {.arg status}."
            ))
        } else {
            cli::cli_inform(
                "ENCODE file listing returned {nrow(files)} file record(s) ({encode_pretty_bytes(known_size)} with known sizes)."
            )
        }
    }
    files
}

# Parent experiment enrichment

# Preserve file rows when optional parent-experiment enrichment fails.
encode_fetch_experiment_metadata_for_files <- function(experiment_paths, metadata = "basic") {
    accessions <- vapply(experiment_paths, encode_accession_from_path, character(1L))
    accessions <- unique(accessions[encode_is_experiment_accession(accessions)])
    if (length(accessions) == 0L) {
        return(encode_empty_results("Experiment"))
    }
    chunks <- split(accessions, ceiling(seq_along(accessions) / 100L))
    results <- lapply(seq_along(chunks), function(i) {
        chunk <- chunks[[i]]
        result <- tryCatch(
            encode_search(
                type = "Experiment",
                filters = list(accession = chunk),
                status = NULL,
                limit = "all",
                metadata = metadata,
                include_facets = FALSE,
                quiet = TRUE
            ),
            error = function(cnd) {
                return(list(
                    data = encode_empty_results("Experiment"),
                    error = conditionMessage(cnd)
                ))
            }
        )
        if (is.list(result) && !is.null(result$error)) {
            return(result)
        }
        list(
            data = encode_results(result),
            error = NA_character_,
            request_history = encode_request_roles(
                result$request_history,
                "parent_metadata"
            )
        )
    })
    request_history <- do.call(
        c,
        lapply(results, function(result) result$request_history %||% list())
    )
    request_history <- request_history %||% list()
    errors <- unique(vapply(results, `[[`, character(1L), "error"))
    errors <- errors[!is.na(errors) & nzchar(errors)]
    if (length(errors) > 0L) {
        cli::cli_warn(c(
            "Could not retrieve parent experiment metadata for some ENCODE file records.",
            "i" = "File rows are still returned, but provenance columns may be incomplete.",
            "x" = errors[[1L]]
        ))
    }
    experiments <- encode_bind_rows(
        lapply(results, `[[`, "data"),
        names(encode_empty_results("Experiment"))
    )
    if (nrow(experiments) == 0L) {
        experiments <- encode_empty_results("Experiment")
        attr(experiments, "metadata_enrichment_error") <- errors
        attr(experiments, "request_history") <- request_history
        return(experiments)
    }
    experiments <- experiments[!duplicated(experiments$accession), , drop = FALSE]
    attr(experiments, "metadata_enrichment_error") <- errors
    attr(experiments, "request_history") <- request_history
    experiments
}

encode_enrich_file_table_from_parent_experiments <- function(files, metadata = "basic") {
    if (!is.data.frame(files) || nrow(files) == 0L) {
        return(files)
    }
    if (!encode_file_table_needs_parent_metadata(files)) {
        return(files)
    }
    experiment_paths <- encode_experiment_paths_from_file_table(files)
    experiments <- encode_fetch_experiment_metadata_for_files(experiment_paths, metadata = metadata)
    files <- encode_fill_file_experiment_metadata(files, experiments)
    request_history <- attr(experiments, "request_history", exact = TRUE)
    if (!is.null(request_history)) {
        attr(files, "request_history") <- request_history
    }
    errors <- attr(experiments, "metadata_enrichment_error", exact = TRUE)
    if (!is.null(errors) && length(errors) > 0L) {
        attr(files, "metadata_enrichment_error") <- errors
    }
    files
}

encode_file_table_needs_parent_metadata <- function(files) {
    columns <- intersect(
        c("organism", "biosample_term_name", "biosample_type", "sample_summary", "assay_title"),
        names(files)
    )
    if (length(columns) == 0L) {
        return(FALSE)
    }
    any(vapply(files[columns], encode_any_missing_text, logical(1L)))
}

encode_any_missing_text <- function(x) {
    missing <- is.na(x) | !nzchar(as.character(x))
    any(missing, na.rm = TRUE)
}

encode_experiment_paths_from_file_table <- function(files) {
    paths <- character()
    if ("dataset" %in% names(files)) {
        paths <- c(paths, as.character(files$dataset))
    }
    if ("experiment_accession" %in% names(files)) {
        accessions <- as.character(files$experiment_accession)
        accessions <- accessions[encode_is_experiment_accession(accessions)]
        paths <- c(paths, paste0("/experiments/", accessions, "/"))
    }
    paths <- unique(paths[!is.na(paths) & nzchar(paths)])
    paths[grepl("^/experiments/", paths)]
}

# Fill missing provenance only; file-level values take precedence.
encode_fill_file_experiment_metadata <- function(files, experiments) {
    if (!is.data.frame(files) || nrow(files) == 0L ||
        !is.data.frame(experiments) || nrow(experiments) == 0L ||
        !"experiment_accession" %in% names(files) ||
        !"accession" %in% names(experiments)) {
        return(files)
    }
    experiment_rows <- match(files$experiment_accession, experiments$accession)
    mapped <- c(
        assay_title = "assay_title",
        assay_term_name = "assay_term_name",
        target = "target",
        control_type = "control_type",
        organism = "organism",
        sample_summary = "sample_summary",
        life_stage_age = "life_stage_age",
        sex = "sex",
        treatment = "treatment",
        biosample_summary = "biosample_summary",
        biosample_type = "biosample_classification",
        biosample_term_name = "biosample_term_name",
        lab = "lab",
        institution = "institution",
        project = "project",
        award = "award"
    )
    for (file_column in names(mapped)) {
        experiment_column <- mapped[[file_column]]
        if (!file_column %in% names(files) || !experiment_column %in% names(experiments)) {
            next
        }
        values <- experiments[[experiment_column]][experiment_rows]
        replace <- is.na(files[[file_column]]) | !nzchar(as.character(files[[file_column]]))
        replace[is.na(replace)] <- TRUE
        files[[file_column]][replace] <- values[replace]
    }
    files
}

# Experiment and file input normalization

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
            return(paste0("/experiments/", x$experiment_accession, "/"))
        }
        if ("accession" %in% names(x)) {
            accessions <- as.character(x$accession)
            accessions <- accessions[encode_is_experiment_accession(accessions)]
            return(paste0("/experiments/", accessions, "/"))
        }
        cli::cli_abort("{.arg x} data frame must contain dataset, id, experiment_accession, or accession.")
    }
    if (is.character(x)) {
        return(vapply(x, encode_as_experiment_path, character(1L)))
    }
    cli::cli_abort("{.arg x} must be experiment identifiers, an ENCODE search result, or a data frame.")
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
        if (!grepl("/$", x)) {
            x <- paste0(x, "/")
        }
        return(x)
    }
    cli::cli_abort("Expected an ENCODE experiment accession or path, not {.val {x}}.")
}

encode_file_table_from_input <- function(x, status = "released") {
    if (inherits(x, "encode_selected_files")) {
        return(x$files)
    }
    if (inherits(x, "encode_file_table")) {
        return(x)
    }
    if (inherits(x, "encode_search_result")) {
        if (!"file_accession" %in% names(x$results) && !"href" %in% names(x$results)) {
            cli::cli_abort("{.arg x} search result does not contain file metadata.")
        }
        files <- x$results
        class(files) <- c("encode_file_table", "data.frame")
        return(files)
    }
    if (is.data.frame(x)) {
        accession_is_file <- "accession" %in% names(x) &&
            all(encode_is_file_accession(toupper(as.character(x$accession))))
        if ("href" %in% names(x) || "file_accession" %in% names(x) || accession_is_file) {
            files <- as.data.frame(x, stringsAsFactors = FALSE)
            class(files) <- c("encode_file_table", "data.frame")
            return(files)
        }
    }
    if (is.character(x)) {
        accessions <- vapply(x, encode_normalize_accession, character(1L))
        if (!all(encode_is_file_accession(accessions))) {
            cli::cli_abort("Character input to file operations must be ENCFF file accessions, paths, or URLs.")
        }
        search_result <- encode_search(
            type = "File",
            filters = list(accession = accessions),
            status = status,
            limit = "all",
            metadata = "basic",
            quiet = TRUE
        )
        files <- encode_results(search_result)
        class(files) <- c("encode_file_table", "data.frame")
        return(files)
    }
    cli::cli_abort("{.arg x} could not be converted to an ENCODE file metadata table.")
}
