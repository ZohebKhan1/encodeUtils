# encodeUtils 0.99.15

## Documentation

- Add a linked function overview, simplify examples, and apply consistent
  spacing to the README and introductory vignette code chunks.

# encodeUtils 0.99.14

## Documentation

- Split the README workflow into short steps with representative console output
  and streamline the introductory vignette.

# encodeUtils 0.99.13

## Submission readiness

- Disclose AI assistance used to develop the test suite and the maintainer's
  review of and responsibility for all package code.

# encodeUtils 0.99.12

## Submission readiness

- Refuse limited biological File searches that would expand across more than
  25 parent experiments. The existing `limit = "all"` value is the explicit
  opt-in for complete expansion, so no new public argument is required.
- Run the small live search, file-listing, and download-plan help examples
  during ordinary example checks.
- Compare the package directly with `ENCODExplorerData` and the former
  `ENCODExplorer` software package.
- Describe download budgets as checks on ENCODE-reported planning sizes,
  followed by observed size and MD5 verification after transfer.

# encodeUtils 0.99.11

## Live workflow

- Replace the synthetic primary tutorial with an evaluated live ENCODE
  workflow pinned to released mouse-heart microRNA quantification records.
  The two verified files total about 122 KB and are downloaded under explicit
  per-file and total size limits.
- Keep live search and file-listing help examples interactive while the
  vignette exercises the complete network workflow during its build.
- Show compact, evaluated output for every loaded-object component, distinguish
  source counts from unavailable TPM values, and separate independent reference
  example calls for readability.

## Correctness and provenance

- Apply File-search limits to files rather than parent experiments, remove the
  non-equivalent direct fallback, and retain every parent and chunk request in
  result tables and manifests.
- Refuse matrix assembly across conflicting organism, assembly, output-type,
  genome-annotation, or feature-set metadata; align `SummarizedExperiment`
  sample metadata to the files that contributed assay columns, and retain the
  source requests and file-selection criteria in its package-level metadata.
- Remove environment-dependent automatic `org.*.eg.db` annotation. Table
  simplification now uses only identifiers already present in the source file.
- Enforce `max_size` against decompressed text size, use unique partial-download
  paths, and compute observed MD5 values independently of portal metadata.
- Allow `gene_id` to be selected explicitly for expression-table row names.
- Apply preferred-default selection within each experiment, distinguish pooled
  from replicate-level files, and retain every applicable exclusion reason.

# encodeUtils 0.99.10

## Bioconductor readiness

- Add a small, evaluated offline vignette workflow using packaged synthetic
  quantification tables. The live ENCODE workflow remains one clearly marked
  network-dependent code block.
- Replace interactive wrappers in offline-capable examples with runnable
  examples for selection, download planning, result extraction, reading, and
  manifest creation.
- Return an aligned `SummarizedExperiment` directly from
  `encode_read(..., as = "SummarizedExperiment")` when compatible matrices
  are available, while retaining the heterogeneous `encode_loaded_files`
  collection as the default.

## Provenance

- Preserve a search result's recorded ENCODE base URL and retrieval time in
  manifests.
- Normalize download input before carrying provenance forward, so direct
  accession and search-result download routes report the request that supplied
  their file metadata.
- Clarify that manifest attribution is request-free for existing result
  objects and file tables, but character ENCSR or ENCFF input must first query
  ENCODE metadata.

# encodeUtils 0.99.9

## Provenance

- Record the ENCODE query URL, retrieval time, and active filters in manifests
  built from `encode_select_files()` and `encode_read()` results. These fields
  were previously empty for the workflow ending in `encode_manifest(loaded)`,
  even though the selected-file and loaded-file tables carried them.
- Carry the metadata retrieval time of the input through `encode_download()`,
  so planned and completed download results report when the ENCODE file
  metadata was retrieved rather than leaving `retrieved_at` empty.
- Document that manifest attribution reuses the metadata already held by the
  input and issues no further requests. For processed ENCODE files, `lab`,
  `institution`, and `project` describe the processing pipeline, not the
  originating laboratory.

## Reading and printing

- Apply `row_names` to CSV input, matching the existing behavior for TSV and
  text tables.
- Print known file sizes without surrounding quotation marks in file, summary,
  and local-file output.

## Internal

- Remove three unreachable code paths: the unused `frame` branch of the
  metadata-request helper, the cloud-URL branch of the flattened download-URL
  helper, and the duplicate-name fixup that followed `make.unique()`.
- Drop roxygen examples from internal `@noRd` blocks, which were never rendered
  or checked.

# encodeUtils 0.99.8

## API and behavior

- Validate public string, string-vector, and logical arguments before issuing
  requests or reading files. Invalid values now identify the responsible
  argument instead of being coerced or ignored.
