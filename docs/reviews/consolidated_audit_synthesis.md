# encodeUtils consolidated audit synthesis

Date: 2026-07-03

This document consolidates eight review sources:

- **A. Older docs-first review:** `docs/reviews/encodeUtils_review.md`
- **B. Older source-code addendum:** `docs/reviews/encodeUtils_review_addendum.md`
- **C. External audit 1:** pasted audit scoring the package **247 / 300**
- **D. External audit 2:** pasted audit scoring the package **324 / 400**
- **E. External audit 3:** pasted audit scoring the package **334 / 400**
- **F. External audit 4:** pasted audit scoring the package **251 / 300**
- **G. External audit 5:** pasted audit scoring the package **235 / 300**
- **H. External audit 6:** pasted workflow/convenience recommendations centered
  on plan objects, smarter presets, richer reads, and discovery helpers

I also spot-checked the current source for the disputed high-impact findings.
Line references below refer to the current working tree at the time this file was
written and may drift as the package changes.

## How to read this synthesis

The review sources disagree in several places because the package changed between
reviews and because some reviewers inferred behavior from documentation or check
logs rather than source. I use the following labels:

- **accept:** the feedback is meaningful and should be implemented.
- **accept with adjustment:** the underlying concern is real, but the proposed
  solution should be modified.
- **already addressed:** the feedback was valid when written but is now fixed.
- **defer:** useful idea, but not needed for the current release milestone.
- **reject/noise:** not useful for this package's current design or contradicted
  by current source.

The **reported by** count is the number of audit sources that raised the same
substantive issue. Related but narrower follow-up bugs are counted separately.

## Executive synthesis

The package is strong for a pre-release R/ENCODE client. The core design is
coherent: search and inspect metadata first, select files deliberately, download
with safety guards, read only safe supported formats, and preserve provenance via
citations and manifests. All reviewers agreed that this architecture is the
right direction and that the package is already more useful than a generic REST
wrapper.

The package should not be redesigned. The best next work is targeted hardening:
fix a few current correctness and safety bugs, make citation/provenance defaults
harder to misuse, clean package metadata for Bioconductor/CRAN review, improve a
handful of generated docs, and add tests around adverse ENCODE response shapes.
The newer audits add one important design theme: once the correctness layer is
solid, the package should make the central user path feel like a first-class
workflow around **search -> plan/preview -> download -> read -> cite**, rather
than leaving users to manually compose every low-level step.

The most important current issues are:

1. `prefer_default` selection is computed too early and can wrongly discard
   valid raw files in mixed file tables.
2. File citations assume every dataset URL is `/experiments/{accession}/`, which
   is wrong for non-experiment datasets such as annotations.
3. Files with missing `file_size` bypass both per-file and total download-size
   guards.
4. `print.encode_file_table()` can produce misleading summaries after users
   subset columns.
5. Generated Rd examples render ENCODE `@@download` paths as invalid
   `@download` paths.
6. Package readiness is not settled: BiocCheck, normal check behavior with
   Suggests, support-tag requirements, and the CRAN-vs-Bioconductor target need
   one clean decision.
7. The highest-value convenience additions are thin workflow helpers, not broad
   new subsystems: a download preview/plan object, selection explanation helper,
   friendlier preset aliases, query-builder aliases, and replicate/file-pair
   summaries.

## Consolidated findings table

