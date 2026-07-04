#' Retrieve an ENCODE schema/profile
#'
#' Retrieve an ENCODE profile JSON document and return a compact property table.
#'
#' @param type ENCODE object type, schema path, or profile JSON URL.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return A schema result. `encode_results()` extracts the property table.
#'
#' @examples
#' # schema <- encode_get_schema("Experiment")
#' # encode_results(schema)
#' @noRd
encode_get_schema <- function(type, quiet = FALSE) {
  path <- encode_schema_path(type)
  if (!isTRUE(quiet)) {
    cli::cli_inform("Retrieving ENCODE schema {.val {type}}.")
  }
  response <- encode_perform_json(path)
  raw <- response$data
  properties <- encode_attach_metadata(
    encode_schema_properties(raw),
    query_url = response$url,
    retrieved_at = response$retrieved_at
  )
  result <- list(
    schema = raw,
    raw = raw,
    properties = properties,
    required = unlist(raw$required %||% character(), use.names = FALSE),
    title = encode_scalar(raw$title),
    id = encode_scalar(raw$id),
    url = response$url,
    query_url = response$url,
    encode_base_url = encode_base_url(),
    request = response[c("status_code", "content_type", "retrieved_at")]
  )
  class(result) <- c("encode_schema_result", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "Returned schema fields. Print the result to view fields, or use {.code encode_results()} for the property table."
    )
  }
  result
}

encode_schema_path <- function(type) {
  if (!is.character(type) || length(type) != 1L || is.na(type) || !nzchar(type)) {
    cli::cli_abort("{.arg type} must be one schema type, path, or URL.")
  }
  if (grepl("^https?://", type) || grepl("^/profiles/.+[.]json$", type)) {
    return(type)
  }
  name <- sub("[.]json$", "", type)
  name <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", name)
  name <- gsub("[ -]+", "_", name)
  paste0("/profiles/", tolower(name), ".json")
}

encode_schema_properties <- function(raw) {
  properties <- raw$properties
  if (is.null(properties) || length(properties) == 0L) {
    return(encode_empty_data_frame(c(
      "property", "type", "title", "description", "required", "enum"
    )))
  }
  required <- unlist(raw$required %||% character(), use.names = FALSE)
  rows <- lapply(names(properties), function(name) {
    property <- properties[[name]]
    type <- property$type %||% property$items$type %||% property$linkTo
    data.frame(
      property = name,
      type = encode_collapse_vector(type),
      title = encode_scalar(property$title),
      description = encode_scalar(property$description %||% property$comment),
      required = name %in% required,
      enum = encode_collapse_vector(property$enum),
      stringsAsFactors = FALSE
    )
  })
  encode_bind_rows(rows, c("property", "type", "title", "description", "required", "enum"))
}
