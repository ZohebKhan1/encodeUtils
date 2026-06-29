# User Workflows

Date: 2026-06-28

Purpose: define the workflows the package should make easy before writing the
implementation. This document is planning material, not installed package
documentation.

## Guiding User Model

The target user is an R user or bioinformatician who wants to work with ENCODE
data from R without constantly switching to the browser.

The package should help the user:

- Find relevant ENCODE experiments.
- Understand what was found.
- Compare available assays, biosamples, organisms, labs, and file types.
- Select files deliberately.
- Avoid accidental huge downloads.
- Download with clear progress and verification.
- Load supported local files into appropriate R/Bioconductor objects when that
  is practical.
- Cite the accessions used in downstream work.

The package should not try to replace the entire ENCODE website. It should make
the common programmatic workflows clear, safe, and efficient.

## Access, Authentication, and Connectivity

Current public-access assumption:

- Public released ENCODE objects can be queried with HTTP GET without a user
  account or API key.
- The package's first version should be read-only and public-data focused.
- API keys, login credentials, submission workflows, POST, PATCH, and private
  metadata should be out of scope for v1.

Connectivity behavior:

- If there is no internet connection, fail quickly with a clear message.
- If ENCODE is reachable but returns an HTTP error, report the status code,
  requested URL, and a short ENCODE error description when available.
- If ENCODE times out, report timeout separately from invalid user input.
- Do not retry forever.
- Use bounded retries only for transient failures such as timeout, 502, 503, or
  504.
- Keep retry count small by default, e.g. 2 or 3 total attempts.
- Respect R's timeout option where possible and expose a package-level timeout
  argument later if needed.

Rate-limit behavior:

- ENCODE's programmatic API is limited to 10 GET requests per second from a
  single user/group/company/lab.
- The package should be more conservative than the limit by default.
- Internal request code should throttle requests so batch metadata calls do not
  exceed the limit.
- A reasonable initial cap is 5 to 8 GET requests per second.
- Functions that fetch one search result page should usually make only one GET.
- Functions that expand many objects should batch carefully and show progress.
- If ENCODE returns 429 or rate-limit-like errors, slow down and retry once or
  twice before failing clearly.

## Workflow 1: Search Experiments

User goal:

Find candidate experiments matching filters such as assay, organism, biosample,
status, target, lab, project, and perturbation state.

Likely function:

```r
res <- encode_search(
    type = "Experiment",
    filters = list(
        "control_type!=" = "*",
        perturbed = "false",
        assay_title = "total RNA-seq"
    ),
    status = "released",
    limit = 25
)
```

User-facing output should show:

- Query URL.
- Total results found.
- Active filters.
- Top facets relevant to the query.
- A compact result table.

Compact result table should aim to include:

- `accession`.
- `id`.
- `assay_title`.
- `assay_term_name`.
- `organism`, when available.
- `biosample_summary`.
- `biosample_classification`.
- `biosample_term_name`.
- `lab`.
- `project`.
- `status`.
- `file_count`, when available.

Safety behavior:

- Default `limit` should be small, e.g. 25.
- `limit = "all"` should require explicit user choice.
- If total results are very large, tell the user before pulling all results.
- Search should not download data files.

Design implication:

- `encode_search()` is the first public function to design carefully.
- It should preserve raw ENCODE response data while returning a convenient
  compact table.

## Workflow 2: Explore Availability With Matrix Counts

User goal:

Understand what data exist before choosing a specific experiment or download.

Likely function:

```r
mat <- encode_matrix(
    filters = list(
        "control_type!=" = "*",
        perturbed = "false"
    ),
    status = "released"
)
```

User-facing output should show:

- Total experiments represented.
- Top assay titles.
- Top biosample classifications.
- Top biosample terms within a classification.
- Counts by assay and biosample.

Return values should include:

- Long matrix table:
  `biosample_classification`, `biosample_term_name`, `assay_title`, `n`.
- Assay summary table:
  `assay_title`, `n`.
- Biosample summary table:
  `biosample_classification`, `biosample_term_name`, `n`.
- Raw response for users who need ENCODE's original nested structure.

Safety behavior:

- Matrix queries are metadata/count queries only.
- No file downloads.
- If matrix parsing fails because ENCODE changes the nested JSON shape, return a
  clear error and preserve the raw response for debugging.

Design implication:

- `encode_matrix()` is a high-value early function because it gives a
  website-like overview from the console.

## Workflow 3: Retrieve One Object

User goal:

Inspect one known ENCODE accession, object path, or URL.

Likely function:

```r
experiment <- encode_get("ENCSR284QGB", frame = "embedded")
file <- encode_get("ENCFF312AWH", frame = "object")
```

Supported inputs:

- Accession, e.g. `ENCSR284QGB`.
- Portal path, e.g. `/experiments/ENCSR284QGB/`.
- Full URL, e.g. `https://www.encodeproject.org/experiments/ENCSR284QGB/`.

User-facing output should show:

- Object type.
- Accession.
- Object ID.
- Status.
- Summary fields relevant to object type.

Experiment summaries should aim to show:

- Assay title and term name.
- Biosample summary.
- Organism, when available.
- Biosample classification and term name.
- Lab and institution.
- Award/project.
- File count and top file formats.

File summaries should aim to show:

- File format.
- Output type.
- Assembly.
- File size.
- Status.
- Dataset accession/path.
- MD5.
- Download href.
- Biological and technical replicate fields.
- Paired-end relationships.

Safety behavior:

- `encode_get()` should never download files.
- Invalid accessions should surface ENCODE's 404 clearly.
- Ambiguous inputs should fail clearly instead of guessing.

## Workflow 4: List File Metadata From Experiments

User goal:

Identify which files from one or more experiments are worth downloading.

Likely function:

```r
files <- encode_list_files(
    "ENCSR284QGB",
    file_format = "fastq",
    output_type = "reads",
    status = "released"
)
```

Inputs should support:

- One experiment accession.
- Multiple experiment accessions.
- Search result object from `encode_search()`.
- Experiment object from `encode_get()`.

Return table should include:

- `file_accession`.
- `experiment_accession`.
- `file_format`.
- `output_type`.
- `assembly`.
- `file_size`.
- `file_size_pretty`.
- `md5sum`.
- `status`.
- `href`.
- `cloud_url`, if available.
- `biological_replicates`.
- `technical_replicates`.
- `paired_end`.
- `paired_with`.

Safety behavior:

- This is metadata only.
- The name should be `encode_list_files()` rather than `encode_files()` to avoid
  implying a download.
- Show total file count and total possible download size if sizes are known.
- Warn if selected files include very large formats such as FASTQ, BAM, or CRAM.

Design implication:

- This function bridges search and download.
- It should make it easy to inspect before committing to data transfer.

## Workflow 5: Download Selected Files

User goal:

Download selected ENCODE files after reviewing metadata.

Likely function:

```r
paths <- encode_download(
    files,
    directory = "data/encode",
    max_size = "2GB",
    overwrite = FALSE
)
```

Important design question:

- For Bioconductor submission, functions should not silently write to the
  user's working directory, home directory, or installed package directory.
- Persistent package-managed downloads should use `BiocFileCache` or
  `tools::R_user_dir(package, which = "cache")`.
- For user-directed project downloads, the user should explicitly provide a
  directory.

Initial policy:

- If `directory` is missing, use a package cache through `BiocFileCache`.
- If `directory` is supplied, write there deliberately.
- Never silently create a large project data folder without telling the user.
- Show planned destination before download.

Safety behavior:

- Show selected file count.
- Show total size.
- Enforce `max_size` by default.
- Provide an explicit override for large downloads.
- Do not overwrite existing files unless `overwrite = TRUE`.
- Resume behavior can be considered later; do not promise it in v1 unless it is
  tested.
- Verify downloaded file size.
- Verify MD5 when ENCODE metadata provide `md5sum`.
- Return a table of local paths and verification status.

Console behavior:

- Use `cli` progress bars for file count and bytes when possible.
- Tell the user which accession is downloading.
- Tell the user when checksum verification passes or fails.
- Keep output concise in noninteractive sessions.

## Workflow 6: Read Supported Local Files

User goal:

Load a downloaded file into R when that is practical and supported.