| ID  | Finding                                                                                                            |                         Reported by | Current status                               | Recommendation                  |
| --- | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------: | -------------------------------------------- | ------------------------------- |
| F1  | `prefer_default` can be applied based on unrelated rows before preset/status/format filters                        |                                 2/8 | current source confirms                      | accept, must fix                |
| F2  | Dataset identity is too experiment-centric; citation URLs can be wrong for annotation or other dataset types       |                                 2/8 | current source confirms                      | accept, must fix                |
| F3  | File-table citation attribution is weaker unless `enrich = TRUE` or parent metadata are otherwise included         |                                 6/8 | current behavior is intentional but risky UX | accept with adjustment          |
| F4  | Missing `file_size` bypasses download-size guards                                                                  |                                 2/8 | current source confirms                      | accept, must fix                |
| F5  | `print.encode_file_table()` is misleading after column subsetting                                                  |                                 1/8 | current source confirms likely bug           | accept, should fix              |
| F6  | Generated Rd examples mangle `@@download` into `@download`                                                         |                                 3/8 | current man pages confirm                    | accept, should fix              |
| F7  | `encode_list_files(limit = "all")` is convenient but can be risky                                                  |                                 3/8 | current default confirmed                    | accept with adjustment          |
| F8  | `frame = "embedded"` improves UX but has schema-drift and payload tradeoffs                                        |                                 3/8 | partially addressed                          | document and test               |
| F9  | Optional genomic readers are under-tested                                                                          |                                 3/8 | likely true                                  | accept, add conditional tests   |
| F10 | Need more adverse-condition tests                                                                                  |                                 6/8 | true                                         | accept, expand suite            |
| F11 | BiocCheck / package metadata readiness issues                                                                      |                                 7/8 | current DESCRIPTION confirms some issues     | accept                          |
| F12 | Normal `R CMD check` behavior depends on local Suggests availability                                               |                                 1/8 | environment-dependent                        | accept as release-process issue |
| F13 | Declare `stats` and `tools` in `Imports`                                                                           |                                 2/8 | current DESCRIPTION omits them               | accept                          |
| F14 | Remove redundant `Author` and `Maintainer` fields when using `Authors@R`                                           |                                 3/8 | current DESCRIPTION confirms                 | accept                          |
| F15 | Add `inst/CITATION`, ORCID, and possibly funder role                                                               |                                 2/8 | absent                                       | accept if metadata available    |
| F16 | Validate fractional numeric `limit` values                                                                         |                                 1/8 | current source accepts fractions             | accept                          |
| F17 | Defensively reject `max_tries < 1`                                                                                 |                                 1/8 | current source does not validate             | accept                          |
| F18 | Failed transfers can leave `.part` files; downloads are not resumable                                              |                                 2/8 | current source confirms no cleanup guard     | accept cleanup, defer resume    |
| F19 | `preferred_default` and default-analysis semantics need deeper analysis modeling                                   |                                 3/8 | partially addressed                          | defer full analysis pinning     |
| F20 | `encode_summary()` naming is overloaded / exported surface may be broader than necessary                           |                                 3/8 | real UX concern, not correctness bug         | defer or document               |
| F21 | Function length and line-width notes                                                                               |                                 2/8 | likely BiocCheck polish                      | accept before submission        |
| F22 | Stale design/review docs can mislead future work                                                                   |                                 2/8 | true by design history                       | accept with superseded notices  |
| F23 | Matrix duplicate fields, aliases, `verify_md5`, retry backoff, citation styles, per-file failure rows              |                    3/8 historically | already addressed                            | do not reopen                   |
| F24 | Missing `encode_select_files.Rd` and `encode_read.Rd`                                                              |                                 1/8 | stale                                        | reject as resolved              |
| F25 | S4/R6 classes, HPC/Slurm integration, Shiny, SQLite mirror, automatic FASTQ/BAM processing, consensus peak calling | multiple as prompts or future ideas | out of scope                                 | reject or defer                 |
| F26 | First-class download preview/plan workflow could make the main path more discoverable                              |                                 2/8 | not implemented                              | accept after hardening          |
| F27 | Presets should be more user-centered and may infer assay context where safe                                        |                                 3/8 | partially implemented                        | accept with adjustment          |
| F28 | Selection explanation should be easier than manually inspecting nested list pieces                                 |                                 2/8 | exclusion log exists                         | accept                          |
| F29 | Query aliases/builders and schema-aware discovery would reduce ENCODE field-name friction                          |                                 2/8 | not implemented                              | accept later                    |
| F30 | Printed outputs should be more decision-oriented; progress/open-page helpers are low-risk convenience ideas        |                                 2/8 | partially implemented                        | accept selectively              |
| F31 | `encode_replicates()` / paired FASTQ grouping would address a real ENCODE pain point                               |                                 2/8 | not implemented                              | accept later                    |
| F32 | ENCODE cart bridge (`files.txt` / `metadata.tsv`) would help portal-to-R workflows                                 |                                 2/8 | not implemented                              | defer                           |
| F33 | Manifest read / re-download workflow would strengthen reproducibility                                              |                                 1/8 | manifest write exists                        | accept later                    |
| F34 | `encode_read_many()` and richer optional readers would improve loading, but must stay conservative                 |                                 1/8 | partial read support exists                  | defer until tests improve       |
| F35 | `encode_count()` and large-query preflight would improve discovery and safety                                      |                                 1/8 | partially available via search total         | accept later                    |
| F36 | Common workflow vignettes should show realistic RNA-seq, ChIP-seq, ATAC-seq, raw FASTQ, and manifest paths         |                                 3/8 | current vignette is useful but thin          | accept                          |
| F37 | A one-call `encode_find_files()` helper could map common biological questions to search/list/select results        |                                 1/8 | not implemented                              | accept later                    |

