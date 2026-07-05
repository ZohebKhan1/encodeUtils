#' List files for ENCODE experiments
#'
#' Return file metadata for one or more ENCODE experiments. The table includes
#' file accessions, formats, output types, assemblies, sizes, checksums, and
#' download links. It does not download file contents.
#'
#' The default `limit = "all"` requests the complete file list for the selected
#' experiments.
#'
#' @param x Experiment accession(s), experiment path(s), a search result from
#'   `encode_search()`, or a data frame containing experiment identifiers.
#' @param file_format Optional file format filter, such as `"fastq"`, `"bed"`,
#'   `"bigWig"`, or `"tsv"`.
#' @param output_type Optional ENCODE output type filter, such as `"reads"` or
#'   `"gene quantifications"`.
#' @param assembly Optional genome assembly filter, such as `"GRCh38"` or
#'   `"mm10"`.
#' @param status Optional file status filter. Use `NULL` to omit.
#' @param limit Number of file records to request, or `"all"`.
#' @param metadata Amount of linked metadata to request. `"basic"` keeps
#'   responses smaller. `"full"` adds more display columns.
#' @param max_experiments Maximum number of experiments accepted without
#'   `allow_many = TRUE`. This guard prevents accidental broad file-listing
#'   queries.
#' @param allow_many Whether to allow many experiment datasets in one query.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return An `encode_file_table` data frame. Common columns include
#'   `file_accession`, `experiment_accession`, `dataset_accession`,
#'   `file_format`, `output_type`, `assembly`, `file_size`, `md5sum`, `href`,
#'   `cloud_url`, and parent experiment metadata when available. The function
#'   lists metadata only; it does not download file contents.
#' @export
#'
#' @examples
#' files <- try(
#'   encode_list_files(
#'     "ENCSR083OKX",
#'     file_format = "tsv",
#'     output_type = "gene quantifications",
#'     assembly = "mm10",
#'     quiet = TRUE
#'   ),
#'   silent = TRUE
#' )
#' if (!inherits(files, "try-error")) {
#'   encode_results(files)
#' }
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
        "i" = "Use {.code allow_many = TRUE} after narrowing the experiment set."
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
  experiment_metadata <- encode_fetch_experiment_metadata_for_files(experiment_paths, metadata = metadata)
  files <- encode_fill_file_experiment_metadata(files, experiment_metadata)
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
    if (nrow(files) == 0L) {
      cli::cli_inform(c(
        "ENCODE file listing found no matching file records.",
        "i" = "Try loosening {.arg file_format}, {.arg output_type}, {.arg assembly}, or {.arg status}."
      ))
    } else {
      cli::cli_inform(
        "ENCODE file listing returned {nrow(files)} file record(s) ({encode_pretty_bytes(known_size)} with known sizes)."
      )
      cli::cli_inform(
        "Returned a file metadata table. Print the result to view files, or use {.code encode_results()} for the table."
      )
    }
  }
  files
}

encode_fetch_experiment_metadata_for_files <- function(experiment_paths, metadata = "basic") {
  accessions <- vapply(experiment_paths, encode_accession_from_path, character(1L))
  accessions <- unique(accessions[encode_is_experiment_accession(accessions)])
  if (length(accessions) == 0L) {
    return(encode_empty_results("Experiment"))
  }
  chunks <- split(accessions, ceiling(seq_along(accessions) / 100L))
  results <- lapply(seq_along(chunks), function(i) {
    chunk <- chunks[[i]]
    result <- tryCatch(
      encode_search(
        type = "Experiment",
        filters = list(accession = chunk),
        status = NULL,
        limit = "all",
        metadata = metadata,
        include_facets = FALSE,
        quiet = TRUE
      ),
      error = function(cnd) {
        return(list(
          data = encode_empty_results("Experiment"),
          error = conditionMessage(cnd)
        ))
      }
    )
    if (is.list(result) && !is.null(result$error)) {
      return(result)
    }
    list(data = encode_results(result), error = NA_character_)
  })
  errors <- unique(vapply(results, `[[`, character(1L), "error"))
  errors <- errors[!is.na(errors) & nzchar(errors)]
  if (length(errors) > 0L) {
    cli::cli_warn(c(
      "Could not retrieve parent experiment metadata for some ENCODE file records.",
      "i" = "File rows are still returned, but provenance columns may be incomplete.",
      "x" = errors[[1L]]
    ))
  }
  experiments <- encode_bind_rows(
    lapply(results, `[[`, "data"),
    names(encode_empty_results("Experiment"))
  )
  if (nrow(experiments) == 0L) {
    experiments <- encode_empty_results("Experiment")
    attr(experiments, "metadata_enrichment_error") <- errors
    return(experiments)
  }
  experiments <- experiments[!duplicated(experiments$accession), , drop = FALSE]
  attr(experiments, "metadata_enrichment_error") <- errors
  experiments
}

