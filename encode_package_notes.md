# ENCODE Package Notes

Date: 2026-06-28

## Current User Goals

- Build an R package that makes ENCODE data easy, efficient, and convenient to
  query, inspect, download, and load from R.
- Keep the package clean, organized, straightforward, and human-auditable.
- Avoid overengineering, unnecessary abstractions, unnecessary dependencies, and
  complex code.
- Make the package feel premium from the console: thoughtful messages, useful
  progress/status updates, and no need to open a browser for common workflows.
- Think comprehensively about contingencies and edge cases before coding.
- Use `ENCODExplorerData` only as a source of ideas because it is outdated and
  heavier than the desired package direction.
- Keep dependencies lean, efficient, and justified.

## Function Naming Questions

The current candidate public functions are:

- `encode_search()` for ENCODE object search.
- `encode_get()` for retrieving one accession, path, or object.
- `encode_files()` for file metadata from experiments.
- `encode_download()` for deliberate selected downloads.
- `encode_read()` for safe supported local file loading.
- `encode_schema()` for schema/profile inspection.
- `encode_citation()` for dataset/file accession citation summaries.

Open questions:

- Do these names fit Bioconductor naming guidance?
- Bioconductor generally recommends camelCase in its R-code chapter, but its
  NAMESPACE chapter allows exported functions to use camel case or underscoring.
- The local project style guide prefers lowercase snake_case.
- The `encode_*()` prefix may feel repetitive, but it keeps functions grouped,
  avoids generic names like `search()` and `files()`, and is clear in user code.
- It may be odd to place `encode` at the end of every function name.
- Consider whether more verb-forward names such as `search_encode()`,
  `get_encode()`, `download_encode()`, or `load_encode_data()` read better.
- Also consider names like `encode_load_data()`, `encode_pull_schema()`, and
  `encode_pull_metadata()`.

Working naming preference to discuss:

- Keep `encode_*()` for namespace clarity and RStudio autocomplete.
- Prefer real verbs after the prefix where possible: `encode_search()`,
  `encode_get()`, `encode_download()`, `encode_read()`.
- Rename noun-like functions if they prove unclear:
  `encode_files()` could become `encode_list_files()` or
  `encode_get_files()`.
  `encode_schema()` could become `encode_get_schema()` or
  `encode_pull_schema()`.
  `encode_citation()` could become `encode_cite()` or
  `encode_format_citation()`.

## Search Page Target

The user asked whether `encode_search()` corresponds to searching this ENCODE
page:

https://www.encodeproject.org/search/?type=Experiment&control_type!=*&status=released&perturbed=false

Yes, this is the conceptual target for `encode_search()`: build the same query
parameters the website uses, request JSON from the REST API, and return the
results in a convenient R object.

Search page observations to preserve:

- The ENCODE search page is complex and facet-driven.
- The page shows active filters, total result count, result count per page, and
  links to report and matrix views.
- The example search shows released non-control, unperturbed experiments.
- The user wants counts like the website shows.
- The package should expose enough metadata that the user sees species, lab,
  university/institution, project, ID, accession, assay title, and biosample
  classification without opening a browser.
- Search should feel like a console version of the ENCODE website, not a thin
  wrapper that returns raw JSON and makes the user do all the work.

## Matrix Page Target

The user asked to inspect this matrix page:

https://www.encodeproject.org/matrix/?type=Experiment&control_type!=*&status=released&perturbed=false

The matrix page is important because it gives a compact overview of available
experiments by assay and biosample categories.

Matrix page goals:

- Understand how ENCODE builds the experiment matrix.
- Determine whether the matrix JSON can be queried directly.
- Consider whether the package should include a matrix-like summary function.
- A possible function could be `encode_matrix()` or `encode_summarize_matrix()`.
- The package should reproduce the useful counts and grouping behavior from the
  ENCODE matrix in a console-friendly table.
- The matrix concept may be central to making the package feel like the website.

## Premium Console UX

The user wants high-quality waiting animations/status updates while commands run.

Desired status behavior:

- Show what the package is doing while querying ENCODE.
- Show when schemas are being pulled.
- Show when metadata is being fetched or flattened.
- Show how many results were found.
- Show when file metadata are being collected.
- Show planned download size before download.
- Show progress during downloads.
- Show where files were saved.
- Keep messages concise and useful.
- Disable or reduce progress output in noninteractive sessions, tests, and
  vignettes.

Possible implementation direction:

- Use `cli` for status messages, spinners, progress bars, and formatted errors.
- Avoid noisy print/cat output.
- Use messages that communicate real work, not decorative text.

## Interactive Search Ideas

The user is interested in an efficient interactive search experience.

Ideas to consider later:

- Query ENCODE and page through results from the console.
- Scroll through pages of search results without opening a browser.
- Fuzzy-match within fetched results.
- Interactively select an experiment or file.
- Show concise result cards with accession, assay, biosample, organism, lab,
  project, status, and file summary.
- Provide enough detail to choose the right dataset without needing the website.
- Keep this as a later feature after the core API functions work.

Potential later functions:

- `encode_browse()`
- `encode_select()`
- `encode_interactive_search()`
- `encode_filter_results()`

These should not be part of the first implementation unless the core functions
are stable.

## Metadata Requirements

For experiment search results and retrieved objects, the package should make it
easy to see:

- Species / organism.
- Lab and institution or university.
- Project.
- ENCODE object ID / `@id`.
- Accession ID.
- Assay title.
- Biosample summary.
- Biosample classification.
- Biosample term name.
- Status.
- Relevant file counts and file formats.
- Relevant audit/status warnings if available.

For files, the package should make it easy to see:

- File accession.
- Dataset accession.
- File format.
- Output type.
- Assembly.
- File size.
- MD5.
- Download URL / href.
- Status.
- Biological and technical replicate when available.
- Paired-end relationships when available.

## Potential Core Functions

Current candidates:

- `encode_search()`
- `encode_get()`
- `encode_list_files()` or `encode_files()`
- `encode_download()`
- `encode_read()` or `encode_load_data()`
- `encode_get_schema()` or `encode_pull_schema()`
- `encode_cite()` or `encode_citation()`
- `encode_matrix()` or `encode_summarize_matrix()`
- `encode_report()` for report-table style metadata.

Possible distinction:

- `encode_search()` should query ENCODE objects and return rows of objects.
- `encode_report()` could return tabular report-style metadata using ENCODE's
  report endpoint or selected search fields.
- `encode_matrix()` could return matrix-style counts grouped by assay and
  biosample.
- `encode_list_files()` is metadata-focused; it should not download anything.
- `encode_download()` should require deliberate selected files.
- `encode_read()` / `encode_load_data()` should only load local files when the
  format is supported and safe.

## Critical Architecture Question

The user asked what the most critical function is, if one exists.

Current hypothesis:

- The critical center is not one user-facing function; it is the internal query
  layer that builds ENCODE URLs, sends bounded/throttled GET requests, handles
  errors, parses JSON, and returns consistent metadata.
- The first user-facing function should probably be `encode_search()` because it
  exercises query construction, facets/filters, pagination/limit behavior,
  result parsing, and user-facing summaries.
- A strong `encode_search()` can then feed `encode_list_files()`,
  `encode_matrix()`, `encode_report()`, `encode_download()`, and interactive
  browsing.

## Website Familiarity Goals

The user wants thorough familiarity with ENCODEproject.org:

- Search pages.
- Matrix pages.
- Report views.
- Experiment pages.
- File detail pages.
- Facets and filters.
- Counts next to report/matrix/list views.
- Download behavior.
- Visualize behavior.
- Metadata layout and available fields.
- Schemas and object relationships.
- Nuances of what information is exposed through the API.

The package should be planned around how ENCODE actually organizes data, not
around assumptions.

## Development Priorities

Before coding:

- Inspect ENCODE search JSON for realistic queries.
- Inspect ENCODE matrix JSON.
- Inspect report TSV/JSON behavior.
- Inspect experiment object structure.
- Inspect file object structure.
- Identify reliable metadata fields for concise result tables.
- Decide function names.
- Decide cache/default download behavior.
- Decide the first implementation path.

Guiding principle:

- Build the smallest robust core that can support a polished user experience.

## Live ENCODE Endpoint Observations

Checked on 2026-06-28.

### Search JSON

Query inspected:

https://www.encodeproject.org/search/?type=Experiment&control_type!=*&status=released&perturbed=false

JSON query form:

https://www.encodeproject.org/search/?type=Experiment&control_type%21=%2A&status=released&perturbed=false&limit=5&format=json&frame=object

Observed behavior:

- The endpoint returns a `Search` object with `total`, `filters`, `facets`,
  `columns`, and `@graph`.
