#' Read a local ENCODE file
#'
#' Read one or more files that are already on disk. Small tabular and JSON files
#' are loaded directly. Genomic interval and sequence formats use optional
#' Bioconductor readers when they are installed. Large or unsupported formats
#' return a path object by default.
#'
#' When downloaded gene-quantification TSV tables are read together, the
#' returned object includes sample metadata, individual file tables, and a merged
#' raw-count matrix. Request TPM, FPKM, or RPKM with `values` when needed.
#' A single local path or one-row downloaded-file table returns the native object
#' for that file. A downloaded-file table with more than one row returns an
#' `encode_loaded_files` collection with `metadata`, `data`, `matrices`, and
#' `by_experiment` components. `files`, `raw_counts`, and `tpm` are convenience
#' aliases for `metadata`, `matrices$raw_counts`, and `matrices$TPM` when those
#' objects are available. Set `as_collection = TRUE` for a downloaded-file table
#' when you want an `encode_loaded_files` collection even for one row.
#'
#' @param path Local file path, downloaded-file table, or file table with a
#'   `local_path` column.
#' @param format Optional file format override.
#' @param max_size Maximum size to read into memory, as bytes or a string.
#' @param region Optional genomic range object passed to `rtracklayer::import()`
#'   as `which` for indexed genomic formats.
#' @param allow_large Whether to allow full import of indexed formats such as
#'   bigWig or bigBed without `region`.
#' @param unsupported What to do for unsupported formats. Use `"return_path"`
#'   to return an `encode_local_file` path object, or `"error"` to fail.
#' @param as Return type. `"auto"` uses Bioconductor classes for genomic
#'   formats when the optional reader package is installed, including
#'   `GRanges` for BED-like intervals when `GenomicRanges` and `IRanges` are
#'   installed. Use `"data.frame"` to force tabular BED-like output,
#'   `"GRanges"` to require genomic ranges for BED-like formats, or `"path"` to
#'   return an `encode_local_file` path object.
#' @param row_names Column to use for row names in loaded expression tables.
#'   Use `"none"` to keep default integer row names.
#' @param values Expression values to combine across files. Defaults to
#'   `"raw_counts"`. Use values such as `"TPM"`, `"FPKM"`, or `"RPKM"` when
#'   those matrices are needed, or `"all"` to build every supported matrix.
#' @param simplify_quant Whether ENCODE gene-quantification tables should be
#'   normalized to common identifier and expression columns. Use `FALSE` to
#'   preserve the raw columns from the downloaded file.
#' @param as_collection Whether downloaded-file table input should always return
#'   an `encode_loaded_files` collection. This is useful when code should handle
#'   one-file and many-file reads with the same object shape.
#' @param ... Additional arguments passed to table readers where applicable.
#'
#' @return The return type depends on input shape and file format. A local path
#'   or one-row downloaded-file table returns the native object for that file:
#'   text tables return data frames, JSON returns a list, FASTA returns a
#'   `DNAStringSet` when `Biostrings` is installed, BED-like intervals return
#'   `GRanges` when the optional genomic reader stack can parse the file, and
#'   GFF/GTF, BigWig, and BigBed return `rtracklayer` imports when available.
#'   ENCODE peak files with extra nonstandard columns may fall back to a data
#'   frame unless `as = "GRanges"` is requested. FASTQ and alignment formats
#'   return `encode_local_file` path objects by default. Multi-row
#'   downloaded-file tables, and any downloaded-file table read with
#'   `as_collection = TRUE`, return an `encode_loaded_files` object with
#'   `metadata`, `data`, `matrices`, and `by_experiment` components plus
#'   documented convenience aliases.
#' @export
#'
#' @examples
#' csv_path <- tempfile(fileext = ".csv")
#' writeLines(c("gene,value", "MYC,2.5"), csv_path)
#' encode_read(csv_path)
#'
#' bed_path <- tempfile(fileext = ".bed")
#' writeLines("chr1\t0\t10\tpeak1\t100\t+", bed_path)
#' encode_read(bed_path, as = "data.frame")
#'
#' bam_path <- tempfile(fileext = ".bam")
#' writeBin(charToRaw("placeholder"), bam_path)
#' # Alignment files are returned as paths unless read with a dedicated reader.
#' encode_read(bam_path)
#'
#' # Use with downloaded rows:
#' # downloaded <- encode_download(encode_results(selected)[1, ], directory = tempdir())
#' # encode_read(downloaded[1, ])
#' # loaded <- encode_read(downloaded)
#' # loaded$metadata
#' # loaded$raw_counts
#' # loaded <- encode_read(downloaded, values = c("raw_counts", "TPM"))
#' # loaded$tpm
#' # one_loaded <- encode_read(downloaded[1, ], as_collection = TRUE)
encode_read <- function(
                        path,
                        format = NULL,
                        max_size = "100MB",
                        region = NULL,
                        allow_large = FALSE,
                        unsupported = c("return_path", "error"),
                        as = c("auto", "data.frame", "GRanges", "path"),
                        row_names = c("gene_symbol", "ensembl_id", "entrez_id", "none"),
                        values = "raw_counts",
                        simplify_quant = TRUE,
                        as_collection = FALSE,
                        ...) {
  unsupported <- match.arg(unsupported)
  as <- match.arg(as)
  row_names <- match.arg(row_names)
  values <- encode_normalize_matrix_values(values)
  if (!is.logical(as_collection) || length(as_collection) != 1L || is.na(as_collection)) {
    cli::cli_abort("{.arg as_collection} must be {.code TRUE} or {.code FALSE}.")
  }
  if (encode_is_read_table(path)) {
    if (!"local_path" %in% names(path)) {
      cli::cli_abort("{.arg path} table input must include {.field local_path}.")
    }
    if (nrow(path) != 1L || isTRUE(as_collection)) {
      return(encode_load_downloaded_files(
        path,
        max_size = max_size,
        format = format,
        region = region,
        allow_large = allow_large,
        unsupported = unsupported,
        as = as,
        row_names = row_names,
        matrix_values = values,
        simplify_quant = simplify_quant,
        quiet = TRUE
      ))
    }
    format <- format %||% encode_row_read_format(path, NULL)
  } else if (isTRUE(as_collection)) {
    cli::cli_abort("{.arg as_collection} requires downloaded-file table input with a {.field local_path} column.")
  }
  path <- encode_read_path(path)
  if (!file.exists(path)) {
    cli::cli_abort("File does not exist: {.path {path}}.")
  }
  if (identical(as, "path")) {
    return(encode_unsupported_local_file(
      path = path,
      reason = "path return requested",
      unsupported = "return_path"
    ))
  }
  max_size <- encode_parse_size(max_size, arg = "max_size")
  file_size <- as.numeric(file.info(path)$size)
  if (!is.na(file_size) && file_size > max_size) {
    return(encode_unsupported_local_file(
      path = path,
      reason = "file exceeds max_size",
      unsupported = unsupported
    ))
  }

  format <- format %||% encode_get_extension(path)
  format <- tolower(format)
  if (format %in% c("tsv", "txt")) {
    return(encode_set_row_names(
      encode_read_tsv(path, simplify_quant = simplify_quant, ...),
      row_names
    ))
  }
  if (format %in% c("csv")) {
    return(utils::read.csv(path, stringsAsFactors = FALSE, ...))
  }
  if (format %in% c("json")) {
    return(jsonlite::fromJSON(path, simplifyVector = FALSE))
  }
  if (format %in% c("bw", "bigwig", "bb", "bigbed") && is.null(region) && !isTRUE(allow_large)) {
    ## Indexed signal and annotation files can be very large; require an
    ## explicit region or opt-in full import.
    return(encode_unsupported_local_file(
      path = path,
      reason = "indexed signal and annotation files require region or allow_large = TRUE",
      unsupported = unsupported
    ))
  }
  if (format %in% c("bed", "narrowpeak", "broadpeak")) {
    return(encode_read_bed(path, format = format, as = as, unsupported = unsupported))
  }
  if (format %in% c("gff", "gtf", "bw", "bigwig", "bb", "bigbed")) {
    return(encode_read_with_optional_package(
      package = "rtracklayer",
      fun = "import",
      path = path,
      unsupported = unsupported,
      reason = "rtracklayer is required for genomic interval imports",
      region = region,
      ...
    ))
  }
  if (format %in% c("fa", "fasta")) {
    return(encode_read_with_optional_package(
      package = "Biostrings",
      fun = "readDNAStringSet",
      path = path,
      unsupported = unsupported,
      reason = "Biostrings is required for FASTA imports"
    ))
  }
  if (format %in% c("fq", "fastq")) {
    return(encode_unsupported_local_file(
      path = path,
      reason = "FASTQ files are returned as paths; use a read-processing tool for sequence data",
      unsupported = unsupported
    ))
  }
  if (format %in% c("bam", "cram", "sam")) {
    return(encode_unsupported_local_file(
      path = path,
      reason = "alignment files are returned as paths; use Rsamtools or GenomicAlignments for region-based reads",
      unsupported = unsupported
    ))
  }

  encode_unsupported_local_file(
    path = path,
    reason = paste0("unsupported file format: ", format),
    unsupported = unsupported
  )
}