Likely function:

```r
obj <- encode_read(path)
```

Initial supported formats should be conservative:

- Metadata/report TSV or CSV into a data frame.
- BED-like files through `rtracklayer::import()` later if we add that suggested
  dependency.
- BigWig or BigBed through `rtracklayer::import()` later.
- Possibly narrowPeak/broadPeak as BED-like data later.

Formats to treat carefully:

- FASTQ: usually large; reading entire files into memory is often a bad default.
- BAM/CRAM: use Bioconductor infrastructure when needed, but do not build a
  casual full-file loader.
- HDF5-based formats: consider only when a concrete user workflow needs them.

Safety behavior:

- Inspect file extension and metadata when available.
- Refuse unsupported formats with a useful message.
- Warn before loading very large local files into memory.
- Prefer established Bioconductor import functions where appropriate.

Design implication:

- Keep `encode_download()` and `encode_read()` separate.
- A future `encode_load_data()` convenience wrapper can compose search,
  download, and read only after those pieces are stable.

## Workflow 7: Schema and Field Discovery

User goal:

Find valid fields and understand what can be queried or summarized.

Likely function:

```r
schema <- encode_get_schema("experiment")
```

User-facing output should show:

- Schema title.
- Object type.
- Required fields.
- Searchable or useful properties when available.
- Compact table of property names, types, titles, and descriptions.

Safety behavior:

- Schema retrieval is metadata only.
- Cache schemas during a session or through cache if useful.
- If schema endpoint changes, preserve raw JSON for inspection.

Design implication:

- This function will help users build valid filters without memorizing ENCODE
  field names.

## Workflow 8: Dataset Attribution / Citation Summaries

User goal:

Prepare a concise, auditable attribution summary for the exact ENCODE
datasets/files used in a report, publication, or methods section.

Primary purpose:

- Tell the user where a specific dataset came from.
- List the experiment accession, file accession(s), PI/lab, institution,
  project/award, assay, biosample, and portal URLs.
- Make it easy to create a supplemental table or methods paragraph that credits
  the producing lab(s) and identifies every ENCODE object used.

Secondary purpose:

- Remind the user to follow ENCODE's broader citation guidance for Consortium
  publications.

Likely function:

```r
encode_citation(files)
```

Output should include:

- Experiment accessions, e.g. `ENCSR...`.
- File accessions, e.g. `ENCFF...`.
- ENCODE object IDs, e.g. `/experiments/.../` and `/files/.../`.
- Assay titles.
- Biosamples.
- Organism, when available.
- Lab / PI.
- Institution, when available from lab metadata.
- Project and award.
- File format, output type, assembly, and MD5 when available.
- Object status.
- ENCODE portal URLs.
- Retrieval date.
- A short note linking to ENCODE citation guidance.

Official ENCODE citation guidance is listed on the ENCODE website under:

https://www.encodeproject.org/help/citing-encode/

The function should distinguish between two related outputs, with dataset
attribution as the main output:

1. Dataset attribution / use summary:
   - the specific ENCSR experiment accessions used,
   - the specific ENCFF file accessions used,
   - the production lab(s) and PI names where available,
   - the institution(s) where available,
   - the ENCODE project/award where available,
   - assay and biosample metadata,
   - portal URLs,
   - retrieval date,
   - file metadata such as format, output type, assembly, and MD5 when
     available.
2. Publication guidance:
   - a reminder to cite ENCODE Consortium publications,
   - a reminder to acknowledge the ENCODE Consortium and production lab(s),
   - a link to the current Citing ENCODE page.

The package should not fabricate formal article citations for a dataset unless
ENCODE metadata explicitly provide a publication/reference record for that
object. Many experiment/file objects have useful accessions and provenance
metadata but do not have a direct publication attached.

Suggested output modes:

```r
encode_citation(files, format = "table")
encode_citation(files, format = "text")
encode_citation(files, format = "markdown")
encode_citation(files, format = "bibtex")
```

Format behavior:

- `format = "table"` should return a data frame suitable for a supplementary
  dataset/accession table.
- `format = "text"` should return a plain methods-style paragraph/list naming
  the accessions, PI/lab, institution, and ENCODE URLs.
