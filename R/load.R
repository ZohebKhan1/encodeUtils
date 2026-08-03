# Loaded-file collection

encode_gene_annotation_cache <- new.env(parent = emptyenv())

encode_load_downloaded_files <- function(
    files,
    max_size = "100MB",
    format = NULL,
    region = NULL,
    allow_large = FALSE,
    unsupported = c("return_path", "error"),
    as = c("auto", "data.frame", "GRanges", "path"),
    row_names = c("gene_symbol", "ensembl_id", "entrez_id", "none"),
    matrix_values = "raw_counts",
    simplify_quant = TRUE,
    quiet = FALSE
) {
    unsupported <- match.arg(unsupported)
    as <- match.arg(as)
    row_names <- match.arg(row_names)
    matrix_values <- encode_normalize_matrix_values(matrix_values)
    files <- as.data.frame(files, stringsAsFactors = FALSE)
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
    if (isTRUE(simplify_quant)) {
        data <- encode_annotate_loaded_data(data, files)
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
    names <- encode_valid_object_names(names)
    names[duplicated(names)] <- paste0(names[duplicated(names)], "_", seq_len(sum(duplicated(names))))
    names
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

# Optional gene annotation

encode_annotate_loaded_data <- function(data, files) {
    if (length(data) == 0L) {
        return(data)
    }
    gene_ids <- lapply(data, function(x) {
        if (!is.data.frame(x)) {
            return(NULL)
        }
        encode_gene_identifier_input(x)
    })
    packages <- vapply(seq_along(data), function(i) {
        if (is.null(gene_ids[[i]])) {
            return(NA_character_)
        }
        encode_gene_annotation_package(files[i, , drop = FALSE])
    }, character(1L))

    # Keep the original table when an optional organism annotation is unavailable.
    for (package in unique(stats::na.omit(packages))) {
        indexes <- which(packages == package)
        requested <- unique(unlist(gene_ids[indexes], use.names = FALSE))
        requested <- requested[!is.na(requested) & nzchar(requested)]
        if (length(requested) == 0L) {
            next
        }
        annotation <- encode_gene_annotation_for_package(requested, package)
        if (is.null(annotation)) {
            next
        }
        row.names(annotation) <- annotation$input_id
        for (i in indexes) {
            data[[i]] <- encode_add_gene_annotation(
                data[[i]],
                annotation[gene_ids[[i]], c("gene_symbol", "ensembl_id", "entrez_id"), drop = FALSE]
            )
        }
    }
    data
}

encode_gene_identifier_input <- function(data) {
    if ("gene_id" %in% names(data)) {
        return(as.character(data$gene_id))
    }
    if ("ensembl_id" %in% names(data) || "entrez_id" %in% names(data)) {
        ensembl <- if ("ensembl_id" %in% names(data)) as.character(data$ensembl_id) else rep(NA_character_, nrow(data))
        entrez <- if ("entrez_id" %in% names(data)) as.character(data$entrez_id) else rep(NA_character_, nrow(data))
        id <- ifelse(!is.na(ensembl) & nzchar(ensembl), ensembl, entrez)
        if (all(is.na(id) | !nzchar(id))) {
            return(NULL)
        }
        return(id)
    }
    NULL
}

encode_add_gene_annotation <- function(data, annotation) {
    data <- as.data.frame(data, stringsAsFactors = FALSE)
    data$gene_symbol <- encode_coalesce_annotation_column(annotation$gene_symbol, data$gene_symbol)
    data$ensembl_id <- encode_coalesce_annotation_column(annotation$ensembl_id, data$ensembl_id)
    data$entrez_id <- encode_coalesce_annotation_column(annotation$entrez_id, data$entrez_id)
    identifiers <- c("gene_symbol", "ensembl_id", "entrez_id")
    other_names <- names(data)[!names(data) %in% identifiers]
    data[, c(identifiers, other_names), drop = FALSE]
}

encode_coalesce_annotation_column <- function(primary, fallback = NULL) {
    if (is.null(fallback)) {
        return(primary)
    }
    fallback <- as.character(fallback)
    missing <- is.na(primary) | !nzchar(primary)
    primary[missing] <- fallback[missing]
    primary
}

encode_gene_annotation_for_package <- function(gene_id, package) {
    gene_id <- as.character(gene_id)
    database <- encode_gene_annotation_database(package)
    if (is.null(database)) {
        return(NULL)
    }
    is_ensembl <- grepl("^ENS[A-Z]*G[0-9]+([.][0-9]+)?$", gene_id)
    is_entrez <- grepl("^[0-9]+$", gene_id)
    ensembl_keys <- sub("[.][0-9]+$", "", gene_id)
    annotation <- data.frame(
        input_id = gene_id,
        gene_symbol = rep(NA_character_, length(gene_id)),
        ensembl_id = ifelse(is_ensembl, gene_id, NA_character_),
        entrez_id = ifelse(is_entrez, gene_id, NA_character_),
        stringsAsFactors = FALSE
    )
    ensembl_lookup <- encode_gene_annotation_lookup(
        package = package,
        keytype = "ENSEMBL",
        keys = ensembl_keys[is_ensembl],
        columns = c("SYMBOL", "ENTREZID")
    )
    if (!is.null(ensembl_lookup)) {
        annotation$gene_symbol[is_ensembl] <- encode_lookup_gene_column(
            ensembl_lookup,
            keytype = "ENSEMBL",
            keys = ensembl_keys[is_ensembl],
            column = "SYMBOL"
        )
        annotation$entrez_id[is_ensembl] <- encode_lookup_gene_column(
            ensembl_lookup,
            keytype = "ENSEMBL",
            keys = ensembl_keys[is_ensembl],
            column = "ENTREZID"
        )
    }

    entrez_lookup <- encode_gene_annotation_lookup(
        package = package,
        keytype = "ENTREZID",
        keys = gene_id[is_entrez],
        columns = c("SYMBOL", "ENSEMBL")
    )
    if (!is.null(entrez_lookup)) {
        entrez_use <- is.na(annotation$gene_symbol) & is_entrez
        annotation$gene_symbol[entrez_use] <- encode_lookup_gene_column(
            entrez_lookup,
            keytype = "ENTREZID",
            keys = gene_id[entrez_use],
            column = "SYMBOL"
        )
        ensembl_use <- is.na(annotation$ensembl_id) & is_entrez
        annotation$ensembl_id[ensembl_use] <- encode_lookup_gene_column(
            entrez_lookup,
            keytype = "ENTREZID",
            keys = gene_id[ensembl_use],
            column = "ENSEMBL"
        )
    }
    unknown_gene <- !is_ensembl & !is_entrez
    annotation$gene_symbol[unknown_gene & is.na(annotation$gene_symbol)] <- gene_id[unknown_gene & is.na(annotation$gene_symbol)]
    if (all(is.na(annotation$gene_symbol)) && all(is.na(annotation$ensembl_id)) && all(is.na(annotation$entrez_id))) {
        return(NULL)
    }
    annotation
}

# Cache AnnotationDbi lookups and suppress incidental package output.
encode_gene_annotation_lookup <- function(package, keytype, keys, columns) {
    keys <- unique(keys[!is.na(keys) & nzchar(keys)])
    if (length(keys) == 0L) {
        return(NULL)
    }
    cache_key <- paste(package, keytype, paste(columns, collapse = ","), sep = "\r")
    cached <- get0(cache_key, envir = encode_gene_annotation_cache, inherits = FALSE)
    if (is.null(cached)) {
        cached <- data.frame(stringsAsFactors = FALSE)
    }
    cached_keys <- if (keytype %in% names(cached)) {
        cached[[keytype]]
    } else {
        character()
    }
    requested <- setdiff(keys, cached_keys)
    if (length(requested) > 0L) {
        database <- encode_gene_annotation_database(package)
        if (is.null(database)) {
            return(NULL)
        }
        selected <- tryCatch(
            withCallingHandlers(
                AnnotationDbi::select(
                    database,
                    keys = requested,
                    keytype = keytype,
                    columns = columns
                ),
                warning = function(cnd) {
                    invokeRestart("muffleWarning")
                },
                message = function(cnd) {
                    invokeRestart("muffleMessage")
                }
            ),
            error = function(cnd) {
                NULL
            }
        )
        if (!is.null(selected) && nrow(selected) > 0L) {
            selected <- as.data.frame(selected, stringsAsFactors = FALSE)
            selected <- selected[!is.na(selected[[keytype]]) & nzchar(selected[[keytype]]), , drop = FALSE]
            selected <- selected[!duplicated(selected[[keytype]]), , drop = FALSE]
            cached <- rbind(cached, selected)
            cached <- cached[!duplicated(cached[[keytype]]), , drop = FALSE]
            assign(cache_key, cached, envir = encode_gene_annotation_cache)
        }
    }
    if (nrow(cached) == 0L || !keytype %in% names(cached)) {
        return(NULL)
    }
    cached[match(keys, cached[[keytype]]), , drop = FALSE]
}

encode_lookup_gene_column <- function(lookup, keytype, keys, column) {
    out <- rep(NA_character_, length(keys))
    if (is.null(lookup) || !column %in% names(lookup)) {
        return(out)
    }
    index <- match(keys, lookup[[keytype]])
    found <- !is.na(index)
    out[found] <- as.character(lookup[[column]][index[found]])
    out
}

encode_gene_annotation_database <- function(package) {
    if (!requireNamespace(package, quietly = TRUE)) {
        return(NULL)
    }
    namespace <- asNamespace(package)
    switch(package,
        "org.Mm.eg.db" = get("org.Mm.eg.db", envir = namespace),
        "org.Hs.eg.db" = get("org.Hs.eg.db", envir = namespace),
        NULL
    )
}

encode_gene_annotation_package <- function(file) {
    organism <- if ("organism" %in% names(file)) {
        tolower(as.character(file$organism[[1L]]))
    } else {
        NA_character_
    }
    assembly <- if ("assembly" %in% names(file)) {
        tolower(as.character(file$assembly[[1L]]))
    } else {
        NA_character_
    }
    if (!is.na(organism) && grepl("mus musculus|mouse", organism)) {
        return("org.Mm.eg.db")
    }
    if (!is.na(organism) && grepl("homo sapiens|human", organism)) {
        return("org.Hs.eg.db")
    }
    if (!is.na(assembly) && grepl("^mm", assembly)) {
        return("org.Mm.eg.db")
    }
    if (!is.na(assembly) && grepl("^hg|^grch", assembly)) {
        return("org.Hs.eg.db")
    }
    NA_character_
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
    feature <- encode_common_feature_column(data)
    if (is.na(feature)) {
        return(encode_empty_matrix_list())
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

encode_empty_matrix_list <- function() {
    structure(
        list(),
        row_data = data.frame(),
        class = c("encode_matrix_list", "list")
    )
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
    features <- unique(unlist(
        lapply(data, function(x) as.character(x[[feature]])),
        use.names = FALSE
    ))
    features[!is.na(features) & nzchar(features)]
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
    annotation <- do.call(
        rbind,
        lapply(data, function(x) x[, c(feature, annotations), drop = FALSE])
    )
    annotation <- annotation[stats::complete.cases(annotation[, feature, drop = FALSE]), , drop = FALSE]
    annotation <- annotation[!duplicated(annotation[[feature]]), , drop = FALSE]
    annotation
}
