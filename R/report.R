#' Build an ENCODE metadata table
#'
#' Return selected ENCODE metadata fields as a table.
#'
#' The default `endpoint = "search"` is bounded by `limit`. The optional
#' `endpoint = "report"` uses ENCODE's report TSV endpoint and requires
#' `allow_large = TRUE` because the portal may return many rows.
#'
#' @param fields Character vector of ENCODE field names to include.
#' @param type ENCODE object type.
#' @param filters Named list of ENCODE query filters.
#' @param search Optional free-text search term.
#' @param status Optional ENCODE status filter. Use `NULL` to omit.
#' @param limit Number of search rows to request, or `"all"`.
#' @param metadata Amount of linked metadata to request when
#'   `endpoint = "search"`. `"full"` returns more readable linked fields.
#'   `"basic"` requests a smaller response.
#' @param endpoint Either `"search"` or `"report"`.
#' @param allow_large Must be `TRUE` to use `endpoint = "report"`.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return A metadata report. `encode_results()` extracts the report table.
#' @export
#'
#' @examples
#' # Offline example.
#' search_json <- paste0(
#'   '{"@graph":[{"accession":"ENCSR000AAA",',
#'   '"assay_title":"total RNA-seq","status":"released"}],"total":1}'
#' )
#' report <- httr2::with_mocked_responses(
#'   function(req) httr2::response(
#'     200,
#'     headers = "Content-Type: application/json",
#'     body = charToRaw(search_json)
#'   ),
#'   encode_report(
#'     fields = c("accession", "assay_title"),
#'     limit = 1,
#'     quiet = TRUE
#'   )
#' )
#' encode_results(report)
#'
#' # Live ENCODE example:
#' # encode_report(
#' #   fields = c("accession", "assay_title", "biosample_summary"),
#' #   type = "Experiment",
#' #   search = "mouse heart ChIP-seq",
#' #   limit = 10
#' # )
encode_report <- function(
                          fields,
                          type = "Experiment",
                          filters = list(),
                          search = NULL,
                          status = "released",
                          limit = 25,
                          metadata = c("full", "basic"),
                          endpoint = c("search", "report"),
                          allow_large = FALSE,
                          quiet = FALSE) {
  if (!is.character(fields) || length(fields) == 0L || any(!nzchar(fields))) {
    cli::cli_abort("{.arg fields} must be a non-empty character vector.")
  }
  endpoint <- match.arg(endpoint)
  metadata_request <- encode_metadata_request(metadata)

  if (identical(endpoint, "search")) {
    return(encode_report_from_search(
      fields = fields,
      type = type,
      filters = filters,
      search = search,
      status = status,
      limit = limit,
      metadata = metadata_request$metadata,
      quiet = quiet
    ))
  }

  encode_report_from_tsv(
    fields = fields,
    type = type,
    filters = filters,
    search = search,
    status = status,
    allow_large = allow_large,
    quiet = quiet
  )
}

encode_report_from_search <- function(
                                      fields,
                                      type,
                                      filters,
                                      search,
                                      status,
                                      limit,
                                      metadata,
                                      quiet) {
  search_result <- encode_search(
    type = type,
    filters = filters,
    search = search,
    status = status,
    limit = limit,
    metadata = metadata,
    include_facets = FALSE,
    quiet = TRUE
  )
  rows <- lapply(search_result$raw$`@graph` %||% list(), function(item) {
    values <- lapply(fields, function(field) {
      value <- encode_extract_field(item, field)
      if (is.list(value)) {
        encode_collapse_vector(value)
      } else {
        encode_scalar(value)
      }
    })
    names(values) <- fields
    as.data.frame(values, stringsAsFactors = FALSE)
  })
  report <- encode_bind_rows(rows, fields)
  report <- encode_attach_metadata(
    report,
    query_url = search_result$query_url,
    retrieved_at = search_result$request$retrieved_at,
    filters = search_result$filters
  )
  if (!isTRUE(quiet)) {
    cli::cli_inform("ENCODE report successfully returned {nrow(report)} row(s) from search results.")
  }
  result <- list(
    report = report,
    raw = search_result$raw,
    url = search_result$url,
    query_url = search_result$query_url,
    encode_base_url = encode_base_url(),
    endpoint = "search",
    fields = fields,
    request = search_result$request
  )
  class(result) <- c("encode_report_result", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "Returned a metadata report. Print the result to view it, or use {.code encode_results()} for the report table."
    )
  }
  result
}

encode_report_from_tsv <- function(
                                   fields,
                                   type,
                                   filters,
                                   search,
                                   status,
                                   allow_large,
                                   quiet) {
  if (!isTRUE(allow_large)) {
    cli::cli_abort(
      c(
        "{.arg endpoint = 'report'} can request very large TSV reports.",
        "i" = "Use {.code allow_large = TRUE} after narrowing filters."
      )
    )
  }

  query <- c(filters, list(field = fields))
  if (!is.null(type)) {
    query$type <- type
  }
  if (!is.null(status)) {
    query$status <- status
  }
  if (!is.null(search)) {
    query$searchTerm <- search
  }

  if (!isTRUE(quiet)) {
    cli::cli_inform("Querying ENCODE report TSV endpoint.")
  }
  response <- encode_perform_text("/report.tsv", query = query)
  lines <- strsplit(response$text, "\n", fixed = TRUE)[[1L]]
  lines <- lines[nzchar(lines)]
  if (length(lines) < 2L) {
    cli::cli_abort("ENCODE report TSV response did not include a table.")
  }
  report <- utils::read.delim(
    text = paste(lines[-1L], collapse = "\n"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  report <- encode_attach_metadata(
    report,
    query_url = response$url,
    retrieved_at = response$retrieved_at,
    filters = encode_filter_table(query)
  )
  result <- list(
    report = report,
    raw = lines,
    url = response$url,
    query_url = response$url,
    encode_base_url = encode_base_url(),
    endpoint = "report",
    fields = fields,
    request = response[c("status_code", "content_type", "retrieved_at")]
  )
  class(result) <- c("encode_report_result", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "ENCODE report successfully returned {nrow(report)} row(s)."
    )
    cli::cli_inform(
      "Returned a metadata report. Print the result to view it, or use {.code encode_results()} for the report table."
    )
  }
  result
}
