# encodeUtils: Design and API Review

Date: 2026-07-03
Reviewer perspective: skeptical ENCODE / R / Bioconductor user.

Superseded note: this is a historical review snapshot. Use
`docs/reviews/consolidated_audit_synthesis.md` as the current audit and
implementation reference.

## Scope and honesty about what was reviewed

This review is based on the package metadata (`DESCRIPTION`, `NAMESPACE`),
`README.md`, `NEWS.md`, the planning notes (`encode_package_notes.md`,
`design/user_workflows.md`), the vignette (`vignettes/encodeUtils.Rmd`), the full
test file (`tests/testthat/test-package.R`), and eight rendered man pages.

Two limitations shape the confidence of each point below:

1. **No `R/` source was available.** Claims about naming, organization, exported
   surface, defaults, provenance design, and test coverage are complete. Claims
   about implementation correctness are _inferred from tests and docs_ and are
   marked "verify" where I could not read the code.
2. **`encode_select_files.Rd` and `encode_read.Rd` were empty/absent** in what I
   read. These are your two most important functions. If the man pages are
   genuinely missing in the package, `R CMD check` will flag undocumented
   exported objects. Confirm they exist and are non-trivial.

Grounded external facts used below (checked against ENCODE docs on 2026-07-03):
the REST API is rate-limited to 10 GET/sec per user; ENCODE files carry a
`preferred_default` flag within a "default analysis," which is what the portal's
"Download preferred default files" option consumes; the batch download flow
emits `files.txt` plus a `metadata.tsv`.

---

## Direct answers to your 15 questions

**1. Are the functions logically organized?**
Yes, mostly. The staged pipeline (discover, inspect, list, select, download,
read, cite/manifest) is coherent and maps cleanly onto real ENCODE use. The
weak spot is that provenance/accessor helpers (`encode_query_url`,
`encode_filters`, `encode_facets`, `encode_search_fields`) and console helpers
(`encode_browse`, `encode_select`, `encode_filter_results`) are flat in the same
namespace as the core verbs, so the exported surface reads as larger and less
tiered than the workflow actually is.

**2. Are the function names intuitive?**
The `encode_*` prefix is the right call: it groups everything for autocomplete
and avoids clobbering generics like `search()` or `files()`. Keep it. Verb-first
core names (`encode_search`, `encode_get`, `encode_download`, `encode_read`) are
clear. The noun-ish ones are where ambiguity creeps in (see Q3).

**3. Are aliases like `encode_files()` helpful or confusing?**
Confusing, on balance. You export five alias pairs: `encode_files` /
`encode_list_files`, `encode_schema` / `encode_get_schema`, `encode_summary` /
`encode_file_summary`, `encode_citation` / `encode_cite`, and
`encode_interactive_search` / `encode_browse`. Your own notes call
`encode_files()` ambiguous about whether it downloads. `encode_summary()` is the
worst offender: it collides conceptually with base `summary()`, with
`encode_get()`'s `$summary`, and with `encode_matrix()`'s `$assay_summary`. Cut
most aliases (see recommendation S1).

**4. Are parameter names intuitive and consistent?**
Largely consistent (`quiet`, `directory`, `dry_run`, `overwrite`, `limit`,
`filters`, `frame` recur predictably). Two frictions: the design doc and
Workflow 5 reference `max_size`, but the shipped API is `max_file_size` /
`max_total_size`, so your own docs drift. And `encode_select_files(use=)` plus
`encode_file_preset(use=)` name a preset with the verb "use"; `preset=` would
read better. Minor, but a pre-1.0 package is the cheap moment to fix it.

**5. Are the workflows natural for real ENCODE use cases?**
Yes. Search then list-files then select then dry-run download is exactly how a
careful user works. The metadata-first, loading-last ordering is correct and is
the package's main virtue.

**6. Are there missing high-value functions?**
The important gap is not a new function but a missing _field_: `preferred_default`
/ default-analysis awareness (recommendation M3). Beyond that, a replicate helper
(`encode_replicates()`) and an ENCODE-native `files.txt` / `metadata.tsv` bridge
are the two additions most aligned with real workflows. Everything else you have
is sufficient.

