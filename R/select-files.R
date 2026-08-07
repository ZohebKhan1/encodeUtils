#' Select ENCODE files
#'
#' Apply a reusable file preset and optional replicate policy to a file table.
#' Use `encode_list_files()` or ordinary data-frame subsetting for exact file
#' format, output type, assembly, and status filters.
#'
#' @param files File metadata from `encode_list_files()`, a File search result,
#'   a selected-file object, or ENCFF accession(s).
#' @param preset Optional preset name. Use `encode_file_presets()` to list or
#'   inspect presets.
#' @param file_accession Optional ENCFF accession(s) to retain.
#' @param replicate_policy How to handle replicate-related outputs. `"all"`
#'   keeps all matching files; `"preferred_processed"` keeps the first
#'   preset-ranked output type per experiment; `"replicate_level"` keeps
#'   single-replicate files; and `"pooled_only"` keeps pooled or IDR-like
#'   outputs.
#' @param prefer_default Whether to prefer records marked `preferred_default`
#'   within each experiment when such records are available.
#' @param quiet If `FALSE`, print a concise selection message.
#'
#' @return An `encode_selected_files` list containing selected files, excluded
#'   files with reasons, and the applied criteria.
#' @export
#'
#' @examples
#' files <- data.frame(
#'     file_accession = c("ENCFFONE", "ENCFFTWO"),
#'     experiment_accession = "ENCSRONE",
#'     file_format = c("tsv", "bed"),
#'     output_type = c("gene quantifications", "peaks"),
#'     href = c(
#'         "/files/ENCFFONE/@@@@download/a.tsv",
#'         "/files/ENCFFTWO/@@@@download/b.bed"
#'     )
#' )
#'
#' selected <- encode_select_files(
#'     files,
#'     preset = "rnaseq_gene_quant",
#'     quiet = TRUE
#' )
#'
#' encode_results(selected)
encode_select_files <- function(
    files,
    preset = NULL,
    file_accession = NULL,
    replicate_policy = c(
        "all", "preferred_processed", "replicate_level", "pooled_only"
    ),
    prefer_default = FALSE,
    quiet = FALSE
) {
    replicate_policy <- match.arg(replicate_policy)
    file_accession <- encode_validate_file_accessions(file_accession)
    prefer_default <- encode_validate_flag(prefer_default, "prefer_default")
    quiet <- encode_validate_flag(quiet, "quiet")
    preset_info <- if (is.null(preset)) NULL else encode_file_preset(preset)
    if (identical(replicate_policy, "preferred_processed") &&
        is.null(preset_info)) {
        cli::cli_abort(
            "{.code replicate_policy = 'preferred_processed'} requires {.arg preset}."
        )
    }

    files <- encode_file_table_from_input(files)
    query_url <- encode_query_url(files)
    retrieved_at <- attr(files, "retrieved_at", exact = TRUE)
    filters <- encode_filters(files)
    request_history <- encode_request_history(files)
    files <- as.data.frame(files, stringsAsFactors = FALSE)
    if (!"file_accession" %in% names(files) && "accession" %in% names(files)) {
        files$file_accession <- files$accession
    }
    files <- encode_ensure_columns(files, c(
        "file_accession", "experiment_accession", "file_format", "output_type",
        "href", "download_url", "biological_replicates", "preferred_default"
    ))
    files$preferred_default <- encode_logical_vector(files$preferred_default)

    criteria <- list(
        preset = preset,
        file_accession = file_accession,
        replicate_policy = replicate_policy,
        prefer_default = prefer_default
    )
    state <- encode_selection_state(files)
    state <- encode_apply_selection_filter(
        state,
        encode_match_values(files$file_accession, file_accession),
        "not requested file accession",
        !is.null(file_accession)
    )
    if (!is.null(file_accession)) {
        missing <- setdiff(file_accession, toupper(files$file_accession))
        if (length(missing) > 0L) {
            cli::cli_abort(
                "Requested ENCODE file accession(s) were not found: {.val {paste(missing, collapse = ', ')}}."
            )
        }
    }
    if (!is.null(preset_info)) {
        state <- encode_apply_selection_filter(
            state,
            encode_match_values(files$file_format, preset_info$file_format),
            "not in preset file formats",
            TRUE
        )
        state <- encode_apply_selection_filter(
            state,
            encode_match_values(
                files$output_type,
                preset_info$output_type_priority
            ),
            "not in preset output types",
            TRUE
        )
    }
    state <- encode_apply_selection_filter(
        state,
        encode_has_download_url(files),
        "missing download URL",
        TRUE
    )
    use_preferred <- prefer_default &&
        any(state$keep & files$preferred_default %in% TRUE)
    state <- encode_apply_preferred_default(state, files, use_preferred)
    state <- encode_apply_replicate_policy(
        state,
        files,
        replicate_policy,
        preset_info$output_type_priority %||% NULL
    )

    selected <- files[state$keep, , drop = FALSE]
    if (!is.null(file_accession) && nrow(selected) > 0L) {
        selected <- selected[
            stats::na.omit(match(file_accession, toupper(selected$file_accession))),
            ,
            drop = FALSE
        ]
    }
    selected <- encode_attach_metadata(
        selected,
        query_url = query_url,
        retrieved_at = retrieved_at,
        filters = filters,
        request_history = request_history,
        selection_criteria = criteria
    )
    class(selected) <- c("encode_file_table", "data.frame")
    result <- list(
        files = selected,
        excluded = encode_exclusion_table(files, state$reasons),
        criteria = criteria,
        query_url = query_url,
        retrieved_at = retrieved_at
    )
    class(result) <- c("encode_selected_files", "list")

    if (!quiet) {
        cli::cli_inform(
            "ENCODE file selection kept {nrow(selected)} of {nrow(files)} file(s)."
        )
    }
    result
}

