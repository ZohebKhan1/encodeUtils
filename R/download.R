#' Download ENCODE files
#'
#' Download files from an ENCODE file table, selected-file object, file search,
#' or file accession. Planned sizes are checked before transfer, existing files
#' are not overwritten by default, files are written through a temporary `.part`
#' path, and size/MD5 checks are used when ENCODE provides the metadata.
#'
#' @param x ENCFF accession(s), file metadata table, file search result, file
#'   object, selected-file object, or experiment object.
#' @param file_accession Optional ENCODE file accession(s), such as
#'   `"ENCFF260OJQ"`, to download from `x`. Use this when you want specific
#'   files rather than the first `n` rows.
#' @param n Optional number of files to use from the top of `x`.
#' @param directory Destination directory. If `NULL`, a package cache directory
#'   from `tools::R_user_dir("encodeUtils", "cache")` is used.
#' @param cache Whether `directory = NULL` should use the package cache. If
#'   `FALSE`, a session temporary directory is used.
#' @param max_file_size Maximum allowed size per file, as bytes or a string like
#'   `"500MB"`.
#' @param max_total_size Maximum allowed total size, as bytes or a string.
#' @param allow_unknown_size Whether to allow real downloads for files whose
#'   ENCODE metadata do not include `file_size`. Dry-runs are always allowed and
#'   report the unknown-size count.
#' @param overwrite Whether existing destination files may be replaced.
#' @param dry_run If `TRUE`, return the planned download table without
#'   downloading.
#' @param read If `TRUE`, read downloaded files into R after a successful
#'   transfer. This is intended for small tabular files and supported local
#'   genomic formats.
#' @param read_max_size Maximum file size to read into memory when
#'   `read = TRUE`.
#' @param read_format Optional file format override used when `read = TRUE`.
#'   Leave as `NULL` to use ENCODE file metadata or the file extension.
#' @param read_region Optional genomic range passed to `encode_read()` for
#'   indexed genomic formats.
#' @param read_allow_large Whether `read = TRUE` may fully import indexed files
#'   such as bigWig or bigBed without `read_region`.
#' @param read_unsupported What to do when a downloaded file cannot be read
#'   directly: return a path object or throw an error.
#' @param assign If `TRUE`, assign loaded file objects and experiment groups
#'   into `envir`. The default is `FALSE` so scripts stay explicit.
#' @param envir Environment used when `assign = TRUE`.
#' @param prefer_cloud Whether to prefer ENCODE cloud URLs when available.
#' @param verify Verification checks to perform. Supported values are `"md5"`
#'   and `"size"`. Use `NULL` to record downloads without size or MD5
#'   verification.
#' @param quiet If `FALSE`, print concise progress messages.
#'
#' @return A download-result table with local paths, download status, observed
#'   file sizes, and verification columns.
#' @export
#'
#' @examples
#' download_marker <- paste0(intToUtf8(64), intToUtf8(64), "download")
#' files <- data.frame(
#'   file_accession = "ENCFF000AAA",
#'   href = paste0(
#'     "/files/ENCFF000AAA/",
#'     download_marker,
#'     "/ENCFF000AAA.txt"
#'   ),
#'   file_size = 3,
#'   md5sum = NA_character_
#' )
#' encode_download(files, directory = tempdir(), dry_run = TRUE, quiet = TRUE)
#' encode_download(files, n = 1, directory = tempdir(), dry_run = TRUE, quiet = TRUE)
#'
#' # Live ENCODE example:
#' # files <- encode_list_files("ENCSR284QGB", file_format = "fastq")
#' # selected <- encode_select_files(files, preset = "raw_fastq")
#' # encode_download(selected, directory = "data/encode", dry_run = TRUE)
#' # downloaded <- encode_download(selected, directory = "data/encode")
encode_download <- function(
                            x,
                            file_accession = NULL,
                            n = NULL,
                            directory = NULL,
                            cache = TRUE,
                            max_file_size = "2GB",
                            max_total_size = "5GB",
                            allow_unknown_size = FALSE,
                            overwrite = FALSE,
                            dry_run = FALSE,
                            read = FALSE,
                            read_max_size = "100MB",
                            read_format = NULL,
                            read_region = NULL,
                            read_allow_large = FALSE,
                            read_unsupported = c("return_path", "error"),
                            assign = FALSE,
                            envir = parent.frame(),
                            prefer_cloud = FALSE,
                            verify = c("md5", "size"),
                            quiet = FALSE) {
  verify <- encode_normalize_verify(verify)
  read_unsupported <- match.arg(read_unsupported)
  if (isTRUE(read) && isTRUE(dry_run)) {
    cli::cli_abort("Use either {.code dry_run = TRUE} or {.code read = TRUE}, not both.")
  }
  files <- encode_file_table_from_input(x, status = NULL)
  files <- encode_filter_file_accessions(files, file_accession)
  files <- encode_limit_file_rows(files, n = n, file_accession = file_accession)
  if (nrow(files) == 0L) {
    cli::cli_abort("{.arg x} did not contain any files to download.")
  }
  files <- encode_prepare_download_table(
    files = files,
    directory = directory,
    cache = cache,
    prefer_cloud = prefer_cloud
  )

  encode_check_download_sizes(
    files,
    max_file_size = max_file_size,
    max_total_size = max_total_size
  )
  unknown_size <- encode_unknown_size_count(files)
  known_size <- encode_size(files)

  if (!isTRUE(quiet)) {
    destination <- unique(dirname(files$local_path))
    cli::cli_inform(c(
      "Planned ENCODE download: {nrow(files)} file(s), at least {encode_pretty_bytes(known_size)} known total size.",
      "i" = "{unknown_size} file(s) have unknown size.",
      "i" = "Destination: {paste(destination, collapse = ', ')}"
    ))
  }

  if (isTRUE(dry_run)) {
    files$download_status <- "planned"
    files$downloaded_size <- NA_real_
    files$md5sum_expected <- files$md5sum
    files$md5sum_observed <- NA_character_
    files$size_ok <- NA
    files$md5_ok <- NA
    files$size_verified <- NA
    files$md5_verified <- NA
    files$failure_reason <- NA_character_
    attr(files, "known_total_size") <- known_size
    attr(files, "unknown_size_count") <- unknown_size
    class(files) <- c("encode_download_result", "encode_file_table", "data.frame")
    files <- encode_attach_metadata(files, query_url = encode_query_url(x), filters = encode_filters(x))
    if (!isTRUE(quiet)) {
      cli::cli_inform(
        "Returned planned download rows. Print the result to view them, or use {.code encode_results()} for the table."
      )
    }
    return(files)
  }

  if (unknown_size > 0L && !isTRUE(allow_unknown_size)) {
    cli::cli_abort(c(
      "Refusing to download {unknown_size} ENCODE file(s) with unknown file size.",
      "i" = "Run {.fun encode_download} with {.code dry_run = TRUE} to inspect the plan.",
      "i" = "Use {.code allow_unknown_size = TRUE} only after reviewing these files."
    ))
  }

  for (dir in unique(dirname(files$local_path))) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  rows <- vector("list", nrow(files))
  for (i in seq_len(nrow(files))) {
    row <- files[i, , drop = FALSE]
    rows[[i]] <- tryCatch(
      encode_download_one(
        row,
        overwrite = overwrite,
        verify = verify,
        quiet = quiet
      ),
      error = function(cnd) {
        encode_failed_download_row(row, conditionMessage(cnd))
      }
    )
  }
  result <- encode_bind_rows(rows, names(rows[[1L]]))
  class(result) <- c("encode_download_result", "encode_file_table", "data.frame")
  result <- encode_attach_metadata(result, query_url = encode_query_url(x), filters = encode_filters(x))
  failed <- result$download_status %in% "failed"
  if (any(failed)) {
    cli::cli_warn(
      "Failed to download or verify {sum(failed)} ENCODE file(s): {.val {paste(result$file_accession[failed], collapse = ', ')}}."
    )
  }
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "ENCODE download completed. Print the result to view downloaded files, or use {.code encode_results()} for the table."
    )
  }
  if (isTRUE(read)) {
    return(encode_load_downloaded_files(
      result,
      max_size = read_max_size,
      format = read_format,
      region = read_region,
      allow_large = read_allow_large,
      unsupported = read_unsupported,
      assign = assign,
      envir = envir,
      quiet = quiet
    ))
  }
  result
}

