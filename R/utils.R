# Shared internal helpers.

`%||%` <- function(x, y) {
  if (is.null(x)) {
    y
  } else {
    x
  }
}

encode_option <- function(name, default) {
  legacy_name <- sub("^encodeUtils", "encodeapiutil", name)
  getOption(name, getOption(legacy_name, default))
}

encode_base_url <- function() {
  base_url <- encode_option(
    "encodeUtils.base_url",
    "https://www.encodeproject.org"
  )
  sub("/+$", "", base_url)
}

encode_package_version <- function() {
  version <- tryCatch(
    as.character(utils::packageVersion("encodeUtils")),
    error = function(cnd) NA_character_
  )
  version
}

encode_attach_metadata <- function(
                                   x,
                                   query_url = NULL,
                                   retrieved_at = NULL,
                                   filters = NULL,
                                   base_url = encode_base_url()) {
  if (!is.null(query_url)) {
    attr(x, "query_url") <- query_url
  }
  if (!is.null(retrieved_at)) {
    attr(x, "retrieved_at") <- retrieved_at
  }
  if (!is.null(filters)) {
    attr(x, "filters") <- filters
  }
  attr(x, "encode_base_url") <- base_url
  attr(x, "package_version") <- encode_package_version()
  x
}

encode_object_url <- function(path) {
  if (length(path) == 0L) {
    return(character())
  }
  vapply(path, encode_object_url_one, character(1L), USE.NAMES = FALSE)
}

encode_object_url_one <- function(path) {
  if (is.na(path) || !nzchar(path)) {
    return(NA_character_)
  }
  if (grepl("^https?://", path)) {
    return(path)
  }
  if (!startsWith(path, "/")) {
    path <- paste0("/", path)
  }
  paste0(encode_base_url(), path)
}

encode_download_url <- function(href, cloud_url = NA_character_) {
  if (!is.na(cloud_url) && nzchar(cloud_url)) {
    return(cloud_url)
  }
  encode_object_url(href)
}

encode_scalar <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_character_)
  }
  if (is.list(x)) {
    return(NA_character_)
  }
  x <- x[[1L]]
  if (is.null(x) || is.na(x)) {
    NA_character_
  } else {
    as.character(x)
  }
}

encode_integer <- function(x) {
  if (is.null(x) || length(x) == 0L || is.na(x[[1L]])) {
    return(NA_integer_)
  }
  as.integer(x[[1L]])
}

encode_numeric <- function(x) {
  if (is.null(x) || length(x) == 0L || is.na(x[[1L]])) {
    return(NA_real_)
  }
  as.numeric(x[[1L]])
}

encode_logical <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA)
  }
  if (is.list(x)) {
    return(NA)
  }
  value <- x[[1L]]
  if (is.null(value) || is.na(value)) {
    return(NA)
  }
  if (is.logical(value)) {
    return(value)
  }
  if (is.numeric(value)) {
    return(value != 0)
  }
  value <- tolower(trimws(as.character(value)))
  if (value %in% c("true", "t", "yes", "y", "1")) {
    return(TRUE)
  }
  if (value %in% c("false", "f", "no", "n", "0")) {
    return(FALSE)
  }
  NA
}

encode_logical_vector <- function(x) {
  if (is.null(x)) {
    return(logical())
  }
  vapply(seq_along(x), function(i) encode_logical(x[i]), logical(1L))
}

encode_as_file_size <- function(x) {
  if (is.null(x)) {
    return(numeric())
  }
  if (is.list(x) && !is.data.frame(x)) {
    x <- vapply(
      x,
      function(value) {
        if (is.null(value) || length(value) == 0L) {
          return(NA_character_)
        }
        value <- unlist(value, recursive = FALSE, use.names = FALSE)
        if (length(value) == 0L || is.null(value[[1L]])) {
          return(NA_character_)
        }
        as.character(value[[1L]])
      },
      character(1L)
    )
  }
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.numeric(x)) {
    out <- as.numeric(x)
  } else {
    x <- trimws(as.character(x))
    out <- rep(NA_real_, length(x))
    numeric_like <- grepl(
      "^(?:[0-9]+(?:[.][0-9]*)?|[.][0-9]+)(?:[eE][+]?[0-9]+)?$",
      x
    )
    out[numeric_like] <- as.numeric(x[numeric_like])
  }
  out[!is.finite(out) | out < 0] <- NA_real_
  out
}

encode_collapse_value <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_character_)
  }
  if (is.list(x)) {
    return(NA_character_)
  }
  paste(vapply(x, as.character, character(1L)), collapse = ", ")
}