encode_read_tsv <- function(path, simplify_quant = TRUE, ...) {
  first_lines <- encode_read_lines(path, n = 5L)
  if (length(first_lines) == 0L) {
    return(data.frame())
  }
  if (encode_is_featurecounts_tsv(first_lines)) {
    return(encode_read_featurecounts(path, simplify_quant = simplify_quant))
  }
  if (encode_is_htseq_counts_tsv(first_lines)) {
    return(encode_read_htseq_counts(path, simplify_quant = simplify_quant))
  }
  table <- utils::read.delim(path, stringsAsFactors = FALSE, check.names = FALSE, ...)
  if (!isTRUE(simplify_quant)) {
    return(table)
  }
  encode_simplify_quant_table(table)
}

encode_read_featurecounts <- function(path, simplify_quant = TRUE) {
  table <- utils::read.delim(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    comment.char = "#"
  )
  if (!isTRUE(simplify_quant)) {
    return(table)
  }
  names(table)[names(table) == "Geneid"] <- "gene_id"
  count_column <- utils::tail(names(table), 1L)
  names(table)[names(table) == count_column] <- "counts"
  table[, intersect(c("gene_id", "counts"), names(table)), drop = FALSE]
}

encode_read_lines <- function(path, n) {
  connection <- if (grepl("[.]gz$", path, ignore.case = TRUE)) {
    gzfile(path, open = "rt")
  } else {
    file(path, open = "rt")
  }
  on.exit(close(connection), add = TRUE)
  readLines(connection, n = n, warn = FALSE)
}

