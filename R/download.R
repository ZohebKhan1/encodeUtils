#' Download ENCODE files
#'
#' Download files from an ENCODE file table, selected-file object, file search,
#' or file accession. Planned sizes are checked before transfer, existing files
#' are not overwritten by default, files are written through a temporary `.part`
#' path, and size/MD5 checks are used when ENCODE provides the metadata.
#'
#' @param x ENCFF accession(s), file metadata table, file search result,
#'   selected-file object, or ENCSR experiment accession(s). ENCSR input is
#'   first passed to `encode_list_files()`.
#' @param file_accession Optional ENCODE file accession(s), such as
#'   `"ENCFF260OJQ"`, to download from `x`. Use this when you want specific
#'   files rather than the first `limit` rows.
#' @param file_format Optional file-format filter used when `x` is an ENCSR
#'   experiment accession.
#' @param output_type Optional output-type filter used when `x` is an ENCSR
#'   experiment accession.
#' @param assembly Optional genome-assembly filter used when `x` is an ENCSR
#'   experiment accession.
#' @param status Optional file-status filter used when `x` is an ENCSR
#'   experiment accession.
#' @param limit Optional number of files to use from the top of `x`.
#' @param directory Destination directory. If `NULL`, a package cache directory
#'   from `tools::R_user_dir("encodeUtils", "cache")` is used. Supply an
#'   explicit project directory for reusable data.
#' @param max_file_size Maximum allowed size per file, as bytes or a string like
#'   `"500MB"`.
#' @param max_total_size Maximum allowed total size, as bytes or a string.
#' @param allow_unknown_size Whether to allow real downloads for files whose
#'   ENCODE metadata do not include `file_size`. Dry-runs are always allowed and
#'   report the unknown-size count.
#' @param overwrite Whether existing destination files may be replaced.
#' @param dry_run If `TRUE`, return the planned download table without
#'   downloading.
#' @param prefer_cloud Whether to prefer ENCODE cloud URLs when available.
#' @param verify Verification checks to perform. Supported values are `"md5"`
#'   and `"size"`. Use `NULL` to record downloads without size or MD5
#'   verification.
#' @param quiet If `FALSE`, print concise progress messages.
#'
#' @return An `encode_download_result` data frame. Dry runs return planned rows
#'   with destination `local_path`, known-size totals, unknown-size counts, and
#'   `download_status = "planned"`. Transfers return one row per file with
#'   `download_status`, `downloaded_at`, `downloaded_size`, the expected
#'   `md5sum`, `observed_md5`, verification flags, and `failure_reason`.
#'   Printing the result shows the transfer status and local destination; use
#'   `encode_results()` for the complete table.
#' @export
#'
#' @examples
#' example_dir <- system.file("example-data", package = "encodeUtils")
#' files <- utils::read.csv(file.path(example_dir, "files.csv"))
#' plan <- encode_download(files, directory = tempdir(), dry_run = TRUE,
#'                         quiet = TRUE)
#' encode_results(plan)
encode_download <- function(
    x,
    file_accession = NULL,
    file_format = NULL,
    output_type = NULL,
    assembly = NULL,
    status = "released",
    limit = NULL,
    directory = NULL,
    max_file_size = "250MB",
    max_total_size = "500MB",
    allow_unknown_size = FALSE,
    overwrite = FALSE,
    dry_run = FALSE,
    prefer_cloud = FALSE,
    verify = c("md5", "size"),
    quiet = FALSE
) {
    file_accession <- encode_validate_file_accessions(file_accession)
    file_format <- encode_validate_values(file_format, "file_format")
    output_type <- encode_validate_values(output_type, "output_type")
    assembly <- encode_validate_values(assembly, "assembly")
    status <- encode_validate_values(status, "status")
    if (!is.null(limit)) {
        limit <- encode_validate_positive_whole_number(limit, "limit")
    }
    directory <- encode_validate_scalar(directory, "directory")
    max_file_size <- encode_parse_size(max_file_size, arg = "max_file_size")
    max_total_size <- encode_parse_size(max_total_size, arg = "max_total_size")
    allow_unknown_size <- encode_validate_flag(allow_unknown_size, "allow_unknown_size")
    overwrite <- encode_validate_flag(overwrite, "overwrite")
    dry_run <- encode_validate_flag(dry_run, "dry_run")
    prefer_cloud <- encode_validate_flag(prefer_cloud, "prefer_cloud")
    quiet <- encode_validate_flag(quiet, "quiet")
    verify <- encode_normalize_verify(verify)

    # Require a narrowed ENCSR request for transfer, but allow unrestricted planning.
    encode_check_experiment_download_scope(
        x,
        dry_run = dry_run,
        file_accession = file_accession,
        file_format = file_format,
        output_type = output_type,
        limit = limit
    )
    files <- encode_download_file_table(
        x,
        file_format = file_format,
        output_type = output_type,
        assembly = assembly,
        status = status
    )
    # Normalize first so accession, search-result, and table routes preserve
    # the request that actually supplied the file metadata.
    query_url <- encode_query_url(files)
    retrieved_at <- attr(files, "retrieved_at", exact = TRUE)
    filters <- encode_filters(files)
    base_url <- attr(files, "encode_base_url", exact = TRUE) %||% encode_base_url()
    if (nrow(files) == 0L) {
        encode_abort_no_matching_download_files(
            x,
            file_format = file_format,
            output_type = output_type,
            assembly = assembly,
            status = status
        )
    }
    files <- encode_filter_file_accessions(files, file_accession)
    if (nrow(files) == 0L) {
        cli::cli_abort(c(
            "No ENCODE files matched {.arg file_accession}.",
            "i" = "Use {.fun encode_results} on the file table to choose valid ENCFF accessions."
        ))
    }
    files <- encode_limit_file_rows(files, limit = limit, file_accession = file_accession)
    files <- encode_prepare_download_table(
        files = files,
        directory = directory,
        prefer_cloud = prefer_cloud
    )
    files <- encode_initialize_download_result(files)

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
        attr(files, "known_total_size") <- known_size
        attr(files, "unknown_size_count") <- unknown_size
        class(files) <- c("encode_download_result", "encode_file_table", "data.frame")
        files <- encode_attach_metadata(
            files,
            query_url = query_url,
            retrieved_at = retrieved_at,
            filters = filters,
            base_url = base_url
        )
        return(files)
    }

    if (unknown_size > 0L && !isTRUE(allow_unknown_size)) {
        # Refuse unknown-size transfers by default because their total cannot be bounded.
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
                quiet = quiet,
                index = i,
                total = nrow(files)
            ),
            error = function(cnd) {
                encode_failed_download_row(row, conditionMessage(cnd))
            }
        )
    }
    result <- encode_bind_rows(rows, names(rows[[1L]]))
    class(result) <- c("encode_download_result", "encode_file_table", "data.frame")
    result <- encode_attach_metadata(
        result,
        query_url = query_url,
        retrieved_at = retrieved_at,
        filters = filters,
        base_url = base_url
    )
    failed <- result$download_status %in% "failed"
    if (any(failed)) {
        cli::cli_warn(
            "Failed to download or verify {sum(failed)} ENCODE file(s): {.val {paste(result$file_accession[failed], collapse = ', ')}}."
        )
    }
    if (!isTRUE(quiet)) {
        downloaded <- sum(result$download_status %in% "downloaded")
        existing <- sum(result$download_status %in% "exists")
        cli::cli_inform(
            "ENCODE download finished: {downloaded} downloaded, {existing} already present, and {sum(failed)} failed."
        )
    }
    result
}

