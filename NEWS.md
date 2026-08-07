# encodeUtils 0.99.15

## Documentation

- Added a linked function table to the README and standardized spacing in the
  README and vignette examples.

# encodeUtils 0.99.14

## Documentation

- Split the README workflow into short steps with console output and shortened
  the introductory vignette.

# encodeUtils 0.99.12

## Submission readiness

- File searches with finite limits now stop before expanding more than 25
  parent experiments. Use `limit = "all"` to request the complete search.
- Live search, file-listing, and download-plan examples now run during package
  checks.
- Documented how the package differs from `ENCODExplorerData` and the former
  `ENCODExplorer` package.
- Clarified that download limits use ENCODE-reported sizes before transfer.
  Observed size and MD5 are checked after transfer.

# encodeUtils 0.99.11

## Live workflow

- Replaced the synthetic tutorial with a live ENCODE workflow using two pinned
  mouse-heart microRNA quantification files. The files total about 122 KB and
  are downloaded under per-file and total size limits.
- Kept live search and file-listing examples interactive. The vignette runs the
  complete network workflow during its build.
- Added evaluated output for loaded objects and noted that the source files
  contain counts but not TPM values.

## Correctness and provenance

- File-search limits now count files rather than parent experiments. Removed a
  non-equivalent direct fallback and retained parent and chunk requests in
  result tables and manifests.
- Matrix construction now rejects conflicting organism, assembly, output type,
  genome annotation, or feature-set metadata. `SummarizedExperiment` column
  metadata is aligned to assay columns and retains request and selection
  provenance.
- Removed automatic `org.*.eg.db` annotation. Simplified tables now use source
  identifiers only.
- Applied `max_size` to decompressed text, assigned unique partial-download
  paths, and calculated observed MD5 values independently of portal metadata.
- Added explicit `gene_id` row-name selection for expression tables.
- Applied preferred-default selection within each experiment, distinguished
  pooled and replicate-level files, and retained all exclusion reasons.

# encodeUtils 0.99.10

## Bioconductor readiness

- Added an evaluated offline vignette example using packaged quantification
  tables. The live ENCODE example remains in a separate network-dependent
  block.
- Replaced interactive wrappers in offline examples with runnable calls for
  selection, download planning, result extraction, reading, and manifest
  creation.
- `encode_read(..., as = "SummarizedExperiment")` now returns an aligned
  `SummarizedExperiment` when the input matrices are compatible. The default
  remains an `encode_loaded_files` object.

## Provenance

- Preserved the ENCODE base URL and retrieval time from search results in
  manifests.
- Preserved the request that supplied file metadata for direct-accession and
  search-result download routes.
- Documented that existing result objects and file tables do not require an
  attribution request. Character ENCSR or ENCFF input requires a metadata
  query.

# encodeUtils 0.99.9

## Provenance

- Added the ENCODE query URL, retrieval time, and active filters to manifests
  built from `encode_select_files()` and `encode_read()` results.
- Preserved input metadata retrieval times in planned and completed download
  results.
- Documented that manifest attribution reuses input metadata without another
  request. For processed files, `lab`, `institution`, and `project` refer to
  the processing pipeline.

## Reading and printing

- Applied `row_names` to CSV files as well as TSV and text files.
- Printed known file sizes without quotes.

## Internal

- Removed unused metadata-request, cloud-URL, and duplicate-name code paths.
- Removed roxygen examples from internal `@noRd` blocks.

# encodeUtils 0.99.8

## API and behavior

- Added validation for public string, string-vector, and logical arguments.
  Invalid values now identify the affected argument.
- Standardized search results on `query_url` and removed the duplicate `url`,
  `total_results`, and `requested_limit` fields.
- Standardized download status fields for planned, downloaded, existing,
  verification-failed, and transfer-failed files. `md5sum` stores the expected
  checksum and `observed_md5` stores the local checksum.
- Preserved `gene_id` when simplifying quantification tables and standardized
  featureCounts and HTSeq count columns as `raw_counts`. Matrix assembly now
  supports complete source identifiers when identifier types differ.
