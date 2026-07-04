## CHANGES IN VERSION 0.99.0

NEW FEATURES

    o Query ENCODE search, matrix, and object endpoints from R.

    o List file metadata for ENCODE experiments, including file accessions,
      formats, output types, assemblies, file sizes, checksums, download URLs,
      biosample fields, targets, controls, and analysis accessions when present.

    o Select files by accession, status, format, output type, assembly, and
      ENCODE preferred-default status.

    o Provide selection presets for common ENCODE file types, including raw
      FASTQ files, RNA-seq gene quantification tables, ATAC-seq peaks,
      ChIP-seq IDR peaks, and ChIP-seq signal bigWig files.

    o Preview downloads before transfer, including destination paths, known
      total size, unknown-size counts, largest files, and checksum availability.

    o Download selected files with existing-file checks, temporary partial files,
      file-size verification, and MD5 verification when metadata are available.

    o Read supported local text, table, JSON, interval, and sequence files.
      Optional Bioconductor readers are used for genomic formats when installed.

    o Create reproducibility manifests with ENCODE dataset and file attribution.

USER-VISIBLE CHANGES

    o The package is named encodeUtils.

    o Search and file-list outputs print compact tables by default. Use
      encode_results() to extract the underlying data frame.

    o encode_search() and encode_get() default to metadata = "full" so common
      lab, organism, biosample, target, control, and release-date fields are
      available in printed tables.

    o encode_download() refuses real downloads with missing file_size metadata
      unless allow_unknown_size = TRUE. Dry-runs and previews still report those
      files.

    o encode_manifest() records the query, selected files, downloads, and
      ENCODE attribution metadata.