- `format = "markdown"` should return a markdown-ready dataset attribution
  block.
- `format = "bibtex"` should be limited to ENCODE publication records we can
  represent honestly. It should not invent BibTeX entries for ENCSR/ENCFF
  accessions as though they were journal articles.
- Default should probably be `format = "table"` because it is safest and easiest
  to audit.

Possible additional argument:

```r
style = c("summary", "methods", "supplement")
```

- `style = "summary"`: compact console summary grouped by experiment.
- `style = "methods"`: prose suitable for draft methods text.
- `style = "supplement"`: one row per file accession with experiment, lab, PI,
  institution, and file metadata.

Safety behavior:

- Citation output should be derived from metadata, not invented prose.
- Do not hide revoked/archived status if files are not released.
- Always include accessions because ENCODE explicitly asks users to reference
  ENCSR dataset accessions and ENCFF file accessions.
- Include status so archived, revoked, or unreleased objects are visible.

## Workflow 9: Interactive Selection Later

User goal:

Search, browse, page, fuzzy-match, and select experiments or files from the
console.

Potential later functions:

```r
selected <- encode_select(res)
selected <- encode_browse(type = "Experiment", search = "heart RNA-seq")
```

Initial approach:

- Do not implement this first.
- Build a robust noninteractive core first.
- Later, add interactive selection as a thin layer over `encode_search()` and
  `encode_list_files()`.

Possible dependency approach:

- Avoid adding interactive/fuzzy dependencies to the runtime core at first.
- Use base R interaction or optional packages only after the core API is stable.

## Cross-Cutting Failure Modes

### No Internet

Expected package behavior:

- Fail quickly.
- Message should say ENCODE could not be reached.
- Include the target host or URL.
- Suggest checking internet/VPN/proxy only if relevant.
- Do not print a long stack trace for common connectivity failures.

### ENCODE Temporarily Down

Expected package behavior:

- Retry a small number of times for transient status codes.
- Report the final status code and URL.
- Do not loop indefinitely.

### API Shape Changes

Expected package behavior:

- Preserve raw responses.
- Use small, isolated parsing helpers.
- Fail with a message naming the missing field or changed shape.
- Unit tests should cover representative stored JSON fixtures.

### Huge Result Sets

Expected package behavior:

- Default to small limits.
- Show total count when available.
- Require explicit `limit = "all"` or equivalent.
- For very large results, warn before requesting all records.

### Huge Downloads

Expected package behavior:

- Always show total planned size when known.
- Enforce default `max_size`.
- Require explicit override for larger transfers.
- Verify size and checksum after download.

### Partial Downloads

Expected package behavior:

- Detect existing incomplete files when possible.
- Do not silently treat partial files as valid.
- Use checksum/size verification.
- Return per-file success/failure status.

### Duplicate Filenames

Expected package behavior:

- Use ENCODE file accessions in filenames.
- Do not overwrite by default.
- If multiple URLs would map to the same filename, disambiguate or error.

### Revoked, Archived, or Non-Released Objects

Expected package behavior:

- Default to `status = "released"` where appropriate.
- If user requests other statuses, show status in every summary table.
- Do not hide revoked/archived status.

### Missing Metadata

Expected package behavior:

- Use `NA` for genuinely missing fields in tables.
- Do not fabricate organism, lab, project, assembly, or biosample values.
- Make extraction helpers conservative and predictable.

## First Implementation Sequence Suggested By Workflows

1. Internal request layer:
   URL builder, GET, JSON parser, timeout, retry, rate limiter, errors.
2. `encode_search()`:
   filter syntax, facets, compact result table, raw response.
3. `encode_get()`:
   one accession/path/URL and concise summary extractors.
4. `encode_matrix()`:
   availability counts and console summaries.
5. `encode_list_files()`:
   file metadata table and total size summary.
6. `encode_download()`:
   cache/directory policy, progress, size guardrail, checksum.
7. `encode_get_schema()`:
   schema table and field discovery.
8. `encode_read()`:
   conservative local file imports.
9. `encode_cite()`:
   citation summaries from selected metadata.

This order keeps the core robust before adding convenience wrappers or
interactive behavior.
