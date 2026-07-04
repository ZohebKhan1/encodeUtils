# Internal HTTP helpers for ENCODE Portal requests.

encode_api_env <- new.env(parent = emptyenv())
encode_api_env$last_request_time <- as.POSIXct(NA_real_, origin = "1970-01-01")

encode_normalize_path <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    cli::cli_abort("{.arg x} must be one non-empty string.")
  }

  if (grepl("^https?://", x)) {
    return(x)
  }

  if (grepl("^ENC[A-Z]{2}[0-9A-Z]+$", x)) {
    prefix <- substr(x, 1L, 5L)
    collection <- switch(
      prefix,
      ENCSR = "experiments",
      ENCFF = "files",
      ENCBS = "biosamples",
      ENCLB = "libraries",
      ENCRE = "replicates",
      ENCAT = "antibodies",
      NULL
    )
    if (!is.null(collection)) {
      x <- paste0("/", collection, "/", x, "/")
    } else {
      x <- paste0("/", x, "/")
    }
  }

  if (!startsWith(x, "/")) {
    x <- paste0("/", x)
  }
  if (!grepl("/$", x) && !grepl("[?]", x) && !grepl("[.][A-Za-z0-9]+$", x)) {
    x <- paste0(x, "/")
  }

  paste0(encode_base_url(), x)
}

encode_request_throttle <- function() {
  rate <- encode_option("encodeUtils.rate_per_second", 5)
  if (isFALSE(rate) || is.na(rate) || rate <= 0) {
    return(invisible(NULL))
  }

  min_interval <- 1 / rate
  now <- Sys.time()
  last <- encode_api_env$last_request_time
  if (!is.na(last)) {
    elapsed <- as.numeric(difftime(now, last, units = "secs"))
    delay <- min_interval - elapsed
    if (delay > 0) {
      Sys.sleep(delay)
    }
  }
  encode_api_env$last_request_time <- Sys.time()
  invisible(NULL)
}

encode_build_request <- function(
                                 path,
                                 query = list(),
                                 timeout = NULL,
                                 accept = "application/json") {
  url <- encode_normalize_path(path)
  req <- httr2::request(url)
  if (!is.null(accept)) {
    req <- httr2::req_headers(req, Accept = accept)
  }
  req <- httr2::req_user_agent(req, "encodeUtils (R package)")

  if (length(query) > 0L) {
    query <- encode_normalize_query_names(query)
    query <- encode_normalize_query_values(query)
    req <- do.call(
      httr2::req_url_query,
      c(list(req), query, list(.multi = "explode"))
    )
  }

  timeout <- timeout %||% getOption("timeout", 60)
  req <- httr2::req_timeout(req, timeout)
  httr2::req_error(req, is_error = function(resp) FALSE)
}

encode_perform_json <- function(
                                path,
                                query = list(),
                                timeout = NULL,
                                allow_search_404 = FALSE) {
  req <- encode_build_request(path, query = query, timeout = timeout)
  resp <- encode_perform_with_retry(req)

  status <- httr2::resp_status(resp)
  body <- httr2::resp_body_string(resp)

  if (status >= 400L) {
    search_404 <- encode_parse_search_404(body, status, allow_search_404)
    if (!is.null(search_404)) {
      return(list(
        data = search_404,
        url = req$url,
        status_code = status,
        content_type = httr2::resp_content_type(resp),
        retrieved_at = Sys.time()
      ))
    }

    details <- encode_error_details(body)
    cli::cli_abort(
      encode_error_message(
        message = "ENCODE request failed with HTTP {status}.",
        url = req$url,
        details = details
      )
    )
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(body, simplifyVector = FALSE),
    error = function(cnd) {
      cli::cli_abort(
        c(
          "ENCODE returned malformed JSON.",
          "i" = "URL: {req$url}",
          "x" = "Response body could not be parsed as JSON."
        ),
        parent = cnd
      )
    }
  )

  list(
    data = parsed,
    url = req$url,
    status_code = status,
    content_type = httr2::resp_content_type(resp),
    retrieved_at = Sys.time()
  )
}

encode_parse_search_404 <- function(body, status, allow_search_404) {
  if (!isTRUE(allow_search_404) || status != 404L || !nzchar(body)) {
    return(NULL)
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(body, simplifyVector = FALSE),
    error = function(cnd) NULL
  )
  if (is.null(parsed)) {
    return(NULL)
  }

  is_search_response <- !is.null(parsed$`@graph`) ||
    identical(encode_scalar(parsed$title), "Search")
  if (!is_search_response) {
    return(NULL)
  }
  parsed
}

