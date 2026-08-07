# encodeUtils 0.99.0

## Initial Bioconductor submission

- Added a focused eight-function workflow for searching ENCODE metadata,
  listing and selecting files, planning and verifying downloads, reading local
  files, and recording reproducibility manifests.
- Returned genomic intervals as `GRanges` objects and compatible expression
  matrices as `SummarizedExperiment` objects with aligned feature, file, query,
  request, and selection metadata.
- Added bounded downloads with reported-size limits, unique partial files,
  cautious replacement, and observed size and MD5 verification.
- Added a fully evaluated ENCODE microRNA-seq vignette covering discovery,
  file selection, a small verified transfer, count-matrix construction, and
  manifest creation.
- Added deterministic fixture-based tests, an opt-in live service check, and
  cross-platform R CMD check and coverage workflows.
- Preserved every successful ENCODE request used to construct file-search
  results, including parent-metadata enrichment requests.
- Required exactly one featureCounts sample column for automatic
  simplification; multi-sample tables can be retained unchanged.
- Kept unknown attribution retrieval dates as `NA` instead of substituting the
  manifest creation date.
