encode_get_record <- function(
                              x,
                              metadata = c("full", "basic"),
                              quiet = TRUE) {
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
