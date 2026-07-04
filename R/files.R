#' List files for ENCODE experiments
#'
#' Return the files attached to one or more ENCODE experiments. This step is
#' metadata only: it reports file accessions, formats, sizes, assemblies,
#' checksums, and download links, but it does not download file contents.
#'
#' The default `limit = "all"` is intentional for file metadata. File selection
#' is safest when it can see the full set of files attached to the experiments
#' you already chose.
#'
#' @param x Experiment accession(s), experiment path(s), a search result from
#'   `encode_search()`, a record from `encode_get()`, or a data frame containing
#'   experiment identifiers.
#' @param file_format Optional file format filter, such as `"fastq"`, `"bed"`,
#'   `"bigWig"`, or `"tsv"`.
#' @param output_type Optional ENCODE output type filter, such as `"reads"` or
#'   `"gene quantifications"`.
#' @param assembly Optional genome assembly filter, such as `"GRCh38"` or
#'   `"mm10"`.
#' @param status Optional file status filter. Use `NULL` to omit.
#' @param limit Number of file records to request, or `"all"`.
#' @param metadata How much linked metadata to request. `"basic"` keeps
#'   file-list responses smaller. `"full"` requests more linked metadata for
#'   display.
#' @param max_experiments Maximum number of experiments accepted without
#'   `allow_many = TRUE`.
#' @param allow_many Whether to allow many experiment datasets in one query.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return A file metadata table. Printing shows the most useful file columns;
#'   `encode_results()` returns the full table.
#' @export
#'
#' @examples
#' # This mocked response keeps the example offline and runnable.
#' download_marker <- paste0(intToUtf8(64), intToUtf8(64), "download")
#' files_json <- paste0(
#'   '{"@graph":[{"accession":"ENCFF000AAA",',
#'   '"@id":"/files/ENCFF000AAA/",',
#'   '"dataset":"/experiments/ENCSR000AAA/",',
#'   '"file_format":"txt","output_type":"metadata",',
#'   '"file_size":3,',
#'   '"href":"/files/ENCFF000AAA/', download_marker, '/ENCFF000AAA.txt",',
#'   '"status":"released"}],"total":1}'
#' )
#' files <- httr2::with_mocked_responses(
#'   function(req) httr2::response(
#'     200,
#'     headers = "Content-Type: application/json",
#'     body = charToRaw(files_json)
#'   ),
#'   encode_list_files("ENCSR000AAA", file_format = "txt", quiet = TRUE)
#' )
#' files[, c("file_accession", "file_format", "file_size_pretty")]
#'
#' # Typical use after an experiment search:
#' # experiments <- encode_search(type = "Experiment", search = "mouse heart ChIP-seq")
#' # encode_list_files(experiments, file_format = "bed", assembly = "mm10")
#'
#' # Or list files from one known experiment:
#' # encode_list_files("ENCSR284QGB", file_format = "fastq")
encode_list_files <- function(
                              x,
                              file_format = NULL,
                              output_type = NULL,
                              assembly = NULL,
                              status = "released",
                              limit = "all",
                              metadata = c("basic", "full"),
                              max_experiments = 25,
                              allow_many = FALSE,
                              quiet = FALSE) {
  metadata_request <- encode_metadata_request(metadata)
  frame <- metadata_request$frame
  metadata <- metadata_request$metadata
  encode_validate_limit(limit)
  experiment_paths <- encode_experiment_paths(x)
  experiment_paths <- unique(experiment_paths[!is.na(experiment_paths) & nzchar(experiment_paths)])
  if (length(experiment_paths) == 0L) {
    cli::cli_abort("{.arg x} did not contain experiment accessions or paths.")
  }
  if (length(experiment_paths) > max_experiments && !isTRUE(allow_many)) {
    cli::cli_abort(
      c(
        "Refusing to list files for {length(experiment_paths)} experiments at once.",
        "i" = "Use {.code allow_many = TRUE} after narrowing the experiment set deliberately."
      )
    )
  }

  filters <- list(dataset = experiment_paths)
  if (!is.null(file_format)) {
    filters$file_format <- file_format
  }
  if (!is.null(output_type)) {
    filters$output_type <- output_type
  }
  if (!is.null(assembly)) {
    filters$assembly <- assembly
  }

  search_result <- encode_search(
    type = "File",
    filters = filters,
    status = status,
    limit = limit,
    metadata = metadata,
    include_facets = TRUE,
    quiet = TRUE
  )
  files <- encode_bind_rows(
    lapply(search_result$raw$`@graph` %||% list(), encode_flatten_file),
    names(encode_empty_results("File"))
  )
  files <- encode_attach_metadata(
    files,
    query_url = search_result$query_url,
    retrieved_at = search_result$request$retrieved_at,
    filters = search_result$filters
  )
  class(files) <- c("encode_file_table", "data.frame")
  attr(files, "total") <- search_result$total
  attr(files, "total_results") <- search_result$total
  attr(files, "url") <- search_result$url
  attr(files, "query_url") <- search_result$query_url
  attr(files, "retrieved_at") <- search_result$request$retrieved_at
  attr(files, "metadata") <- metadata
  attr(files, "frame") <- frame

  if (!isTRUE(quiet)) {
    known_size <- encode_size(files)
    cli::cli_inform(
      "ENCODE file listing successfully found {nrow(files)} file record(s) ({encode_pretty_bytes(known_size)} with known sizes)."
    )
    cli::cli_inform(
      "Returned a file metadata table. Print the result to view files, or use {.code encode_results()} for the table."
    )
  }
  files
}