## Must-fix current issues

### F1. `prefer_default` selection is computed too early

**Reported by:** 2/8 sources, but high-confidence because current source
confirms it.

**Current evidence:** `R/select-files.R` computes:

```r
use_preferred_default <- isTRUE(prefer_default) &&
  any(files$preferred_default %in% TRUE)
```

before applying status, format, output-type, assembly, href, or preset filters.
Later it applies:

```r
keep = files$preferred_default %in% TRUE
```

If a mixed file table contains processed files with `preferred_default = TRUE`
and raw FASTQ files with `preferred_default = NA`, then
`encode_select_files(files, preset = "raw_reads", prefer_default = TRUE)` can
remove all otherwise valid raw reads because the decision to use
`preferred_default` was made from unrelated processed rows.

**Evaluation:** This is not noise. It affects the package's most valuable
function.

**Implementation direction:** Determine preferred-default availability only
inside the current candidate set after status/file-format/output-type/assembly
and download-URL filters. If no remaining candidate has `preferred_default =
TRUE`, skip the preferred-default filter and record in `criteria` that the
preference was unavailable for the selected file class.

**Tests to add:** A mixed fixture with one processed preferred-default file and
two raw FASTQ rows lacking preferred-default flags. The raw-read preset with
`prefer_default = TRUE` should keep the raw files rather than selecting zero rows.

### F2. Citation URLs assume every dataset is an experiment

**Reported by:** 2/8 sources as a precise bug. Related citation/provenance
concerns were raised by 6/8 sources.

**Current evidence:** `R/cite.R` constructs:

```r
encode_object_url(paste0("/experiments/", files$experiment_accession, "/"))
```

for every file-table citation. `R/flatten.R` stores the dataset path in
`dataset`, but citation ignores that path and uses only the parsed accession.
ENCODE file datasets can be annotations or other dataset types, not only
experiments.

**Evaluation:** This is a real provenance bug. The package should not fabricate
incorrect dataset URLs.

**Implementation direction:** Preserve and use the original dataset path:

- Keep `experiment_accession` for experiment datasets if useful.
- Add or standardize `dataset_accession`, `dataset`, and ideally `dataset_type`.
- In citations, use `dataset` when it is present and looks like an ENCODE path.
- Only construct `/experiments/{accession}/` when the dataset path is absent and
  the accession is clearly an experiment accession.

**Tests to add:** A file row with `dataset = "/annotations/ENCSR124WJM/"` should
produce an annotation URL, not an experiment URL.

### F3. Citation enrichment is too easy to miss

**Reported by:** 6/8 sources.

**Current evidence:** `encode_cite()` can enrich file-table citations from parent
experiment metadata when `enrich = TRUE`, but the default file-table citation can
have weaker lab/project/organism information because file searches use lighter
file metadata.

**Evaluation:** The function already supports the better behavior, but the
default user path may produce less useful citation output than the package's
documentation promises.

**Implementation direction:** The newer audits make a good point: the package's
provenance story is weakened if users must know a hidden `enrich = TRUE` switch.
Use a bounded automatic default rather than an unbounded network surprise:

- Change the default to something like `enrich = "auto"` for file-table inputs.
- In auto mode, enrich only when the number of unique experiment datasets is
  small, for example `max_enrich_datasets = 10`.
- Print or record that parent experiment metadata were fetched.
- For large tables, skip automatic enrichment with a clear message and tell the
  user to pass `enrich = TRUE` deliberately.
- Keep `enrich = FALSE` available for fully offline or no-extra-request use.
- Prefer carrying richer dataset metadata from `encode_list_files()` where
  ENCODE search fields can provide it cheaply.

**Tests to add:** Auto-enriched small file-table citation should fill parent
experiment attribution; large tables should not silently fan out to many
requests; `enrich = FALSE` should remain no-extra-request behavior.

### F4. Unknown file sizes bypass download guards

**Reported by:** 2/8 sources, but source-confirmed and important.

**Current evidence:** `R/download.R` checks:

```r
too_large <- !is.na(sizes) & sizes > max_file_size
total_size <- sum(sizes, na.rm = TRUE)
```

Files with `file_size = NA` are never too large and do not contribute to the
total. If all sizes are unknown, the planned total is effectively zero.

**Evaluation:** This weakens the central safety promise of size-aware downloads.