#' Preview an ENCODE download
#'
#' Preview files before download. New code can usually use
#' `encode_download(..., dry_run = TRUE)` instead; this helper remains for code
#' that wants the older plan summary with largest files and required overrides.
#'
#' @param x ENCFF accession(s), file metadata table, file search result,
#'   selected-file object, or experiment object.
#' @param file_accession Optional ENCODE file accession(s), such as
#'   `"ENCFF260OJQ"`, to include from `x`. Use this when you want specific files
#'   rather than the first `n` rows.
#' @param n Optional number of files to include from the top of `x`.
#' @param directory Destination directory. If `NULL`, a package cache directory
#'   from `tools::R_user_dir("encodeUtils", "cache")` is used.
#' @param cache Whether `directory = NULL` should use the package cache. If
#'   `FALSE`, a session temporary directory is used.
#' @param max_file_size Maximum allowed size per file, as bytes or a string like
#'   `"500MB"`.
#' @param max_total_size Maximum allowed total size, as bytes or a string.
#' @param allow_unknown_size Whether the eventual download plan may include files
#'   with missing `file_size` metadata without listing an override requirement.
#' @param prefer_cloud Whether to prefer ENCODE cloud URLs when available.
#' @param n_largest Number of largest known-size files to include in the plan.
#' @param quiet If `FALSE`, print a concise status message.
#'
#' @return A download plan.
#' @export
#'
#' @examples
#' download_marker <- paste0(intToUtf8(64), intToUtf8(64), "download")
#' files <- data.frame(
#'   file_accession = "ENCFF000AAA",
#'   href = paste0(
#'     "/files/ENCFF000AAA/",
#'     download_marker,
#'     "/ENCFF000AAA.txt"
#'   ),
#'   file_size = 3,
#'   md5sum = "900150983cd24fb0d6963f7d28e17f72"
#' )
#' encode_preview_download(files, directory = tempdir())
#' encode_preview_download(files, n = 1, directory = tempdir())
#'
#' # Live ENCODE example:
#' # selected <- encode_select_files(files, preset = "raw_fastq")
#' # encode_preview_download(selected, directory = "data/encode")
encode_preview_download <- function(
                                    x,
                                    file_accession = NULL,
                                    n = NULL,
                                    directory = NULL,
                                    cache = TRUE,
                                    max_file_size = "2GB",
                                    max_total_size = "5GB",
                                    allow_unknown_size = FALSE,
                                    prefer_cloud = FALSE,
                                    n_largest = 5,
                                    quiet = FALSE) {
  files <- encode_file_table_from_input(x, status = NULL)
  files <- encode_filter_file_accessions(files, file_accession)
  files <- encode_limit_file_rows(files, n = n, file_accession = file_accession)
  if (nrow(files) == 0L) {
    cli::cli_abort("{.arg x} did not contain any files to preview.")
  }
  files <- encode_prepare_download_table(
    files = files,
    directory = directory,
    cache = cache,
    prefer_cloud = prefer_cloud
  )
  sizes <- encode_as_file_size(files$file_size)
  known_total_size <- sum(sizes, na.rm = TRUE)
  unknown_size_count <- sum(is.na(sizes))
  checksums_available <- sum(!is.na(files$md5sum) & nzchar(files$md5sum))
  required_overrides <- encode_download_required_overrides(
    files = files,
    max_file_size = max_file_size,
    max_total_size = max_total_size,
    allow_unknown_size = allow_unknown_size
  )
  plan <- list(
    files = files,
    summary = data.frame(
      n_files = nrow(files),
      known_total_size = known_total_size,
      known_total_size_pretty = encode_pretty_bytes(known_total_size),
      unknown_size_count = unknown_size_count,
      checksums_available = checksums_available,
      destination_count = length(unique(dirname(files$local_path))),
      stringsAsFactors = FALSE
    ),
    largest_files = encode_largest_files(files, n = n_largest),
    destinations = unique(dirname(files$local_path)),
    required_overrides = required_overrides,
    query_url = encode_query_url(x),
    filters = encode_filters(x)
  )
  class(plan) <- c("encode_download_plan", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "Returned a download plan. Print the result to view it, or use {.code encode_results()} for planned file rows."
    )
  }
  plan
}

