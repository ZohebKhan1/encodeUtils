# Attribution dispatch

encode_attribution <- function(
    x,
    enrich = "auto",
    max_enrich_datasets = 10,
    quiet = FALSE
) {
    encode_attribution_table(
        x,
        enrich = enrich,
        max_enrich_datasets = max_enrich_datasets,
        quiet = quiet
    )
}

encode_attribution_table <- function(
    x,
    enrich = "auto",
    max_enrich_datasets = 10,
    quiet = FALSE
) {
    if (inherits(x, "encode_selected_files")) {
        return(encode_attribution_from_file_table(
            x$files,
            enrich = enrich,
            max_enrich_datasets = max_enrich_datasets,
            quiet = quiet
        ))
    }
    if (inherits(x, "encode_download_result") || inherits(x, "encode_file_table")) {
        return(encode_attribution_from_file_table(
            x,
            enrich = enrich,
            max_enrich_datasets = max_enrich_datasets,
            quiet = quiet
        ))
    }
    if (inherits(x, "encode_loaded_files")) {
        return(encode_attribution_from_file_table(
            x$metadata,
            enrich = enrich,
            max_enrich_datasets = max_enrich_datasets,
            quiet = quiet
        ))
    }
    if (inherits(x, "encode_search_result")) {
        if ("file_accession" %in% names(x$results)) {
            return(encode_attribution_from_file_table(
                x$results,
                enrich = enrich,
                max_enrich_datasets = max_enrich_datasets,
                quiet = quiet
            ))
        }
        return(encode_attribution_from_experiment_table(x$results))
    }
    if (is.data.frame(x)) {
        if ("file_accession" %in% names(x) || "href" %in% names(x)) {
            return(encode_attribution_from_file_table(
                x,
                enrich = enrich,
                max_enrich_datasets = max_enrich_datasets,
                quiet = quiet
            ))
        }
        if ("accession" %in% names(x)) {
            return(encode_attribution_from_experiment_table(x))
        }
    }
    if (is.character(x)) {
        return(encode_attribution_from_character(x, quiet = quiet))
    }
    cli::cli_abort("{.arg x} could not be converted to ENCODE attribution metadata.")
}

# Accession attribution

encode_attribution_from_character <- function(x, quiet = FALSE) {
    accessions <- vapply(x, encode_normalize_accession, character(1L))
    file_ids <- accessions[encode_is_file_accession(accessions)]
    experiment_ids <- accessions[encode_is_experiment_accession(accessions)]
    other <- setdiff(accessions, c(file_ids, experiment_ids))
    if (length(other) > 0L) {
        cli::cli_abort("Character input currently supports ENCSR and ENCFF accessions/URLs.")
    }
    file_rows <- if (length(file_ids) > 0L) {
        encode_attribution_from_file_table(
            encode_file_table_from_input(file_ids, status = NULL),
            enrich = TRUE
        )
    } else {
        NULL
    }
    experiment_rows <- if (length(experiment_ids) > 0L) {
        experiments <- encode_search(
            type = "Experiment",
            filters = list(accession = experiment_ids),
            status = NULL,
            limit = "all",
            metadata = "full",
            include_facets = FALSE,
            quiet = TRUE
        )
        encode_attribution_from_experiment_table(encode_results(experiments))
    } else {
        NULL
    }
    rows <- Filter(Negate(is.null), list(file_rows, experiment_rows))
    if (!isTRUE(quiet)) {
        cli::cli_inform("Built ENCODE attribution metadata for {length(x)} input id(s).")
    }
    encode_bind_rows(rows, encode_attribution_columns())
}

# File attribution and optional parent-dataset enrichment