# Download input normalization and safety limits

encode_download_file_table <- function(x, file_format = NULL, output_type = NULL, assembly = NULL, status = "released") {
    experiment_input <- is.character(x) && all(encode_is_experiment_accession(vapply(x, encode_normalize_accession, character(1L))))
    filters_requested <- !is.null(file_format) || !is.null(output_type) || !is.null(assembly)
    if (experiment_input) {
        return(encode_list_files(
            x,
            file_format = file_format,
            output_type = output_type,
            assembly = assembly,
            status = status,
            limit = "all",
            quiet = TRUE
        ))
    }
    if (filters_requested) {
        cli::cli_abort(
            "{.arg file_format}, {.arg output_type}, and {.arg assembly} can only be used when {.arg x} is an ENCSR experiment accession."
        )
    }
    encode_file_table_from_input(x, status = NULL)
}

encode_check_experiment_download_scope <- function(
    x,
    dry_run,
    file_accession,
    file_format,
    output_type,
    limit
) {
    if (isTRUE(dry_run) || !encode_is_direct_experiment_download_input(x)) {
        return(invisible(NULL))
    }
    narrowed <- !is.null(file_accession) ||
        !is.null(file_format) ||
        !is.null(output_type) ||
        !is.null(limit)
    if (narrowed) {
        return(invisible(NULL))
    }
    cli::cli_abort(c(
        "Refusing to download all files for an ENCODE experiment accession without narrowing the request.",
        "i" = "Run {.code encode_download(x, dry_run = TRUE)} to inspect the full plan.",
        "i" = "For real downloads, provide {.arg file_format}, {.arg output_type}, {.arg file_accession}, or {.arg limit}."
    ))
}