encode_download_required_overrides <- function(
                                               files,
                                               max_file_size,
                                               max_total_size,
                                               allow_unknown_size) {
  max_file_size <- encode_parse_size(max_file_size, arg = "max_file_size")
  max_total_size <- encode_parse_size(max_total_size, arg = "max_total_size")
  sizes <- encode_as_file_size(files$file_size)
  rows <- list()

  unknown_size <- sum(is.na(sizes))
  if (unknown_size > 0L && !isTRUE(allow_unknown_size)) {
    rows[[length(rows) + 1L]] <- data.frame(
      override = "allow_unknown_size = TRUE",
      reason = paste0(unknown_size, " file(s) have unknown file_size"),
      stringsAsFactors = FALSE
    )
  }

  too_large <- !is.na(sizes) & sizes > max_file_size
  if (any(too_large)) {
    rows[[length(rows) + 1L]] <- data.frame(
      override = "increase max_file_size",
      reason = paste0(sum(too_large), " file(s) exceed max_file_size"),
      stringsAsFactors = FALSE
    )
  }

  known_total_size <- sum(sizes, na.rm = TRUE)
  if (!is.na(known_total_size) && known_total_size > max_total_size) {
    rows[[length(rows) + 1L]] <- data.frame(
      override = "increase max_total_size",
      reason = paste0("known total size is ", encode_pretty_bytes(known_total_size)),
      stringsAsFactors = FALSE
    )
  }

  encode_bind_rows(rows, c("override", "reason"))
}