encode_experiment_paths <- function(x) {
  if (inherits(x, "encode_search_result")) {
    return(encode_experiment_paths(x$results))
  }
  if (inherits(x, "encode_object")) {
    if (identical(x$type, "Experiment")) {
      return(encode_scalar(x$data$`@id`))
    }
    cli::cli_abort("{.arg x} is an ENCODE object, but it is not an Experiment.")
  }
  if (is.data.frame(x)) {
    if ("dataset" %in% names(x)) {
      return(as.character(x$dataset))
    }
    if ("id" %in% names(x)) {
      return(as.character(x$id))
    }
    if ("experiment_accession" %in% names(x)) {
      return(paste0("/experiments/", x$experiment_accession, "/"))
    }
    if ("accession" %in% names(x)) {
      accessions <- as.character(x$accession)
      accessions <- accessions[encode_is_experiment_accession(accessions)]
      return(paste0("/experiments/", accessions, "/"))
    }
    cli::cli_abort("{.arg x} data frame must contain dataset, id, experiment_accession, or accession.")
  }
  if (is.character(x)) {
    return(vapply(x, encode_as_experiment_path, character(1L)))
  }
  cli::cli_abort("{.arg x} must be experiment identifiers, an ENCODE result, an ENCODE object, or a data frame.")
}

encode_as_experiment_path <- function(x) {
  if (is.na(x) || !nzchar(x)) {
    return(NA_character_)
  }
  if (grepl("^https?://", x)) {
    x <- sub("^https?://[^/]+", "", x)
    x <- sub("[?].*$", "", x)
  }
  if (encode_is_experiment_accession(x)) {
    return(paste0("/experiments/", x, "/"))
  }
  if (grepl("^/experiments/[^/]+/?$", x)) {
    if (!grepl("/$", x)) {
      x <- paste0(x, "/")
    }
    return(x)
  }
  cli::cli_abort("Expected an ENCODE experiment accession or path, not {.val {x}}.")
}

encode_file_table_from_input <- function(x, status = "released") {
  if (inherits(x, "encode_selected_files")) {
    return(x$files)
  }
  if (inherits(x, "encode_file_table")) {
    return(x)
  }
  if (inherits(x, "encode_download_result")) {
    return(as.data.frame(x, stringsAsFactors = FALSE))
  }
  if (inherits(x, "encode_search_result")) {
    if (!"file_accession" %in% names(x$results) && !"href" %in% names(x$results)) {
      cli::cli_abort("{.arg x} search result does not contain file metadata.")
    }
    files <- x$results
    class(files) <- c("encode_file_table", "data.frame")
    return(files)
  }
  if (inherits(x, "encode_object")) {
    if (identical(x$type, "File")) {
      files <- encode_flatten_file(x$data)
      files <- encode_attach_metadata(
        files,
        query_url = x$query_url,
        retrieved_at = x$request$retrieved_at
      )
      class(files) <- c("encode_file_table", "data.frame")
      return(files)
    }
    if (identical(x$type, "Experiment")) {
      return(encode_list_files(x, status = status, quiet = TRUE))
    }
  }
  if (is.data.frame(x)) {
    if ("href" %in% names(x) || "file_accession" %in% names(x) || "accession" %in% names(x)) {
      files <- as.data.frame(x, stringsAsFactors = FALSE)
      class(files) <- c("encode_file_table", "data.frame")
      return(files)
    }
  }
  if (is.character(x)) {
    accessions <- vapply(x, encode_normalize_accession, character(1L))
    if (!all(encode_is_file_accession(accessions))) {
      cli::cli_abort("Character input to file operations must be ENCFF file accessions, paths, or URLs.")
    }
    search_result <- encode_search(
      type = "File",
      filters = list(accession = accessions),
      status = status,
      limit = "all",
      metadata = "basic",
      quiet = TRUE
    )
    files <- encode_bind_rows(
      lapply(search_result$raw$`@graph` %||% list(), encode_flatten_file),
      names(encode_empty_results("File"))
    )
    files <- encode_attach_metadata(
      files,
      query_url = search_result$query_url,
      retrieved_at = search_result$request$retrieved_at,
      filters = search_result$filters
    )
    class(files) <- c("encode_file_table", "data.frame")
    return(files)
  }
  cli::cli_abort("{.arg x} could not be converted to an ENCODE file metadata table.")
}