**Implementation direction:** Add an explicit policy for unknown sizes. The
cleanest default is conservative:

```r
encode_download(..., allow_unknown_size = FALSE)
```

If any file has unknown size and `dry_run = FALSE`, abort unless
`allow_unknown_size = TRUE`. Dry-runs should report the count of unknown-size
files and say that total size is a known-size lower bound.

**Tests to add:** Unknown-size rows should be reported in dry-run and should
abort real download unless explicitly allowed.

### F5. File-table print summaries are misleading after column subsetting

**Reported by:** 1/8 sources, source-confirmed as plausible.

**Current evidence:** `print.encode_file_table()` always calls
`encode_file_summary(x)`. `encode_file_summary()` uses
`encode_ensure_columns()` to add missing columns as `NA`. If a user prints:

```r
files[, c("file_accession", "file_format")]
```

the object may retain class `encode_file_table`, but summary fields such as
experiment count and total size are computed from synthetic `NA` columns.

**Evaluation:** This is a real UX bug because it can make valid data look empty
or incorrectly summarized.

**Implementation direction:** Make printing column-aware:

- If required summary columns are absent, print only the row count and available
  table.
- Or implement `[.encode_file_table` to drop the class when subsetting removes
  core metadata columns.

**Tests to add:** Subsetted file tables should not print `experiments: 0` or
`known total size: 0 B` as if those were true facts.

### F6. Rd examples mangle `@@download`

**Reported by:** 3/8 sources.

**Current evidence:** Roxygen source examples use `@@download`, but generated man
pages contain `/@download/` in at least `encode_download.Rd`,
`encode_list_files.Rd`, and `encode_select_files.Rd`.

**Evaluation:** This is a documentation correctness bug. It does not break tests
because examples are mocked/dry-run, but it teaches an invalid ENCODE path.

**Implementation direction:** Escape literal `@` in roxygen examples or avoid
literal `@@download` paths in examples by constructing them with `paste0("@",
"@download")`.

**Tests/checks:** Regenerate documentation and search `man/` for `@download`.
There should be no single-`@download` paths.

## Should-fix before public release

### F7. `encode_list_files(limit = "all")` deserves guardrails

**Reported by:** 3/8 sources.

**Evaluation:** The default is understandable because file listing is usually the
next step after a narrowed experiment search, and `max_experiments` plus
`allow_many` provides a meaningful guard. Still, it conflicts with the package's
general "avoid accidental `limit = all`" principle.

**Implementation direction:** Do not necessarily change the default immediately.
Instead:

- Document clearly that `limit = "all"` is intentional for file metadata.
- Include `attr(files, "total")` and warn when returned rows are very large.
- Consider requiring `allow_many = TRUE` not only for many experiments, but also
  for file queries whose returned total exceeds a threshold.

### F8. Frame defaults need explicit documentation and tests

**Reported by:** 3/8 sources.

**Evaluation:** The older object-frame critique was valid before the package
switched search/get to `frame = "embedded"`. The remaining issue is not to undo
that change blindly, but to make the tradeoff intentional.

**Implementation direction:**

- Keep `encode_search()` and `encode_get()` embedded by default for rich console
  summaries.
- Document that `encode_list_files()` defaults to object frame because file
  metadata needed for downloads is mostly top-level and lighter.
- Add object-frame fixtures so compact-table degradation is tested and
  intentional.

### F9. Optional genomic reader success paths are under-tested

**Reported by:** 3/8 sources.

**Evaluation:** This is meaningful but should remain conditional. The package is
right to keep `rtracklayer` and `Biostrings` optional, but optional success paths
should not be completely untested in environments where those packages exist.

**Implementation direction:** Add tests guarded by `testthat::skip_if_not_installed()`
for small local BED/narrowPeak/FASTA examples. Avoid live downloads and avoid
large files.

### F10. Adverse-condition test gaps remain

**Reported by:** 6/8 sources.

**Most valuable additions:**

- Mixed `prefer_default` candidate bug.
- Annotation dataset citation URL.
- Unknown-size download guard.
- Subsetted `encode_file_table` printing.
- Malformed matrix response shape.
- Object-frame path-shaped linked metadata.
- `Retry-After` behavior and invalid `max_tries`.
- Fractional limits.
- Partial transfer cleanup.
- Optional reader success paths when dependencies are installed.

### F11. BiocCheck and package metadata readiness

**Reported by:** 7/8 sources.

