# encodeUtils Review Addendum: Source-Code Pass

Date: 2026-07-03
Supersedes the inferred sections of `encodeUtils_review.md` wherever they conflict.

Superseded note: this is a historical review snapshot. Use
`docs/reviews/consolidated_audit_synthesis.md` as the current audit and
implementation reference.

This addendum is based on reading all R source files that were provided on disk:
`accessors.R`, `cite.R`, `download.R`, `files.R`, `flatten.R`, `get.R`, `http.R`,
`interactive.R`, `manifest.R`, `matrix.R`, `print.R`, `read.R`, `report.R`,
`schema.R`, `search.R`, `select-files.R`, `summary.R`, `utils.R`. `package.R` was
listed in the upload but was not present on disk, so the package-level doc block
was not reviewed.

Line numbers refer to the uploaded copies and should match your working tree
closely.

---

## Confirmed from source (was inferred before)

### C1. Object-frame degradation of the compact experiment table

**Grounded.** ENCODE's REST API help confirms that `frame=object` returns linked
properties (`lab`, `award`, `biosample_ontology`) as portal _paths_, and only
`frame=embedded` returns them as full objects with titles.

In `search.R`, the default is `frame = c("object", "embedded")`, i.e. `"object"`.
In `flatten.R`:

- `encode_institution()` (lines ~260-265) requires a list and returns
  `NA_character_` for a path string, so **institution is always NA in object
  frame**.
- `encode_lab()` (lines ~250-258) returns `encode_accession_from_path(lab)` for a
  path, i.e. the lab **slug** (`bing-ren`), not the title (`Bing Ren, UCSD`).
- `encode_project()` (lines ~267-275) returns the **award id** from the path, not
  the project string (`ENCODE`).
- `encode_experiment_organism()` (lines ~297-320) falls back to string-matching
  the `biosample_summary` prefix for `Homo sapiens` / `Mus musculus`, so organism
  is a heuristic, NA for anything that does not start with the species.

Fix options, in order of preference:

1. Default `encode_search()` (and `encode_get()`, `encode_report(endpoint="search")`,
   `encode_list_files()` where experiment fields matter) to `frame = "embedded"`.
   This is what your extractors already assume and what the website view uses.
2. Keep `frame = "object"` but request the specific embedded columns via ENCODE
   `field=` selection (`field=lab.title&field=award.project&...`) so the displayed
   fields populate without a full embedded payload. Test that search honors this.
3. At minimum, document that rich columns require `frame = "embedded"`, and add a
   fixture with path-form `lab`/`award` asserting the degraded behavior so it is at
   least intentional and covered.

Tradeoff: embedded responses are larger. For a 25-row experiment search this is
negligible; for `limit = "all"` it is not, so if you default to embedded, keep the
small default `limit`.

### C2. Duplicated matrix result fields

**Confirmed** at `matrix.R:80-86`:

```r
matrix = matrix_long,
matrix_long = matrix_long,
assays = assay_summary,
assay_summary = assay_summary,
biosamples = biosample_summary,
biosample_summary = biosample_summary,
```

Keep one name each (`matrix`, `assays`, `biosamples`) and update `print.R`,
`summary.R`, and `manifest.R` references. This removes three redundant copies from
every matrix object.

### C3. `preferred_default` is never surfaced

**Confirmed.** `encode_flatten_file()` (`flatten.R:149-187`) extracts
`output_type`, `output_category`, `assembly`, etc., but not `preferred_default`
and not the parent analysis. `select-files.R` never references it. This is the
highest-value addition. Concrete change in `flatten.R`:

```r
# inside encode_flatten_file(), add a column:
preferred_default = isTRUE(item$preferred_default),
```

Add `"preferred_default"` to the File column list in
`encode_empty_results("File")` (`flatten.R:224-234`). Then in `select-files.R`,
add a `prefer_default = FALSE` argument that, when `TRUE`, keeps only rows where
`preferred_default` is `TRUE` and logs the rest with reason
`"not preferred_default"`, degrading gracefully (skip the filter) for file types
that carry no such flag, such as raw FASTQ.

### C4. Deprecated `verify_md5` shim in a first release

**Confirmed** at `download.R:52` and `encode_normalize_verify()`
(`download.R:113-126`). Since 0.99.0 is unreleased, there is nothing to be
backward-compatible with. Delete `verify_md5` and keep only
`verify = c("md5", "size")`.

---

## New findings (only visible in source)

### N-A. `encode_cite(style = ...)` is a no-op

`cite.R:30-49` validates `style` with `match.arg()`, but
`encode_citation_text()` (`cite.R:241-256`) and `encode_citation_markdown()`
(`cite.R:258-281`) both take `style` and never branch on it. All three styles
produce identical output, contradicting the design doc's three distinct formats
(`summary`, `methods`, `supplement`). Either implement the branches or drop the
argument. Dropping it is the honest short-term move; implementing `supplement`
(one row per file with experiment, lab, PI, institution, file metadata) is the
version worth building later.