encode_is_featurecounts_tsv <- function(lines) {
  any(grepl("^Geneid\\tChr\\tStart\\tEnd\\tStrand\\tLength\\t", lines))
}

encode_is_htseq_counts_tsv <- function(lines) {
  fields <- strsplit(lines[[1L]], "\t", fixed = TRUE)[[1L]]
  length(fields) %in% c(2L, 4L) &&
    grepl("^(N_|ENS[A-Z]*G|[0-9]+)", fields[[1L]]) &&
    all(grepl("^-?[0-9]+([.][0-9]+)?$", fields[-1L]))
}

encode_read_htseq_counts <- function(path, simplify_quant = TRUE) {
  table <- utils::read.delim(
    path,
    header = FALSE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (!isTRUE(simplify_quant)) {
    return(table)
  }
  if (ncol(table) == 2L) {
    names(table) <- c("gene_id", "counts")
  } else if (ncol(table) == 4L) {
    names(table) <- c("gene_id", "counts", "stranded_first", "stranded_second")
  } else {
    names(table)[[1L]] <- "gene_id"
    names(table)[[2L]] <- "counts"
  }
  table <- table[!grepl("^N_", table$gene_id), , drop = FALSE]
  table[, intersect(c("gene_id", "counts"), names(table)), drop = FALSE]
}

encode_simplify_quant_table <- function(table) {
  if (!is.data.frame(table) || !"gene_id" %in% names(table)) {
    return(table)
  }
  if (!any(c("expected_count", "counts", "count", "TPM", "FPKM", "RPKM") %in% names(table))) {
    return(table)
  }
  table <- as.data.frame(table, stringsAsFactors = FALSE)
  if (!"raw_counts" %in% names(table)) {
    if ("expected_count" %in% names(table)) {
      table$raw_counts <- table$expected_count
    } else if ("counts" %in% names(table)) {
      table$raw_counts <- table$counts
    } else if ("count" %in% names(table)) {
      table$raw_counts <- table$count
    }
  }
  table <- encode_normalize_quant_identifiers(table)
  columns <- intersect(c("gene_symbol", "ensembl_id", "entrez_id", "raw_counts", "TPM", "FPKM", "RPKM"), names(table))
  table[, columns, drop = FALSE]
}

encode_normalize_quant_identifiers <- function(table) {
  if (!"gene_id" %in% names(table)) {
    return(table)
  }
  gene_id <- as.character(table$gene_id)
  if (!"ensembl_id" %in% names(table)) {
    table$ensembl_id <- ifelse(grepl("^ENS[A-Z]*G[0-9]+([.][0-9]+)?$", gene_id), gene_id, NA_character_)
  }
  if (!"entrez_id" %in% names(table)) {
    table$entrez_id <- ifelse(grepl("^[0-9]+$", gene_id), gene_id, NA_character_)
  }
  if (!"gene_symbol" %in% names(table)) {
    table$gene_symbol <- ifelse(
      !grepl("^ENS[A-Z]*G[0-9]+([.][0-9]+)?$", gene_id) & !grepl("^[0-9]+$", gene_id),
      gene_id,
      NA_character_
    )
  }
  table
}

encode_read_bed <- function(path, format = "bed", as = "auto", unsupported = "return_path") {
  if (identical(as, "data.frame")) {
    return(encode_read_bed_table(path, format = format))
  }
  if (identical(as, "auto") && !encode_can_return_granges()) {
    return(encode_read_bed_table(path, format = format))
  }
  if (as %in% c("auto", "GRanges")) {
    return(encode_read_bed_granges(path, format = format, unsupported = unsupported))
  }
  encode_read_bed_table(path, format = format)
}

encode_read_bed_granges <- function(path, format = "bed", unsupported = "return_path") {
  if (!encode_can_return_granges()) {
    return(encode_unsupported_local_file(
      path = path,
      reason = "GenomicRanges and IRanges are required to import BED-like files as GRanges",
      unsupported = unsupported
    ))
  }
  imported <- if (requireNamespace("rtracklayer", quietly = TRUE)) {
    try(rtracklayer::import(path, format = "BED"), silent = TRUE)
  } else {
    structure("rtracklayer is not installed", class = "try-error")
  }
  if (!inherits(imported, "try-error")) {
    return(imported)
  }
  ## rtracklayer handles standard BED-like files. ENCODE peak files can include
  ## additional columns, so fall back to a parsed table and construct GRanges
  ## from chrom/start/end when possible.
  table <- encode_read_bed_table(path, format = format)
  tryCatch(
    encode_bed_table_to_granges(table),
    error = function(cnd) {
      if (identical(unsupported, "error")) {
        cli::cli_abort(c(
          "Failed to convert BED-like file to GRanges.",
          "x" = conditionMessage(cnd),
          "i" = "Use {.code as = \"data.frame\"} to read the file as a table."
        ))
      }
      table
    }
  )
}

encode_can_return_granges <- function() {
  requireNamespace("GenomicRanges", quietly = TRUE) &&
    requireNamespace("IRanges", quietly = TRUE)
}

encode_bed_table_to_granges <- function(table) {
  required <- c("chrom", "start", "end")
  if (!all(required %in% names(table))) {
    cli::cli_abort("BED-like table must contain chrom, start, and end columns.")
  }
  start <- encode_as_integer_no_warning(table$start) + 1L
  end <- encode_as_integer_no_warning(table$end)
  if (anyNA(start) || anyNA(end)) {
    cli::cli_abort("BED-like start and end columns must be numeric.")
  }
  if (any(end < start)) {
    cli::cli_abort("BED-like end positions must be greater than or equal to start positions after coordinate conversion.")
  }
  strand <- rep("*", nrow(table))
  if ("strand" %in% names(table)) {
    observed <- as.character(table$strand)
    strand[observed %in% c("+", "-", "*")] <- observed[observed %in% c("+", "-", "*")]
  }
  metadata <- table[, setdiff(names(table), c("chrom", "start", "end", "strand")), drop = FALSE]
  do.call(
    GenomicRanges::GRanges,
    c(
      list(
        seqnames = as.character(table$chrom),
        ranges = IRanges::IRanges(start = start, end = end),
        strand = strand
      ),
      as.list(metadata)
    )
  )
}

encode_as_integer_no_warning <- function(x) {
  withCallingHandlers(
    as.integer(x),
    warning = function(cnd) {
      invokeRestart("muffleWarning")
    }
  )
}

encode_read_bed_table <- function(path, format = "bed") {
  table <- utils::read.delim(
    path,
    header = FALSE,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    comment.char = "#"
  )
  format <- tolower(format)
  names <- switch(
    format,
    narrowpeak = c(
      "chrom", "start", "end", "name", "score", "strand",
      "signal_value", "p_value", "q_value", "peak"
    ),
    broadpeak = c(
      "chrom", "start", "end", "name", "score", "strand",
      "signal_value", "p_value", "q_value"
    ),
    c("chrom", "start", "end", "name", "score", "strand")
  )
  named_count <- min(length(names), ncol(table))
  extra_count <- ncol(table) - named_count
  column_names <- names[seq_len(named_count)]
  if (extra_count > 0L) {
    column_names <- c(column_names, paste0("extra_", seq_len(extra_count)))
  }
  names(table) <- column_names
  table
}

encode_read_path <- function(path) {
  if (encode_is_read_table(path)) {
    if (!"local_path" %in% names(path)) {
      cli::cli_abort("{.arg path} table input must include {.field local_path}.")
    }
    if (nrow(path) != 1L) {
      cli::cli_abort("{.arg path} table input must contain exactly one row.")
    }
    return(path$local_path[[1L]])
  }
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    cli::cli_abort("{.arg path} must be one local file path.")
  }
  path
}

encode_is_read_table <- function(path) {
  is.data.frame(path) &&
    ("local_path" %in% names(path) ||
      inherits(path, "encode_download_result") ||
      inherits(path, "encode_file_table"))
}

encode_read_with_optional_package <- function(package, fun, path, unsupported, reason, region = NULL, ...) {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(encode_unsupported_local_file(
      path = path,
      reason = reason,
      unsupported = unsupported
    ))
  }
  reader <- getExportedValue(package, fun)
  if (is.null(region)) {
    return(reader(path, ...))
  }
  reader(path, which = region, ...)
}

encode_unsupported_local_file <- function(path, reason, unsupported) {
  if (identical(unsupported, "error")) {
    cli::cli_abort(reason)
  }
  result <- list(
    path = path,
    reason = reason,
    file_size = as.numeric(file.info(path)$size),
    file_size_pretty = encode_pretty_bytes(as.numeric(file.info(path)$size))
  )
  class(result) <- c("encode_local_file", "list")
  result
}
