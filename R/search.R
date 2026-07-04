#' Search ENCODE metadata
#'
#' Find ENCODE experiments, files, or other portal records by metadata. The
#' search returns matching records and the total number of matches, but it never
#' downloads data files.
#'
#' The result prints as a compact table. Use `encode_results()` when you want the
#' table as a data frame, and `print(x, verbose = TRUE)` when you need the query
#' URL, active filters, or facets for troubleshooting.
#'
#' @param type ENCODE object type to search, such as `"Experiment"` or `"File"`.
#'   Use `"Experiment"` to find datasets and `"File"` to find individual files.
#'   Use `NULL` only for mixed free-text searches.
#' @param filters Named list of ENCODE search filters. Raw ENCODE filter names
#'   are supported, including dot notation and negation such as
#'   `"control_type!="`.
#' @param search Optional free-text search term.
#' @param status Optional ENCODE status filter. The default keeps released
#'   records only. Use `NULL` to omit the status filter.
#' @param limit Number of records to return, or the explicit string `"all"`.
#' @param metadata How much linked metadata to request. `"full"` returns more
#'   readable linked fields for browsing. `"basic"` requests a smaller response.
#' @param include_facets Whether to keep ENCODE facet counts in the result
#'   object for verbose printing and filter discovery.
#' @param quiet If `FALSE`, print a concise query status message.
#'
#' @return Search results with a compact printed summary. `encode_results()`
#'   extracts the result table.
#' @export
#'
#' @examples
#' # This mocked response keeps the example offline and runnable.
#' search_json <- paste0(
#'   '{"@graph":[{"accession":"ENCSR000AAA",',
#'   '"@id":"/experiments/ENCSR000AAA/",',
#'   '"assay_title":"total RNA-seq","status":"released"}],"total":1}'
#' )
#' res <- httr2::with_mocked_responses(
#'   function(req) httr2::response(
#'     200,
#'     headers = "Content-Type: application/json",
#'     body = charToRaw(search_json)
#'   ),
#'   encode_search(
#'     filters = list(assay_title = "total RNA-seq"),
#'     limit = 1,
#'     quiet = TRUE
#'   )
#' )
#' encode_results(res)[, c("accession", "assay_title")]
#'
#' # Search experiments, then continue with file listing:
#' # res <- encode_search(
#' #   type = "Experiment",
#' #   search = "mouse heart ChIP-seq",
#' #   limit = 10
#' # )
#' # encode_results(res)
#' # files <- encode_list_files(res, file_format = "bed", assembly = "mm10")
encode_search <- function(
                          type = "Experiment",
                          filters = list(),
                          search = NULL,
                          status = "released",
                          limit = 25,
                          metadata = c("full", "basic"),
                          include_facets = TRUE,
                          quiet = FALSE) {
  metadata_request <- encode_metadata_request(metadata)
  frame <- metadata_request$frame
  metadata <- metadata_request$metadata
  encode_validate_filters(filters)
  encode_validate_limit(limit)

  query <- encode_search_query(
    type = type,
    filters = filters,
    search = search,
    status = status,
    limit = limit,
    frame = frame
  )

  if (!isTRUE(quiet)) {
    shown_type <- type %||% "mixed"
    cli::cli_inform("Querying ENCODE search ({.field {shown_type}}, limit {.val {limit}}).")
  }

  response <- encode_perform_json("/search/", query = query, allow_search_404 = TRUE)
  raw <- response$data
  graph <- raw$`@graph` %||% list()
  facets <- if (isTRUE(include_facets)) {
    encode_facets(raw)
  } else {
    encode_facets(list())
  }
  results <- encode_flatten_search_results(graph, type = type)
  filters <- encode_active_filters(raw, query)
  results <- encode_attach_metadata(
    results,
    query_url = response$url,
    retrieved_at = response$retrieved_at,
    filters = filters
  )
  results <- encode_class_search_results(results, type = type)

  result <- list(
    results = results,
    raw = raw,
    total = encode_total(raw, graph),
    filters = filters,
    facets = facets,
    columns = encode_columns(raw),
    url = response$url,
    query_url = response$url,
    encode_base_url = encode_base_url(),
    frame = frame,
    metadata = metadata,
    limit = limit,
    total_results = encode_total(raw, graph),
    requested_limit = limit,
    request = response[c("status_code", "content_type", "retrieved_at")]
  )
  class(result) <- c("encode_search_result", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "ENCODE search successfully returned {nrow(results)} of {result$total} matching record(s)."
    )
    cli::cli_inform(
      "Returned {encode_result_kind(type)}. Print the result to view records, or use {.code encode_results()} for the result table."
    )
  }
  result
}