- The example query currently returns `total = 20671` experiments.
- The `@graph` list contains the result objects.
- With `frame=object`, linked objects such as `lab`, `award`, and
  `biosample_ontology` are returned as ENCODE paths.
- With `frame=embedded`, selected linked objects are expanded and are easier to
  summarize, but this is heavier and less stable as a long-term internal
  representation.
- Active filters are returned explicitly. For `control_type!=*`, ENCODE reports
  the filter field as `control_type!` with term `*`.
- Search facets include counts needed to reproduce much of the website's
  browsing experience.

Top observed facets for the example query:

- `assay_slims`: DNA binding 9281, Transcription 5202, DNA accessibility 4285,
  Single cell 849, 3D chromatin structure 603.
- `assay_title`: TF ChIP-seq 4690, Histone ChIP-seq 3694, DNase-seq 3425,
  total RNA-seq 1964, Mint-ChIP-seq 895.
- `status`: released 20671, archived 1021, revoked 345.
- `perturbed`: false 20671, true 2531.

First result from the example query:

- Accession: `ENCSR961MEG`.
- `@id`: `/experiments/ENCSR961MEG/`.
- Assay title: `Hi-C`.
- Assay term name: `HiC`.
- Biosample summary: `Mus musculus strain B6XCast EiJ adrenal gland tissue`.
- Status: `released`.
- Lab path: `/labs/erez-aiden/`.
- Award path: `/awards/UM1HG009375/`.
- File count in object frame: 3.
- Biosample ontology path: `/biosample-types/tissue_UBERON_0002369/`.

Implications for `encode_search()`:

- `encode_search()` should be a true ENCODE search-page equivalent, not just a
  raw JSON wrapper.
- It should preserve `total`, `filters`, `facets`, `columns`, `@graph`, and the
  final query URL.
- It should return a compact results table by default and keep the raw response
  available.
- It should probably print a short summary such as result count, active filters,
  and top facets.
- The default `limit` should remain safe, e.g. 25, rather than defaulting to
  `limit=all`.
- `limit=all` should be explicit because ENCODE warns that very large searches
  can generate large result sets.

### Matrix JSON

Query inspected:

https://www.encodeproject.org/matrix/?type=Experiment&control_type!=*&status=released&perturbed=false

JSON query form:

https://www.encodeproject.org/matrix/?type=Experiment&control_type%21=%2A&status=released&perturbed=false&format=json

Observed behavior:

- The endpoint returns a `Matrix` object with `total`, `filters`,
  `facet_groups`, `facets`, `matrix`, and `search_base`.
- The example matrix currently has `total = 20671`.
- `matrix` has `x` and `y` components.
- `matrix.x.group_by` is `assay_title`.
- `matrix.y.group_by` is
  `biosample_ontology.classification` and `biosample_ontology.term_name`.
- The y-axis matrix is nested:
  biosample classification -> biosample term -> assay title counts.

Top assay buckets from `matrix.x`:

- TF ChIP-seq 4690.
- Histone ChIP-seq 3694.
- DNase-seq 3425.
- total RNA-seq 1964.
- Mint-ChIP-seq 895.
- polyA plus RNA-seq 798.
- ATAC-seq 464.
- long read RNA-seq 441.
- microRNA-seq 412.
- snRNA-seq 395.
- snATAC-seq 364.
- intact Hi-C 299.

Top biosample classifications from `matrix.y`:

- tissue 7594.
- cell line 6897.
- primary cell 3860.
- whole organisms 1442.
- in vitro differentiated cells 691.
- cell-free sample 111.

Examples of nested matrix cells:

- tissue -> dorsolateral prefrontal cortex:
  Histone ChIP-seq 188, total RNA-seq 120, DNase-seq 110.
- tissue -> heart:
  Histone ChIP-seq 81, snRNA-seq 49, DNase-seq 41.
- cell line -> K562:
  TF ChIP-seq 749, eCLIP 145, DNase-seq 59.
- cell line -> HepG2:
  TF ChIP-seq 814, eCLIP 105, Histone ChIP-seq 15.
- primary cell -> CD4-positive, alpha-beta T cell:
  total RNA-seq 191, DNase-seq 160, Histone ChIP-seq 12.

Implications for `encode_matrix()`:

- This likely deserves a public function.
- Return a long table with columns such as
  `biosample_classification`, `biosample_term_name`, `assay_title`, and `n`.
- Optionally return an assay-level summary table and a biosample-level summary
  table.
