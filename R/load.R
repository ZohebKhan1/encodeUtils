# Loaded-file collection

encode_load_downloaded_files <- function(
    files,
    max_size = "100MB",
    format = NULL,
    region = NULL,
    allow_large = FALSE,
    unsupported = c("return_path", "error"),
    as = c("auto", "data.frame", "GRanges", "path"),
    row_names = c("gene_symbol", "gene_id", "ensembl_id", "entrez_id", "none"),
    matrix_values = "raw_counts",
    simplify_quant = TRUE,
    quiet = FALSE
) {
    unsupported <- match.arg(unsupported)
    as <- match.arg(as)
    row_names <- match.arg(row_names)
    matrix_values <- encode_normalize_matrix_values(matrix_values)
    query_url <- encode_query_url(files)
    retrieved_at <- attr(files, "retrieved_at", exact = TRUE)
    filters <- encode_filters(files)
    request_history <- encode_request_history(files)
    selection_criteria <- encode_selection_criteria(files)
    base_url <- attr(files, "encode_base_url", exact = TRUE) %||% encode_base_url()
    files <- as.data.frame(files, stringsAsFactors = FALSE)
    files <- encode_attach_metadata(
        files,
        query_url = query_url,
        retrieved_at = retrieved_at,
        filters = filters,
        base_url = base_url,
        request_history = request_history,
        selection_criteria = selection_criteria
    )
    if (!"local_path" %in% names(files)) {
        cli::cli_abort("Downloaded file metadata must include {.field local_path}.")
    }
    if ("download_status" %in% names(files)) {
        readable <- files$download_status %in% c("downloaded", "exists")
        if (!all(readable)) {
            bad <- files$file_accession[!readable]
            cli::cli_abort(
                "Cannot read failed or unplanned download rows: {.val {paste(bad, collapse = ', ')}}."
            )
        }
    }

    data <- vector("list", nrow(files))
    names(data) <- encode_loaded_file_names(files)
    if (!isTRUE(quiet)) {
        cli::cli_inform("Reading {nrow(files)} downloaded ENCODE file(s).")
    }
    for (i in seq_len(nrow(files))) {
        row <- files[i, , drop = FALSE]
        row_format <- encode_row_read_format(row, format)
        if (!isTRUE(quiet)) {
            accession <- names(data)[[i]]
            cli::cli_inform("Reading ({i}/{nrow(files)}) {.val {accession}}.")
        }
        data[[i]] <- encode_read(
            row$local_path[[1L]],
            format = row_format,
            max_size = max_size,
            region = region,
            allow_large = allow_large,
            unsupported = unsupported,
            as = as,
            row_names = "none",
            simplify_quant = simplify_quant
        )
    }
    if (!isTRUE(quiet)) {
        cli::cli_inform("Preparing loaded ENCODE tables.")
    }
    data <- encode_set_row_names(data, row_names)
    class(data) <- c("encode_data_list", "list")

    matrices <- encode_tabular_matrices(data, files, values = matrix_values)
    row_data <- attr(matrices, "row_data", exact = TRUE)
    attr(matrices, "row_data") <- NULL
    assays <- encode_set_assay_row_names(matrices, row_data, row_names)
    result <- list(
        metadata = files,
        data = data,
        row_data = assays$row_data,
        matrices = assays$matrices
    )
    class(result) <- c("encode_loaded_files", "list")

    if (!isTRUE(quiet)) {
        cli::cli_inform(
            "Loaded {length(data)} ENCODE file object(s). Use {.code x$metadata}, {.code x$data}, {.code x$row_data}, and {.code x$matrices}."
        )
    }
    result
}

encode_loaded_summarized_experiment <- function(loaded) {
    assays <- lapply(loaded$matrices, identity)
    if (length(assays) == 0L) {
        reason <- attr(loaded$matrices, "reason", exact = TRUE)
        cli::cli_abort(
            c(
                "No compatible expression matrices were assembled, so a SummarizedExperiment cannot be created.",
                "x" = reason %||% "The loaded files did not provide compatible tabular expression data."
            )
        )
    }
    samples <- colnames(assays[[1L]])
    features <- rownames(assays[[1L]])
    sample_index <- match(samples, encode_loaded_file_names(loaded$metadata))
    if (anyNA(sample_index)) {
        cli::cli_abort(
            "Assay columns could not be matched to their ENCODE file metadata."
        )
    }
    col_data <- S4Vectors::DataFrame(
        as.data.frame(loaded$metadata[sample_index, , drop = FALSE], stringsAsFactors = FALSE),
        row.names = samples
    )
    row_data <- S4Vectors::DataFrame(
        as.data.frame(loaded$row_data, stringsAsFactors = FALSE),
        row.names = features
    )
    provenance <- list(
        query_url = encode_query_url(loaded),
        retrieved_at = attr(loaded$metadata, "retrieved_at", exact = TRUE),
        filters = encode_filters(loaded),
        requests = encode_request_history(loaded),
        selection_criteria = encode_selection_criteria(loaded)
    )
    SummarizedExperiment::SummarizedExperiment(
        assays = assays,
        rowData = row_data,
        colData = col_data,
        metadata = list(encodeUtils = provenance)
    )
}