**Evaluation:** The audits disagree on exact check status. Treat the precise
status as something to re-run after the next code changes. The package metadata
issues are still real from source inspection.

**Implementation direction:**

- Remove hand-written `Author:` and `Maintainer:` fields from `DESCRIPTION` and
  rely on `Authors@R`.
- Add `stats` and `tools` to `Imports` if the package continues using
  `stats::` and `tools::`.
- Add ORCID and funder role only if the correct metadata are available.
- Add `inst/CITATION`.
- Re-run `R CMD build`, normal `R CMD check`, and `BiocCheck::BiocCheck()`.
- The Bioconductor support watched-tag issue is partly external to the codebase;
  it needs the package/support metadata set up before submission.

### F12. Normal check behavior with Suggests must be settled

**Reported by:** 1/8 sources.

**Evaluation:** This is not necessarily a package-code defect. It is a release
environment issue: normal checks will require Suggests unless configured
otherwise. For Bioconductor submission, the right answer is to make sure
Suggests are available in the check environment and examples/tests skip
optional functionality correctly.

**Implementation direction:** Do not remove useful optional readers just because
the local renv is missing them. Instead, either install/snapshot the Suggests in
the development environment or make optional examples/tests skip cleanly while
ensuring Bioc build machines can install the declared packages.

### F13. Add `stats` and `tools` to `Imports`

**Reported by:** 2/8 sources.

**Evaluation:** Low-risk cleanup. Even if base-priority packages are exempt in
some checks, explicit imports are clearer and less surprising.

### F14. Remove redundant `Author` and `Maintainer`

**Reported by:** 3/8 sources.

**Evaluation:** Current `DESCRIPTION` contains `Authors@R`, `Author`, and
`Maintainer`. That is redundant and can trigger BiocCheck issues.

### F15. Add `inst/CITATION`

**Reported by:** 2/8 sources.

**Evaluation:** This package itself helps users cite ENCODE data, so a package
citation file is especially appropriate.

### F16. Numeric `limit` should be whole-number only

**Reported by:** 1/8 sources.

**Current evidence:** `encode_validate_limit()` accepts any finite non-negative
number, including `1.5`.

**Implementation direction:** Require integer-like numeric values:

```r
limit == floor(limit)
```

and probably require `limit >= 0`. Decide whether `limit = 0` is meaningful; if
not, require positive integers except `"all"`.

### F17. Invalid retry counts should fail clearly

**Reported by:** 1/8 sources.

**Current evidence:** `encode_perform_with_retry()` reads
`getOption("encodeUtils.max_tries", 3)` and loops over `seq_len(max_tries)`
without first checking that it is a positive whole number.

**Implementation direction:** Add a small internal validator. Reject `NA`, zero,
negative, fractional, and non-numeric values with a clear error.

### F18. Clean up partial download files on failed transfer

**Reported by:** 2/8 sources.

**Evaluation:** Full HTTP range/resume support is not needed now, but stale
`.part` files after failed transfers are confusing.

**Implementation direction:** Use an `on.exit()` cleanup for the `.part` file
until the rename succeeds. Keep resume support out of scope for now.

### F19. Default-analysis pinning is useful but not MVP-critical

**Reported by:** 3/8 sources.

**Evaluation:** The package now surfaces `preferred_default`, `analyses`, and
`analysis_step_version`. That is enough for the current milestone. Full
`analysis = "default"` semantics require modeling ENCODE Analysis objects and
should be driven by real examples.

**Implementation direction:** Defer, but keep it in the roadmap after the
selection layer stabilizes.

### F20. `encode_summary()` naming is overloaded

**Reported by:** 3/8 sources.

**Evaluation:** This is a real discoverability concern, but not a correctness
bug. The older claim that `encode_summary()` was just an alias is stale; current
source makes it a real polymorphic helper.

**Implementation direction:** Do not drop it as part of the next bug-fix pass.
Either document the dispatch behavior more clearly or decide before release
whether to rename it to `encode_overview()`.

### F21. Function length and line-width notes

**Reported by:** 2/8 sources.

**Evaluation:** This is polish, not behavior. Address before submission if
BiocCheck keeps flagging it, but avoid churn that obscures the bug fixes.

### F22. Stale design/review docs need status banners

**Reported by:** 2/8 sources.

**Evaluation:** The old reviews are useful history, but several findings are now
known to be fixed or superseded. Future agents could waste time chasing them.

**Implementation direction:** Add a short superseded notice to older review
files and design docs, pointing to this synthesis and `feedback_triage.md`.
Preserve history; do not delete the old reviews.