encode_is_direct_experiment_download_input <- function(x) {
    if (!is.character(x) || length(x) == 0L) {
        return(FALSE)
    }
    accessions <- vapply(x, encode_normalize_accession, character(1L))
    all(encode_is_experiment_accession(accessions))
}

encode_abort_no_matching_download_files <- function(
    x,
    file_format = NULL,
    output_type = NULL,
    assembly = NULL,
    status = "released"
) {
    if (is.character(x) && any(encode_is_experiment_accession(vapply(x, encode_normalize_accession, character(1L))))) {
        filters <- c(
            if (!is.null(file_format)) paste0("file_format = ", paste(file_format, collapse = ", ")),
            if (!is.null(output_type)) paste0("output_type = ", paste(output_type, collapse = ", ")),
            if (!is.null(assembly)) paste0("assembly = ", paste(assembly, collapse = ", ")),
            if (!is.null(status)) paste0("status = ", paste(status, collapse = ", "))
        )
        details <- if (length(filters) > 0L) paste(filters, collapse = "; ") else "no file filters"
        cli::cli_abort(c(
            "No ENCODE files matched this experiment download request.",
            "i" = "Input: {.val {paste(x, collapse = ', ')}}.",
            "i" = "Filters: {details}.",
            "i" = "Run {.code encode_list_files(x)} to inspect available files, then choose file accessions with {.arg file_accession}."
        ))
    }
    cli::cli_abort(c(
        "{.arg x} did not contain any files to download.",
        "i" = "Use {.fun encode_results} to inspect the object before downloading."
    ))
}

encode_limit_file_rows <- function(files, limit = NULL, file_accession = NULL) {
    if (is.null(limit)) {
        return(files)
    }
    if (!is.null(file_accession)) {
        cli::cli_abort("Use either {.arg file_accession} or {.arg limit}, not both.")
    }
    if (nrow(files) <= limit) {
        return(files)
    }
    files[seq_len(limit), , drop = FALSE]
}

encode_normalize_verify <- function(verify) {
    if (is.null(verify)) {
        return(character())
    }
    match.arg(verify, choices = c("md5", "size"), several.ok = TRUE)
}

# Download planning

