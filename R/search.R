#' Search ENCODE metadata
#'
#' Search ENCODE records with exact Portal filter fields. The result contains a
#' flattened table, match count, active filters, facets, and request provenance.
#' It does not download files.
#'
#' @param type ENCODE object type, such as `"Experiment"` or `"File"`. Use
#'   `NULL` only for mixed free-text searches.
#' @param filters Named list of ENCODE search fields and values. Dot notation
#'   and negated fields such as `"control_type!="` are accepted.
#' @param search Optional free-text search term.
#' @param status Optional ENCODE status. The default keeps released records;
#'   use `NULL` to omit this filter.
#' @param limit Number of records to return, or `"all"`.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return An `encode_search_result` list. Use `encode_results()` to extract
#'   its flattened result table.
#' @export
#'
#' @examples
#' experiments <- encode_search(
#'     filters = list(
#'         assay_title = "microRNA-seq",
#'         "biosample_ontology.organ_slims" = "heart"
#'     ),
#'     limit = 1,
#'     quiet = TRUE
#' )
#'
#' encode_results(experiments)
encode_search <- function(
    type = "Experiment",
    filters = list(),
    search = NULL,
    status = "released",
    limit = 25,
    quiet = FALSE
) {
    type <- encode_validate_scalar(type, "type")
    search <- encode_validate_scalar(search, "search")
    status <- encode_validate_values(status, "status")
    quiet <- encode_validate_flag(quiet, "quiet")
    encode_validate_filters(filters)
    encode_validate_limit(limit)
    encode_validate_search_filters(filters)

    query <- encode_search_query(
        type = type,
        filters = filters,
        search = search,
        status = status,
        limit = limit
    )
    if (!quiet) {
        cli::cli_inform(
            "Querying ENCODE search ({.field {type %||% 'mixed'}}, limit {.val {limit}})."
        )
    }

    response <- encode_perform_json(
        "/search/",
        query = query,
        allow_search_404 = TRUE
    )
    graph <- response$data$`@graph` %||% list()
    active_filters <- encode_active_filters(response$data, query)
    request_history <- list(encode_request_record(response, query))
    results <- encode_flatten_search_results(graph, type = type)
    results <- encode_attach_metadata(
        results,
        query_url = response$url,
        retrieved_at = response$retrieved_at,
        filters = active_filters,
        request_history = request_history
    )
    if (identical(type, "File")) {
        class(results) <- c("encode_file_table", "data.frame")
    }

    result <- list(
        results = results,
        total = encode_total(response$data, graph),
        filters = active_filters,
        facets = encode_facets(response$data),
        query_url = response$url,
        encode_base_url = encode_base_url(),
        request = response[c("status_code", "content_type", "retrieved_at")],
        request_history = request_history
    )
    class(result) <- c("encode_search_result", "list")

    if (!quiet) {
        cli::cli_inform(
            "ENCODE search returned {nrow(results)} of {result$total} matching record(s)."
        )
    }
    result
}

encode_validate_search_filters <- function(filters) {
    reserved <- intersect(
        sub("!=$", "!", names(filters)),
        c("type", "status", "searchTerm", "limit", "format", "frame")
    )
    if (length(reserved) > 0L) {
        cli::cli_abort(
            "Pass reserved search field(s) through their named arguments, not {.arg filters}: {.field {paste(reserved, collapse = ', ')}}."
        )
    }
    invisible(filters)
}

encode_search_query <- function(type, filters, search, status, limit) {
    query <- list(format = "json", frame = "embedded")
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

encode_request_record <- function(response, query, role = "search") {
    list(
        role = role,
        url = response$url,
        status_code = response$status_code,
        content_type = response$content_type,
        retrieved_at = encode_manifest_timestamp(response$retrieved_at),
        query = encode_filter_table(query)
    )
}