#' List or inspect file-selection presets
#'
#' @param preset Preset name, or `NULL` to list all preset names.
#'
#' @return A character vector of preset names or one preset definition.
#' @export
#'
#' @examples
#' encode_file_presets()
#' encode_file_presets("rnaseq_gene_quant")
encode_file_presets <- function(preset = NULL) {
    encode_file_preset(preset)
}

encode_file_preset <- function(preset = NULL) {
    presets <- list(
        raw_reads = list(
            file_format = "fastq",
            output_type_priority = "reads"
        ),
        alignments = list(
            file_format = c("bam", "cram", "sam"),
            output_type_priority = c("alignments", "unfiltered alignments")
        ),
        chipseq_peaks = list(
            file_format = c("bed", "narrowPeak", "broadPeak", "bigBed"),
            output_type_priority = c(
                "optimal IDR thresholded peaks",
                "conservative IDR thresholded peaks",
                "IDR thresholded peaks",
                "pseudoreplicated peaks",
                "replicated peaks",
                "peaks"
            )
        ),
        chipseq_signal = list(
            file_format = c("bigWig", "bw"),
            output_type_priority = c(
                "fold change over control",
                "signal p-value",
                "control normalized signal",
                "read-depth normalized signal",
                "signal"
            )
        ),
        atacseq_peaks = list(
            file_format = c("bed", "narrowPeak", "broadPeak", "bigBed"),
            output_type_priority = c(
                "IDR thresholded peaks",
                "optimal IDR thresholded peaks",
                "conservative IDR thresholded peaks",
                "pseudoreplicated peaks",
                "replicated peaks",
                "peaks"
            )
        ),
        rnaseq_gene_quant = list(
            file_format = c("tsv", "txt", "csv"),
            output_type_priority = c(
                "gene quantifications",
                "gene expression quantifications",
                "gene TPMs",
                "gene counts",
                "quantifications"
            )
        ),
        rnaseq_transcript_quant = list(
            file_format = c("tsv", "txt", "csv"),
            output_type_priority = c(
                "transcript quantifications",
                "transcript expression quantifications",
                "transcript TPMs",
                "quantifications"
            )
        ),
        metadata = list(
            file_format = c("txt", "tsv", "json"),
            output_type_priority = "metadata"
        )
    )
    if (is.null(preset)) {
        return(names(presets))
    }
    if (!is.character(preset) || length(preset) != 1L || is.na(preset) ||
        !trimws(preset) %in% names(presets)) {
        cli::cli_abort(
            "{.arg preset} must be one of {.val {paste(names(presets), collapse = ', ')}}."
        )
    }
    info <- presets[[trimws(preset)]]
    info$preset <- trimws(preset)
    info
}

