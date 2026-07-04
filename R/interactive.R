#' Browse ENCODE search results from the console
#'
#' Run `encode_search()` and optionally select rows from the compact result table.
#' Interactive selection uses only base R and is a thin layer over the regular
#' noninteractive helpers.
#'
#' @param ... Arguments passed to `encode_search()`.
#' @param select Whether to prompt for row selection.
#'
#' @return A search result when `select = FALSE`, otherwise a data frame of
#'   selected rows.
#'
#' @examples
#' search_json <- paste0(
#'   '{"@graph":[{"accession":"ENCSR000AAA",',
#'   '"@id":"/experiments/ENCSR000AAA/",',
#'   '"assay_title":"total RNA-seq","status":"released"}],"total":1}'
#' )
#' browsed <- httr2::with_mocked_responses(
#'   function(req) httr2::response(
#'     200,
#'     headers = "Content-Type: application/json",
#'     body = charToRaw(search_json)
#'   ),
#'   encode_browse(limit = 1, quiet = TRUE)
#' )
#' encode_results(browsed)
#' @noRd
encode_browse <- function(..., select = FALSE) {
  result <- encode_search(...)
  if (isTRUE(select)) {
    return(encode_select(result))
  }
  result
}

#' Select rows from ENCODE helper output
#'
#' @param x A search result from `encode_search()`, a file table from
#'   `encode_list_files()`, selected files from `encode_select_files()`, or a
#'   data frame.
#' @param rows Optional integer row numbers. If omitted in an interactive
#'   session, the user is prompted.
#' @param accession Optional ENCODE accession(s) to select by ID instead of row
#'   number.
#'
#' @return A selected data frame.
#'
#' @examples
#' table <- data.frame(accession = c("ENCSR000AAA", "ENCSR000AAB"))
#' encode_select(table, accession = "ENCSR000AAA")
#' @noRd
encode_select <- function(x, rows = NULL, accession = NULL) {
  table <- if (inherits(x, "encode_search_result")) {
    x$results
  } else if (is.data.frame(x)) {
    x
  } else {
    cli::cli_abort("{.arg x} must be an ENCODE result or data frame.")
  }
  if (nrow(table) == 0L) {
    cli::cli_abort("{.arg x} contains no rows to select.")
  }

  if (!is.null(accession)) {
    if (!is.null(rows)) {
      cli::cli_abort("Use either {.arg accession} or {.arg rows}, not both.")
    }
    rows <- encode_select_by_accession(table, accession)
  }

  if (is.null(rows)) {
    if (!encode_can_prompt()) {
      cli::cli_abort("{.arg rows} or {.arg accession} is required in noninteractive sessions.")
    }
    encode_print_table("Selectable rows", table, n = 25L)
    answer <- readline("Select row number(s), comma-separated: ")
    rows <- as.integer(strsplit(answer, ",", fixed = TRUE)[[1L]])
  }
  if (!is.numeric(rows) || any(is.na(rows)) || any(rows < 1L) || any(rows > nrow(table))) {
    cli::cli_abort("{.arg rows} must contain valid row numbers.")
  }
  table[rows, , drop = FALSE]
}

encode_can_prompt <- function() {
  interactive() && !identical(Sys.getenv("TESTTHAT"), "true")
}
