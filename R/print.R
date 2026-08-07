# S3 print methods

#' @export
print.encode_search_result <- function(x, ..., verbose = FALSE) {
    cli::cli_text("ENCODE search: {nrow(x$results)} of {x$total} match(es)")
    encode_print_head(x$results)
    if (verbose) {
        encode_print_head(x$filters, label = "Filters")
        encode_print_head(
            x$facets[order(x$facets$count, decreasing = TRUE), , drop = FALSE],
            label = "Facets"
        )
        cli::cli_text("URL: {x$query_url}")
    }
    invisible(x)
}

#' @export
print.encode_file_table <- function(x, ..., verbose = FALSE) {
    cli::cli_text("ENCODE files: {nrow(x)}")
    columns <- if (inherits(x, "encode_download_result")) {
        c(
            "file_accession", "file_format", "output_type", "file_size_pretty",
            "download_status", "size_verified", "md5_verified", "local_path"
        )
    } else {
        c(
            "file_accession", "experiment_accession", "file_format",
            "output_type", "assembly", "file_size_pretty", "status"
        )
    }
    encode_print_head(x, columns = columns)
    if (verbose) {
        cli::cli_text("Known total size: {encode_pretty_bytes(encode_size(x))}")
    }
    invisible(x)
}

#' @export
print.encode_selected_files <- function(x, ..., verbose = FALSE) {
    cli::cli_text(
        "ENCODE selected files: {nrow(x$files)} selected, {nrow(x$excluded)} excluded"
    )
    encode_print_head(x$files)
    if (verbose) encode_print_head(encode_filter_table(x$criteria), "Criteria")
    invisible(x)
}

#' @export
print.encode_loaded_files <- function(x, ..., verbose = FALSE) {
    cli::cli_text(
        "ENCODE loaded files: {length(x$data)} object(s) from {nrow(x$metadata)} file(s)"
    )
    encode_print_head(x$metadata)
    if (verbose && length(x$data) > 0L) {
        objects <- data.frame(
            name = names(x$data),
            class = vapply(
                x$data,
                function(value) paste(class(value), collapse = ", "),
                character(1L)
            )
        )
        encode_print_head(objects, "Objects")
    }
    invisible(x)
}

#' @export
print.encode_manifest <- function(x, ..., verbose = FALSE) {
    cli::cli_text(
        "ENCODE manifest: {x$object_type}, created {x$retrieval$created_at}"
    )
    path <- attr(x, "path", exact = TRUE)
    if (!is.null(path)) cli::cli_text("Path: {.path {path}}")
    if (verbose) cli::cli_text("URL: {x$retrieval$query_url}")
    invisible(x)
}

#' @export
print.encode_local_file <- function(x, ...) {
    cli::cli_text("ENCODE local path: {.path {x$path}}")
    cli::cli_text("Reason: {x$reason}")
    invisible(x)
}

#' @export
`[.encode_file_table` <- function(x, i, j, drop = FALSE) {
    provenance <- lapply(
        c(
            "query_url", "retrieved_at", "filters", "encode_base_url",
            "request_history", "selection_criteria", "total"
        ),
        function(name) attr(x, name, exact = TRUE)
    )
    names(provenance) <- c(
        "query_url", "retrieved_at", "filters", "encode_base_url",
        "request_history", "selection_criteria", "total"
    )
    out <- NextMethod("[")
    if (!is.data.frame(out)) return(out)
    for (name in names(provenance)) {
        if (!is.null(provenance[[name]])) attr(out, name) <- provenance[[name]]
    }
    if (!missing(j) && !all(encode_file_core_columns() %in% names(out))) {
        class(out) <- setdiff(class(out), "encode_file_table")
    }
    out
}

encode_file_core_columns <- function() {
    c("file_accession", "file_format", "output_type")
}

encode_print_head <- function(x, label = NULL, columns = NULL, n = 10L) {
    if (!is.null(label)) cli::cli_text("{label}:")
    if (is.null(x) || NROW(x) == 0L) {
        cli::cli_text("No rows.")
        return(invisible(NULL))
    }
    table <- as.data.frame(x, stringsAsFactors = FALSE)
    if (!is.null(columns)) {
        columns <- intersect(columns, names(table))
        if (length(columns) > 0L) table <- table[columns]
    }
    print(utils::head(table, n), row.names = FALSE)
    invisible(NULL)
}