encode_perform_text <- function(path, query = list(), timeout = NULL) {
  req <- encode_build_request(
    path,
    query = query,
    timeout = timeout,
    accept = "text/tab-separated-values, text/plain, */*"
  )
  resp <- encode_perform_with_retry(req)
  status <- httr2::resp_status(resp)
  body <- httr2::resp_body_string(resp)

  if (status >= 400L) {
    details <- encode_error_details(body)
    cli::cli_abort(
      encode_error_message(
        message = "ENCODE request failed with HTTP {status}.",
        url = req$url,
        details = details
      )
    )
  }

  list(
    text = body,
    url = req$url,
    status_code = status,
    content_type = httr2::resp_content_type(resp),
    retrieved_at = Sys.time()
  )
}

encode_perform_file <- function(url, path, timeout = NULL) {
  req <- encode_build_request(
    url,
    timeout = timeout,
    accept = "application/octet-stream, */*"
  )
  resp <- encode_perform_with_retry(req, path = path)
  status <- httr2::resp_status(resp)

  if (status >= 400L) {
    body <- if (file.exists(path)) {
      paste(readLines(path, warn = FALSE, n = 20L), collapse = "\n")
    } else {
      ""
    }
    details <- encode_error_details(body)
    cli::cli_abort(
      encode_error_message(
        message = "ENCODE file download failed with HTTP {status}.",
        url = req$url,
        details = details
      )
    )
  }

  list(
    url = req$url,
    status_code = status,
    content_type = httr2::resp_content_type(resp),
    retrieved_at = Sys.time()
  )
}

encode_perform_with_retry <- function(req, path = NULL) {
  max_tries <- encode_option("encodeUtils.max_tries", 3)
  max_tries <- encode_validate_positive_whole_number(
    max_tries,
    "encodeUtils.max_tries"
  )
  last_error <- NULL

  for (attempt in seq_len(max_tries)) {
    encode_request_throttle()
    resp <- tryCatch(
      {
        if (is.null(path)) {
          httr2::req_perform(req)
        } else {
          httr2::req_perform(req, path = path)
        }
      },
      error = identity
    )

    if (inherits(resp, "condition")) {
      last_error <- resp
      resp <- NULL
    }

    if (is.null(resp)) {
      if (attempt < max_tries) {
        encode_retry_sleep(attempt)
        next
      }
      cli::cli_abort(
        c(
          "ENCODE request failed.",
          "x" = "The request could not be completed after {max_tries} attempts."
        ),
        parent = last_error
      )
    }

    status <- httr2::resp_status(resp)
    if (!encode_is_transient_status(status) || attempt == max_tries) {
      return(resp)
    }
    encode_retry_sleep(attempt, resp = resp)
  }

  resp
}

encode_retry_sleep <- function(attempt, resp = NULL) {
  delay <- encode_retry_after(resp)
  if (is.na(delay)) {
    base <- encode_option("encodeUtils.retry_base_seconds", 0.5)
    delay <- base * 2^(attempt - 1L)
  }
  if (!is.na(delay) && delay > 0) {
    Sys.sleep(delay)
  }
  invisible(delay)
}

encode_retry_after <- function(resp) {
  if (is.null(resp)) {
    return(NA_real_)
  }
  value <- httr2::resp_header(resp, "retry-after")
  if (is.null(value) || is.na(value) || !nzchar(value)) {
    return(NA_real_)
  }
  value <- trimws(value)
  if (grepl("^[0-9]+(?:[.][0-9]+)?$", value)) {
    return(as.numeric(value))
  }
  date <- tryCatch(
    as.POSIXct(value, format = "%a, %d %b %Y %H:%M:%S", tz = "GMT"),
    error = function(cnd) NA
  )
  if (is.na(date)) {
    return(NA_real_)
  }
  max(0, as.numeric(difftime(date, Sys.time(), units = "secs")))
}

encode_error_message <- function(message, url, details = "") {
  out <- c(message, stats::setNames(paste0("URL: ", url), "i"))
  if (nzchar(details)) {
    out <- c(out, stats::setNames(details, "x"))
  }
  out
}

encode_is_transient_status <- function(status) {
  status %in% c(429L, 500L, 502L, 503L, 504L)
}

encode_error_details <- function(body) {
  if (!nzchar(body)) {
    return("")
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(body, simplifyVector = FALSE),
    error = function(cnd) NULL
  )
  if (is.null(parsed)) {
    return(substr(body, 1L, 300L))
  }

  fields <- c(
    parsed$description,
    parsed$title,
    parsed$detail,
    parsed$notification,
    parsed$`@type`[[1L]]
  )
  fields <- unlist(fields, use.names = FALSE)
  fields <- fields[!is.na(fields) & nzchar(fields)]
  paste(unique(fields), collapse = " ")
}
