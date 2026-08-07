#' Extract the main table from an ENCODE result
#'
#' `encode_results()` returns the main table from an encodeUtils object. Use it
#' before filtering, joining, writing a CSV, or passing rows to another function.
#'
#' @param x An object returned by `encode_search()`, `encode_list_files()`,
#'   `encode_select_files()`, `encode_download()`, or `encode_read_all()`.
#'
#' @return A data frame. For `encode_search()` and `encode_list_files()` output,
#'   this is the record or file table. For `encode_select_files()`, it is the
#'   selected file table. For `encode_download()`, it is the download-result
#'   table. For `encode_read_all()` output, it is the loaded-file
#'   metadata table.
#' @export
#'
#' @examples
#' files <- data.frame(
#'     file_accession = "ENCFFONE",
#'     file_format = "tsv",
#'     output_type = "gene quantifications",
#'     assembly = "mm10",
#'     status = "released",
#'     href = "/files/ENCFFONE/@@@@download/a.tsv"
#' )
#'
#' selected <- encode_select_files(
#'     files,
#'     preset = "rnaseq_gene_quant",
#'     quiet = TRUE
#' )
#'
#' encode_results(selected)
encode_results <- function(x) {
    if (inherits(x, "encode_search_result")) {
        return(x$results)
    }
    if (inherits(x, "encode_selected_files")) {
        return(x$files)
    }
    if (inherits(x, "encode_loaded_files")) {
        return(x$metadata)
    }
    if (is.data.frame(x)) {
        return(x)
    }
    cli::cli_abort("{.arg x} does not contain a result table supported by {.fn encode_results}.")
}

# Result provenance accessors

#' Extract the ENCODE query URL from a result object
#'
#' @param x An object returned by `encode_search()`, `encode_list_files()`,
#'   `encode_select_files()`, or `encode_download()`.
#'
#' @return A single URL string, or `NA_character_` when no query URL is
#'   available.
#'
#' @noRd
encode_query_url <- function(x) {
    # Loaded collections carry request provenance on their metadata table.
    if (inherits(x, "encode_loaded_files")) {
        return(encode_query_url(x$metadata))
    }
    query_url <- attr(x, "query_url", exact = TRUE)
    if (!is.null(query_url)) {
        return(query_url)
    }
    url <- attr(x, "url", exact = TRUE)
    if (!is.null(url)) {
        return(url)
    }
    if (!is.data.frame(x) && is.list(x) && !is.null(x$query_url)) {
        return(x$query_url)
    }
    if (!is.data.frame(x) && is.list(x) && !is.null(x$url)) {
        return(x$url)
    }
    NA_character_
}

#' Extract ENCODE filters from a result object
#'
#' @param x An ENCODE result object or table with filter metadata.
#'
#' @return A data frame with filter fields and values, or an empty data frame.
#'
#' @noRd
encode_filters <- function(x) {
    # Collections keep the active filters on their file or metadata table.
    if (inherits(x, "encode_loaded_files")) {
        return(encode_filters(x$metadata))
    }
    if (inherits(x, "encode_selected_files")) {
        return(encode_filters(x$files))
    }
    if (is.list(x) && !is.null(x$filters)) {
        return(x$filters)
    }
    filters <- attr(x, "filters", exact = TRUE)
    if (!is.null(filters)) {
        return(filters)
    }
    data.frame(field = character(), value = character())
}

encode_request_history <- function(x) {
    if (inherits(x, "encode_loaded_files")) {
        return(encode_request_history(x$metadata))
    }
    if (inherits(x, "encode_selected_files")) {
        return(encode_request_history(x$files))
    }
    if (is.list(x) && !is.null(x$request_history)) {
        return(x$request_history)
    }
    attr(x, "request_history", exact = TRUE) %||% list()
}

encode_selection_criteria <- function(x) {
    if (inherits(x, "encode_loaded_files")) {
        return(encode_selection_criteria(x$metadata))
    }
    if (inherits(x, "encode_selected_files")) {
        return(x$criteria)
    }
    attr(x, "selection_criteria", exact = TRUE)
}