## High-value convenience additions from newer audits

These are worth adding only after the correctness/safety pass. They are not
noise, but they should be implemented as thin, auditable helpers over the stable
core rather than as a large new abstraction layer.

### F26. First-class download preview / plan workflow

**Reported by:** 2/8 sources.

**Evaluation:** This is the strongest new workflow idea. The package already has
`encode_download(..., dry_run = TRUE)`, selected-file objects, manifests, and
citations. A plan object would make that path more discoverable and easier to
print, inspect, save, cite, and download later.

**Implementation direction:** Add this in two steps:

1. Add `encode_preview_download()` as a thin wrapper over
   `encode_download(dry_run = TRUE)` that returns a printable
   `encode_download_plan` object instead of feeling like a side effect of the
   download function.
2. Later, consider `encode_plan()` as a higher-level object that combines
   selected files, exclusions, size summary, destination, query metadata,
   citation summary, and manifest-ready provenance.

Do not make `encode_plan()` hide search, selection, or size-guard decisions.
The plan should make the existing decisions more visible.

### F27. Friendlier presets and assay-aware inference

**Reported by:** 3/8 sources.

**Evaluation:** The package already has useful assay-aware presets, but newer
feedback correctly notes that names such as `rnaseq_gene_quant` are still a
little implementation-shaped. User-centered aliases such as `raw_fastq`,
`chipseq_idr_peaks`, `chipseq_signal_bigwig`, `rna_gene_counts`, and
`rna_gene_tpm` would be easier to discover.

**Implementation direction:** Add aliases rather than rename everything
immediately. Keep one canonical preset table with alias metadata, and make
`encode_file_preset()` show canonical names plus aliases. Assay auto-detection is
useful but should be conservative: infer only when `assay_title` is present and
unambiguous; otherwise ask the user to choose a specific preset.

### F28. Selection explanation helper

**Reported by:** 2/8 sources.

**Evaluation:** The exclusion log is one of the package's best features, but
users should not have to remember the internal list structure.

**Implementation direction:** Add `encode_explain_selection()` returning a tidy
table with selected and excluded rows plus concise reasons. It should work on an
`encode_selected_files` object and optionally summarize counts by reason. This
is a low-risk wrapper around existing data.

### F29. Guided query builder and schema-aware discovery

**Reported by:** 2/8 sources.

**Evaluation:** ENCODE field names are powerful but intimidating. A helper that
maps common biological terms to raw ENCODE filters would make the package easier
without removing expert control.

**Implementation direction:** Prefer a builder over widening `encode_search()`
immediately:

```r
filters <- encode_query(
  assay = "total RNA-seq",
  organism = "Homo sapiens",
  biosample = "heart"
)
encode_search(filters = filters)
```

Later, add schema-aware typo detection for raw filter names and convenience
discovery helpers such as `encode_assays()`, `encode_biosample_terms()`, and
`encode_file_outputs()`. Keep raw `filters = list(...)` as the escape hatch.

### F37. One-call file finder

**Reported by:** 1/8 sources.

**Evaluation:** `encode_find_files()` could be genuinely useful for new users:
it would turn common biological inputs into the package's existing
search/list/select workflow. The risk is that it becomes the rejected
`encode_load_data()` mega-wrapper under another name.

**Implementation direction:** Defer until `encode_query()`,
`encode_select_files()`, and download previews are stable. If added, it should:

- Search experiments from friendly aliases.
- List files for the matched experiments.
- Run `encode_select_files()` with explicit preset/assembly/default criteria.
- Return a structured object containing the search result, full file table,
  selected files, and exclusions.
- Never download or read files automatically.

### F30. Decision-oriented printing and small console conveniences

**Reported by:** 2/8 sources.

**Evaluation:** This aligns with the original "console version of the website"
goal. Wide tables and misleading summaries reduce confidence even when the data
are correct.

**Implementation direction:** First fix the subsetted file-table print bug. Then
curate print columns for search/file/selection objects while preserving full
data frames under the hood. A small `encode_open()` helper that opens ENCODE
object URLs is reasonable later. A byte-level progress bar is useful, but should
not take priority over correctness and should stay quiet in noninteractive
tests/examples.

### F31. Replicate and paired FASTQ helper

**Reported by:** 2/8 sources.

**Evaluation:** This remains one of the best future additions because replicate
and paired-end relationships are a real ENCODE pain point.