**7. Are any existing functions overengineered, underpowered, or confusing?**
Overengineered via hedged naming: the duplicated `encode_matrix()` result fields
and the alias sprawl. Underpowered: `encode_select_files()` presets are too broad
for the assay-specific reality of ENCODE. `encode_read()` is scoped correctly;
resist the urge to grow it into a format zoo.

**8. Are defaults safe and practical?**
Mostly yes. `status = "released"`, small `limit`, `overwrite = FALSE`, dry-run
affordance, and post-download size/MD5 verification are all correct. Caveat: your
own example FASTQ (ENCFF312AWH) is 1.37 GB, so `max_total_size = "5GB"` will
routinely block legitimate paired raw-read pulls across replicates. That is a
defensible safe default, but the block message must show the planned total and
the exact override.

**9. Is the file-selection design useful enough?**
It is the strongest idea in the package, and the exclusion log is excellent. It
is not yet as useful as it could be because it ignores `preferred_default` and
analysis grouping, which is precisely how ENCODE itself disambiguates "the right
file." Close that gap (M3) and this becomes a genuine reason to use the package.

**10. Is the package doing enough for reproducibility/provenance?**
Close to yes, and better than most wrappers. Query URL, filters, facets,
retrieval date, checksums, selected-and-excluded files, and a JSON manifest is a
strong set. The gap is that package version and timestamp appear tied to
`include_session`; record them unconditionally (S6).

**11. Are there edge cases likely to break?**
The frame/path extraction issue (M2) is the main risk. Others under-covered:
malformed `matrix.y` JSON, multi-experiment file listing with throttling, 429
specifically (only 503 is tested), and `encode_get()` on an archived accession
(confirm the `released` default is not applied to single-object GET, or you will
"lose" valid archived objects).

**12. Are tests meaningful, or are important behaviors under-tested?**
Meaningful and, for a solo package, genuinely good: negation encoding, empty/404,
bounded retries (503 x3), download verify-failure, cloud fallback, duplicate
paths, messy file sizes, and the BibTeX refusal are all tested well. Gaps listed
in S5. All tests are mocked, which is correct for offline CRAN/Bioc builds;
adding a few recorded real fixtures would harden against schema drift.

**13. Are docs/vignettes clear enough for a new user?**
The vignette is clean and builds offline (good), but thin: it never demonstrates
`encode_matrix()`, a realistic `encode_select_files()` exclusion, `encode_read()`,
or schema/field discovery, so it undersells the file-selection crown jewel.
Several man `\description{}` fields just repeat the title. Fix both (S4).

**14. CRAN-style minimalism or Bioconductor-style integration?**
Commit to Bioconductor. Every signal already points there: `0.99.0`, `biocViews`,
`BiocStyle` vignette, `Artistic-2.0`, `rtracklayer`/`Biostrings` in Suggests,
`R_user_dir` caching, and the domain itself. Do not try to serve both. See S7 for
what "committing" implies.

**15. What should be improved before this is polished?**
In order: confirm the two missing man pages (M1); resolve the frame/path
extraction question (M2); add `preferred_default` awareness (M3); trim aliases
and duplicate fields (S1); then the doc, test, and manifest refinements.

---

## Prioritized recommendations

### MUST FIX

#### M1. Confirm and populate the two crown-jewel man pages

- **Priority:** must fix
- **Affected:** `encode_select_files()`, `encode_read()`
- **Why it matters:** These are the two functions that most differentiate the
  package. If their `.Rd` files are empty or missing, `R CMD check` reports
  undocumented exported objects and Bioconductor review stops there. Even if they
  exist, they must document every argument (`use`/`preset`, `replicate_policy`,
  `assembly`, `explain` for selection; `max_size`, `unsupported`, format handling
  for read) with runnable examples.
- **Suggested behavior:** Ensure roxygen blocks with `@param` for every argument,
  a `@return` describing the `encode_selected_files` and `encode_local_file`
  objects, and at least one self-contained example each.