encode_class_search_results <- function(results, type) {
  if (identical(type, "File")) {
    class(results) <- c("encode_file_table", "data.frame")
  }
  if (identical(type, "Experiment")) {
    class(results) <- c("encode_experiment_table", "data.frame")
  }
  results
}

encode_search_query <- function(
                                type,
                                filters,
                                search,
                                status,
                                limit,
                                frame) {
  query <- list(format = "json", frame = frame)

  if (!is.null(type)) {
    query$type <- type
  }
  if (!is.null(status)) {
    query$status <- status
  }
  if (!is.null(search)) {
    query$searchTerm <- search
  }
  query$limit <- as.character(limit)

  c(query, filters)
}

#' Count ENCODE search matches
#'
#' Return only the number of records that match a search. This is useful as a
#' quick preflight for broad queries before asking for many rows or before using
#' `limit = "all"`.
#'
#' Most interactive workflows can start with `encode_search()`, which already
#' reports both the number returned and the total number available.
#'
#' @inheritParams encode_search
#' @param metadata How much linked metadata to request. The default `"basic"`
#'   keeps the count request small because no result rows are returned.
#'
#' @return A query count. Printing shows the total number of matching records.
#' @noRd
#'
encode_count <- function(
                         type = "Experiment",
                         filters = list(),
                         search = NULL,
                         status = "released",
                         metadata = c("basic", "full"),
                         quiet = FALSE) {
  metadata_request <- encode_metadata_request(metadata)
  result <- encode_search(
    type = type,
    filters = filters,
    search = search,
    status = status,
    limit = 0,
    metadata = metadata_request$metadata,
    include_facets = FALSE,
    quiet = TRUE
  )
  out <- list(
    total = result$total,
    total_results = result$total,
    filters = result$filters,
    query_url = result$query_url,
    url = result$url,
    encode_base_url = result$encode_base_url,
    metadata = metadata_request$metadata,
    frame = metadata_request$frame,
    request = result$request
  )
  class(out) <- c("encode_count_result", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform("ENCODE count successfully found {out$total} matching record(s).")
    cli::cli_inform(
      "Returned a query count. Print the result to view it."
    )
  }
  out
}

#' Filter an ENCODE result table in R
#'
#' Filter the compact table from `encode_search()` or another ENCODE helper
#' without making another web request. Values are matched exactly by default.
#'
#' @param x A search result from `encode_search()` or a data frame.
#' @param filters Named list of columns and values to keep.
#' @param ignore_case Whether character matching should ignore case.
#'
#' @return A filtered data frame.
#'
#' @examples
#' results <- data.frame(
#'   accession = c("ENCSR000AAA", "ENCSR000AAB"),
#'   assay_title = c("total RNA-seq", "ChIP-seq")
#' )
#' encode_filter_results(results, list(assay_title = "total RNA-seq"))
#' @noRd
encode_filter_results <- function(x, filters = list(), ignore_case = TRUE) {
  encode_validate_filters(filters)
  table <- if (inherits(x, "encode_search_result")) {
    x$results
  } else if (is.data.frame(x)) {
    x
  } else {
    cli::cli_abort("{.arg x} must be an ENCODE search result or data frame.")
  }

  keep <- rep(TRUE, nrow(table))
  for (field in names(filters)) {
    if (!field %in% names(table)) {
      cli::cli_abort("Column {.field {field}} is not present in {.arg x}.")
    }
    values <- filters[[field]]
    column <- table[[field]]
    if (is.character(column) && isTRUE(ignore_case)) {
      column <- tolower(column)
      values <- tolower(as.character(values))
    }
    keep <- keep & column %in% values
  }
  table[keep, , drop = FALSE]
}