- Later, add a console print method that shows top assays and top biosample
  categories like the website.
- This function could help users choose useful queries before downloading
  anything.

### Report TSV

Query inspected:

https://www.encodeproject.org/report.tsv?type=Experiment&control_type%21=%2A&status=released&perturbed=false&field=accession&field=assay_title&field=biosample_ontology.classification&field=biosample_ontology.term_name&field=lab.title&field=award.project&field=status

Observed behavior:

- The report TSV endpoint returns a first metadata line containing a timestamp
  and report URL.
- The generated report URL includes `limit=all`.
- The second line is the tabular header.
- Selected fields become human-readable column names, e.g. `Accession`,
  `Assay title`, `Biosample classification`, `Biosample term name`, `Lab`,
  `Project`, and `Status`.
- Example rows include accessions such as `ENCSR874VJT`, `ENCSR951SLK`,
  `ENCSR070KPQ`, `ENCSR700DCY`, `ENCSR728KQL`, and `ENCSR786FLO`.

Implications for `encode_report()`:

- A report function could be very useful for user-selected metadata tables.
- It should not be the first implementation target because the endpoint is
  report-oriented and tends to request all rows.
- If implemented, require explicit fields and make large result behavior clear.
- It may be safer to first build selected-field summaries from search JSON.

### Experiment Object

Object inspected:

https://www.encodeproject.org/experiments/ENCSR284QGB/?frame=embedded&format=json

Observed summary:

- `@id`: `/experiments/ENCSR284QGB/`.
- Accession: `ENCSR284QGB`.
- Assay title: `total RNA-seq`.
- Assay term name: `RNA-seq`.
- Biosample summary: `Homo sapiens GM18507`.
- Status: `released`.
- Lab: `Stephen Montgomery, Stanford`.
- Award project: `ENCODE`.
- Award name: `U01HG009431`.
- Biosample classification: `cell line`.
- Biosample term name: `GM18507`.
- Organism can be derived from replicate biosample donor organism:
  `Homo sapiens`.
- Example files include paired FASTQ reads:
  `ENCFF312AWH` and `ENCFF109WOK`.

Implications for `encode_get()` and summary printing:

- `encode_get()` should retrieve by accession, object path, or URL.
- A concise summary helper should show accession, object ID, assay, biosample,
  organism, lab, project, status, and file counts.
- Organism is not always a simple top-level field and may require a conservative
  extractor from embedded replicate biosample donor organism.
- The object should remain available as a nested list for users who need fields
  beyond the summary.

### File Object

Object inspected:

https://www.encodeproject.org/files/ENCFF312AWH/?frame=object&format=json

Observed summary:

- `@id`: `/files/ENCFF312AWH/`.
- Accession: `ENCFF312AWH`.
- File format: `fastq`.
- Output type: `reads`.
- Assembly: missing for this raw FASTQ.
- File size: 1371462218 bytes.
- MD5: `ec2d7dcfa91923680b84083275afd3fc`.
- Download href:
  `/files/ENCFF312AWH/@@download/ENCFF312AWH.fastq.gz`.
- Dataset: `/experiments/ENCSR284QGB/`.
- Status: `released`.
- Biological replicate: 1.
- Technical replicate: `1_1`.
- Paired end: `1`.
- Paired with: `/files/ENCFF109WOK/`.
- Read length: 75.
- Run type: `paired-ended`.
- `cloud_metadata` includes a public S3 URL and matching file size.

Implications for file functions:

- `encode_list_files()` should clearly mean metadata only.
- `encode_download()` should use file metadata to show accession, format,
  output type, size, MD5, paired-end relationship, and destination before
  downloading.
- Download should verify file size and preferably MD5 after completion.
- Raw FASTQ files can be large. Download should require deliberate selection and
  should support a size guardrail.
- The file `href` is enough for the portal download URL. `cloud_metadata.url`
  may be useful but should not be assumed present for all files.

### Schema Endpoint

Endpoint inspected:

https://www.encodeproject.org/profiles/experiment.json

Observed behavior:

- Schema records are available under `/profiles/`.
- The experiment schema has title `Experiment`, type `object`, and id
  `/profiles/experiment.json`.
- Top-level properties include `@id`, `@type`, `accession`, `aliases`,
  `alternate_accessions`, `analyses`, `assay_slims`, `assay_synonyms`,
  `assay_term_id`, `assay_term_name`, `assay_title`, `assembly`, `award`,
  `bio_replicate_count`, `biosample_ontology`, and `biosample_summary`.