encode_collapse_vector <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_character_)
  }
  if (is.list(x)) {
    x <- unlist(lapply(x, encode_collapse_item), recursive = FALSE, use.names = FALSE)
  }
  if (length(x) == 0L) {
    return(NA_character_)
  }
  x <- vapply(x, encode_scalar_text, character(1L))
  x <- unique(x[!is.na(x) & nzchar(x)])
  if (length(x) == 0L) {
    return(NA_character_)
  }
  paste(x, collapse = ", ")
}

encode_collapse_item <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_character_)
  }
  if (is.list(x)) {
    preferred <- x$accession %||% x$`@id` %||% x$name %||% x$title
    if (!is.null(preferred)) {
      return(encode_scalar_text(preferred))
    }
    return(unlist(x, recursive = TRUE, use.names = FALSE))
  }
  x
}

encode_scalar_text <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_character_)
  }
  if (is.list(x)) {
    x <- unlist(x, recursive = TRUE, use.names = FALSE)
  }
  if (length(x) == 0L || is.null(x[[1L]]) || is.na(x[[1L]])) {
    return(NA_character_)
  }
  as.character(x[[1L]])
}

encode_pluck <- function(x, path) {
  value <- x
  for (name in path) {
    if (!is.list(value) || is.null(value[[name]])) {
      return(NULL)
    }
    value <- value[[name]]
  }
  value
}

encode_extract_field <- function(x, field) {
  if (is.null(field) || !nzchar(field)) {
    return(NULL)
  }
  encode_pluck(x, strsplit(field, ".", fixed = TRUE)[[1L]])
}

encode_first_type <- function(x) {
  types <- x$`@type` %||% character()
  types <- unlist(types, use.names = FALSE)
  types <- types[!types %in% "Item"]
  encode_scalar(types)
}

encode_accession_from_path <- function(path) {
  path <- encode_scalar(path)
  if (is.na(path)) {
    return(NA_character_)
  }
  pieces <- strsplit(gsub("/+$", "", path), "/", fixed = TRUE)[[1L]]
  pieces <- pieces[nzchar(pieces)]
  if (length(pieces) == 0L) {
    return(NA_character_)
  }
  utils::tail(pieces, 1L)
}

encode_normalize_accession <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    return(NA_character_)
  }
  if (grepl("^https?://", x)) {
    x <- sub("[?].*$", "", x)
  }
  encode_accession_from_path(x)
}

encode_pretty_bytes <- function(bytes) {
  bytes <- encode_as_file_size(bytes)
  if (length(bytes) == 0L) {
    return(character())
  }
  vapply(bytes, encode_pretty_byte, character(1L), USE.NAMES = FALSE)
}

encode_pretty_byte <- function(bytes) {
  if (length(bytes) != 1L || is.na(bytes)) {
    return(NA_character_)
  }
  units <- c("B", "KB", "MB", "GB", "TB")
  size <- bytes
  unit_index <- 1L
  while (size >= 1024 && unit_index < length(units)) {
    size <- size / 1024
    unit_index <- unit_index + 1L
  }
  if (unit_index == 1L) {
    paste0(as.integer(size), " ", units[[unit_index]])
  } else {
    paste0(format(round(size, 2), nsmall = 2), " ", units[[unit_index]])
  }
}

