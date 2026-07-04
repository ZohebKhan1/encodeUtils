# Print methods.

#' @export
names.encode_search_result <- function(x) {
  c("results", "total_results", "query_url", "metadata", "requested_limit")
}

#' @export
names.encode_object <- function(x) {
  c("summary", "type", "accession", "query_url", "metadata")
}

#' @export
names.encode_matrix_result <- function(x) {
  c("matrix", "assay_summary", "biosample_summary", "total_results", "query_url")
}

#' @export
names.encode_report_result <- function(x) {
  c("report", "endpoint", "query_url")
}

#' @export
names.encode_schema_result <- function(x) {
  c("properties", "title", "id", "query_url")
}

#' @export
names.encode_selected_files <- function(x) {
  c("files", "excluded", "criteria")
}

#' @export
names.encode_download_plan <- function(x) {
  c("files", "summary", "largest_files", "required_overrides")
}

#' @export
names.encode_loaded_files <- function(x) {
  c("files", "metadata", "data", "matrices", "by_experiment")
}

#' @export
print.encode_search_result <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE search")
  cli::cli_text("- total matches: {.val {x$total}}")
  cli::cli_text("- returned: {.val {nrow(x$results)}}")
  encode_print_table("Results", encode_result_display(x$results))
  if (isTRUE(verbose)) {
    cli::cli_text("- URL: {x$query_url %||% x$url}")
    encode_print_table("Active filters", x$filters)
    encode_print_table("Top facets", encode_top_facets(x$facets))
  }
  invisible(x)
}

#' @export
print.encode_experiment_table <- function(x, ...) {
  cli::cli_text("ENCODE experiments")
  cli::cli_text("- experiments: {.val {nrow(x)}}")
  encode_print_table("Experiments", encode_experiment_display(x))
  invisible(x)
}

#' @export
print.encode_object <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE record")
  cli::cli_text("- type: {.val {x$type}}")
  encode_print_table("Summary", encode_result_display(x$summary))
  if (isTRUE(verbose)) {
    cli::cli_text("URL: {x$url}")
  }
  invisible(x)
}

#' @export
print.encode_matrix_result <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE matrix")
  cli::cli_text("- total represented: {.val {x$total}}")
  encode_print_table("Top assays", utils::head(x$assay_summary, 10L))
  encode_print_table("Top biosamples", encode_matrix_biosample_display(x$biosample_summary))
  if (isTRUE(verbose)) {
    cli::cli_text("- URL: {x$query_url %||% x$url}")
    encode_print_table("Active filters", x$filters)
  }
  invisible(x)
}

#' @export
print.encode_report_result <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE report")
  cli::cli_text("Endpoint: {.val {x$endpoint}}")
  cli::cli_text("Rows: {.val {nrow(x$report)}}")
  encode_print_table("Report", x$report)
  if (isTRUE(verbose)) {
    cli::cli_text("URL: {x$url}")
  }
  invisible(x)
}

#' @export
print.encode_schema_result <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE schema")
  cli::cli_text("Title: {.val {x$title}}")
  encode_print_table("Properties", x$properties)
  if (isTRUE(verbose)) {
    cli::cli_text("URL: {x$url}")
  }
  invisible(x)
}

#' @export
print.encode_file_table <- function(x, ..., verbose = FALSE) {
  summary <- encode_file_summary(x)
  cli::cli_text("ENCODE files")
  cli::cli_text("- files: {.val {summary$n_files}}")
  if ("experiment_accession" %in% names(x)) {
    cli::cli_text("- experiments: {.val {summary$n_experiments}}")
  }
  if ("file_size" %in% names(x)) {
    cli::cli_text("- known total size: {.val {summary$total_size_pretty}}")
  }
  encode_print_table("Files", encode_display_columns(x, encode_file_display_columns()))
  if (isTRUE(verbose)) {
    encode_print_table("Formats", summary$formats)
    encode_print_table("Assemblies", summary$assemblies)
    encode_print_table("Output types", summary$output_types)
  }
  invisible(x)
}

