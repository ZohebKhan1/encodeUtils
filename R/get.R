#' Retrieve one ENCODE record
#'
#' Get the metadata for a single ENCODE record, such as one experiment or one
#' file. This is useful after a search when you want a closer look at one
#' accession. It retrieves metadata only and never downloads file contents.
#'
#' @param x One ENCODE accession, portal path, or full portal URL.
#' @param metadata How much linked metadata to request. `"full"` returns more
#'   readable linked fields for browsing. `"basic"` requests a smaller response.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return One ENCODE record with a compact printed summary. `encode_results()`
#'   extracts the summary table.
#' @export
#'
#' @examples
#' # This mocked response keeps the example offline and runnable.
#' object_json <- paste0(
#'   '{"@type":["Experiment","Item"],"accession":"ENCSR000AAA",',
#'   '"@id":"/experiments/ENCSR000AAA/",',
#'   '"assay_title":"total RNA-seq","status":"released"}'
#' )
#' experiment <- httr2::with_mocked_responses(
#'   function(req) httr2::response(
#'     200,
#'     headers = "Content-Type: application/json",
#'     body = charToRaw(object_json)
#'   ),
#'   encode_get("ENCSR000AAA", quiet = TRUE)
#' )
#' encode_results(experiment)
#'
#' # Look up one record from ENCODE:
#' # encode_get("ENCSR284QGB")
encode_get <- function(
                       x,
                       metadata = c("full", "basic"),
                       quiet = FALSE) {
  metadata_request <- encode_metadata_request(metadata)
  frame <- metadata_request$frame
  metadata <- metadata_request$metadata
  if (!isTRUE(quiet)) {
    cli::cli_inform("Retrieving ENCODE record {.val {x}}.")
  }

  response <- encode_perform_json(
    x,
    query = list(format = "json", frame = frame)
  )
  raw <- response$data
  type <- encode_first_type(raw)
  summary <- encode_attach_metadata(
    encode_summarize_object(raw, type),
    query_url = response$url,
    retrieved_at = response$retrieved_at
  )
  result <- list(
    data = raw,
    raw = raw,
    summary = summary,
    type = type,
    accession = encode_scalar(raw$accession),
    id = encode_scalar(raw$`@id`),
    url = response$url,
    query_url = response$url,
    encode_base_url = encode_base_url(),
    frame = frame,
    metadata = metadata,
    request = response[c("status_code", "content_type", "retrieved_at")]
  )
  class(result) <- c("encode_object", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "Successfully retrieved one ENCODE record. Print the result to view the summary, or use {.code encode_results()} for the summary table."
    )
  }
  result
}

encode_summarize_object <- function(raw, type = NULL) {
  type <- type %||% encode_first_type(raw)
  if (identical(type, "Experiment")) {
    return(encode_flatten_experiment(raw))
  }
  if (identical(type, "File")) {
    return(encode_flatten_file(raw))
  }
  if (identical(type, "Biosample")) {
    return(encode_flatten_biosample(raw))
  }
  encode_flatten_object(raw)
}