- Required experiment fields include `award`, `lab`, `assay_term_name`, and
  `biosample_ontology`.

Implications for `encode_get_schema()`:

- `encode_get_schema("experiment")` can call `/profiles/experiment.json`.
- A schema helper can support query building, validation, and field discovery.
- It should probably return the raw schema plus a compact table of property
  names, titles, types, and descriptions when available.

## Revised Function Naming Direction

The naming should be simple and consistent with both Bioconductor and the local
style guide.

Bioconductor naming facts:

- Exported function names can use camel case or underscores.
- Avoid `.` in exported function names because it implies S3 dispatch.
- Do not export functions starting with `.`.
- The local coding guide prefers snake_case, so `encode_search()` is acceptable.

Current preferred public names:

- `encode_search()` for Search endpoint queries.
- `encode_get()` for one accession, path, or URL.
- `encode_list_files()` for file metadata only.
- `encode_download()` for deliberate selected downloads.
- `encode_read()` for local file reading.
- `encode_get_schema()` for `/profiles/` schemas.
- `encode_cite()` for citation summaries.
- `encode_matrix()` for Matrix endpoint summaries.
- `encode_report()` later, only after core search behavior is stable.

Names to avoid or delay:

- Avoid `encode_files()` if it is ambiguous about whether files are downloaded.
- Avoid `encode_load_data()` as a first function if it mixes search, download,
  and read behavior. It may be useful later as a convenience wrapper.
- Avoid `encode_pull_metadata()` if it is unclear whether it searches, gets one
  object, or extracts selected fields.

## Proposed Search Interface Shape

Potential first version:

```r
encode_search <- function(
    type = "Experiment",
    filters = list(),
    search = NULL,
    status = "released",
    limit = 25,
    frame = c("object", "embedded"),
    include_facets = TRUE,
    quiet = FALSE
) {
    ## implementation later
}
```

Design notes:

- `filters` should allow raw ENCODE query parameters so users can express any
  website query.
- Negation needs explicit handling. Simple first option:
  `filters = list("control_type!=" = "*", perturbed = "false")`.
- The function can normalize `!=` to URL encoding internally.
- `search` maps to ENCODE `searchTerm`.
- `status = "released"` is a reasonable default, but other filters should not
  be silently applied unless the user asks.
- The returned object should include:
  - compact result table,
  - raw `@graph`,
  - total count,
  - facets,
  - active filters,
  - columns,
  - final URL.

## Most Critical Function

The most critical implementation is an internal request/query layer, not a
single exported user function.

It should handle:

- Base URL normalization.
- Query construction and URL encoding.
- `Accept: application/json`.
- ENCODE's 10 GET requests per second limit.
- Timeouts.
- Bounded retries.
- Clear HTTP errors.
- JSON parsing.
- Consistent raw response structure.
- Small, truthful progress messages.

The first public function to build should still be `encode_search()` because it
validates nearly every important design decision:

- Website-equivalent query parameters.
- Search JSON parsing.
- Result table construction.
- Facet/count summaries.
- Limit behavior.
- Frame behavior.
- Console UX.

Once `encode_search()` is solid, the rest of the package can be built as small
composable functions around the same core:

- `encode_matrix()` for counts and exploration.
- `encode_get()` for selected object inspection.
- `encode_list_files()` for file metadata from selected experiments.
- `encode_download()` for deliberate files.
- `encode_read()` for local loading.

## Package Setup Notes

Added on 2026-06-28.

- Private GitHub repository / folder name requested by the user:
  `encode-api-util`.
- Current R package name in `DESCRIPTION`: `encodeapiutil`.
- Reason: R package names cannot contain hyphens.
- Bioconductor's package submission guidance says the repository/directory name
  and `Package:` field should match.
- Therefore, before any Bioconductor submission, we need to decide whether to:
  - rename the repository/folder to `encodeapiutil`, or
  - choose a different valid R package name and matching repository name.
- For the private planning/development repository, keep `encode-api-util` unless
  the user chooses otherwise.
- `renv` is initialized for local development reproducibility.
- The package build excludes `renv`, project notes, the project-local
  `tools/r_codex_utils` shim, and local RStudio files through `.Rbuildignore`.
- Runtime package dependencies should still be declared in `DESCRIPTION`;
  `renv.lock` is for reproducing this development checkout, not for users or
  Bioconductor builders.
