#' Select ENCODE files to use or download
#'
#' Choose files from an `encode_list_files()` table using explicit filters or a
#' preset. The result keeps the selected files for download or reading.
#'
#' Call `encode_select_files()` with no `files` argument to list available
#' presets, or with `preset = "name"` to inspect one preset.
#'
#' @param files File metadata from `encode_list_files()`, a file search result,
#'   or another object accepted by `encode_download()`. Leave as `NULL` to
#'   inspect available presets instead of selecting files.
#' @param preset Optional preset name. Supported values include broad presets
#'   such as `"raw_reads"`, `"signal"`, `"peaks"`, and assay-aware presets such
#'   as `"chipseq_peaks"`, `"chipseq_signal"`, `"atacseq_peaks"`, and
#'   `"rnaseq_gene_quant"`.
#' @param file_format Optional file format filter. If omitted and `preset` is set,
#'   the preset supplies a format preference.
#' @param output_type Optional output type filter. If omitted and `preset` is set,
#'   the preset supplies an output-type priority.
#' @param assembly Optional genome assembly filter.
#' @param file_accession Optional ENCODE file accession(s), such as
#'   `"ENCFF260OJQ"`, to select explicitly before applying other filters.
#' @param status Optional status filter. Defaults to `"released"`.
#' @param replicate_policy How to handle replicate-related outputs. `"all"`
#'   keeps all matching files; `"preferred_processed"` keeps the highest-priority
#'   output type per experiment when a preset priority is available;
#'   `"replicate_level"` keeps files with biological replicate labels;
#'   `"pooled_only"` keeps files whose output type indicates pooled or IDR-like
#'   processing.
#' @param prefer_default Whether to prefer ENCODE records marked
#'   `preferred_default`. When no preferred-default rows are present, the filter
#'   is skipped and the other explicit criteria are used.
#' @param require_href Whether selected rows must include an ENCODE download
#'   path or URL.
#' @param explain If `FALSE`, suppress the concise selection message.
#'
#' @return Selected files. If `files = NULL`, returns preset names or a preset
#'   definition.
#' @export
#'
#' @examples
#' encode_select_files()
#' encode_select_files(preset = "chipseq_idr_peaks")
#'
#' download_marker <- paste0(intToUtf8(64), intToUtf8(64), "download")
#' files <- data.frame(
#'   file_accession = c("ENCFF000AAA", "ENCFF000AAB"),
#'   experiment_accession = "ENCSR000AAA",
#'   file_format = c("bed", "bed"),
#'   output_type = c("optimal IDR thresholded peaks", "replicated peaks"),
#'   assembly = c("GRCh38", "hg19"),
#'   status = c("released", "released"),
#'   href = paste0(
#'     "/files/",
#'     c("ENCFF000AAA", "ENCFF000AAB"),
#'     "/",
#'     download_marker,
#'     "/",
#'     c("a.bed", "b.bed")
#'   )
#' )
#' selected <- encode_select_files(files, preset = "peaks", assembly = "GRCh38")
#' encode_results(selected)
encode_select_files <- function(
                                files = NULL,
                                preset = NULL,
                                file_format = NULL,
                                output_type = NULL,
                                assembly = NULL,
                                file_accession = NULL,
                                status = "released",
                                replicate_policy = c("all", "preferred_processed", "replicate_level", "pooled_only"),
                                prefer_default = FALSE,
                                require_href = TRUE,
                                explain = TRUE) {
  if (is.null(files)) {
    return(encode_file_preset(preset))
  }
  replicate_policy <- match.arg(replicate_policy)
  files <- encode_file_table_from_input(files, status = status)
  files <- as.data.frame(files, stringsAsFactors = FALSE)
  if (!"file_accession" %in% names(files) && "accession" %in% names(files)) {
    files$file_accession <- files$accession
  }
  files <- encode_ensure_columns(files, c(
    "file_accession", "experiment_accession", "file_format", "output_type",
    "assembly", "status", "href", "download_url", "biological_replicates",
    "preferred_default"
  ))
  files$preferred_default <- encode_logical_vector(files$preferred_default)
  file_accession <- encode_validate_file_accessions(file_accession)

  preset_info <- if (is.null(preset)) {
    list(file_format = NULL, output_type_priority = NULL)
  } else {
    encode_file_preset(preset)
  }
  if (is.null(file_format)) {
    file_format <- preset_info$file_format
  }
  output_priority <- output_type %||% preset_info$output_type_priority
  output_filter <- output_type %||% preset_info$output_type_priority

  criteria <- list(
    preset = preset,
    file_format = file_format,
    output_type = output_filter,
    assembly = assembly,
    file_accession = file_accession,
    status = status,
    replicate_policy = replicate_policy,
    prefer_default = prefer_default,
    preferred_default_available = FALSE,
    preferred_default_used = FALSE,
    require_href = require_href
  )

  if (nrow(files) == 0L) {
    class(files) <- c("encode_file_table", "data.frame")
    result <- list(
      files = files,
      excluded = encode_exclusion_table(files, list()),
      criteria = criteria,
      query_url = encode_query_url(files),
      retrieved_at = attr(files, "retrieved_at", exact = TRUE)
    )
    class(result) <- c("encode_selected_files", "list")
    return(result)
  }

  state <- encode_selection_state(files)
  state <- encode_apply_selection_filter(
    state,
    keep = encode_match_values(files$file_accession, file_accession),
    reason = "not requested file accession",
    active = !is.null(file_accession)
  )
  if (!is.null(file_accession)) {
    missing <- setdiff(file_accession, toupper(files$file_accession))
    if (length(missing) > 0L) {
      cli::cli_abort(c(
        "Requested ENCODE file accession(s) were not found in {.arg files}.",
        "x" = "{paste(missing, collapse = ', ')}"
      ))
    }
  }
  state <- encode_apply_selection_filter(
    state,
    keep = encode_match_values(files$status, status),
    reason = "wrong status",
    active = !is.null(status)
  )
  state <- encode_apply_selection_filter(
    state,
    keep = encode_match_values(files$file_format, file_format),
    reason = "wrong file format",
    active = !is.null(file_format)
  )
  state <- encode_apply_selection_filter(
    state,
    keep = encode_match_values(files$output_type, output_filter),
    reason = "wrong output type",
    active = !is.null(output_filter)
  )
  state <- encode_apply_selection_filter(
    state,
    keep = encode_match_values(files$assembly, assembly),
    reason = "wrong assembly",
    active = !is.null(assembly)
  )
  state <- encode_apply_selection_filter(
    state,
    keep = encode_has_download_url(files),
    reason = "missing download URL",
    active = isTRUE(require_href)
  )
  preferred_default_available <- any(state$keep & files$preferred_default %in% TRUE)
  use_preferred_default <- isTRUE(prefer_default) && preferred_default_available
  criteria$preferred_default_available <- preferred_default_available
  criteria$preferred_default_used <- use_preferred_default
  state <- encode_apply_selection_filter(
    state,
    keep = files$preferred_default %in% TRUE,
    reason = "not preferred_default",
    active = use_preferred_default
  )
  state <- encode_apply_replicate_policy(
    state = state,
    files = files,
    policy = replicate_policy,
    output_priority = output_priority
  )

  selected <- files[state$keep, , drop = FALSE]
  if (!is.null(file_accession) && nrow(selected) > 0L) {
    requested_order <- match(file_accession, toupper(selected$file_accession))
    requested_order <- requested_order[!is.na(requested_order)]
    selected <- selected[requested_order, , drop = FALSE]
  }
  selected <- encode_attach_metadata(
    selected,
    query_url = encode_query_url(files),
    retrieved_at = attr(files, "retrieved_at", exact = TRUE),
    filters = attr(files, "filters", exact = TRUE)
  )
  class(selected) <- c("encode_file_table", "data.frame")

  excluded <- encode_exclusion_table(files, state$reasons)
  result <- list(
    files = selected,
    excluded = excluded,
    criteria = criteria,
    query_url = encode_query_url(files),
    retrieved_at = attr(files, "retrieved_at", exact = TRUE)
  )
  class(result) <- c("encode_selected_files", "list")

  if (!isTRUE(explain)) {
    return(result)
  }
  cli::cli_inform(c(
    "ENCODE file selection successfully selected {nrow(selected)} of {nrow(files)} file(s).",
    "i" = "Returned selected files. Print the result to view them, or use {.code encode_results()} for selected file rows."
  ))
  result
}

