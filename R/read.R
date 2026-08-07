#' Read one local ENCODE file
#'
#' Read one local file without quantification-table simplification or matrix
#' assembly. Tabular files are returned as stored. Large or unsupported formats
#' return a path object by default.
#'
#' @param path One local file path.
#' @param format Optional format override.
#' @param max_size Maximum uncompressed size to read into memory, as bytes or a
#'   string. Use `NULL` for no cap. Compressed text is scanned before import.
#' @param region Optional genomic range passed to `rtracklayer::import()` as
#'   `which` for indexed genomic formats.
#' @param allow_large Whether to import a complete BigWig or BigBed without a
#'   region.
#' @param unsupported Use `"return_path"` to return an `encode_local_file`
#'   object for unsupported input, or `"error"` to fail.
#' @param as Return form for BED-like input: `"auto"`, `"data.frame"`,
#'   `"GRanges"`, or `"path"`.
#' @param ... Additional arguments passed to tabular or rtracklayer readers.
#'
#' @return The native object for one file. TSV and CSV files return data frames;
#'   JSON returns a list; genomic formats use Bioconductor readers when
#'   available; and unsupported or intentionally deferred formats return an
#'   `encode_local_file` object by default.
#' @export
#'
#' @examples
#' path <- tempfile(fileext = ".tsv")
#' writeLines(c("gene_id\texpected_count", "Gata4\t10"), path)
#' encode_read(path)
encode_read <- function(
    path,
    format = NULL,
    max_size = "100MB",
    region = NULL,
    allow_large = FALSE,
    unsupported = c("return_path", "error"),
    as = c("auto", "data.frame", "GRanges", "path"),
    ...
) {
    path <- encode_read_path(path)
    format <- encode_validate_scalar(format, "format")
    allow_large <- encode_validate_flag(allow_large, "allow_large")
    unsupported <- match.arg(unsupported)
    as <- match.arg(as)
    if (!file.exists(path)) {
        cli::cli_abort("File does not exist: {.path {path}}.")
    }
    if (identical(as, "path")) {
        return(encode_unsupported_local_file(
            path, "path return requested", "return_path"
        ))
    }

    format <- tolower(format %||% encode_get_extension(path))
    if (!is.null(max_size)) {
        max_size <- encode_parse_size(max_size, arg = "max_size")
    }
    region_bounded <- !is.null(region) &&
        format %in% c("bw", "bigwig", "bb", "bigbed")
    if (!region_bounded && encode_input_exceeds_max_size(path, max_size)) {
        compressed <- grepl("[.](gz|bgz)$", path, ignore.case = TRUE)
        reason <- if (compressed) {
            "file exceeds max_size after decompression"
        } else {
            "file exceeds max_size"
        }
        return(encode_unsupported_local_file(path, reason, unsupported))
    }

    if (format %in% c("tsv", "txt")) {
        return(utils::read.delim(
            path,
            stringsAsFactors = FALSE,
            check.names = FALSE,
            ...
        ))
    }
    if (identical(format, "csv")) {
        return(utils::read.csv(
            path,
            stringsAsFactors = FALSE,
            check.names = FALSE,
            ...
        ))
    }
    if (identical(format, "json")) {
        return(jsonlite::fromJSON(path, simplifyVector = FALSE))
    }
    if (format %in% c("bed", "narrowpeak", "broadpeak")) {
        return(encode_read_bed(path, format, as, unsupported))
    }
    if (format %in% c("gff", "gtf")) {
        return(encode_read_gff(path, format, unsupported, region, ...))
    }
    if (format %in% c("bw", "bigwig", "bb", "bigbed")) {
        if (is.null(region) && !allow_large) {
            return(encode_unsupported_local_file(
                path,
                "indexed signal and annotation files require region or allow_large = TRUE",
                unsupported
            ))
        }
        return(encode_read_with_optional_package(
            "rtracklayer",
            "import",
            path,
            unsupported,
            "rtracklayer is required for indexed genomic imports",
            region = region,
            ...
        ))
    }
    if (format %in% c("fa", "fasta")) {
        return(encode_read_with_optional_package(
            "Biostrings",
            "readDNAStringSet",
            path,
            unsupported,
            "Biostrings is required for FASTA imports"
        ))
    }
    if (format %in% c("fq", "fastq")) {
        return(encode_unsupported_local_file(
            path,
            "FASTQ files are returned as paths; use a sequence-processing tool",
            unsupported
        ))
    }
    if (format %in% c("bam", "cram", "sam")) {
        return(encode_unsupported_local_file(
            path,
            "alignment files are returned as paths; use a region-aware alignment reader",
            unsupported
        ))
    }
    encode_unsupported_local_file(
        path,
        paste0("unsupported file format: ", format),
        unsupported
    )
}