- Reused the enriched File search table in `encode_list_files()` instead of
  retrieving parent experiments again.
- Labeled File search records as `files` in manifests and reported attribution
  failures.
- Recorded manifest creation times as UTC ISO 8601 values with second
  precision and printed manifest identifiers without quotes.

## Documentation and tests

- Replaced the simulated vignette with an ENCODE RNA-seq workflow covering
  search, file listing, selection, download, matrix assembly, and manifest
  creation.
- Added test-coverage and R-version badges. The coverage workflow checks the
  displayed value.
- Added contract tests for argument validation, result schemas, transfer
  failures, File search manifests, and duplicate parent-metadata requests.

# encodeUtils 0.99.7

## API and behavior

- Applied `quiet` consistently to search, file-listing, selection, and download
  functions.
- Added transfer status, verification results, destination paths, and failure
  reasons to download output.
- Expression matrices are now built only when all tables have a complete,
  unique biological feature key. Tables with ambiguous identifiers remain
  separate.
- Built experiment attribution URLs from experiment accessions instead of
  assuming that every parent dataset is an Experiment.

## Documentation

- Documented the main workflow, matrix alignment, native file readers, and
  development installation.
- Grouped internal helpers and applied four-space indentation to R source.

# encodeUtils 0.99.6

## File import

- Added support for GFF files that begin with UCSC `track` or `browser`
  directives.
- Applied the documented fallback when an optional native reader rejects a
  nonstandard schema.

# encodeUtils 0.99.5

## Bioconductor integration

- Moved `GenomicRanges` and `IRanges` to core dependencies so BED-like files
  consistently return `GRanges` objects.
- Corrected package metadata and excluded generated check directories from
  package builds.

# encodeUtils 0.99.4

## Documentation and continuous integration

- Consolidated the introductory documentation into one vignette and added
  installation and workflow sections to the README.
- Removed generated database-overview images and unused data exclusions.
- Added package build, vignette, manual, and check jobs for release and
  development R.

# encodeUtils 0.99.3

## Public API

- Reduced the exported API to eight workflow functions and removed obsolete
  schema, interactive-selection, count, and local-filter interfaces.
- Separated download from import: `encode_download()` returns download records,
  and `encode_read()` reads local files.
- Standardized download arguments, selection presets, and the
  `encode_loaded_files` structure.

## Reliability

- Preserved raw quantification columns when simplification is disabled.
- Verified replacement downloads before removing an existing destination.
- Capped server-requested retry delays and validated retry and throttle
  settings.
- Replaced duplicate implementation tests with fixture-based tests of public
  contracts, provenance, retries, matrix alignment, and atomic replacement.

# encodeUtils 0.99.2

## Documentation

- Documented return values for search, file listing, file selection, download,
  reading, manifest creation, and result accessors.
- Documented package scope, file-search fallback, transfer safety, genomic
  imports, and matrix construction.

# encodeUtils 0.99.1

## Download safety

- Set default download limits to 250 MB per file and 500 MB total.
- Required direct experiment downloads to be narrowed before transfer.
- Included the request URL and final connection error after failed retries.
- Preserved existing destination files when a replacement failed verification.

## Metadata

- Recorded parent-enrichment failures on returned file tables.
- Read organism metadata from nested biosamples and recognized common ENCODE
  model organisms.
- Replaced append-style list growth for large file and attribution result sets.

# encodeUtils 0.99.0

## Initial release

- Searched current ENCODE Portal records by accession and biological metadata.
- Flattened experiment and file metadata while retaining query, request, and
  attribution records.
- Listed and selected files by accession, status, format, output type,
  assembly, preset, and preferred-default status.
- Downloaded files with size limits, partial files, existing-file checks, and
  size or MD5 verification.
- Read supported text, JSON, interval, sequence, and quantification files.
- Combined compatible RNA-seq tables into aligned count or expression
  matrices.
- Created JSON-ready provenance manifests for ENCODE experiments and files.