- **Tradeoff:** None. This is table stakes.

#### M2. Resolve compact-table richness under `frame = "object"`

- **Priority:** must fix (pending verification)
- **Affected:** `encode_search()`, `encode_get()`, `encode_list_files()`, and the
  internal summary extractors
- **Why it matters:** In object frame, ENCODE returns `lab`, `award`, and
  `biosample_ontology` as paths (`/labs/x/`), not titled objects. Your fixture
  contains both a titled and a path form, and the test only asserts on the titled
  one, so lab title, institution, organism, and biosample classification are
  untested on the default frame. On live object-frame data these columns may come
  back NA or as raw paths, which undercuts the "console version of the website"
  goal.
- **Suggested behavior:** Pick one of three, in order of preference. (a) Keep
  `frame = "object"` default but resolve the handful of summary fields
  (lab.title, award.project, organism, biosample classification/term) via a
  bounded, throttled follow-up or via `field=` selection so the compact table is
  always populated. (b) Default the _summarized columns_ to an embedded-field
  request while keeping the raw graph in object frame. (c) At minimum, document
  loudly that rich columns require `frame = "embedded"` and test both frames.
- **Tradeoff:** Option (a) costs extra requests; keep it inside the rate budget
  and only for displayed fields. Option (b) is heavier per call. Do not silently
  fabricate values from paths.

#### M3. Add `preferred_default` and default-analysis awareness to file handling

- **Priority:** must fix for the package's core value proposition
- **Affected:** `encode_list_files()`, `encode_select_files()`,
  `encode_file_preset()`
- **Why it matters:** ENCODE's own answer to "which file is the right one" is the
  `preferred_default` flag inside a default analysis. This is exactly what the
  portal's "Download preferred default files" option uses. Your presets
  (`peaks`, `signal`, `raw_reads`) reinvent a coarser version of a distinction
  ENCODE already encodes. Surfacing it turns `encode_select_files()` from "a
  reasonable heuristic" into "reproduces the portal default."
- **Suggested API:**
  ```r
  files <- encode_list_files("ENCSR284QGB")   # now includes a preferred_default column
  selected <- encode_select_files(files, prefer_default = TRUE)
  ```
  `prefer_default = TRUE` keeps only `preferred_default` files (optionally within
  the default analysis) and logs everything else in the existing exclusion table
  with reason "not preferred_default". Leave the current preset path intact for
  users who want non-default outputs.
- **Tradeoff:** `preferred_default` is not present on every file type (raw FASTQ
  has none), so `prefer_default` must degrade gracefully to the preset logic for
  outputs that lack the flag, and say so in the log.

### SHOULD IMPROVE

#### S1. Trim alias sprawl and collapse duplicated result fields

- **Priority:** should improve
- **Affected:** `NAMESPACE`; `encode_files`, `encode_schema`, `encode_summary`,
  `encode_interactive_search`, `encode_citation`; `encode_matrix()` result
- **Why it matters:** Fewer exports is easier to learn, document, and defend in
  review. The `encode_matrix()` object currently carries `matrix_long`==`matrix`,
  `assay_summary`==`assays`, `biosample_summary`==`biosamples` (your tests assert
  the identity), which is memory and cognitive overhead for no gain.
- **Suggested behavior:** Keep one canonical name per concept:
  `encode_list_files`, `encode_get_schema`, `encode_file_summary`, `encode_cite`,
  `encode_browse`. Drop `encode_summary` and `encode_interactive_search`
  entirely. If you want to preserve `encode_files`/`encode_schema`/
  `encode_citation` for muscle memory, keep them as documented aliases in the
  same `.Rd` but stop advertising them as separate functions. For the matrix
  object, keep `matrix`, `assays`, `biosamples` and delete the `*_long` /
  `*_summary` duplicates (or vice versa), one name each.
- **Tradeoff:** Anyone already depending on a dropped alias breaks, but the
  package is unreleased (0.99.0), so there is no installed base to protect.

#### S2. Remove the `verify_md5` deprecation shim