encode_prepare_download_table <- function(files, directory, prefer_cloud) {
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

    directory <- directory %||% tools::R_user_dir("encodeUtils", which = "cache")
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
    # Include accessions when needed to keep destination paths unique.
    files$local_path <- encode_unique_paths(
        file.path(directory, local_name),
        accessions = files$file_accession
    )
    class(files) <- c("encode_file_table", "data.frame")
    files
}

encode_initialize_download_result <- function(files) {
    files$download_status <- NA_character_
    files$downloaded_at <- as.POSIXct(
        rep(NA_real_, nrow(files)),
        origin = "1970-01-01",
        tz = "UTC"
    )
    files$downloaded_size <- NA_real_
    files$observed_md5 <- NA_character_
    files$size_verified <- NA
    files$md5_verified <- NA
    files$failure_reason <- NA_character_
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

# Atomic transfer and verification

encode_download_one <- function(file, overwrite, verify, quiet, index = NULL, total = NULL) {
    path <- file$local_path[[1L]]
    accession <- file$file_accession[[1L]]
    if (file.exists(path) && !isTRUE(overwrite)) {
        status <- encode_verify_existing_file(file, verify = verify)
        file$download_status <- status$download_status
        file$downloaded_size <- status$downloaded_size
        file$observed_md5 <- status$observed_md5
        file$size_verified <- status$size_verified
        file$md5_verified <- status$md5_verified
        file$failure_reason <- status$failure_reason
        return(file)
    }

    if (!isTRUE(quiet)) {
        progress <- if (!is.null(index) && !is.null(total)) {
            paste0(" (", index, "/", total, ")")
        } else {
            ""
        }
        cli::cli_inform("Downloading{progress} {.val {accession}}.")
    }
    tmp_path <- paste0(path, ".part")
    # Write to a .part file so interrupted transfers cannot appear complete.
    if (file.exists(tmp_path)) {
        unlink(tmp_path)
    }
    on.exit(
        {
            if (file.exists(tmp_path)) {
                unlink(tmp_path)
            }
        },
        add = TRUE
    )
    response <- encode_perform_file(file$download_url[[1L]], tmp_path)
    file$downloaded_at <- response$retrieved_at
    file$downloaded_size <- as.numeric(file.info(tmp_path)$size)
    file$observed_md5 <- encode_observed_md5(tmp_path, file$md5sum[[1L]])
    file$size_verified <- if ("size" %in% verify) {
        encode_verify_size(tmp_path, file$file_size[[1L]])
    } else {
        NA
    }
    file$md5_verified <- if ("md5" %in% verify) {
        encode_verify_md5(tmp_path, file$md5sum[[1L]])
    } else {
        NA
    }
    if (identical(file$size_verified[[1L]], FALSE) ||
        identical(file$md5_verified[[1L]], FALSE)) {
        file$download_status <- "failed"
        file$failure_reason <- "Downloaded file failed size or MD5 verification."
        return(file)
    }

    backup_path <- NA_character_
    if (file.exists(path) && isTRUE(overwrite)) {
        backup_path <- tempfile(
            pattern = paste0(".", basename(path), ".backup-"),
            tmpdir = dirname(path)
        )
        if (!file.rename(path, backup_path)) {
            cli::cli_abort("Could not preserve the existing file before replacement: {.path {path}}.")
        }
    }
    on.exit(
        {
            if (!is.na(backup_path) && file.exists(backup_path)) {
                if (!file.exists(path)) {
                    file.rename(backup_path, path)
                } else {
                    unlink(backup_path)
                }
            }
        },
        add = TRUE
    )
    if (!file.rename(tmp_path, path)) {
        cli::cli_abort("Could not move the verified download into place: {.path {path}}.")
    }
    if (!is.na(backup_path) && file.exists(backup_path)) {
        unlink(backup_path)
        backup_path <- NA_character_
    }
    file$download_status <- "downloaded"
    file$failure_reason <- NA_character_
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
        observed_md5 = encode_observed_md5(file$local_path[[1L]], file$md5sum[[1L]]),
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
