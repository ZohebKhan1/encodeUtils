# encodeUtils 0.99.0

## Initial Bioconductor submission

- Provides eight functions to search ENCODE metadata, list and select files,
  plan and verify downloads, read local files, and create manifests.
- Reads genomic intervals as `GRanges` objects and aligned expression matrices
  as `SummarizedExperiment` objects. Feature, file, query, request, and
  selection metadata are retained.
- Applies per-file and total-size limits before downloading. Transfers use
  temporary files and are checked against reported sizes and MD5 values.
- Includes an evaluated ENCODE microRNA-seq vignette covering search, file
  selection, download, count-matrix construction, and manifest creation.
- Includes fixture-based unit tests, a separate live-service test, R CMD check
  workflows, and a coverage workflow.
- Records successful requests used to construct file-search results, including
  parent-metadata requests.
- Requires one featureCounts sample column for automatic simplification.
  Multi-sample tables can be retained with `simplify_quant = FALSE`.
- Uses `NA` when an attribution retrieval date is unknown.