#' Read all files in a completed download table
#'
#' Read each `local_path` with `encode_read()` and retain the file metadata.
#' No tables are simplified or combined automatically.
#'
#' @param files A file table with a `local_path` column.
#' @inheritParams encode_read
#' @param quiet If `FALSE`, print concise progress messages.
#'
#' @return An `encode_loaded_files` list with `metadata` and `data` components.
#' @export
#'
#' @examples
#' path <- tempfile(fileext = ".tsv")
#' writeLines(c("gene_id\tvalue", "Gata4\t10"), path)
#' files <- data.frame(
#'     file_accession = "ENCFFLOCAL1",
#'     file_format = "tsv",
#'     local_path = path
#' )
#' encode_read_all(files, quiet = TRUE)
encode_read_all <- function(
    files,
    max_size = "100MB",
    region = NULL,
    allow_large = FALSE,
    unsupported = c("return_path", "error"),
    as = c("auto", "data.frame", "GRanges", "path"),
    quiet = FALSE,
    ...
) {
    unsupported <- match.arg(unsupported)
    as <- match.arg(as)
    quiet <- encode_validate_flag(quiet, "quiet")
    files <- encode_file_table_from_input(files)
    query_url <- encode_query_url(files)
    retrieved_at <- attr(files, "retrieved_at", exact = TRUE)
    filters <- encode_filters(files)
    request_history <- encode_request_history(files)
    selection_criteria <- encode_selection_criteria(files)
    base_url <- attr(files, "encode_base_url", exact = TRUE) %||%
        encode_base_url()
    files <- as.data.frame(files, stringsAsFactors = FALSE)
    if (!"local_path" %in% names(files)) {
        cli::cli_abort("{.arg files} must include {.field local_path}.")
    }
    if ("download_status" %in% names(files)) {
        readable <- files$download_status %in% c("downloaded", "exists")
        if (!all(readable)) {
            cli::cli_abort("Cannot read failed or unplanned download rows.")
        }
    }
    files <- encode_attach_metadata(
        files,
        query_url = query_url,
        retrieved_at = retrieved_at,
        filters = filters,
        base_url = base_url,
        request_history = request_history,
        selection_criteria = selection_criteria
    )
    names <- encode_loaded_file_names(files)
    data <- lapply(seq_len(nrow(files)), function(i) {
        if (!quiet) {
            cli::cli_inform(
                "Reading ({i}/{nrow(files)}) {.val {names[[i]]}}."
            )
        }
        encode_read(
            files$local_path[[i]],
            format = encode_row_read_format(files[i, , drop = FALSE]),
            max_size = max_size,
            region = region,
            allow_large = allow_large,
            unsupported = unsupported,
            as = as,
            ...
        )
    })
    names(data) <- names
    result <- list(metadata = files, data = data)
    class(result) <- c("encode_loaded_files", "list")
    result
}