encode_set_row_names <- function(x, row_names) {
    if (identical(row_names, "none")) {
        if (is.data.frame(x)) {
            row.names(x) <- NULL
            return(x)
        }
        if (is.list(x)) {
            x[] <- lapply(x, encode_set_row_names, row_names = row_names)
        }
        return(x)
    }
    if (is.data.frame(x)) {
        if (row_names %in% names(x)) {
            values <- as.character(x[[row_names]])
            missing <- is.na(values) | !nzchar(values)
            values[missing] <- paste0("row_", which(missing))
            row.names(x) <- make.unique(values)
        }
        return(x)
    }
    if (is.list(x)) {
        x[] <- lapply(x, encode_set_row_names, row_names = row_names)
    }
    x
}

encode_loaded_file_names <- function(files) {
    names <- if ("file_accession" %in% names(files)) {
        files$file_accession
    } else if ("accession" %in% names(files)) {
        files$accession
    } else {
        tools::file_path_sans_ext(basename(files$local_path))
    }
    encode_valid_object_names(names)
}

encode_valid_object_names <- function(x) {
    x <- as.character(x)
    x[is.na(x) | !nzchar(x)] <- "encode_object"
    x <- gsub("[^A-Za-z0-9_.]", "_", x)
    starts_bad <- !grepl("^[A-Za-z.]", x) | grepl("^[.][0-9]", x)
    x[starts_bad] <- paste0("x_", x[starts_bad])
    make.unique(x, sep = "_")
}

encode_row_read_format <- function(row, format) {
    if (!is.null(format)) {
        return(format)
    }
    if ("file_format" %in% names(row) && !is.na(row$file_format[[1L]]) && nzchar(row$file_format[[1L]])) {
        file_format <- row$file_format[[1L]]
        indexed_or_binary <- tolower(file_format) %in% c(
            "bigbed", "bb", "bigwig", "bw", "bam", "cram", "sam", "fastq", "fq"
        )
        if (isTRUE(indexed_or_binary)) {
            return(file_format)
        }
    }
    if ("file_type" %in% names(row) && !is.na(row$file_type[[1L]]) && nzchar(row$file_type[[1L]])) {
        file_type <- tolower(row$file_type[[1L]])
        if (grepl("narrowpeak", file_type)) {
            return("narrowPeak")
        }
        if (grepl("broadpeak", file_type)) {
            return("broadPeak")
        }
    }
    if ("file_format" %in% names(row) && !is.na(row$file_format[[1L]]) && nzchar(row$file_format[[1L]])) {
        return(row$file_format[[1L]])
    }
    NULL
}

# Expression-matrix assembly

encode_tabular_matrices <- function(data, files, values = "raw_counts") {
    values <- encode_normalize_matrix_values(values)
    tabular <- vapply(data, is.data.frame, logical(1L))
    if (!any(tabular)) {
        return(encode_empty_matrix_list())
    }
    data <- data[tabular]
    files <- files[tabular, , drop = FALSE]
    if (length(data) == 0L) {
        return(encode_empty_matrix_list())
    }
    if (any(vapply(data, encode_is_interval_table, logical(1L)))) {
        return(encode_empty_matrix_list())
    }
    conflicts <- encode_matrix_metadata_conflicts(files)
    if (length(conflicts) > 0L) {
        return(encode_empty_matrix_list(paste0(
            "Files have incompatible metadata: ",
            paste(conflicts, collapse = ", "),
            "."
        )))
    }
    feature <- encode_common_feature_column(data)
    if (is.na(feature)) {
        return(encode_empty_matrix_list(
            "Tables do not share one complete, unique feature identifier."
        ))
    }
    numeric_columns <- Reduce(
        intersect,
        lapply(data, function(x) names(x)[vapply(x, is.numeric, logical(1L))])
    )
    numeric_columns <- setdiff(numeric_columns, feature)
    available <- stats::setNames(numeric_columns, tolower(numeric_columns))
    supported <- c("raw_counts", "tpm", "fpkm", "rpkm")
    selected <- intersect(values %||% supported, names(available))
    if (length(selected) == 0L) {
        return(encode_empty_matrix_list())
    }
    features <- encode_matrix_features(data, feature)
    if (is.null(features)) {
        return(encode_empty_matrix_list(
            "Tables contain different feature sets and were not combined."
        ))
    }
    matrices <- vector("list", length(selected))
    names(matrices) <- selected
    for (i in seq_along(selected)) {
        matrices[[i]] <- encode_merge_numeric_column(
            data = data,
            files = files,
            feature = feature,
            value = available[[selected[[i]]]],
            features = features
        )
    }
    attr(matrices, "row_data") <- encode_matrix_row_data(data, feature, features)
    class(matrices) <- c("encode_matrix_list", "list")
    matrices
}