encode_attribution_from_file_table <- function(
    files,
    enrich = "auto",
    max_enrich_datasets = 10,
    quiet = FALSE
) {
    retrieval_date <- encode_attribution_retrieval_date(files)
    files <- as.data.frame(files, stringsAsFactors = FALSE)
    if (!"file_accession" %in% names(files) && "accession" %in% names(files)) {
        files$file_accession <- files$accession
    }
    files <- encode_add_file_dataset_identity(files)
    if (encode_should_enrich_file_attribution(
        files,
        enrich = enrich,
        max_enrich_datasets = max_enrich_datasets,
        quiet = quiet
    )) {
        files <- encode_enrich_file_attribution(files)
    }
    files <- encode_ensure_columns(files, c(
        "dataset", "dataset_accession", "dataset_type", "experiment_accession",
        "file_accession", "lab", "institution", "project", "assay_title",
        "biosample_summary", "organism", "file_format", "output_type",
        "assembly", "md5sum", "status", "url", "download_url"
    ))
    dataset_url <- encode_object_url(files$dataset)
    experiment_url <- encode_object_url(paste0(
        "/experiments/",
        files$experiment_accession,
        "/"
    ))
    missing_experiment <- is.na(files$experiment_accession) |
        !nzchar(files$experiment_accession)
    experiment_url[missing_experiment] <- NA_character_
    out <- data.frame(
        dataset_accession = files$dataset_accession,
        dataset_type = files$dataset_type,
        experiment_accession = files$experiment_accession,
        file_accession = files$file_accession,
        lab = files$lab,
        institution = files$institution,
        project = files$project,
        assay_title = files$assay_title,
        biosample = files$biosample_summary,
        organism = files$organism,
        file_format = files$file_format,
        output_type = files$output_type,
        assembly = files$assembly,
        md5sum = files$md5sum,
        status = files$status,
        dataset_url = dataset_url,
        experiment_url = experiment_url,
        file_url = files$url,
        download_url = files$download_url,
        retrieval_date = retrieval_date,
        attribution_guidance_url = "https://www.encodeproject.org/help/citing-encode/",
        stringsAsFactors = FALSE
    )
    out <- out[encode_attribution_columns()]
    class(out) <- c("encode_attribution_table", "data.frame")
    out
}

encode_add_file_dataset_identity <- function(files) {
    files <- encode_ensure_columns(files, c(
        "dataset", "dataset_accession", "dataset_type", "experiment_accession"
    ))
    needs_dataset <- (is.na(files$dataset) | !nzchar(files$dataset)) &
        !is.na(files$experiment_accession) & nzchar(files$experiment_accession)
    files$dataset[needs_dataset] <- paste0(
        "/experiments/",
        files$experiment_accession[needs_dataset],
        "/"
    )

    missing_accession <- is.na(files$dataset_accession) | !nzchar(files$dataset_accession)
    files$dataset_accession[missing_accession] <- vapply(
        files$dataset[missing_accession],
        encode_accession_from_path,
        character(1L)
    )

    missing_type <- is.na(files$dataset_type) | !nzchar(files$dataset_type)
    files$dataset_type[missing_type] <- vapply(
        files$dataset[missing_type],
        encode_dataset_type_from_path,
        character(1L)
    )

    experiment_rows <- !is.na(files$dataset_type) &
        files$dataset_type %in% "Experiment"
    missing_experiment <- is.na(files$experiment_accession) | !nzchar(files$experiment_accession)
    fill_experiment <- experiment_rows & missing_experiment
    files$experiment_accession[fill_experiment] <- files$dataset_accession[fill_experiment]
    files
}

encode_should_enrich_file_attribution <- function(files, enrich, max_enrich_datasets, quiet) {
    if (isTRUE(enrich)) {
        return(TRUE)
    }
    if (isFALSE(enrich)) {
        return(FALSE)
    }
    if (!identical(enrich, "auto")) {
        cli::cli_abort("{.arg enrich} must be {.val auto}, TRUE, or FALSE.")
    }
    max_enrich_datasets <- encode_validate_positive_whole_number(
        max_enrich_datasets,
        "max_enrich_datasets"
    )
    accessions <- unique(stats::na.omit(files$experiment_accession))
    accessions <- accessions[nzchar(accessions)]
    if (length(accessions) == 0L) {
        return(FALSE)
    }
    if (length(accessions) > max_enrich_datasets) {
        if (!isTRUE(quiet)) {
            cli::cli_inform(c(
                "Skipping attribution enrichment for {length(accessions)} parent experiment dataset(s).",
                "i" = "Use {.code enrich = TRUE} to request enrichment."
            ))
        }
        return(FALSE)
    }
    TRUE
}