encode_limit_file_rows <- function(files, n = NULL, file_accession = NULL) {
  if (is.null(n)) {
    return(files)
  }
  if (!is.null(file_accession)) {
    cli::cli_abort("Use either {.arg file_accession} or {.arg n}, not both.")
  }
  n <- encode_validate_positive_whole_number(n, "n")
  if (nrow(files) <= n) {
    return(files)
  }
  files[seq_len(n), , drop = FALSE]
}

encode_normalize_verify <- function(verify) {
  if (is.null(verify)) {
    return(character())
  }
  match.arg(verify, choices = c("md5", "size"), several.ok = TRUE)
}

encode_prepare_download_table <- function(files, directory, cache, prefer_cloud) {
  files <- as.data.frame(files, stringsAsFactors = FALSE)
  if (!"file_accession" %in% names(files)) {
    if ("accession" %in% names(files)) {
      files$file_accession <- files$accession
    } else {
      cli::cli_abort("File metadata must include {.field file_accession} or {.field accession}.")
    }
  }
  if (!"href" %in% names(files)) {
    files$href <- NA_character_
  }
  if (!"file_size" %in% names(files)) {
    files$file_size <- NA_real_
  }
  files$file_size <- encode_as_file_size(files$file_size)
  files$file_size_pretty <- encode_pretty_bytes(files$file_size)
  if (!"md5sum" %in% names(files)) {
    files$md5sum <- NA_character_
  }
  if (!"cloud_url" %in% names(files)) {
    files$cloud_url <- NA_character_
  }

  directory <- directory %||% if (isTRUE(cache)) {
    tools::R_user_dir("encodeUtils", which = "cache")
  } else {
    tempdir()
  }
  if (!is.character(directory) || length(directory) != 1L || is.na(directory) || !nzchar(directory)) {
    cli::cli_abort("{.arg directory} must be one non-empty path or NULL.")
  }

  download_url <- encode_download_urls(files, prefer_cloud = prefer_cloud)
  missing_download <- is.na(download_url) | !nzchar(download_url)
  if (any(missing_download)) {
    cli::cli_abort("File metadata must include ENCODE download {.field href} or usable {.field cloud_url}.")
  }

  local_name_source <- ifelse(!is.na(files$href) & nzchar(files$href), files$href, download_url)
  local_name <- basename(sub("[?].*$", "", local_name_source))
  missing_name <- is.na(local_name) | !nzchar(local_name)
  local_name[missing_name] <- paste0(files$file_accession[missing_name], ".dat")
  no_accession <- !mapply(
    grepl,
    pattern = files$file_accession,
    x = local_name,
    MoreArgs = list(fixed = TRUE),
    USE.NAMES = FALSE
  )
  local_name[no_accession] <- paste(files$file_accession[no_accession], local_name[no_accession], sep = "_")

  files$download_url <- download_url
  files$local_path <- encode_unique_paths(
    file.path(directory, local_name),
    accessions = files$file_accession
  )
  class(files) <- c("encode_file_table", "data.frame")
  files
}