- **Priority:** should improve
- **Affected:** `encode_download()`
- **Why it matters:** Shipping a _deprecated_ argument in a package's first
  release is contradictory: there is no prior version that used it, so there is
  nothing to be backward-compatible with. It is pure surface area.
- **Suggested behavior:** Delete `verify_md5`; keep only `verify = c("md5",
"size")`. Document the vector form clearly.
- **Tradeoff:** None pre-release.

#### S3. Assay-aware presets plus a printed selection decision report

- **Priority:** should improve
- **Affected:** `encode_select_files()`, `encode_file_preset()`
- **Why it matters:** "peaks" means different files for TF ChIP-seq vs ATAC-seq
  vs histone ChIP-seq. Named, assay-specific presets remove guesswork and pair
  naturally with M3.
- **Suggested API:** add presets such as `chipseq_peaks`, `chipseq_signal`,
  `atacseq_peaks`, `rnaseq_gene_quant`, `rnaseq_transcript_quant`, alongside the
  existing broad categories. Have `encode_select_files()` print a compact report:
  N kept, and N excluded broken out by reason (wrong assembly, wrong status,
  missing href, lower-priority output type, not preferred_default, replicate
  policy). You already compute the exclusion table; this is a print method over
  it.
- **Tradeoff:** More presets to maintain as ENCODE output-type vocabulary
  evolves. Keep the mapping in one small, data-driven table so it is auditable.

#### S4. Fill stub man descriptions and expand the vignette

- **Priority:** should improve
- **Affected:** several `.Rd` files; `vignettes/encodeUtils.Rmd`
- **Why it matters:** `encode_file_preset`, `encode_facets`, `encode_filters`,
  and `encode_file_summary` have `\description{}` identical to the title.
  Bioconductor reviewers read these. The vignette never shows the selection,
  matrix, or read steps that justify the package.
- **Suggested behavior:** One real sentence of description per function. Add
  vignette sections for `encode_matrix()`, a multi-file `encode_select_files()`
  run that shows the exclusion log, and an `encode_read()` example including a
  refusal. Keep it mock-driven so it still builds offline.
- **Tradeoff:** Slightly longer vignette build; negligible.

#### S5. Close the specific test gaps

- **Priority:** should improve
- **Affected:** test suite
- **Why it matters:** The gaps map onto the real failure modes.
- **Suggested additions:** (a) a 429 response that retries then fails clearly, to
  match the workflow doc's rate-limit handling; (b) a malformed `matrix.y`
  fixture that asserts a clear error and preserved raw response; (c)
  multi-experiment `encode_list_files()` to exercise batching and throttling; (d)
  an object-frame search fixture (paths, not titles) asserting how lab/organism/
  biosample columns resolve; (e) a real `encode_read()` BED/narrowPeak path via
  `rtracklayer` when installed, not only the refusals; (f) print-method snapshot
  tests so console output stays stable; (g) `encode_get()` on an archived
  accession returning the object regardless of the `released` default.
- **Tradeoff:** More fixtures to maintain; worth it for schema-drift safety.

#### S6. Record provenance unconditionally in the manifest

- **Priority:** should improve
- **Affected:** `encode_manifest()`
- **Why it matters:** Package version and retrieval timestamp are the cheapest,
  highest-value reproducibility fields and should never depend on
  `include_session = TRUE`.
- **Suggested behavior:** Always write `package$name`, `package$version`, an ISO
  timestamp, and the ENCODE query URL(s). Let `include_session` gate only the
  heavier `sessionInfo()` block.
- **Tradeoff:** None.

#### S7. Make the Bioconductor commitment explicit and consistent

- **Priority:** should improve
- **Affected:** `DESCRIPTION`, caching, checks
- **Why it matters:** Half-committing invites contradictory guidance. You are
  already 90% Bioc.
- **Suggested behavior:** Keep `tools::R_user_dir()` caching as the lean default;
  treat `BiocFileCache` as an optional integration, not a hard dependency, unless
  a concrete workflow demands it. Confirm `R (>= 4.6.0)` matches current Bioc
  devel. Budget time to clear `BiocCheck` notes (function length, indentation,
  `importFrom` specificity). Add a `CITATION` file.