#' Prepare quantification tables explicitly
#'
#' Add common `gene_id` and `raw_counts` names to recognized HTSeq,
#' featureCounts, and ENCODE quantification tables. Existing columns are kept.
#' HTSeq summary rows beginning with `N_` or `__` are removed.
#'
#' @param x A data frame or an `encode_loaded_files` object.
#'
#' @return The same type as `x`, with recognized quantification tables prepared.
#' @export
#'
#' @examples
#' table <- data.frame(gene_id = "Gata4", expected_count = 10)
#' encode_prepare_quant(table)
encode_prepare_quant <- function(x) {
    if (inherits(x, "encode_loaded_files")) {
        x$data <- lapply(x$data, function(value) {
            if (is.data.frame(value)) encode_prepare_quant(value) else value
        })
        return(x)
    }
    if (!is.data.frame(x)) {
        cli::cli_abort("{.arg x} must be a data frame or loaded-file object.")
    }
    table <- as.data.frame(x, stringsAsFactors = FALSE)
    generic_names <- identical(names(table), paste0("V", seq_len(ncol(table))))
    if (generic_names && ncol(table) %in% c(2L, 4L)) {
        names(table)[seq_len(ncol(table))] <- c(
            "gene_id", "raw_counts", "stranded_first", "stranded_second"
        )[seq_len(ncol(table))]
    }
    if ("Geneid" %in% names(table) && !"gene_id" %in% names(table)) {
        names(table)[names(table) == "Geneid"] <- "gene_id"
    }
    canonical <- c(tpm = "TPM", fpkm = "FPKM", rpkm = "RPKM")
    lower_names <- tolower(names(table))
    for (source in names(canonical)) {
        target <- canonical[[source]]
        index <- which(lower_names == source)
        if (length(index) == 1L && !target %in% names(table)) {
            names(table)[index] <- target
        }
    }
    if (!"raw_counts" %in% names(table)) {
        count_source <- intersect(
            c("expected_count", "counts", "count"),
            names(table)
        )
        if (length(count_source) > 0L) {
            table$raw_counts <- table[[count_source[[1L]]]]
        } else if ("gene_id" %in% names(table) &&
            all(c("Chr", "Start", "End", "Strand", "Length") %in%
                names(table))) {
            annotation <- c(
                "gene_id", "Chr", "Start", "End", "Strand", "Length"
            )
            count_columns <- setdiff(names(table), annotation)
            numeric_counts <- count_columns[vapply(
                table[count_columns], is.numeric, logical(1L)
            )]
            if (length(numeric_counts) == 1L) {
                table$raw_counts <- table[[numeric_counts[[1L]]]]
            }
        }
    }
    if ("gene_id" %in% names(table)) {
        summary_row <- grepl("^(N_|__)", as.character(table$gene_id))
        summary_row[is.na(summary_row)] <- FALSE
        table <- table[!summary_row, , drop = FALSE]
    }
    table
}

#' Convert prepared quantification tables to a SummarizedExperiment
#'
#' @param x An `encode_loaded_files` object containing data frames.
#' @param feature_id Complete, unique feature identifier column shared by every
#'   table.
#' @param assays Numeric column names to combine into assays.
#'
#' @return A `SummarizedExperiment` with file metadata in `colData()` and query
#'   provenance in `metadata()`.
#' @export
#'
#' @examples
#' path <- tempfile(fileext = ".tsv")
#' writeLines(c("gene_id\texpected_count", "Gata4\t10"), path)
#' files <- data.frame(
#'     file_accession = "ENCFFLOCAL1",
#'     file_format = "tsv",
#'     local_path = path
#' )
#' loaded <- encode_prepare_quant(encode_read_all(files, quiet = TRUE))
#' encode_as_summarized_experiment(loaded)
encode_as_summarized_experiment <- function(
    x,
    feature_id = "gene_id",
    assays = "raw_counts"
) {
    if (!inherits(x, "encode_loaded_files")) {
        cli::cli_abort("{.arg x} must come from {.fun encode_read_all}.")
    }
    feature_id <- encode_validate_scalar(feature_id, "feature_id", allow_null = FALSE)
    assays <- encode_validate_values(assays, "assays", allow_null = FALSE)
    if (length(x$data) == 0L || !all(vapply(x$data, is.data.frame, logical(1L)))) {
        cli::cli_abort("Every loaded object must be a data frame.")
    }
    conflicts <- encode_matrix_metadata_conflicts(x$metadata)
    if (length(conflicts) > 0L) {
        cli::cli_abort(
            "File metadata differ across {.field {paste(conflicts, collapse = ', ')}}."
        )
    }
    for (i in seq_along(x$data)) {
        table <- x$data[[i]]
        missing <- setdiff(c(feature_id, assays), names(table))
        if (length(missing) > 0L) {
            cli::cli_abort(
                "Table {.val {names(x$data)[[i]]}} lacks {.field {paste(missing, collapse = ', ')}}."
            )
        }
        features <- as.character(table[[feature_id]])
        if (anyNA(features) || any(!nzchar(features)) || anyDuplicated(features)) {
            cli::cli_abort(
                "{.field {feature_id}} must be complete and unique in every table."
            )
        }
        if (!all(vapply(table[assays], is.numeric, logical(1L)))) {
            cli::cli_abort("Every requested assay column must be numeric.")
        }
    }
    features <- as.character(x$data[[1L]][[feature_id]])
    if (!all(vapply(x$data[-1L], function(table) {
        setequal(features, as.character(table[[feature_id]]))
    }, logical(1L)))) {
        cli::cli_abort("Quantification tables do not contain the same feature set.")
    }
    labels <- encode_loaded_file_names(x$metadata)
    assay_list <- lapply(assays, function(assay) {
        values <- unlist(lapply(x$data, function(table) {
            table[[assay]][match(features, as.character(table[[feature_id]]))]
        }), use.names = FALSE)
        base::matrix(
            values,
            nrow = length(features),
            ncol = length(x$data),
            dimnames = list(features, labels)
        )
    })
    names(assay_list) <- assays
    row_data <- data.frame(features, stringsAsFactors = FALSE)
    names(row_data) <- feature_id
    row.names(row_data) <- features
    col_data <- as.data.frame(x$metadata, stringsAsFactors = FALSE)
    row.names(col_data) <- labels
    provenance <- list(
        query_url = encode_query_url(x),
        retrieved_at = attr(x$metadata, "retrieved_at", exact = TRUE),
        filters = encode_filters(x),
        requests = encode_request_history(x),
        selection_criteria = encode_selection_criteria(x)
    )
    SummarizedExperiment::SummarizedExperiment(
        assays = assay_list,
        rowData = S4Vectors::DataFrame(row_data),
        colData = S4Vectors::DataFrame(col_data),
        metadata = list(encodeUtils = provenance)
    )
}