#' Show an ENCODE file-selection preset
#'
#' @param preset Preset name, or `NULL` to list all preset names.
#'
#' @return A list describing file-format and output-type preferences.
#'
#' @examples
#' encode_select_files(preset = "peaks")
#' @noRd
encode_file_preset <- function(preset = NULL) {
  presets <- list(
    raw_reads = list(
      file_format = "fastq",
      output_type_priority = "reads"
    ),
    raw_fastq = list(
      file_format = "fastq",
      output_type_priority = "reads"
    ),
    alignments = list(
      file_format = c("bam", "cram", "sam"),
      output_type_priority = c("alignments", "unfiltered alignments")
    ),
    signal = list(
      file_format = c("bigWig", "bw"),
      output_type_priority = c(
        "fold change over control",
        "signal p-value",
        "read-depth normalized signal",
        "signal"
      )
    ),
    peaks = list(
      file_format = c("bed", "narrowPeak", "broadPeak", "bigBed"),
      output_type_priority = c(
        "optimal IDR thresholded peaks",
        "conservative IDR thresholded peaks",
        "IDR thresholded peaks",
        "pseudoreplicated peaks",
        "replicated peaks",
        "peaks"
      )
    ),
    chipseq_peaks = list(
      file_format = c("bed", "narrowPeak", "broadPeak", "bigBed"),
      output_type_priority = c(
        "optimal IDR thresholded peaks",
        "conservative IDR thresholded peaks",
        "IDR thresholded peaks",
        "pseudoreplicated peaks",
        "replicated peaks",
        "peaks"
      )
    ),
    chipseq_idr_peaks = list(
      file_format = c("bed", "narrowPeak", "broadPeak", "bigBed"),
      output_type_priority = c(
        "optimal IDR thresholded peaks",
        "conservative IDR thresholded peaks",
        "IDR thresholded peaks",
        "pseudoreplicated peaks",
        "replicated peaks",
        "peaks"
      )
    ),
    chipseq_signal = list(
      file_format = c("bigWig", "bw"),
      output_type_priority = c(
        "fold change over control",
        "signal p-value",
        "control normalized signal",
        "read-depth normalized signal",
        "signal"
      )
    ),
    chipseq_signal_bigwig = list(
      file_format = c("bigWig", "bw"),
      output_type_priority = c(
        "fold change over control",
        "signal p-value",
        "control normalized signal",
        "read-depth normalized signal",
        "signal"
      )
    ),
    atacseq_peaks = list(
      file_format = c("bed", "narrowPeak", "broadPeak", "bigBed"),
      output_type_priority = c(
        "IDR thresholded peaks",
        "optimal IDR thresholded peaks",
        "conservative IDR thresholded peaks",
        "pseudoreplicated peaks",
        "replicated peaks",
        "peaks"
      )
    ),
    quantification = list(
      file_format = c("tsv", "txt", "csv"),
      output_type_priority = c(
        "gene quantifications",
        "transcript quantifications",
        "gene expression quantifications",
        "quantifications"
      )
    ),
    rnaseq_gene_quant = list(
      file_format = c("tsv", "txt", "csv"),
      output_type_priority = c(
        "gene quantifications",
        "gene expression quantifications",
        "gene TPMs",
        "gene counts",
        "quantifications"
      )
    ),
    rna_gene_counts = list(
      file_format = c("tsv", "txt", "csv"),
      output_type_priority = c(
        "gene counts",
        "gene quantifications",
        "gene expression quantifications",
        "quantifications"
      )
    ),
    rna_gene_tpm = list(
      file_format = c("tsv", "txt", "csv"),
      output_type_priority = c(
        "gene TPMs",
        "gene quantifications",
        "gene expression quantifications",
        "quantifications"
      )
    ),
    rnaseq_transcript_quant = list(
      file_format = c("tsv", "txt", "csv"),
      output_type_priority = c(
        "transcript quantifications",
        "transcript expression quantifications",
        "transcript TPMs",
        "quantifications"
      )
    ),
    rna_transcript_quant = list(
      file_format = c("tsv", "txt", "csv"),
      output_type_priority = c(
        "transcript quantifications",
        "transcript expression quantifications",
        "transcript TPMs",
        "quantifications"
      )
    ),
    metadata = list(
      file_format = c("txt", "tsv", "json"),
      output_type_priority = "metadata"
    )
  )
  if (is.null(preset)) {
    return(names(presets))
  }
  if (!is.character(preset) || length(preset) != 1L || !preset %in% names(presets)) {
    cli::cli_abort(
      "{.arg preset} must be one of {.val {paste(names(presets), collapse = ', ')}}."
    )
  }
  preset_info <- presets[[preset]]
  preset_info$preset <- preset
  preset_info
}

