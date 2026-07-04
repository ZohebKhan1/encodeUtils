#' Summarize ENCODE availability counts
#'
#' Query the ENCODE Matrix endpoint to see how many records are available across
#' assay and biosample categories. It returns metadata counts only and does not
#' download files.
#'
#' @param type ENCODE object type. The primary supported type is `"Experiment"`.
#' @param filters Named list of ENCODE matrix filters.
#' @param status Optional ENCODE status filter. The default keeps released
#'   records only. Use `NULL` to omit.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return A matrix summary containing long matrix counts plus assay and
#'   biosample summaries. Use `encode_results(x, component = "assays")`
#'   or `encode_results(x, component = "biosamples")` to extract summaries.
#' @export
#'
#' @examples
#' # Offline example.
#' matrix_json <- paste0(
#'   '{"total":1,"matrix":{"x":{"group_by":"assay_title",',
#'   '"assay_title":{"buckets":[{"key":"RNA-seq","doc_count":1}]}},',
#'   '"y":{"group_by":["biosample_ontology.classification",',
#'   '"biosample_ontology.term_name"],',
#'   '"biosample_ontology.classification":{"buckets":[{"key":"tissue",',
#'   '"doc_count":1,"biosample_ontology.term_name":{"buckets":[{',
#'   '"key":"heart","doc_count":1,"assay_title":{"buckets":[{',
#'   '"key":"RNA-seq","doc_count":1}]}}]}}]}}}}'
#' )
#' mat <- httr2::with_mocked_responses(
#'   function(req) httr2::response(
#'     200,
#'     headers = "Content-Type: application/json",
#'     body = charToRaw(matrix_json)
#'   ),
#'   encode_matrix(quiet = TRUE)
#' )
#' encode_results(mat)
#' encode_results(mat, component = "assays")
#'
#' # Live ENCODE example:
#' # encode_matrix(filters = list("control_type!=" = "*", perturbed = "false"))
encode_matrix <- function(
                          type = "Experiment",
                          filters = list(),
                          status = "released",
                          quiet = FALSE) {
  encode_validate_filters(filters)
  query <- c(list(format = "json"), filters)
  if (!is.null(type)) {
    query$type <- type
  }
  if (!is.null(status)) {
    query$status <- status
  }

  if (!isTRUE(quiet)) {
    cli::cli_inform("Querying ENCODE matrix ({.field {type %||% 'mixed'}}).")
  }

  response <- encode_perform_json("/matrix/", query = query)
  raw <- response$data
  parsed <- encode_parse_matrix(raw)
  filters <- encode_active_filters(raw, query)
  matrix_table <- encode_attach_metadata(
    parsed$matrix,
    query_url = response$url,
    retrieved_at = response$retrieved_at,
    filters = filters
  )
  assay_summary <- encode_attach_metadata(
    parsed$assays,
    query_url = response$url,
    retrieved_at = response$retrieved_at,
    filters = filters
  )
  biosample_summary <- encode_attach_metadata(
    parsed$biosamples,
    query_url = response$url,
    retrieved_at = response$retrieved_at,
    filters = filters
  )

  result <- list(
    matrix = matrix_table,
    assay_summary = assay_summary,
    biosample_summary = biosample_summary,
    raw = raw,
    total = raw$total %||% NROW(parsed$matrix),
    total_results = raw$total %||% NROW(parsed$matrix),
    filters = filters,
    url = response$url,
    query_url = response$url,
    encode_base_url = encode_base_url(),
    request = response[c("status_code", "content_type", "retrieved_at")]
  )
  class(result) <- c("encode_matrix_result", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "ENCODE matrix successfully returned availability counts."
    )
    cli::cli_inform(
      "Returned a matrix summary. Print the result to view summaries, or use {.code encode_results()} with component = 'assays' or 'biosamples'."
    )
  }
  result
}

encode_parse_matrix <- function(raw) {
  matrix <- raw$matrix
  if (is.null(matrix) || is.null(matrix$x) || is.null(matrix$y)) {
    cli::cli_abort("ENCODE matrix response did not contain {.field matrix.x} and {.field matrix.y}.")
  }

  x_field <- encode_scalar(matrix$x$group_by)
  y_fields <- matrix$y$group_by %||% character()
  y_fields <- unlist(y_fields, use.names = FALSE)
  if (is.na(x_field) || length(y_fields) < 2L) {
    cli::cli_abort("ENCODE matrix response had an unexpected grouping shape.")
  }

  assay_buckets <- encode_pluck(matrix$x, c(x_field, "buckets")) %||% list()
  assays <- encode_bucket_table(assay_buckets, c("assay_title", "n"))

  classification_field <- y_fields[[1L]]
  term_field <- y_fields[[2L]]
  classification_buckets <- encode_pluck(matrix$y, c(classification_field, "buckets")) %||% list()

  long_rows <- list()
  biosample_rows <- list()
  for (classification in classification_buckets) {
    classification_name <- encode_scalar(classification$key)
    classification_n <- encode_integer(classification$doc_count)
    term_buckets <- encode_pluck(classification, c(term_field, "buckets")) %||% list()
    for (term in term_buckets) {
      term_name <- encode_scalar(term$key)
      term_n <- encode_integer(term$doc_count)
      biosample_rows[[length(biosample_rows) + 1L]] <- data.frame(
        biosample_classification = classification_name,
        biosample_term_name = term_name,
        n = term_n,
        classification_n = classification_n,
        stringsAsFactors = FALSE
      )

      cell_buckets <- encode_pluck(term, c(x_field, "buckets")) %||% list()
      for (cell in cell_buckets) {
        long_rows[[length(long_rows) + 1L]] <- data.frame(
          biosample_classification = classification_name,
          biosample_term_name = term_name,
          assay_title = encode_scalar(cell$key),
          n = encode_integer(cell$doc_count),
          biosample_n = term_n,
          classification_n = classification_n,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  list(
    matrix = encode_bind_rows(long_rows, c(
      "biosample_classification", "biosample_term_name", "assay_title",
      "n", "biosample_n", "classification_n"
    )),
    assays = assays,
    biosamples = encode_bind_rows(biosample_rows, c(
      "biosample_classification", "biosample_term_name", "n", "classification_n"
    ))
  )
}

encode_bucket_table <- function(buckets, columns) {
  rows <- lapply(buckets, function(bucket) {
    data.frame(
      assay_title = encode_scalar(bucket$key),
      n = encode_integer(bucket$doc_count),
      stringsAsFactors = FALSE
    )
  })
  encode_bind_rows(rows, columns)
}