#' @export
print.encode_selected_files <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE selected files")
  cli::cli_text("- selected: {.val {nrow(x$files)}}")
  cli::cli_text("- excluded: {.val {nrow(x$excluded)}}")
  encode_print_table("Selected files", encode_display_columns(x$files, encode_file_display_columns()))
  if (isTRUE(verbose)) {
    encode_print_table("Criteria", encode_filter_table(x$criteria))
    encode_print_table("Exclusion reasons", encode_exclusion_summary(x$excluded))
  }
  invisible(x)
}

#' @export
print.encode_download_plan <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE download plan")
  cli::cli_text("- files: {.val {x$summary$n_files}}")
  cli::cli_text("- known total size: {.val {x$summary$known_total_size_pretty}}")
  cli::cli_text("- unknown-size files: {.val {x$summary$unknown_size_count}}")
  if (NROW(x$required_overrides) == 0L) {
    cli::cli_text("- required overrides: none")
  } else {
    encode_print_table("Required overrides", x$required_overrides)
  }
  encode_print_table(
    "Largest files",
    encode_display_columns(x$largest_files, encode_file_display_columns())
  )
  if (isTRUE(verbose)) {
    cli::cli_text("- checksums available: {.val {x$summary$checksums_available}}")
    cli::cli_text("- destination directories: {.val {x$summary$destination_count}}")
    encode_print_table("Files", encode_display_columns(x$files, encode_file_display_columns()))
  }
  invisible(x)
}

#' @export
print.encode_loaded_files <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE loaded files")
  cli::cli_text("- files: {.val {nrow(x$files)}}")
  cli::cli_text("- file objects: {.val {length(x$data)}}")
  cli::cli_text("- matrices: {.val {length(x$matrices)}}")
  cli::cli_text("- experiments: {.val {length(x$by_experiment)}}")
  encode_print_table("Metadata", encode_display_columns(x$metadata, encode_file_display_columns()))
  if (isTRUE(verbose)) {
    objects <- data.frame(
      name = names(x$data),
      class = vapply(x$data, function(value) paste(class(value), collapse = ", "), character(1L)),
      stringsAsFactors = FALSE
    )
    encode_print_table("Loaded objects", objects, n = length(objects$name))
  }
  invisible(x)
}

#' @export
`[.encode_file_table` <- function(x, i, j, drop = FALSE) {
  out <- NextMethod("[")
  if (!is.data.frame(out)) {
    return(out)
  }
  if (!missing(j) && !all(encode_file_core_columns() %in% names(out))) {
    class(out) <- setdiff(class(out), "encode_file_table")
  }
  out
}

#' @export
print.encode_file_summary <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE file summary")
  cli::cli_text("- files: {.val {x$n_files}}")
  cli::cli_text("- experiments: {.val {x$n_experiments}}")
  cli::cli_text("- known total size: {.val {x$total_size_pretty}}")
  encode_print_table("Formats", x$formats)
  if (isTRUE(verbose)) {
    encode_print_table("Assemblies", x$assemblies)
    encode_print_table("Output types", x$output_types)
  }
  invisible(x)
}

#' @export
print.encode_manifest <- function(x, ..., verbose = FALSE) {
  cli::cli_text("ENCODE manifest")
  cli::cli_text("- package: {.val {x$package$name}} {.val {x$package$version}}")
  cli::cli_text("- date: {.val {x$retrieval$date}}")
  if (isTRUE(verbose)) {
    cli::cli_text("- query URL: {x$retrieval$query_url}")
  }
  invisible(x)
}

#' @export
print.encode_local_file <- function(x, ...) {
  cli::cli_text("<encode_local_file>")
  cli::cli_text("Path: {.path {x$path}}")
  cli::cli_text("Reason: {x$reason}")
  cli::cli_text("Size: {.val {x$file_size_pretty}}")
  invisible(x)
}

encode_print_table <- function(label, table, n = 10L) {
  if (is.null(table) || NROW(table) == 0L) {
    cli::cli_text("{label}: no rows.")
    return(invisible(NULL))
  }
  cli::cli_text("{label}:")
  display <- utils::head(table, n)
  if (is.data.frame(display)) {
    class(display) <- "data.frame"
  }
  print(display, row.names = FALSE)
  invisible(NULL)
}