encode_parse_size <- function(x, arg = "size") {
  if (is.null(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be one size value.")
  }
  if (is.numeric(x)) {
    if (x < 0 || is.infinite(x)) {
      cli::cli_abort("{.arg {arg}} must be a finite non-negative size.")
    }
    return(as.numeric(x))
  }
  if (!is.character(x)) {
    cli::cli_abort("{.arg {arg}} must be numeric bytes or a string like {.val 500MB}.")
  }
  value <- toupper(gsub("\\s+", "", x))
  match <- regexec("^([0-9]+(?:[.][0-9]+)?)(B|KB|MB|GB|TB)?$", value)
  parts <- regmatches(value, match)[[1L]]
  if (length(parts) == 0L) {
    cli::cli_abort("{.arg {arg}} must be numeric bytes or a string like {.val 500MB}.")
  }
  unit <- if (nzchar(parts[[3L]])) parts[[3L]] else "B"
  multiplier <- switch(
    unit,
    B = 1,
    KB = 1024,
    MB = 1024^2,
    GB = 1024^3,
    TB = 1024^4
  )
  as.numeric(parts[[2L]]) * multiplier
}

encode_first_present <- function(x, names) {
  for (name in names) {
    if (name %in% names(x)) {
      return(x[[name]])
    }
  }
  NULL
}

encode_empty_data_frame <- function(columns) {
  out <- stats::setNames(
    rep(list(character()), length(columns)),
    columns
  )
  as.data.frame(out, stringsAsFactors = FALSE)
}

encode_bind_rows <- function(rows, columns = NULL) {
  if (length(rows) == 0L) {
    if (is.null(columns)) {
      return(data.frame())
    }
    return(encode_empty_data_frame(columns))
  }
  all_columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
  if (!is.null(columns)) {
    all_columns <- unique(c(columns, all_columns))
  }
  rows <- lapply(rows, function(row) {
    missing <- setdiff(all_columns, names(row))
    for (name in missing) {
      row[[name]] <- NA
    }
    row[all_columns]
  })
  do.call(rbind, rows)
}

encode_validate_filters <- function(filters) {
  if (!is.list(filters)) {
    cli::cli_abort("{.arg filters} must be a named list.")
  }
  if (length(filters) == 0L) {
    return(invisible(NULL))
  }

  names <- names(filters)
  if (is.null(names) || any(!nzchar(names))) {
    cli::cli_abort("{.arg filters} must be a named list.")
  }
  invisible(NULL)
}

encode_validate_limit <- function(limit) {
  if (identical(limit, "all")) {
    return(invisible(NULL))
  }
  if (!is.numeric(limit) || length(limit) != 1L || is.na(limit) ||
    is.infinite(limit) || limit < 0 || limit != floor(limit)) {
    cli::cli_abort("{.arg limit} must be a non-negative whole number or {.val all}.")
  }
  invisible(NULL)
}

encode_validate_positive_whole_number <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) ||
    is.infinite(x) || x < 1 || x != floor(x)) {
    cli::cli_abort("{.arg {arg}} must be a positive whole number.")
  }
  as.integer(x)
}

encode_validate_file_accessions <- function(file_accession, arg = "file_accession") {
  if (is.null(file_accession)) {
    return(NULL)
  }
  if (!is.character(file_accession) || any(is.na(file_accession))) {
    cli::cli_abort("{.arg {arg}} must contain ENCODE file accessions like {.val ENCFF260OJQ}.")
  }
  file_accession <- toupper(trimws(file_accession))
  file_accession <- file_accession[nzchar(file_accession)]
  if (length(file_accession) == 0L || any(!encode_is_file_accession(file_accession))) {
    cli::cli_abort("{.arg {arg}} must contain ENCODE file accessions like {.val ENCFF260OJQ}.")
  }
  unique(file_accession)
}

encode_file_accession_column <- function(files) {
  if ("file_accession" %in% names(files)) {
    return("file_accession")
  }
  if ("accession" %in% names(files)) {
    return("accession")
  }
  cli::cli_abort("File metadata must include {.field file_accession} or {.field accession}.")
}

encode_filter_file_accessions <- function(files, file_accession = NULL) {
  file_accession <- encode_validate_file_accessions(file_accession)
  if (is.null(file_accession)) {
    return(files)
  }
  column <- encode_file_accession_column(files)
  available <- toupper(as.character(files[[column]]))
  missing <- setdiff(file_accession, available)
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Requested ENCODE file accession(s) were not found in {.arg x}.",
      "x" = "{paste(missing, collapse = ', ')}"
    ))
  }
  order_index <- match(file_accession, available)
  files[order_index, , drop = FALSE]
}

encode_select_by_accession <- function(table, accession = NULL) {
  if (is.null(accession)) {
    return(NULL)
  }
  if (!is.character(accession) || any(is.na(accession))) {
    cli::cli_abort("{.arg accession} must contain ENCODE accessions.")
  }
  accession <- toupper(trimws(accession))
  accession <- accession[nzchar(accession)]
  if (length(accession) == 0L) {
    cli::cli_abort("{.arg accession} must contain ENCODE accessions.")
  }
  columns <- intersect(c("file_accession", "experiment", "experiment_accession", "accession"), names(table))
  if (length(columns) == 0L) {
    cli::cli_abort("{.arg x} does not contain an accession column.")
  }
  matches <- lapply(columns, function(column) {
    match(accession, toupper(as.character(table[[column]])))
  })
  row_index <- rep(NA_integer_, length(accession))
  for (candidate in matches) {
    missing <- is.na(row_index)
    row_index[missing] <- candidate[missing]
  }
  missing_accession <- accession[is.na(row_index)]
  if (length(missing_accession) > 0L) {
    cli::cli_abort(c(
      "Requested ENCODE accession(s) were not found in {.arg x}.",
      "x" = "{paste(missing_accession, collapse = ', ')}"
    ))
  }
  row_index
}