- **Tradeoff:** Bioconductor's release cadence and review are heavier than CRAN,
  but the domain fit and the download-cache model make it the right home.

### NICE LATER

#### N1. `encode_replicates()` and paired-end FASTQ pairing

- **Priority:** nice later
- **Affected:** new helper over `encode_list_files()`
- **Why it matters:** Replicate structure and `paired_with` relationships are
  where users most often pick the wrong files. A helper that returns one row per
  biological/technical replicate with paired R1/R2 grouped is high utility.
- **Suggested API:** `encode_replicates(files)` returning a tidy replicate table;
  optionally a `pair_fastq = TRUE` mode that groups `paired_end` 1/2 via
  `paired_with`.
- **Tradeoff:** Adds selection surface; keep it read-only and descriptive.

#### N2. ENCODE-native `files.txt` / `metadata.tsv` bridge

- **Priority:** nice later
- **Affected:** new helper; complements `encode_manifest()`
- **Why it matters:** Many ENCODE users already work from the portal's batch
  `files.txt` + `metadata.tsv`. Ingesting or emitting that format lets people
  move between the website's cart flow and your package without re-querying.
- **Suggested API:** `encode_read_manifest("files.txt")` to ingest,
  and an option on `encode_write_manifest()` to also emit an ENCODE-style
  `metadata.tsv`.
- **Tradeoff:** The portal format can change; isolate the parser and test it
  against a recorded fixture.

#### N3. Analysis-level pinning in selection

- **Priority:** nice later
- **Affected:** `encode_select_files()`
- **Why it matters:** Selecting "optimal IDR thresholded peaks" without pinning
  the analysis can mix files from different processing runs. Pinning to the
  default analysis (or a named one) makes selections fully reproducible.
- **Suggested API:** `encode_select_files(files, analysis = "default")`.
- **Tradeoff:** Requires modeling ENCODE's analysis objects; only worth it after
  M3 lands.

#### N4. Recorded real HTTP fixtures for schema-drift resilience

- **Priority:** nice later
- **Affected:** tests
- **Why it matters:** Mocks prove your parser handles the shapes you imagined;
  recorded real responses prove it handles the shapes ENCODE actually returns,
  and catch drift when they re-record.
- **Tradeoff:** Larger test assets; refresh periodically.

---

## Explicitly do NOT build yet

Your existing exclusion list is correct; keep all of it out of scope: consensus
or de novo peak calling, a SQLite/local mirror of ENCODE, a Shiny GUI, private
auth or credentialed access, any POST/PATCH/submission path, and automatic
FASTQ/BAM processing. Add three more to that list:

- **`encode_load_data()` mega-wrapper** that fuses search, download, and read.
  It hides exactly the deliberate, auditable steps that make this package safe.
  If you ever add it, make it a thin, loudly-logged convenience over the stable
  pieces, not a shortcut around them.
- **Audit interpretation.** Surface ENCODE audit strings (you already do), but do
  not translate them into pass/fail verdicts. Judging whether a "low read depth"
  audit disqualifies a file is a scientific decision that depends on the user's
  question, and getting it wrong silently is worse than showing the raw audit.
- **A heavy interactive TUI.** The thin base-R `encode_browse()` selector is the
  right ceiling. A full pager/fuzzy-finder adds dependencies and maintenance for
  marginal benefit over piping search results into standard R tools.

---

## One-paragraph summary

The architecture is sound and the instincts are right: metadata-first, explicit
downloads, conservative reads, and real provenance. The package is closer to
"polished" than most first-pass API wrappers. The work that remains is
subtractive as much as additive: cut the alias sprawl and duplicated matrix
fields, remove the pre-release deprecation shim, and resolve the naming hedges.
The additive work worth doing is narrow and high-value: confirm the two missing
man pages, verify that the default object frame actually populates the compact
table, and teach file selection about `preferred_default`. Do those, tidy the
vignette and the handful of test gaps, and commit fully to Bioconductor.
