# ENCODE URL normalization

encode_normalize_path <- function(x) {
    if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
        cli::cli_abort("{.arg x} must be one non-empty string.")
    }

    if (grepl("^https?://", x)) {
        return(x)
    }

    if (grepl("^ENC[A-Z]{2}[0-9A-Z]+$", x)) {
        prefix <- substr(x, 1L, 5L)
        collection <- switch(prefix,
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

# Request construction and response parsing

encode_build_request <- function(
    path,
    query = list(),
    timeout = NULL,
    accept = "application/json"
) {
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
    req <- httr2::req_error(req, is_error = function(resp) FALSE)
    max_tries <- encode_validate_positive_whole_number(
        encode_option("encodeUtils.max_tries", 3L),
        "encodeUtils.max_tries"
    )
    req <- httr2::req_retry(
        req,
        max_tries = max_tries,
        retry_on_failure = TRUE,
        is_transient = function(resp) {
            httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
        }
    )
    rate <- encode_option("encodeUtils.rate_per_second", 5)
    if (!isFALSE(rate)) {
        if (!is.numeric(rate) || length(rate) != 1L || is.na(rate) ||
            !is.finite(rate) || rate < 0) {
            cli::cli_abort(
                "Option {.code encodeUtils.rate_per_second} must be FALSE or one finite non-negative number."
            )
        }
        if (rate > 0) {
            req <- httr2::req_throttle(req, rate = rate, fill_time_s = 1)
        }
    }
    req
}

encode_perform_json <- function(
    path,
    query = list(),
    timeout = NULL,
    allow_search_404 = FALSE
) {
    req <- encode_build_request(path, query = query, timeout = timeout)
    resp <- httr2::req_perform(req)

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
    # Treat only structured ENCODE search payloads as valid empty 404 responses.
    parsed
}

# File transfer

encode_perform_file <- function(url, path, timeout = NULL) {
    req <- encode_build_request(
        url,
        timeout = timeout,
        accept = "application/octet-stream, */*"
    )
    resp <- httr2::req_perform(req, path = path)
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

# HTTP error reporting

encode_error_message <- function(message, url, details = "") {
    out <- c(message, stats::setNames(paste0("URL: ", url), "i"))
    if (nzchar(details)) {
        out <- c(out, stats::setNames(details, "x"))
    }
    out
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