**Implementation direction:** Add `encode_replicates(files, pair_fastq = TRUE)`
after file selection stabilizes. It should be descriptive, not prescriptive: one
row per experiment/biological replicate/technical replicate, paired FASTQ files
grouped through `paired_with`, and no automatic biological filtering beyond what
the user requested.

### F32. ENCODE cart bridge

**Reported by:** 2/8 sources.

**Evaluation:** Useful for users who start in the ENCODE portal and then want to
continue in R.

**Implementation direction:** Defer until core workflows are polished. Later add
helpers to read portal `files.txt` and `metadata.tsv`, and optionally emit a
compatible metadata TSV from `encode_write_manifest()`.

### F33. Manifest read / re-download workflow

**Reported by:** 1/8 sources.

**Evaluation:** This fits the package's reproducibility promise and is more
valuable than adding another broad search wrapper.

**Implementation direction:** Add `encode_read_manifest()` or
`encode_manifest_read()` after the manifest format stabilizes. It should allow a
user to inspect a previous plan and re-run `encode_download()` against recorded
file URLs/checksums.

### F34. `encode_read_many()` and richer loading

**Reported by:** 1/8 sources.

**Evaluation:** Useful, but risky if it encourages loading large files
indiscriminately. Keep `encode_read()` conservative.

**Implementation direction:** First add conditional tests for existing optional
reader success paths. Then consider `encode_read_many()` for selected/downloaded
small files, returning a named list with metadata attached. Do not add automatic
full BAM/FASTQ/CRAM reads.

### F35. `encode_count()` and large-query preflight

**Reported by:** 1/8 sources.

**Evaluation:** Useful and low risk. Users often need to know whether a query is
huge before retrieving rows.

**Implementation direction:** Add `encode_count()` as a thin search wrapper that
requests a minimal result and returns the live `total`, filters, and query URL.
Also consider warning when a query matches many rows and the user asked for
`limit = "all"`.

### F36. Common workflow vignettes

**Reported by:** 3/8 sources.

**Evaluation:** Worth doing once the APIs stabilize. Vignettes are where the
package will prove that the workflow is genuinely easier than manual ENCODE
portal use.

**Implementation direction:** Add short, mostly mocked vignettes or vignette
sections for:

- RNA-seq quantification discovery/download/load.
- ChIP-seq peaks and signal tracks.
- ATAC-seq peak files.
- Raw FASTQ download safety.
- Manifest/citation-based reproducibility.

## Already addressed and should not be reopened

These were valid findings when raised but are already fixed in the current tree
or explicitly triaged:

- Search/get richness: `encode_search()` and `encode_get()` now default to
  `frame = "embedded"`.
- `preferred_default`, `analyses`, and `analysis_step_version` are surfaced from
  file metadata.
- `encode_select_files()` uses `preset`, including assay-aware presets.
- `encode_matrix()` no longer carries duplicate `matrix_long`, `assays`, or
  `biosamples` fields.
- Exported aliases such as `encode_files()`, `encode_schema()`,
  `encode_citation()`, and `encode_interactive_search()` were removed.
- The pre-release `verify_md5` shim was removed.
- Transient retries now include backoff and `Retry-After` handling.
- Batch downloads now return per-file failed rows instead of aborting the whole
  batch on verification failure.
- `encode_cite(style = ...)` now branches across summary, methods, and
  supplement styles.
- `encode_select_files.Rd` and `encode_read.Rd` exist; the older missing-man-page
  finding is stale.
- `encode_summary()` is a real dispatcher, not a trivial alias.

## Feedback to reject or keep out of scope

The following suggestions are not appropriate for the current package milestone:

- **Heavy S4/R6 class system.** The current S3 lists/data frames are the right
  shape for an API client that returns inspectable metadata tables.
- **Slurm/HPC architecture.** Querying ENCODE metadata and controlled downloads
  are not bottlenecked in a way that needs HPC machinery.
- **Shiny browser or full interactive TUI.** The package should remain a
  scriptable R workflow tool.
- **Private authentication, POST/PATCH/submission workflows.** Out of scope for
  a read-only public data client.
- **SQLite mirror or global metadata dump.** This would move the package away
  from small, live, explicit queries.
- **Automatic FASTQ/BAM/CRAM processing.** The package should refuse unsafe full
  reads and point users to appropriate Bioconductor tooling.
- **Consensus/de novo peak calling.** This requires biological choices that the
  package should not silently invent.
- **A mega-wrapper such as `encode_load_data()`.** It would hide the deliberate
  steps that make the workflow safe and auditable.