encode_selection_state <- function(files) {
    list(
        keep = rep(TRUE, nrow(files)),
        reasons = stats::setNames(vector("list", nrow(files)), seq_len(nrow(files)))
    )
}

encode_apply_selection_filter <- function(state, keep, reason, active) {
    if (!active) {
        return(state)
    }
    keep[is.na(keep)] <- FALSE
    for (index in which(!keep)) {
        state$reasons[[index]] <- c(state$reasons[[index]], reason)
    }
    state$keep <- state$keep & keep
    state
}

encode_apply_preferred_default <- function(state, files, active) {
    if (!active) {
        return(state)
    }
    groups <- files$experiment_accession
    missing <- is.na(groups) | !nzchar(groups)
    groups[missing] <- files$file_accession[missing]
    keep <- rep(TRUE, nrow(files))
    for (group in unique(groups[state$keep])) {
        index <- which(state$keep & groups == group)
        preferred <- files$preferred_default[index] %in% TRUE
        if (any(preferred)) {
            keep[index[!preferred]] <- FALSE
        }
    }
    encode_apply_selection_filter(
        state,
        keep,
        "not preferred_default",
        TRUE
    )
}

encode_apply_replicate_policy <- function(state, files, policy, output_priority) {
    if (identical(policy, "all")) {
        return(state)
    }
    if (identical(policy, "replicate_level")) {
        keep <- !is.na(files$biological_replicates) &
            nzchar(trimws(files$biological_replicates)) &
            !grepl("[,;|]", files$biological_replicates) &
            !grepl(
                "pooled|idr|pseudoreplicated|optimal|conservative",
                files$output_type,
                ignore.case = TRUE
            )
        return(encode_apply_selection_filter(
            state, keep, "not replicate-level", TRUE
        ))
    }
    if (identical(policy, "pooled_only")) {
        keep <- grepl(
            "pooled|idr|pseudoreplicated|optimal|conservative",
            files$output_type,
            ignore.case = TRUE
        )
        return(encode_apply_selection_filter(
            state, keep, "not pooled or IDR-like", TRUE
        ))
    }
    encode_keep_best_output_type(state, files, output_priority)
}

encode_keep_best_output_type <- function(state, files, output_priority) {
    ranks <- match(tolower(files$output_type), tolower(output_priority))
    groups <- files$experiment_accession
    missing <- is.na(groups) | !nzchar(groups)
    groups[missing] <- files$file_accession[missing]
    keep <- rep(TRUE, nrow(files))
    for (group in unique(groups[state$keep])) {
        index <- which(state$keep & groups == group)
        ranked <- ranks[index]
        if (!all(is.na(ranked))) {
            best <- min(ranked, na.rm = TRUE)
            keep[index[is.na(ranked) | ranked > best]] <- FALSE
        }
    }
    encode_apply_selection_filter(
        state, keep, "lower-priority output type", TRUE
    )
}

encode_match_values <- function(values, allowed) {
    if (is.null(allowed)) {
        return(rep(TRUE, length(values)))
    }
    !is.na(values) & tolower(values) %in% tolower(allowed)
}

encode_has_download_url <- function(files) {
    (!is.na(files$href) & nzchar(files$href)) |
        (!is.na(files$download_url) & nzchar(files$download_url))
}

encode_exclusion_table <- function(files, reasons) {
    excluded <- which(vapply(reasons, length, integer(1L)) > 0L)
    if (length(excluded) == 0L) {
        return(data.frame(
            file_accession = character(),
            experiment_accession = character(),
            reason = character()
        ))
    }
    data.frame(
        file_accession = files$file_accession[excluded],
        experiment_accession = files$experiment_accession[excluded],
        reason = vapply(
            reasons[excluded],
            function(x) paste(unique(x), collapse = "; "),
            character(1L)
        ),
        stringsAsFactors = FALSE
    )
}