### N-B. File-based citations lose attribution

`encode_flatten_file()` carries only a `lab` column (path-slug in object frame)
and no `institution`, `project`, or `organism`. So
`encode_citation_from_file_table()` (`cite.R:122-160`) fills those with `NA` via
`encode_ensure_columns()`. Result: `encode_cite(encode_list_files(...))` produces
a table where lab is a slug and institution/project/organism are blank. To get
real attribution, `encode_cite()` should join each file's
`experiment_accession` back to its parent experiment's embedded metadata (one
batched experiment search), or the file query itself should embed
`dataset.lab.title`, `dataset.award.project`, and organism. This is the same
root cause as C1.

### N-C. `encode_download()` aborts the whole batch on one bad file

`encode_download_one()` (`download.R:280-283`) calls `cli_abort()` when a file
fails size or MD5 verification, and `encode_verify_existing_file()`
(`download.R:298-305`) aborts on an existing-file mismatch. Because
`encode_download()` loops row by row (`download.R:99-106`), a single corrupt file
in a multi-file batch throws and discards the result table for the files that
already succeeded. This contradicts the workflow doc's "return per-file
success/failure status." Suggested change: have `encode_download_one()` record
`download_status = "failed"` plus the verification flags and return the row
instead of aborting; after the loop, if any row failed, emit a single
`cli::cli_warn()` naming the failed accessions. Keep a hard error only for
unrecoverable cases (no writable directory, no URL). This makes batch downloads
resumable and auditable rather than all-or-nothing.

### N-D. Retry has no backoff

`encode_perform_with_retry()` (`http.R:231-273`) re-issues immediately, spaced
only by the ~0.2s rate throttle, and ignores `Retry-After`. Three attempts can
land in well under a second, which is the opposite of what a 429 wants. Either
delegate to `httr2::req_retry(max_tries, is_transient, backoff)` and let httr2
honor `Retry-After`, or add a short exponential sleep keyed to the attempt
number. `encode_is_transient_status()` already includes 429/500/502/503/504, so
the classification is correct; only the pacing is missing.

### N-E. Minor observations

- `encode_pretty_byte()` (`utils.R:225-241`) divides by 1024 but labels units
  `KB/MB/GB`. Strictly these should be `KiB/MiB/GiB`, or use 1000 for `KB/MB/GB`.
  Cosmetic and common, but a pedantic reviewer may note it.
- `encode_list_files()` defaults `limit = "all"` (`files.R:50`). Reasonable for
  file listing and bounded by `max_experiments`, but it is worth a one-line doc
  note since it diverges from the "limit = all is explicit" principle used
  elsewhere.
- In `encode_flatten_file()` (`flatten.R:174`), `download_url` is computed with
  `cloud_url = NA_character_` hardcoded, so the `download_url` column is always
  href-derived; cloud preference is applied later in `encode_download_urls()`.
  Correct in effect, but the column name slightly oversells what it contains.
- `encode_bucket_table()` (`matrix.R:163-172`) hardcodes `assay_title`/`n` in the
  row builder and only uses its `columns` argument for the empty-fallback naming.
  Harmless, but the argument implies more flexibility than exists.

---

## Retractions from the first review (now that source is visible)

- **S6 (record version/timestamp unconditionally): already done.**
  `encode_manifest()` (`manifest.R:28-41`) writes `package$version` and
  `retrieval$date` regardless of `include_session`, which gates only
  `sessionInfo()`.
- **429 handling: present.** `encode_is_transient_status()` includes 429; only a
  test is missing (see N-D for the separate backoff point).
- **Multi-experiment file listing: fine.** `encode_list_files()` issues one
  batched `type=File&dataset=...` search with datasets exploded into repeated
  params (`files.R:71-90`), not one request per experiment.
- **`encode_get()` on archived objects: fine.** It applies no status filter and
  fetches by path, so archived/revoked objects are returned.
- **`encode_summary()` is not a bare alias.** It is a polymorphic dispatcher
  (`summary.R:19-45`) across search, matrix, object, selected-files, and file
  inputs. The surviving critique is only that "summary" is overloaded across
  `encode_summary()`, `encode_file_summary()`, the `$summary` field, and
  `$assay_summary`.

---

## Revised priority order

1. **C1** frame decision (headline correctness issue).
2. **C3** `preferred_default` support (headline value-add).
3. **N-C** download batch failure behavior (data-integrity ergonomics).
4. **N-A / N-B** cite `style` and file-citation attribution (either implement or
   scope down honestly).
5. **C2, C4** matrix dedup and `verify_md5` removal (cheap cleanups).
6. **N-D** retry backoff; then the earlier vignette/test/description work.

The architecture underneath all of this is sound. None of these require
structural rework; they are targeted fixes to a design that is already close.
