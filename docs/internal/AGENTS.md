# Encode R Package Guidance

This workspace is for designing and implementing an R package that makes ENCODE
Portal metadata, files, and selected datasets straightforward to find, download,
and load from R.

The implementation goal is simple, auditable, and useful code. Prefer the direct
solution a careful senior bioinformatician would write. Do not over-engineer the
package with classes, caches, abstractions, or cross-language dependencies unless
they solve a concrete user problem.

## Local Style And Execution

- Follow `coding_guidelines.md` in this repository for R style and review
  standards.
- Use WSL-native paths under `/home/zoheb/`; never use `/mnt/c/` paths for
  active work.
- Prefer `bun` for JavaScript tooling only if JavaScript tooling becomes
  necessary. This package should not need JavaScript for the core work.
- For non-trivial R work, use the project-local `tools/r_codex_utils` runner
  once it exists. Install or verify it from the project root with
  `/home/zoheb/.codex/skills/r-codex-utils/scripts/install_r_codex_utils.sh`.
- Use Context7 or official documentation before making claims about current R,
  Bioconductor, ENCODE, or dependency behavior.
- Do not start coding before reading this file, `coding_guidelines.md`, and the
  specific source files being modified.

## Design Principles

- Keep the package read-only at first: search, inspect metadata, list files,
  download selected files, and load supported local files.
- Do not implement ENCODE submission, `POST`, or `PATCH` functionality in the
  initial package.
- Keep core dependencies lean and available on CRAN or Bioconductor.
- Prefer R-native implementation. Do not add Python, `reticulate`, command-line
  wrappers, or external system requirements unless there is a strong reason.
- Model the workflow as metadata first, selected files second, loading last.
- Do not silently download large data. Show what will be downloaded before
  downloading.
- Make all network failure messages clear and bounded. No unbounded retry loops.
- Return ordinary R objects that users can inspect in RStudio: tibbles/data
  frames, lists for raw JSON objects, and file paths for downloaded files.
- Avoid custom S4/R6 classes in the MVP. Use existing Bioconductor classes when
  loading genomic files, such as `GRanges`, `SummarizedExperiment`, or
  `DNAStringSet`, only when the return type naturally fits the data.

## ENCODE API Facts To Preserve

- ENCODE public released data can be queried without authentication.
- ENCODE programmatic API use is limited to 10 GET requests per second per user,
  group, company, or lab. Implement a conservative client-side throttle.
- ENCODE data are JSON objects. The core object types for this package are
  usually `Experiment`, `File`, `Biosample`, `Replicate`, `Library`, `Donor`,
  `Target`, and schema/profile objects.
- Search results contain records in `@graph` plus useful metadata such as
  `total`, `filters`, `facets`, `columns`, and `notification`.
- Search URLs use ordinary query parameters:
  `type=Experiment`, `status=released`, `assay_title=total RNA-seq`,
  `target.label=H3K4me3`, and so on.
- ENCODE supports nested field search with dot syntax, for example
  `target.label`.
- ENCODE supports wildcard values with `*` and negation with `!=`.
- Repeated parameters for the same property can behave like OR; different
  properties narrow the query.
- Default search results return only 25 hits unless `limit` is set.
- Avoid defaulting to `limit=all`; it can generate large result sets.
- Prefer `frame='object'` by default because it returns full properties with
  linked objects represented by identifiers and is more stable than embedded
  expansion.
- Use `frame='embedded'` only when the caller asks for convenience and accepts a
  larger, less stable response.
- Object schemas are available from the portal profiles. Use schemas to validate
  known fields and to explain object properties where useful.
- File objects carry important metadata: `accession`, `file_format`,
  `output_type`, `assembly`, `file_size`, `md5sum`, `href`, `dataset`, `status`,
  and sometimes cloud metadata.
- Direct file download URLs are usually based on `href` paths such as
  `/files/ENCFF.../@@download/...`; construct full URLs from the ENCODE base URL.
- ENCODE asks users to cite dataset accessions (`ENCSR...`) and file accessions
  (`ENCFF...`) when using data in publications or presentations.
- RNA-Get should not be an MVP dependency because the ENCODE RNA-Get help page
  currently says the endpoint is disabled.

## Bioconductor Requirements To Respect