encode_empty_matrix_list <- function(reason = NULL) {
    structure(
        list(),
        row_data = data.frame(),
        reason = reason,
        class = c("encode_matrix_list", "list")
    )
}

encode_matrix_metadata_conflicts <- function(files) {
    fields <- intersect(
        c("organism", "assembly", "output_type", "genome_annotation"),
        names(files)
    )
    fields[vapply(fields, function(field) {
        values <- tolower(trimws(as.character(files[[field]])))
        values <- unique(values[!is.na(values) & nzchar(values)])
        length(values) > 1L
    }, logical(1L))]
}

encode_normalize_matrix_values <- function(values) {
    if (is.null(values)) {
        return(NULL)
    }
    if (!is.character(values)) {
        cli::cli_abort("{.arg values} must be a character vector.")
    }
    values <- unique(tolower(values[!is.na(values) & nzchar(values)]))
    if (length(values) == 0L || "all" %in% values) {
        return(NULL)
    }
    supported <- c("raw_counts", "tpm", "fpkm", "rpkm")
    invalid <- setdiff(values, supported)
    if (length(invalid) > 0L) {
        cli::cli_abort(
            "{.arg values} must contain supported values: {.val {paste(supported, collapse = ', ')}}."
        )
    }
    values
}

encode_is_interval_table <- function(x) {
    all(c("chrom", "start", "end") %in% names(x))
}

# Require one complete, unique feature key shared by every table.
encode_common_feature_column <- function(data) {
    candidates <- c(
        "gene_symbol", "ensembl_id", "entrez_id", "gene_id", "gene_name", "gene", "transcript_id", "transcript_name",
        "id", "name"
    )
    common <- Reduce(intersect, lapply(data, names))
    found <- candidates[candidates %in% common]
    if (length(found) == 0L) {
        return(NA_character_)
    }
    for (candidate in found) {
        unique_in_each_table <- vapply(
            data,
            function(x) {
                values <- x[[candidate]]
                complete <- !is.na(values) & nzchar(as.character(values))
                all(complete) && !any(duplicated(values[complete]))
            },
            logical(1L)
        )
        if (all(unique_in_each_table)) {
            return(candidate)
        }
    }
    NA_character_
}

encode_matrix_features <- function(data, feature) {
    features <- as.character(data[[1L]][[feature]])
    compatible <- vapply(data[-1L], function(x) {
        setequal(features, as.character(x[[feature]]))
    }, logical(1L))
    if (!all(compatible)) {
        return(NULL)
    }
    features
}

encode_merge_numeric_column <- function(data, files, feature, value, features) {
    labels <- encode_loaded_file_names(files)
    merged <- matrix(
        NA_real_,
        nrow = length(features),
        ncol = length(data),
        dimnames = list(features, labels)
    )
    for (i in seq_along(data)) {
        index <- match(features, as.character(data[[i]][[feature]]))
        merged[, i] <- as.numeric(data[[i]][[value]][index])
    }
    merged
}

encode_matrix_row_data <- function(data, feature, features) {
    annotation <- encode_feature_annotation(data, feature)
    if (is.null(annotation)) {
        annotation <- data.frame(features, stringsAsFactors = FALSE)
        names(annotation) <- feature
    } else {
        annotation <- annotation[
            match(features, as.character(annotation[[feature]])), ,
            drop = FALSE
        ]
        annotation[[feature]] <- features
    }
    row.names(annotation) <- make.unique(features)
    annotation
}

encode_set_assay_row_names <- function(matrices, row_data, row_names) {
    if (!is.data.frame(row_data) || nrow(row_data) == 0L) {
        return(list(matrices = matrices, row_data = row_data))
    }
    labels <- row.names(row_data)
    if (identical(row_names, "none")) {
        labels <- NULL
        row.names(row_data) <- NULL
    } else if (row_names %in% names(row_data)) {
        requested <- as.character(row_data[[row_names]])
        missing <- is.na(requested) | !nzchar(requested)
        requested[missing] <- labels[missing]
        labels <- make.unique(requested)
        row.names(row_data) <- labels
    }
    matrices[] <- lapply(matrices, function(x) {
        row.names(x) <- labels
        x
    })
    list(matrices = matrices, row_data = row_data)
}

encode_feature_annotation <- function(data, feature) {
    annotations <- c("gene_symbol", "ensembl_id", "entrez_id", "gene_name", "transcript_name")
    annotations <- setdiff(annotations, feature)
    common <- Reduce(intersect, lapply(data, names))
    annotations <- annotations[annotations %in% common]
    if (length(annotations) == 0L) {
        return(NULL)
    }
    features <- as.character(data[[1L]][[feature]])
    reference <- data[[1L]][, c(feature, annotations), drop = FALSE]
    consistent <- vapply(annotations, function(annotation) {
        reference_values <- as.character(reference[[annotation]])
        all(vapply(data[-1L], function(x) {
            index <- match(features, as.character(x[[feature]]))
            identical(reference_values, as.character(x[[annotation]][index]))
        }, logical(1L)))
    }, logical(1L))
    reference[, c(feature, annotations[consistent]), drop = FALSE]
}