encode_selection_state <- function(files) {
  list(
    keep = rep(TRUE, nrow(files)),
    reasons = stats::setNames(vector("list", nrow(files)), seq_len(nrow(files)))
  )
}

encode_apply_selection_filter <- function(state, keep, reason, active) {
  if (!isTRUE(active)) {
    return(state)
  }
  keep[is.na(keep)] <- FALSE
  newly_excluded <- state$keep & !keep
  for (index in which(newly_excluded)) {
    state$reasons[[index]] <- c(state$reasons[[index]], reason)
  }
  state$keep <- state$keep & keep
  state
}

encode_apply_replicate_policy <- function(state, files, policy, output_priority) {
  if (identical(policy, "all")) {
    return(state)
  }
  if (identical(policy, "replicate_level")) {
    return(encode_apply_selection_filter(
      state,
      keep = !is.na(files$biological_replicates) & nzchar(files$biological_replicates),
      reason = "not replicate-level",
      active = TRUE
    ))
  }
  if (identical(policy, "pooled_only")) {
    pooled <- grepl("pooled|idr|pseudoreplicated|optimal|conservative", files$output_type, ignore.case = TRUE)
    return(encode_apply_selection_filter(
      state,
      keep = pooled,
      reason = "not pooled or IDR-like",
      active = TRUE
    ))
  }
  if (identical(policy, "preferred_processed") && !is.null(output_priority)) {
    return(encode_keep_best_output_type(state, files, output_priority))
  }
  state
}