- The package is a Bioconductor-style software package if submitted there.
- Use package version `0.99.0` for initial Bioconductor submission planning.
- All dependencies must be on CRAN or Bioconductor. Do not use `Remotes:`.
- Keep `DESCRIPTION` concise but complete: `Package`, `Title`, `Version`,
  `Description` with at least three sentences, `Authors@R`, `License`,
  `Imports`, `Suggests`, `URL`, `BugReports`, and `biocViews`.
- Prefer a standard open-source license. `Artistic-2.0` is common in core
  Bioconductor packages and is compatible with Bioconductor expectations.
- Use `importFrom()` or fully enumerated imports. Do not use broad export
  patterns.
- Export only user-facing functions. Internal helpers should be unexported and
  may use a leading dot only if that matches the local package style.
- Every exported function needs a help page with runnable examples.
- The package needs at least one evaluated R Markdown vignette, preferably using
  `BiocStyle::html_document`.
- Do not run installation commands or install system dependencies from examples,
  vignettes, README files, or package code.
- If package data are included in `inst/extdata/`, add a reproducibility script
  or clear provenance notes under `inst/scripts/`.
- Keep the source package under 10 MB. Keep individual files under 5 MB.
- Keep `R CMD check --no-build-vignettes` under 10 minutes when possible.
- Keep examples, tests, and vignettes small enough for Bioconductor builders.
- Use `R CMD build`, `R CMD check`, and `BiocCheck::BiocCheck()` before any
  serious release or submission decision.
- Include a single top-level `.gitignore` once this is a Git repository. Exclude
  system files, hidden IDE files, build artifacts, logs, cache files, and large
  downloaded ENCODE data.
- Add a `NEWS.md` with list items before release-oriented development.
- If accepted by Bioconductor, every commit to the Bioconductor repository must
  bump the `z` component of the package version.

## Web Querying And Downloads

- All URL retrieval must have bounded retries and clear error messages.
- Respect `getOption('timeout')` or an explicit request timeout.
- Avoid infinite `while()` loops and unbounded pagination.
- Treat HTTP errors and ENCODE JSON error responses as first-class errors with
  actionable messages.
- Distinguish no results from failed requests. ENCODE may return 404 for some
  empty or invalid searches.
- In package examples and vignettes, use tiny queries and small files only.
- Do not write downloaded files to a user's home directory, working directory, or
  installed package directory automatically.
- For Bioconductor compliance, persistent package-managed downloads should use
  `BiocFileCache` or `tools::R_user_dir(package, which='cache')`.
- For an interactive user function, allow a deliberate destination directory,
  but default to a package cache rather than surprise project-root writes.
- Always return downloaded file paths and metadata.
- Check file size before downloading when `file_size` is available.
- Provide size guardrails such as `max_file_size` and `max_total_size`.
- Verify `md5sum` after download when available.
- Use progress bars for downloads in interactive sessions; avoid noisy progress
  output in noninteractive examples/tests.

## Dependency Strategy

Start with a small R-native core:

- `httr2` for HTTP requests, errors, retries, headers, and timeouts.
- `jsonlite` for JSON parsing.
- `cli` for concise user messages and progress bars.
- `tibble` or base data frames for clean metadata tables.

Possible optional dependencies:

- `BiocFileCache` for Bioconductor-compliant persistent caching.
- `readr` for convenient delimited file loading, if base R becomes clunky.
- `rtracklayer` for BED, GTF, GFF, bigWig, and bigBed import.
- `Rsamtools` and `GenomicAlignments` for BAM/SAM support.
- `Biostrings` for FASTA.
- `ShortRead` for FASTQ.
- `SummarizedExperiment` only when constructing true assay-by-sample objects.
- `testthat` for unit tests, unless we choose `tinytest` to reduce dependency
  weight.
- `httptest2` or recorded fixtures for testing HTTP code without repeatedly
  hitting ENCODE.

Do not add these until needed:

- `reticulate`, Python scripts, external command-line tools, Shiny, SQLite,
  custom caches, parallel frameworks, or S4 classes.

## Initial Function Architecture

Keep public functions few, verb-first, and easy to remember:

