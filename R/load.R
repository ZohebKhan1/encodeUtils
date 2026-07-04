# Loaded-download helpers.

encode_load_downloaded_files <- function(
                                         files,
                                         max_size = "100MB",
                                         format = NULL,
                                         region = NULL,
                                         allow_large = FALSE,
                                         unsupported = c("return_path", "error"),
                                         assign = FALSE,
                                         envir = parent.frame(),
                                         quiet = FALSE) {
  unsupported <- match.arg(unsupported)
  files <- as.data.frame(files, stringsAsFactors = FALSE)
  if (!"local_path" %in% names(files)) {
    cli::cli_abort("Downloaded file metadata must include {.field local_path}.")
  }
  if ("download_status" %in% names(files)) {
    readable <- files$download_status %in% c("downloaded", "exists")
    if (!all(readable)) {
      bad <- files$file_accession[!readable]
      cli::cli_abort(
        "Cannot read failed or unplanned download rows: {.val {paste(bad, collapse = ', ')}}."
      )
    }
  }

  data <- vector("list", nrow(files))
  names(data) <- encode_loaded_file_names(files)
  for (i in seq_len(nrow(files))) {
    row <- files[i, , drop = FALSE]
    row_format <- encode_row_read_format(row, format)
    data[[i]] <- encode_read(
      row$local_path[[1L]],
      format = row_format,
      max_size = max_size,
      region = region,
      allow_large = allow_large,
      unsupported = unsupported
    )
  }

  by_experiment <- encode_group_loaded_by_experiment(files, data)
  result <- list(
    files = files,
    metadata = encode_loaded_metadata(files),
    data = data,
    matrices = encode_tabular_matrices(data, files),
    by_experiment = by_experiment
  )
  class(result) <- c("encode_loaded_files", "list")

  if (isTRUE(assign)) {
    encode_assign_loaded_files(result, envir = envir)
  }
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "Loaded {length(data)} ENCODE file object(s). Use {.code x$data} for file objects and {.code x$by_experiment} for experiment groups."
    )
  }
  result
}

encode_loaded_file_names <- function(files) {
  names <- if ("file_accession" %in% names(files)) {
    files$file_accession
  } else if ("accession" %in% names(files)) {
    files$accession
  } else {
    tools::file_path_sans_ext(basename(files$local_path))
  }
  names <- encode_valid_object_names(names)
  names[duplicated(names)] <- paste0(names[duplicated(names)], "_", seq_len(sum(duplicated(names))))
  names
}

encode_valid_object_names <- function(x) {
  x <- as.character(x)
  x[is.na(x) | !nzchar(x)] <- "encode_object"
  x <- gsub("[^A-Za-z0-9_.]", "_", x)
  starts_bad <- !grepl("^[A-Za-z.]", x) | grepl("^[.][0-9]", x)
  x[starts_bad] <- paste0("x_", x[starts_bad])
  make.unique(x, sep = "_")
}

encode_row_read_format <- function(row, format) {
  if (!is.null(format)) {
    return(format)
  }
  if ("file_format" %in% names(row) && !is.na(row$file_format[[1L]]) && nzchar(row$file_format[[1L]])) {
    return(row$file_format[[1L]])
  }
  NULL
}

encode_loaded_metadata <- function(files) {
  columns <- c(
    "experiment_accession", "dataset_type", "file_accession", "assay_title",
    "target", "control_type", "organism", "biosample_term_name",
    "biosample_type", "life_stage_age", "sex", "sample_summary", "treatment",
    "file_format", "file_type", "output_type", "assembly",
    "analysis_accession", "file_size_pretty", "status", "download_status",
    "local_path"
  )
  encode_display_columns(files, stats::setNames(columns, columns))
}

encode_group_loaded_by_experiment <- function(files, data) {
  if (!"experiment_accession" %in% names(files)) {
    return(list())
  }
  experiments <- files$experiment_accession
  experiments[is.na(experiments) | !nzchar(experiments)] <- "unknown_experiment"
  experiment_names <- unique(experiments)
  groups <- vector("list", length(experiment_names))
  names(groups) <- encode_valid_object_names(experiment_names)
  for (i in seq_along(experiment_names)) {
    keep <- experiments == experiment_names[[i]]
    group_files <- files[keep, , drop = FALSE]
    group_data <- data[keep]
    groups[[i]] <- list(
      files = group_files,
      metadata = encode_loaded_metadata(group_files),
      data = group_data,
      matrices = encode_tabular_matrices(group_data, group_files)
    )
    class(groups[[i]]) <- c("encode_loaded_experiment", "list")
  }
  groups
}

encode_tabular_matrices <- function(data, files) {
  tabular <- vapply(data, is.data.frame, logical(1L))
  if (!any(tabular)) {
    return(list())
  }
  data <- data[tabular]
  files <- files[tabular, , drop = FALSE]
  if (length(data) == 0L) {
    return(list())
  }
  feature <- encode_common_feature_column(data)
  if (is.na(feature)) {
    return(list())
  }
  numeric_columns <- Reduce(
    intersect,
    lapply(data, function(x) names(x)[vapply(x, is.numeric, logical(1L))])
  )
  numeric_columns <- setdiff(numeric_columns, feature)
  if (length(numeric_columns) == 0L) {
    return(list())
  }
  matrices <- vector("list", length(numeric_columns))
  names(matrices) <- encode_valid_object_names(numeric_columns)
  for (i in seq_along(numeric_columns)) {
    matrices[[i]] <- encode_merge_numeric_column(
      data = data,
      files = files,
      feature = feature,
      value = numeric_columns[[i]]
    )
  }
  matrices
}

encode_common_feature_column <- function(data) {
  candidates <- c(
    "gene_id", "gene_name", "gene", "transcript_id", "transcript_name",
    "id", "name", "chrom", "chr"
  )
  common <- Reduce(intersect, lapply(data, names))
  found <- candidates[candidates %in% common]
  if (length(found) == 0L) {
    return(NA_character_)
  }
  found[[1L]]
}

encode_merge_numeric_column <- function(data, files, feature, value) {
  pieces <- vector("list", length(data))
  labels <- encode_loaded_file_names(files)
  for (i in seq_along(data)) {
    piece <- data[[i]][, c(feature, value), drop = FALSE]
    names(piece) <- c(feature, labels[[i]])
    pieces[[i]] <- piece
  }
  Reduce(function(x, y) merge(x, y, by = feature, all = TRUE), pieces)
}

encode_assign_loaded_files <- function(x, envir) {
  if (!is.environment(envir)) {
    cli::cli_abort("{.arg envir} must be an environment.")
  }
  for (name in names(x$data)) {
    base::assign(name, x$data[[name]], envir = envir)
  }
  for (name in names(x$by_experiment)) {
    base::assign(name, x$by_experiment[[name]], envir = envir)
  }
  invisible(x)
}