## Implementation plan for review

### Phase 0: Re-establish baseline

Before behavior edits, run or record the current baseline so the conflicting
audit claims are settled against the real checkout:

- `devtools::test()` or equivalent package test runner.
- `R CMD build`.
- Normal `R CMD check` in the intended release environment.
- `BiocCheck::BiocCheck()` if Bioconductor remains the target.

After each code-edit batch, run `tools/r_codex_utils check` on the changed R
files and then the relevant package tests.

### Phase 1: Correctness and safety fixes

These should happen before adding new user-facing helpers:

1. Fix `prefer_default` so it is evaluated after candidate filters.
2. Preserve dataset paths/types and use them for citation URLs.
3. Add `allow_unknown_size = FALSE` behavior to `encode_download()`.
4. Clean `.part` files after failed transfers.
5. Fix file-table printing after column subsetting.
6. Harden `encode_validate_limit()` and retry `max_tries` validation.
7. Fix roxygen/Rd `@@download` escaping.

### Phase 2: Tests for the fixes

Add mocked/unit tests for:

- Mixed preferred-default/raw-read selection.
- Annotation dataset citation URL.
- Unknown-size download dry-run and real-download guard.
- Subsetted file-table printing.
- Partial transfer cleanup.
- Fractional `limit`.
- Invalid `encodeUtils.max_tries`.
- `Retry-After` behavior, if not already covered.
- Rd examples do not contain invalid single-`@download` paths.

### Phase 3: Low-risk package metadata and release hygiene

1. Update `DESCRIPTION`: remove redundant `Author`/`Maintainer`, add `stats` and
   `tools`, and add ORCID/funder metadata if available.
2. Add `inst/CITATION`.
3. Document `encode_list_files(limit = "all")` and frame-default tradeoffs.
4. Add superseded notices to older design/review docs.

### Phase 4: Provenance and workflow ergonomics

These are the highest-value UX changes from the newer audits once the bug fixes
are stable:

1. Make file-table citation enrichment bounded and automatic, for example
   `enrich = "auto"` with a small `max_enrich_datasets` guard.
2. Add `encode_preview_download()` returning a printable
   `encode_download_plan` object.
3. Add `encode_explain_selection()` over existing selected/excluded file data.
4. Add user-centered preset aliases such as `raw_fastq`,
   `chipseq_idr_peaks`, `chipseq_signal_bigwig`, `rna_gene_counts`, and
   `rna_gene_tpm` without removing the current presets.
5. Curate print columns for search, file, selected-file, and download-plan
   objects while preserving full data frames.
6. Add `encode_count()` as a low-risk large-query preflight helper.

### Phase 5: Documentation and onboarding

1. Make README and the main vignette show one complete workflow:
   search -> list files -> summarize -> select -> preview download -> manifest
   -> citation.
2. Add focused workflow sections or vignettes for RNA-seq quantification,
   ChIP-seq peaks/signal, ATAC-seq peaks, raw FASTQ safety, and manifest-based
   reproducibility.
3. Teach `encode_cite()` auto-enrichment and explicit `enrich = TRUE/FALSE`
   behavior.

### Phase 6: Release-target decision

Make a clear decision between:

- **Bioconductor-first:** justify the domain fit, optionally make Bioconductor
  integration more load-bearing over time, satisfy BiocCheck/support-tag
  requirements, and keep BiocStyle/biocViews.
- **CRAN-first:** keep the dependency graph lean and treat Bioconductor packages
  as optional readers.

Do not contort the package just to silence the "no Bioconductor dependency" note.
The target should reflect the package's actual value proposition.

### Phase 7: Later roadmap

After the hardening and core UX pass:

- Add `encode_replicates()` / paired FASTQ grouping.
- Add `encode_query()` and schema-aware typo/discovery helpers.
- Add `encode_find_files()` as a transparent search/list/select helper that does
  not download or read automatically.
- Add ENCODE `files.txt` / `metadata.tsv` import/export bridge.
- Add manifest read / re-download support.
- Add `encode_read_many()` only after optional-reader success paths are tested.
- Consider analysis/default-analysis pinning after verifying real metadata
  behavior across assays and assemblies.
- Add recorded real ENCODE fixtures for schema-drift monitoring.

## Recommended next action

Start with Phase 1 and Phase 2. Those changes address real current bugs and can
be validated locally without changing the package's overall API philosophy. Then
handle package metadata, followed by the bounded provenance/preview/explanation
helpers that make the existing workflow feel smoother.