encode_download_urls <- function(files, prefer_cloud) {
  cloud_url <- files$cloud_url
  href <- files$href
  if (isTRUE(prefer_cloud)) {
    preferred <- ifelse(!is.na(cloud_url) & nzchar(cloud_url), cloud_url, href)
  } else {
    preferred <- ifelse(!is.na(href) & nzchar(href), href, cloud_url)
  }
  vapply(preferred, encode_object_url, character(1L))
}

encode_check_download_sizes <- function(files, max_file_size, max_total_size) {
  max_file_size <- encode_parse_size(max_file_size, arg = "max_file_size")
  max_total_size <- encode_parse_size(max_total_size, arg = "max_total_size")
  sizes <- encode_as_file_size(files$file_size)

  too_large <- !is.na(sizes) & sizes > max_file_size
  if (any(too_large)) {
    details <- paste(
      paste0(files$file_accession[too_large], " (", encode_pretty_bytes(sizes[too_large]), ")"),
      collapse = ", "
    )
    cli::cli_abort(
      c(
        "One or more ENCODE files exceed {.arg max_file_size}.",
        "x" = details
      )
    )
  }

  total_size <- sum(sizes, na.rm = TRUE)
  if (!is.na(total_size) && total_size > max_total_size) {
    cli::cli_abort(
      c(
        "Planned ENCODE download exceeds {.arg max_total_size}.",
        "x" = "Known total size: {encode_pretty_bytes(total_size)}"
      )
    )
  }
  invisible(NULL)
}

encode_unknown_size_count <- function(files) {
  sizes <- encode_as_file_size(files$file_size)
  sum(is.na(sizes))
}