encode_read_lines <- function(path, n) {
    connection <- if (grepl("[.](gz|bgz)$", path, ignore.case = TRUE)) {
        gzfile(path, open = "rt")
    } else {
        file(path, open = "rt")
    }
    on.exit(close(connection), add = TRUE)
    readLines(connection, n = n, warn = FALSE)
}

encode_input_exceeds_max_size <- function(path, max_size) {
    if (is.null(max_size)) {
        return(FALSE)
    }
    if (!grepl("[.](gz|bgz)$", path, ignore.case = TRUE)) {
        size <- as.numeric(file.info(path)$size)
        return(!is.na(size) && size > max_size)
    }
    connection <- gzfile(path, open = "rb")
    on.exit(close(connection), add = TRUE)
    total <- 0
    repeat {
        chunk <- readBin(connection, what = "raw", n = 1024L * 1024L)
        total <- total + length(chunk)
        if (total > max_size) {
            return(TRUE)
        }
        if (length(chunk) == 0L) {
            return(FALSE)
        }
    }
}

encode_read_gff <- function(path, format, unsupported, region = NULL, ...) {
    first_lines <- encode_read_lines(path, 50L)
    import_path <- path
    if (any(encode_is_ucsc_directive(first_lines))) {
        import_path <- encode_gff_without_ucsc_directives(path, format)
        on.exit(unlink(import_path), add = TRUE)
    }
    encode_read_with_optional_package(
        "rtracklayer",
        "import",
        import_path,
        unsupported,
        "rtracklayer is required for GFF and GTF imports",
        source_path = path,
        region = region,
        ...
    )
}

encode_gff_without_ucsc_directives <- function(path, format) {
    input <- if (grepl("[.](gz|bgz)$", path, ignore.case = TRUE)) {
        gzfile(path, open = "rt")
    } else {
        file(path, open = "rt")
    }
    output_path <- tempfile(fileext = paste0(".", tolower(format)))
    output <- file(output_path, open = "wt")
    on.exit({
        try(close(input), silent = TRUE)
        try(close(output), silent = TRUE)
    }, add = TRUE)
    repeat {
        lines <- readLines(input, n = 10000L, warn = FALSE)
        if (length(lines) == 0L) break
        writeLines(lines[!encode_is_ucsc_directive(lines)], output)
    }
    close(input)
    close(output)
    output_path
}

encode_is_ucsc_directive <- function(lines) {
    grepl("^[[:space:]]*(track|browser)([[:space:]]|$)", lines)
}

encode_read_bed <- function(
    path,
    format = "bed",
    as = "auto",
    unsupported = "return_path"
) {
    if (identical(as, "data.frame")) {
        return(encode_read_bed_table(path, format))
    }
    imported <- if (requireNamespace("rtracklayer", quietly = TRUE)) {
        try(rtracklayer::import(path, format = "BED"), silent = TRUE)
    } else {
        structure("rtracklayer is not installed", class = "try-error")
    }
    if (!inherits(imported, "try-error")) {
        return(imported)
    }
    table <- encode_read_bed_table(path, format)
    tryCatch(
        encode_bed_table_to_granges(table),
        error = function(cnd) {
            if (identical(as, "GRanges") || identical(unsupported, "error")) {
                cli::cli_abort(
                    c(
                        "Failed to convert BED-like file to GRanges.",
                        "x" = conditionMessage(cnd)
                    )
                )
            }
            table
        }
    )
}