encode_enrich_file_attribution <- function(files) {
    files <- encode_ensure_columns(files, c("experiment_accession"))
    accessions <- unique(stats::na.omit(files$experiment_accession))
    accessions <- accessions[nzchar(accessions)]
    if (length(accessions) == 0L) {
        return(files)
    }
    experiments <- encode_search(
        type = "Experiment",
        filters = list(accession = accessions),
        status = NULL,
        limit = "all",
        metadata = "full",
        include_facets = FALSE,
        quiet = TRUE
    )$results
    if (nrow(experiments) == 0L) {
        return(files)
    }
    match_index <- match(files$experiment_accession, experiments$accession)
    matched <- !is.na(match_index)
    files <- encode_ensure_columns(files, c(
        "lab", "institution", "project", "assay_title", "biosample_summary",
        "organism"
    ))
    fill_map <- c(
        lab = "lab",
        institution = "institution",
        project = "project",
        assay_title = "assay_title",
        biosample_summary = "biosample_summary",
        organism = "organism"
    )
    for (file_column in names(fill_map)) {
        experiment_column <- fill_map[[file_column]]
        if (!experiment_column %in% names(experiments)) {
            next
        }
        replacement <- rep(NA_character_, nrow(files))
        replacement[matched] <- experiments[[experiment_column]][match_index[matched]]
        available <- !is.na(replacement) & nzchar(replacement)
        files[[file_column]][available] <- replacement[available]
    }
    files
}

# Experiment attribution

encode_attribution_from_experiment_table <- function(experiments) {
    retrieval_date <- encode_attribution_retrieval_date(experiments)
    experiments <- as.data.frame(experiments, stringsAsFactors = FALSE)
    experiments <- encode_ensure_columns(experiments, c(
        "accession", "lab", "institution", "project", "assay_title",
        "biosample_summary", "organism", "status", "url"
    ))
    out <- data.frame(
        dataset_accession = experiments$accession,
        dataset_type = "Experiment",
        experiment_accession = experiments$accession,
        file_accession = NA_character_,
        lab = experiments$lab,
        institution = experiments$institution,
        project = experiments$project,
        assay_title = experiments$assay_title,
        biosample = experiments$biosample_summary,
        organism = experiments$organism,
        file_format = NA_character_,
        output_type = NA_character_,
        assembly = NA_character_,
        md5sum = NA_character_,
        status = experiments$status,
        dataset_url = experiments$url,
        experiment_url = experiments$url,
        file_url = NA_character_,
        download_url = NA_character_,
        retrieval_date = retrieval_date,
        attribution_guidance_url = "https://www.encodeproject.org/help/citing-encode/",
        stringsAsFactors = FALSE
    )
    out <- out[encode_attribution_columns()]
    class(out) <- c("encode_attribution_table", "data.frame")
    out
}

encode_attribution_retrieval_date <- function(x) {
    retrieved_at <- attr(x, "retrieved_at", exact = TRUE)
    if (is.null(retrieved_at) || length(retrieved_at) == 0L || all(is.na(retrieved_at))) {
        return(as.character(Sys.Date()))
    }
    as.character(as.Date(retrieved_at, tz = "UTC"))
}

# Attribution table schema

encode_attribution_columns <- function() {
    c(
        "dataset_accession", "dataset_type", "experiment_accession",
        "file_accession", "lab", "institution", "project", "assay_title",
        "biosample", "organism", "file_format", "output_type", "assembly",
        "md5sum", "status", "dataset_url", "experiment_url", "file_url",
        "download_url", "retrieval_date", "attribution_guidance_url"
    )
}

encode_ensure_columns <- function(x, columns) {
    for (column in columns) {
        if (!column %in% names(x)) {
            x[[column]] <- rep(NA_character_, nrow(x))
        }
    }
    x
}
