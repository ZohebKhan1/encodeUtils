# encodeUtils 0.99.0

## Initial Bioconductor submission

- Provides focused functions to search ENCODE metadata, list and select files,
  plan and verify downloads, read local files, and create manifests.
- Reads genomic intervals as `GRanges` objects. Quantification preparation and
  `SummarizedExperiment` assembly are explicit operations.
- Uses uncapped download defaults; optional per-file and total-size limits remain
  available. Transfers use temporary files and are checked against reported
  sizes and MD5 values when supplied by ENCODE.
- Includes an evaluated ENCODE microRNA-seq vignette covering search, file
  selection, download, count-matrix construction, and manifest creation.
- Includes fixture-based unit tests, a separate live-service test, R CMD check
  workflows, and a coverage workflow.
- Records successful requests and preserves their provenance across file-table
  row subsetting.
- Uses `httr2` retry and throttle policies instead of package-global request
  state.