encode_download_one <- function(file, overwrite, verify, quiet) {
  path <- file$local_path[[1L]]
  accession <- file$file_accession[[1L]]
  if (file.exists(path) && !isTRUE(overwrite)) {
    status <- encode_verify_existing_file(file, verify = verify)
    file$download_status <- status$download_status
    file$downloaded_size <- status$downloaded_size
    file$md5sum_expected <- file$md5sum
    file$md5sum_observed <- status$md5sum_observed
    file$size_ok <- status$size_verified
    file$md5_ok <- status$md5_verified
    file$size_verified <- status$size_verified
    file$md5_verified <- status$md5_verified
    file$failure_reason <- status$failure_reason
    return(file)
  }

  if (!isTRUE(quiet)) {
    cli::cli_inform("Downloading {.val {accession}}.")
  }
  tmp_path <- paste0(path, ".part")
  if (file.exists(tmp_path)) {
    unlink(tmp_path)
  }
  on.exit({
    if (file.exists(tmp_path)) {
      unlink(tmp_path)
    }
  }, add = TRUE)
  response <- encode_perform_file(file$download_url[[1L]], tmp_path)
  if (file.exists(path) && isTRUE(overwrite)) {
    unlink(path)
  }
  renamed <- file.rename(tmp_path, path)
  if (!isTRUE(renamed)) {
    cli::cli_abort("Could not move downloaded file into place: {.path {path}}.")
  }

  file$download_status <- "downloaded"
  file$downloaded_at <- response$retrieved_at
  file$downloaded_size <- as.numeric(file.info(path)$size)
  file$md5sum_expected <- file$md5sum
  file$md5sum_observed <- encode_observed_md5(path, file$md5sum[[1L]])
  file$size_verified <- if ("size" %in% verify) {
    encode_verify_size(path, file$file_size[[1L]])
  } else {
    NA
  }
  file$md5_verified <- if ("md5" %in% verify) {
    encode_verify_md5(path, file$md5sum[[1L]])
  } else {
    NA
  }
  file$size_ok <- file$size_verified
  file$md5_ok <- file$md5_verified
  file$failure_reason <- NA_character_

  if (identical(file$size_verified[[1L]], FALSE) ||
    identical(file$md5_verified[[1L]], FALSE)) {
    file$download_status <- "failed"
    file$failure_reason <- "Downloaded file failed size or MD5 verification."
  }
  file
}

encode_verify_existing_file <- function(file, verify) {
  size_verified <- if ("size" %in% verify) {
    encode_verify_size(file$local_path[[1L]], file$file_size[[1L]])
  } else {
    NA
  }
  md5_verified <- if ("md5" %in% verify) {
    encode_verify_md5(file$local_path[[1L]], file$md5sum[[1L]])
  } else {
    NA
  }
  failure_reason <- if (identical(size_verified, FALSE) || identical(md5_verified, FALSE)) {
    "Existing file does not match ENCODE metadata; use overwrite = TRUE to replace it."
  } else {
    NA_character_
  }
  list(
    download_status = if (is.na(failure_reason)) "exists" else "failed",
    downloaded_size = as.numeric(file.info(file$local_path[[1L]])$size),
    md5sum_observed = encode_observed_md5(file$local_path[[1L]], file$md5sum[[1L]]),
    size_verified = size_verified,
    md5_verified = md5_verified,
    failure_reason = failure_reason
  )
}

encode_failed_download_row <- function(file, reason) {
  tmp_path <- paste0(file$local_path[[1L]], ".part")
  if (file.exists(tmp_path)) {
    unlink(tmp_path)
  }
  file$download_status <- "failed"
  file$downloaded_size <- if (file.exists(file$local_path[[1L]])) {
    as.numeric(file.info(file$local_path[[1L]])$size)
  } else {
    NA_real_
  }
  file$md5sum_expected <- file$md5sum
  file$md5sum_observed <- encode_observed_md5(file$local_path[[1L]], file$md5sum[[1L]])
  file$size_ok <- FALSE
  file$md5_ok <- FALSE
  file$size_verified <- FALSE
  file$md5_verified <- FALSE
  file$failure_reason <- reason
  file
}

encode_verify_size <- function(path, expected_size) {
  expected_size <- encode_as_file_size(expected_size)
  if (length(expected_size) != 1L || is.na(expected_size)) {
    return(NA)
  }
  file.exists(path) && identical(as.numeric(file.info(path)$size), expected_size)
}

encode_verify_md5 <- function(path, expected_md5) {
  if (is.na(expected_md5) || !nzchar(expected_md5)) {
    return(NA)
  }
  if (!file.exists(path)) {
    return(FALSE)
  }
  observed <- unname(tools::md5sum(path))
  identical(tolower(observed), tolower(expected_md5))
}

encode_observed_md5 <- function(path, expected_md5 = NA_character_) {
  if (is.na(expected_md5) || !nzchar(expected_md5) || !file.exists(path)) {
    return(NA_character_)
  }
  unname(tools::md5sum(path))
}