- `encode_search()` searches ENCODE objects and returns a table by default.
- `encode_get()` retrieves one ENCODE object by accession, path, or URL.
- `encode_files()` returns file metadata for one or more experiments.
- `encode_download()` downloads selected file records or file accessions.
- `encode_read()` reads a downloaded file when the format is supported and safe.
- `encode_schema()` retrieves schema/profile metadata for an object type.
- `encode_citation()` summarizes dataset and file accessions for citation.

Internal helpers should be small and boring:

- Build URLs.
- Encode query parameters, including negation and repeated values.
- Perform throttled GET requests.
- Parse JSON and ENCODE error payloads.
- Flatten selected nested metadata fields.
- Normalize file metadata columns.
- Check size and MD5 before/after downloads.

## Function Interface Principles

- Prefer explicit arguments over clever query DSLs.
- Allow both named filters and a `filters` list for fields not exposed as formal
  arguments.
- Use `type`, `search`, `status`, `limit`, `frame`, `fields`, and `filters`
  consistently where applicable.
- Default `status='released'` for experiment/file searches unless the user opts
  out.
- Default `limit=25` for searches.
- Require an explicit override for `limit='all'`.
- Return a compact table by default, with an option to return raw JSON.
- Preserve ENCODE accessions and `@id` in returned tables.
- Avoid silently dropping metadata; if nested columns are too complex for a
  table, keep them in a raw object or list column only when necessary.
- Messages should be short and useful: what query ran, how many records were
  found, what will be downloaded, and where files were saved.
- Do not print full JSON objects, full count matrices, or long download logs.

## Edge Cases To Design For

- Zero results.
- HTTP 301/302/307 redirects.
- HTTP 404 from invalid IDs or empty/invalid searches.
- HTTP 429 or API throttling.
- Network timeout or transient server failure.
- Search results with multiple object types because `type` was omitted.
- `frame='embedded'` returning inconsistent nested object depth.
- Missing `href`, `file_size`, or `md5sum` on a file object.
- Archived, revoked, replaced, or unreleased files.
- Multiple files with the same format but different assemblies or output types.
- Paired-end FASTQ files.
- Technical and biological replicates.
- Very large raw files.
- Compressed tabular files.
- Unsupported formats that should return a path rather than attempting to load.
- Windows/macOS/Linux path behavior and case-insensitive filesystems.
- Noninteractive examples/tests where progress bars should be disabled.

## ENCODExplorerData Takeaways

`ENCODExplorerData` is useful as prior art but should not define this package.
Its useful ideas are:

- A lightweight metadata table is easier to work with than a full metadata dump.
- A fuller metadata table can be useful but should not be loaded by default.
- AnnotationHub is appropriate for static, versioned metadata resources.
- Helper functions around ENCODE search and downloads are valuable.

Avoid carrying forward its heavier or outdated choices unless justified:

- Do not start with a full SQLite mirror.
- Do not require users to load a large global metadata table for simple live
  queries.
- Do not build around old ENCODE API assumptions or old package dependency
  choices.

## Documentation Plan

- `README.md`: short motivation, installation, and three basic examples:
  search, list files, download one selected file.
- Main vignette: evaluated quick-start using tiny queries and no large downloads.
- Function man pages: all exported functions with runnable small examples.
- Package-level help page: overview of the workflow and links to key functions.
- Include ENCODE citation guidance in documentation and `encode_citation()`.
- Include a short comparison to ENCODExplorer/ENCODExplorerData in the vignette:
  this package favors live, small, explicit queries and selected downloads over
  a full metadata mirror.

## Sources To Recheck During Development

- ENCODE REST API: https://www.encodeproject.org/help/rest-api/
- ENCODE getting started/query building:
  https://www.encodeproject.org/help/getting-started/
- ENCODE data organization:
  https://www.encodeproject.org/help/data-organization/
- ENCODE schemas: https://www.encodeproject.org/profiles/
- ENCODE file formats: https://www.encodeproject.org/help/file-formats/
- ENCODE citation guidance:
  https://www.encodeproject.org/help/citing-encode/
- ENCODE RNA-Get status: https://www.encodeproject.org/rna-get-help/
- Bioconductor package guidelines:
  https://contributions.bioconductor.org/index.html
- Bioconductor web resource guidance:
  https://contributions.bioconductor.org/querying-web-resources.html
- ENCODExplorerData package page:
  https://bioconductor.org/packages/ENCODExplorerData/