- Give search results one canonical query field (`query_url`) and remove the
  duplicate `url`, `total_results`, and `requested_limit` fields.
- Give download results a stable status schema for planned, downloaded,
  existing, verification-failed, and transfer-failed rows. ENCODE's `md5sum`
  remains the expected checksum; `observed_md5` records the local checksum.
  Redundant checksum and verification aliases were removed.
- Preserve `gene_id` while simplifying quantification tables and normalize
  featureCounts and HTSeq count columns to `raw_counts`. Mixed identifier types
  can now use the complete source identifier to assemble aligned matrices.
- Reuse the enriched File search table in `encode_list_files()` instead of
  flattening the response and retrieving parent experiments a second time.
- Label File search records as `files` in manifests and report requested
  attribution failures instead of silently omitting the attribution component.
- Record manifest creation times as second-resolution UTC ISO 8601 values and
  print manifest identifiers without decorative quoting.

## Documentation and tests

- Replace the simulated vignette with a direct ENCODE RNA-seq workflow covering
  search, file listing, selection, download, matrix assembly, and manifest
  creation. Reference examples now use supported ENCODE calls rather than test
  fixtures.
- Add measured-coverage and R-version badges while retaining the R CMD check
  and pkgdown badges. The coverage workflow verifies the displayed percentage.
- Add contract tests for argument validation, result schemas, transfer failures,
  File search manifests, and duplicate parent-metadata requests.

# encodeUtils 0.99.7

## API and behavior

- Use `quiet` consistently in search, file-listing, selection, and download
  functions.
- Print transfer status, verification results, destination paths, and failure
  reasons for download results.
- Build expression matrices only when all input tables share a complete, unique
  biological feature key. Tables with ambiguous identifiers remain separate.
- Construct experiment attribution URLs from experiment accessions rather than
  assuming every parent dataset is an Experiment.

## Documentation

- Document the public workflow, matrix alignment rules, native file readers,
  and development installation.
- Group internal helper families and apply four-space indentation to R source.

# encodeUtils 0.99.6

## File import

- Import GFF files that begin with UCSC `track` or `browser` directives.
- Apply the documented fallback when an optional native reader rejects a
  nonstandard file schema.

# encodeUtils 0.99.5

## Bioconductor integration

- Move `GenomicRanges` and `IRanges` to core dependencies so BED-like imports
  return `GRanges` consistently.
- Correct package metadata and exclude generated check directories from package
  builds.

# encodeUtils 0.99.4

## Documentation and continuous integration

- Consolidate introductory material into one vignette and add installation and
  workflow sections to the README.
- Remove generated database-overview images and unused data exclusions.
- Add package build, vignette, manual, and check jobs for release and development
  R environments.

# encodeUtils 0.99.3

## Public API

- Limit the exported API to eight workflow functions and remove obsolete
  schema, interactive-selection, count, and local-filter interfaces.
- Separate transfer from import: `encode_download()` returns download records,
  and `encode_read()` loads local files.
- Standardize download arguments, selection presets, and the
  `encode_loaded_files` structure.

## Reliability

- Preserve raw quantification columns when simplification is disabled.
- Verify replacement downloads before removing an existing destination.
- Cap server-requested retry delays and validate retry and throttle options.
- Replace duplicated implementation tests with fixture-backed tests of public
  contracts, provenance, retries, matrix alignment, and atomic replacement.

# encodeUtils 0.99.2

## Documentation

- Define return-value contracts for search, file listing, file selection,
  download, read, manifest, and result-accessor functions.
- Clarify package scope and document file-search fallback, transfer safety,
  genomic imports, and matrix construction.

# encodeUtils 0.99.1

## Download safety

- Set default transfer limits to 250 MB per file and 500 MB in total.
- Require direct experiment downloads to be narrowed before transfer.
- Include the request URL and final connection error when retries are exhausted.
- Preserve existing destination files when a replacement fails verification.

## Metadata

- Record parent-enrichment failures on returned file tables.
- Read organism metadata from nested biosamples and recognize common ENCODE
  model organisms.
- Avoid append-style list growth for broad file and attribution result sets.

# encodeUtils 0.99.0

## Initial release

- Search current ENCODE Portal records with accession-aware and biological
  filters.
- Flatten experiment and file metadata while retaining query, request, and
  attribution context.
- List and select ENCODE files by accession, status, format, output type,
  assembly, preset, and preferred-default status.
- Download files with size limits, temporary partial files, existing-file
  checks, and size or MD5 verification.
- Read supported text, JSON, interval, sequence, and quantification files.
- Combine compatible RNA-seq tables into aligned count or expression matrices.
- Create JSON-ready provenance manifests for ENCODE experiments and files.
