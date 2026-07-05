## CHANGES IN VERSION 0.99.0

NEW FEATURES

    o Query ENCODE search endpoints from R.

    o Search common ENCODE biology fields with direct arguments such as
      organism, assay, biosample, organ, system, life_stage, target,
      target_category, and exclude_controls.

    o List file metadata for ENCODE experiments, including file accessions,
      formats, output types, assemblies, file sizes, checksums, download URLs,
      biosample fields, targets, controls, and analysis accessions when present.

    o Select files by accession, status, format, output type, assembly, and
      ENCODE preferred-default status.

    o Provide selection presets for common ENCODE file types, including raw
      FASTQ files, RNA-seq gene quantification tables, ATAC-seq peaks,
      ChIP-seq IDR peaks, and ChIP-seq signal bigWig files.

    o Check downloads before transfer with encode_download(dry_run = TRUE),
      including destination paths, known total size, and unknown-size counts.

    o Download selected files with existing-file checks, temporary partial files,
      file-size verification, and MD5 verification when metadata are available.

    o Download and read supported files in one step with
      encode_download(read = TRUE). RNA-seq gene-quantification tables can be
      merged into raw-count, TPM, FPKM, or RPKM matrices.

    o Read supported local text, table, JSON, interval, and sequence files.
      BED-like interval files use GRanges via rtracklayer when available, and
      users can request plain tables with encode_read(as = "data.frame").

    o Preserve raw ENCODE gene-quantification columns with
      encode_read(simplify_quant = FALSE) when the normalized expression-column
      view is not desired.

    o Create reproducibility manifests with ENCODE dataset and file attribution.

USER-VISIBLE CHANGES

    o The package is named encodeUtils.

    o Search and file-list outputs print compact tables by default. Use
      encode_results() to extract the underlying data frame.

    o The README includes ENCODE database overview figures for common RNA-seq,
      ChIP-seq, and ATAC-seq experiment metadata.

    o encode_search() defaults to metadata = "full" so common
      lab, organism, biosample, target, control, and release-date fields are
      available in printed tables.

    o encode_download() refuses real downloads with missing file_size metadata
      unless allow_unknown_size = TRUE. Dry-runs still report those files.

    o encode_manifest() records the query, selected files, downloads, and
      ENCODE attribution metadata.