encode_enrich_file_table_from_parent_experiments <- function(files, metadata = "basic") {
  if (!is.data.frame(files) || nrow(files) == 0L) {
    return(files)
  }
  if (!encode_file_table_needs_parent_metadata(files)) {
    return(files)
  }
  experiment_paths <- encode_experiment_paths_from_file_table(files)
  experiments <- encode_fetch_experiment_metadata_for_files(experiment_paths, metadata = "full")
  files <- encode_fill_file_experiment_metadata(files, experiments)
  errors <- attr(experiments, "metadata_enrichment_error", exact = TRUE)
  if (!is.null(errors) && length(errors) > 0L) {
    attr(files, "metadata_enrichment_error") <- errors
  }
  files
}

encode_file_table_needs_parent_metadata <- function(files) {
  columns <- intersect(
    c("organism", "biosample_term_name", "biosample_type", "sample_summary", "assay_title"),
    names(files)
  )
  if (length(columns) == 0L) {
    return(FALSE)
  }
  any(vapply(files[columns], encode_any_missing_text, logical(1L)))
}

encode_any_missing_text <- function(x) {
  missing <- is.na(x) | !nzchar(as.character(x))
  any(missing, na.rm = TRUE)
}

encode_experiment_paths_from_file_table <- function(files) {
  paths <- character()
  if ("dataset" %in% names(files)) {
    paths <- c(paths, as.character(files$dataset))
  }
  if ("experiment_accession" %in% names(files)) {
    accessions <- as.character(files$experiment_accession)
    accessions <- accessions[encode_is_experiment_accession(accessions)]
    paths <- c(paths, paste0("/experiments/", accessions, "/"))
  }
  paths <- unique(paths[!is.na(paths) & nzchar(paths)])
  paths[grepl("^/experiments/", paths)]
}

encode_fill_file_experiment_metadata <- function(files, experiments) {
  if (!is.data.frame(files) || nrow(files) == 0L ||
    !is.data.frame(experiments) || nrow(experiments) == 0L ||
    !"experiment_accession" %in% names(files) ||
    !"accession" %in% names(experiments)) {
    return(files)
  }
  experiment_rows <- match(files$experiment_accession, experiments$accession)
  mapped <- c(
    assay_title = "assay_title",
    assay_term_name = "assay_term_name",
    target = "target",
    control_type = "control_type",
    organism = "organism",
    sample_summary = "sample_summary",
    life_stage_age = "life_stage_age",
    sex = "sex",
    treatment = "treatment",
    biosample_summary = "biosample_summary",
    biosample_type = "biosample_classification",
    biosample_term_name = "biosample_term_name",
    lab = "lab",
    institution = "institution",
    project = "project",
    award = "award"
  )
  for (file_column in names(mapped)) {
    experiment_column <- mapped[[file_column]]
    if (!file_column %in% names(files) || !experiment_column %in% names(experiments)) {
      next
    }
    values <- experiments[[experiment_column]][experiment_rows]
    replace <- is.na(files[[file_column]]) | !nzchar(as.character(files[[file_column]]))
    replace[is.na(replace)] <- TRUE
    files[[file_column]][replace] <- values[replace]
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
      files <- encode_enrich_file_table_from_parent_experiments(files, metadata = "basic")
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
    files <- encode_results(search_result)
    class(files) <- c("encode_file_table", "data.frame")
    return(files)
  }
  cli::cli_abort("{.arg x} could not be converted to an ENCODE file metadata table.")
}