encode_metadata_request <- function(metadata = NULL, frame = NULL) {
  if (!is.null(metadata)) {
    if (length(metadata) > 1L) {
      metadata <- metadata[[1L]]
    }
    if (!is.character(metadata) || length(metadata) != 1L || is.na(metadata)) {
      cli::cli_abort("{.arg metadata} must be {.val full} or {.val basic}.")
    }
    metadata <- match.arg(metadata, c("full", "basic"))
    return(list(
      metadata = metadata,
      frame = if (identical(metadata, "full")) "embedded" else "object"
    ))
  }

  if (length(frame) > 1L) {
    frame <- frame[[1L]]
  }
  frame <- match.arg(frame, c("embedded", "object"))
  metadata <- if (identical(frame, "embedded")) "full" else "basic"
  list(
    metadata = metadata,
    frame = frame
  )
}

encode_result_kind <- function(type = NULL) {
  if (identical(type, "Experiment")) {
    return("experiment search results")
  }
  if (identical(type, "File")) {
    return("file search results")
  }
  "search results"
}

encode_normalize_query_names <- function(query) {
  if (length(query) == 0L) {
    return(query)
  }
  query_names <- names(query)
  query_names <- sub("!=$", "!", query_names)
  names(query) <- query_names
  query
}

encode_normalize_query_values <- function(query) {
  lapply(query, function(value) {
    if (is.logical(value)) {
      return(ifelse(value, "true", "false"))
    }
    if (is.null(value)) {
      return(NULL)
    }
    as.character(value)
  })
}

encode_filter_table <- function(filters) {
  if (length(filters) == 0L) {
    return(data.frame(field = character(), value = character()))
  }

  if (is.list(filters) && !is.null(names(filters)) && any(nzchar(names(filters)))) {
    out <- data.frame(
      field = names(filters),
      value = vapply(filters, encode_collapse_value, character(1L)),
      stringsAsFactors = FALSE
    )
    return(out[nzchar(out$field), , drop = FALSE])
  }

  if (is.list(filters)) {
    fields <- vapply(filters, function(x) encode_scalar(x$field), character(1L))
    values <- vapply(filters, function(x) encode_scalar(x$term), character(1L))
    missing_value <- !nzchar(values)
    values[missing_value] <- vapply(
      filters[missing_value],
      function(x) encode_scalar(x$value),
      character(1L)
    )
    return(data.frame(field = fields, value = values, stringsAsFactors = FALSE))
  }

  data.frame(field = character(), value = character())
}

encode_get_extension <- function(path) {
  name <- basename(path)
  name <- sub("[?].*$", "", name)
  lower <- tolower(name)
  lower <- sub("[.]gz$", "", lower)
  lower <- sub("[.]bgz$", "", lower)
  ext <- sub("^.*[.]", "", lower)
  if (identical(ext, lower)) {
    ""
  } else {
    ext
  }
}

encode_unique_paths <- function(paths, accessions = NULL) {
  if (length(paths) <= 1L || !any(duplicated(paths))) {
    return(paths)
  }

  out <- paths
  duplicated_paths <- unique(paths[duplicated(paths)])
  for (path in duplicated_paths) {
    index <- which(paths == path)
    pieces <- path_parts(path)
    suffix <- seq_along(index)
    if (!is.null(accessions) && length(accessions) == length(paths)) {
      accession_suffix <- accessions[index]
      accession_suffix[is.na(accession_suffix) | !nzchar(accession_suffix)] <- suffix
      suffix <- accession_suffix
      if (any(duplicated(suffix))) {
        suffix <- paste0(suffix, "_", seq_along(index))
      }
    }
    out[index] <- file.path(
      pieces$directory,
      paste0(pieces$stem, "_", suffix, pieces$extension)
    )
  }
  out
}

path_parts <- function(path) {
  directory <- dirname(path)
  base <- basename(path)
  extension <- regmatches(base, regexpr("[.][^.]+$", base))
  if (length(extension) == 0L || identical(extension, character())) {
    extension <- ""
  }
  stem <- if (nzchar(extension)) {
    sub("[.][^.]+$", "", base)
  } else {
    base
  }
  list(directory = directory, stem = stem, extension = extension)
}

encode_is_file_accession <- function(x) {
  grepl("^ENCFF[0-9A-Z]+$", x)
}

encode_is_experiment_accession <- function(x) {
  grepl("^ENCSR[0-9A-Z]+$", x)
}
