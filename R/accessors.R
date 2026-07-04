#' Extract the main table from an ENCODE result
#'
#' `encode_results()` returns the main data frame from an ENCODE result object.
#' Use it before filtering, joining, writing a CSV, or passing rows to another
#' function.
#'
#' @param x An object returned by `encode_search()`, `encode_get()`,
#'   `encode_matrix()`, `encode_report()`, `encode_list_files()`,
#'   `encode_select_files()`, `encode_preview_download()`, or
#'   `encode_download()`.
#' @param component For `encode_matrix()` results, which table to extract:
#'   `"matrix"`, `"assays"`, or `"biosamples"`. Ignored for other result types.
#'
#' @return A data frame.
#' @export
#'
#' @examples
#' # res <- encode_search(type = "Experiment", search = "mouse heart ChIP-seq")
#' # experiments <- encode_results(res)
encode_results <- function(x, component = c("matrix", "assays", "biosamples")) {
  component <- match.arg(component)
  if (inherits(x, "encode_search_result")) {
    return(x$results)
  }
  if (inherits(x, "encode_object")) {
    return(x$summary)
  }
  if (inherits(x, "encode_matrix_result")) {
    return(switch(
      component,
      matrix = x$matrix,
      assays = x$assay_summary,
      biosamples = x$biosample_summary
    ))
  }
  if (inherits(x, "encode_report_result")) {
    return(x$report)
  }
  if (inherits(x, "encode_schema_result")) {
    return(x$properties)
  }
  if (inherits(x, "encode_selected_files")) {
    return(x$files)
  }
  if (inherits(x, "encode_download_plan")) {
    return(x$files)
  }
  if (is.data.frame(x)) {
    return(x)
  }
  cli::cli_abort("{.arg x} does not contain a result table supported by {.fn encode_results}.")
}

#' Extract the ENCODE query URL from a result object
#'
#' @param x An object returned by `encode_search()`, `encode_matrix()`,
#'   `encode_report()`, `encode_list_files()`, `encode_select_files()`, or
#'   `encode_download()`.
#'
#' @return A single URL string, or `NA_character_` when no query URL is
#'   available.
#'
#' @examples
#' tbl <- data.frame(accession = "ENCSR000AAA")
#' attr(tbl, "query_url") <- "https://www.encodeproject.org/search/?type=Experiment"
#' encode_query_url(tbl)
#' @noRd
encode_query_url <- function(x) {
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
#' @examples
#' tbl <- data.frame(accession = "ENCSR000AAA")
#' attr(tbl, "filters") <- data.frame(field = "status", value = "released")
#' encode_filters(tbl)
#' @noRd
encode_filters <- function(x) {
  if (is.list(x) && !is.null(x$filters)) {
    return(x$filters)
  }
  filters <- attr(x, "filters", exact = TRUE)
  if (!is.null(filters)) {
    return(filters)
  }
  data.frame(field = character(), value = character())
}

#' List searchable fields from an ENCODE schema
#'
#' Retrieve an ENCODE schema and return the compact property table. This is a
#' convenience wrapper around `encode_get_schema()` for field discovery.
#'
#' @param type ENCODE object type, schema path, or profile JSON URL.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return A data frame describing schema properties.
#'
#' @examples
#' schema_json <- paste0(
#'   '{"title":"Experiment","id":"/profiles/experiment.json",',
#'   '"properties":{"accession":{"type":"string","title":"Accession"}}}'
#' )
#' fields <- httr2::with_mocked_responses(
#'   function(req) httr2::response(
#'     200,
#'     headers = "Content-Type: application/json",
#'     body = charToRaw(schema_json)
#'   ),
#'   encode_search_fields("Experiment")
#' )
#' fields$property
#' @noRd
encode_search_fields <- function(type = "Experiment", quiet = TRUE) {
  encode_get_schema(type, quiet = quiet)$properties
}