encode_bed_table_to_granges <- function(table) {
    start <- encode_as_integer_no_warning(table$start) + 1L
    end <- encode_as_integer_no_warning(table$end)
    if (anyNA(start) || anyNA(end) || any(end < start)) {
        cli::cli_abort("BED-like start and end columns must define valid ranges.")
    }
    strand <- rep("*", nrow(table))
    if ("strand" %in% names(table)) {
        observed <- as.character(table$strand)
        valid <- observed %in% c("+", "-", "*")
        strand[valid] <- observed[valid]
    }
    metadata <- table[
        ,
        setdiff(names(table), c("chrom", "start", "end", "strand")),
        drop = FALSE
    ]
    do.call(
        GenomicRanges::GRanges,
        c(
            list(
                seqnames = as.character(table$chrom),
                ranges = IRanges::IRanges(start = start, end = end),
                strand = strand
            ),
            as.list(metadata)
        )
    )
}

encode_as_integer_no_warning <- function(x) {
    withCallingHandlers(
        as.integer(x),
        warning = function(cnd) invokeRestart("muffleWarning")
    )
}

encode_read_bed_table <- function(path, format = "bed") {
    table <- utils::read.delim(
        path,
        header = FALSE,
        stringsAsFactors = FALSE,
        check.names = FALSE,
        comment.char = "#"
    )
    columns <- switch(tolower(format),
        narrowpeak = c(
            "chrom", "start", "end", "name", "score", "strand",
            "signal_value", "p_value", "q_value", "peak"
        ),
        broadpeak = c(
            "chrom", "start", "end", "name", "score", "strand",
            "signal_value", "p_value", "q_value"
        ),
        c("chrom", "start", "end", "name", "score", "strand")
    )
    known <- min(length(columns), ncol(table))
    extras <- ncol(table) - known
    names(table) <- c(
        columns[seq_len(known)],
        if (extras > 0L) paste0("extra_", seq_len(extras))
    )
    table
}

encode_read_path <- function(path) {
    if (!is.character(path) || length(path) != 1L || is.na(path) ||
        !nzchar(path)) {
        cli::cli_abort("{.arg path} must be one local file path.")
    }
    path
}

encode_read_with_optional_package <- function(
    package,
    fun,
    path,
    unsupported,
    reason,
    source_path = path,
    region = NULL,
    ...
) {
    if (!requireNamespace(package, quietly = TRUE)) {
        return(encode_unsupported_local_file(
            source_path, reason, unsupported
        ))
    }
    reader <- getExportedValue(package, fun)
    value <- tryCatch(
        if (is.null(region)) reader(path, ...) else reader(path, which = region, ...),
        error = identity
    )
    if (inherits(value, "error")) {
        return(encode_unsupported_local_file(
            source_path,
            paste0(package, "::", fun, "() failed: ", conditionMessage(value)),
            unsupported
        ))
    }
    value
}

encode_unsupported_local_file <- function(path, reason, unsupported) {
    if (identical(unsupported, "error")) {
        cli::cli_abort(reason)
    }
    size <- as.numeric(file.info(path)$size)
    result <- list(
        path = path,
        reason = reason,
        file_size = size,
        file_size_pretty = encode_pretty_bytes(size)
    )
    class(result) <- c("encode_local_file", "list")
    result
}

encode_loaded_file_names <- function(files) {
    labels <- if ("file_accession" %in% names(files)) {
        files$file_accession
    } else if ("accession" %in% names(files)) {
        files$accession
    } else {
        tools::file_path_sans_ext(basename(files$local_path))
    }
    labels <- as.character(labels)
    labels[is.na(labels) | !nzchar(labels)] <- "encode_file"
    make.unique(labels)
}

encode_row_read_format <- function(row) {
    if ("file_type" %in% names(row)) {
        type <- tolower(as.character(row$file_type[[1L]]))
        if (!is.na(type) && grepl("narrowpeak", type)) return("narrowPeak")
        if (!is.na(type) && grepl("broadpeak", type)) return("broadPeak")
    }
    if ("file_format" %in% names(row)) {
        format <- as.character(row$file_format[[1L]])
        if (!is.na(format) && nzchar(format)) return(format)
    }
    NULL
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