encode_keep_best_output_type <- function(state, files, output_priority) {
  ranks <- match(tolower(files$output_type), tolower(output_priority))
  groups <- files$experiment_accession
  groups[is.na(groups) | !nzchar(groups)] <- files$file_accession[is.na(groups) | !nzchar(groups)]
  keep <- state$keep
  for (group in unique(groups[state$keep])) {
    index <- which(state$keep & groups == group)
    ranked <- ranks[index]
    if (all(is.na(ranked))) {
      next
    }
    best <- min(ranked, na.rm = TRUE)
    lower_priority <- index[is.na(ranked) | ranked > best]
    keep[lower_priority] <- FALSE
  }
  encode_apply_selection_filter(
    state,
    keep = keep,
    reason = "lower-priority output type",
    active = TRUE
  )
}

encode_match_values <- function(values, allowed) {
  if (is.null(allowed)) {
    return(rep(TRUE, length(values)))
  }
  !is.na(values) & tolower(values) %in% tolower(allowed)
}

encode_has_download_url <- function(files) {
  has_href <- !is.na(files$href) & nzchar(files$href)
  has_download <- !is.na(files$download_url) & nzchar(files$download_url)
  has_href | has_download
}

encode_exclusion_table <- function(files, reasons) {
  excluded <- which(vapply(reasons, length, integer(1L)) > 0L)
  if (length(excluded) == 0L) {
    return(data.frame(
      file_accession = character(),
      experiment_accession = character(),
      reason = character(),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    file_accession = files$file_accession[excluded],
    experiment_accession = files$experiment_accession[excluded],
    reason = vapply(reasons[excluded], function(x) paste(unique(x), collapse = "; "), character(1L)),
    stringsAsFactors = FALSE
  )
}