encode_file_core_columns <- function() {
  c(
    "file_accession", "experiment_accession", "file_format", "output_type",
    "assembly", "file_size"
  )
}

encode_file_display_columns <- function() {
  c(
    experiment = "experiment_accession",
    dataset_type = "dataset_type",
    file = "file_accession",
    assay = "assay_title",
    target = "target",
    control_type = "control_type",
    organism = "organism",
    biosample = "biosample_term_name",
    biosample_type = "biosample_type",
    age = "life_stage_age",
    sex = "sex",
    sample = "sample_summary",
    treatment = "treatment",
    lab = "lab",
    project = "project",
    format = "file_format",
    output = "output_type",
    assembly = "assembly",
    analysis = "analysis_accession",
    file_size = "file_size_pretty",
    date_released = "date_released",
    status = "status",
    local_path = "local_path"
  )
}

encode_experiment_display_columns <- function() {
  c(
    experiment = "accession",
    assay = "assay_title",
    target = "target",
    control_type = "control_type",
    organism = "organism",
    biosample = "biosample_term_name",
    biosample_type = "biosample_classification",
    age = "life_stage_age",
    sex = "sex",
    sample = "sample_summary",
    treatment = "treatment",
    lab = "lab",
    project = "project",
    files = "file_count",
    date_released = "date_released",
    status = "status"
  )
}

encode_result_display <- function(x) {
  if (inherits(x, "encode_file_table") ||
    (is.data.frame(x) && "file_accession" %in% names(x))) {
    return(encode_display_columns(x, encode_file_display_columns()))
  }
  if (inherits(x, "encode_experiment_table") ||
    (is.data.frame(x) && "assay_title" %in% names(x) && "file_count" %in% names(x))) {
    return(encode_experiment_display(x))
  }
  x
}

encode_experiment_display <- function(x) {
  encode_display_columns(x, encode_experiment_display_columns())
}

encode_matrix_biosample_display <- function(x) {
  encode_display_columns(
    x,
    c(
      biosample_type = "biosample_classification",
      biosample = "biosample_term_name",
      n = "n",
      biosample_type_n = "classification_n"
    )
  )
}

encode_display_columns <- function(x, columns) {
  if (!is.data.frame(x)) {
    return(x)
  }
  source_columns <- unname(columns)
  display_names <- names(columns)
  display_names[!nzchar(display_names)] <- source_columns[!nzchar(display_names)]
  keep <- intersect(source_columns, names(x))
  if (length(keep) == 0L) {
    return(x)
  }
  labels <- display_names[match(keep, source_columns)]
  out <- as.data.frame(x, stringsAsFactors = FALSE)
  out <- out[, keep, drop = FALSE]
  names(out) <- labels
  available <- vapply(out, encode_display_column_available, logical(1L))
  out <- out[, available, drop = FALSE]
  out
}

encode_display_column_available <- function(x) {
  if (length(x) == 0L) {
    return(TRUE)
  }
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.character(x)) {
    return(any(!is.na(x) & nzchar(x)))
  }
  any(!is.na(x))
}

encode_top_facets <- function(facets) {
  if (is.null(facets) || NROW(facets) == 0L) {
    return(facets)
  }
  facets[order(facets$count, decreasing = TRUE), , drop = FALSE]
}

encode_exclusion_summary <- function(excluded) {
  if (is.null(excluded) || nrow(excluded) == 0L || !"reason" %in% names(excluded)) {
    return(data.frame(reason = character(), n = integer()))
  }
  reasons <- strsplit(excluded$reason, "; ", fixed = TRUE)
  reasons <- unlist(reasons, use.names = FALSE)
  reasons <- reasons[!is.na(reasons) & nzchar(reasons)]
  if (length(reasons) == 0L) {
    return(data.frame(reason = character(), n = integer()))
  }
  counts <- sort(table(reasons), decreasing = TRUE)
  data.frame(
    reason = names(counts),
    n = as.integer(counts),
    stringsAsFactors = FALSE
  )
}
