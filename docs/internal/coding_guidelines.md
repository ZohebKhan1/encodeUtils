# R Bioinformatics Coding Guidelines

Purpose: one consolidated guide for LLM agents writing, editing, or reviewing R
bioinformatics code. The goal is clean, readable, reproducible, human-auditable
code that a skeptical bioinformatics reviewer can understand without guessing.

Core principle: write R as a careful senior bioinformatician would: direct,
logical, statistically defensible, and easy to maintain.

## 0. How Agents Should Use This Guide

Use this file as the global R/bioinformatics coding guide. A project `AGENTS.md`
should stay project-specific and point here for reusable coding policy. Explicit
project instructions override this guide only where they are more specific.

Before making R/bioinformatics changes:

1. Read the project `AGENTS.md` and the relevant script, helper, object schema,
   workbook, figure, or markdown file completely.
2. Inspect existing project conventions before inventing names, folders,
   contrasts, thresholds, factor levels, output paths, or helper APIs.
3. Use the project-local `tools/r_codex_utils` runner for non-trivial R work.

The runner verifies work; it does not replace judgment. Biological parameters,
statistical choices, output locations, and script structure must still follow
this guide and the project conventions.

Do not use raw `Rscript`, `Rscript -e`, or `Rscript -` for non-trivial project
work unless the user explicitly asks for it or the task is a truly trivial
one-line environment check. Use:

- `tools/r_codex_utils preflight`: verify project setup, R environment, runner
  version, manifest, package requirements, contexts, and target-file hygiene.
  If `CANONICAL_RUNNER_STATUS` is `installed_copy_stale`, update from the
  canonical runner before editing project R code. Project-local runners should
  normally be installer-created shims, not copied helper implementations.
- `tools/r_codex_utils check path/to/script.R`: preflight scan, parse check,
  conservative `styler` spacing/indentation formatting that preserves deliberate
  line breaks, and parse check again.
- `tools/r_codex_utils check path/to/report.Rmd`: for `.Rmd`/`.qmd` documents,
  preflight scan, extract R chunks with `knitr`, parse-check the extracted code,
  and skip styling.
- `tools/r_codex_utils script path/to/script.R`: run maintained scripts. Add
  `--expect-output path/to/output` when the script should create or update a
  file artifact.
- `tools/r_codex_utils render TARGET --expect-output path/to/output`: render
  `.Rmd`, `.qmd`, bookdown, or Quarto projects and verify intended outputs.
- `tools/r_codex_utils chunk --show-stdout --stdout-tail 120 -`: run chat-only
  diagnostics or one-off calculations without adding scratch files.
- `tools/r_codex_utils contexts` and `tools/r_codex_utils objects`: discover
  source-data loaders and inspect object schemas, DEG keys, and list keys.
- `tools/r_codex_utils jobs`, `logs last`, and `logs failures`: inspect slow jobs
  and debug failures from compact summaries plus complete raw logs.

Before running both a maintained script and a document render, check whether the
render setup sources the same full analysis. If it does, use render as the
execution test and run the script separately only to isolate a failure. Inspect
prior elapsed times, heartbeats, or logs before repeating expensive DESeq2,
GO/GSEA, or bookdown/Quarto jobs.

`CONTEXTS_DISCOVERED: 0` is not automatically a problem in small/tutorial
projects with explicit RDS/CSV inputs. Inspect those declared inputs with
`chunk` rather than inventing a loader.

For detailed command examples, use
`/home/zoheb/github_projects/00_bioinformatics_rules/r_codex_utils/r_codex_utils.md`
or the installed Codex skill command map.

## 1. Non-Negotiable Rules

- Read supplied files completely before making claims or edits. Do not skim only
  the first section or infer content from memory when the file is available.
- Use relative project paths only. Do not use absolute `/home/zoheb/...`,
  `/mnt/c/...`, or `C:/...` paths inside project code.
- Do not call `setwd()`. The `.Rproj` defines the project root; create one if a
  project lacks it.
- Do not rely on invisible workspace state, `.RData`, or objects from an
  interactive session. Scripts must run from declared inputs.
- Do not fabricate DESeq2 designs, contrasts, reference levels, ranking metrics,
  thresholds, factor levels, filtering rules, or other analytical decisions.
- Ask or inspect conventions before choosing biological/statistical parameters.
- Use canonical source-data loaders and canonical objects when they exist. Do not
  regenerate VST, DDS, TPM, metadata, count matrices, or DEG objects unless the
  user requests regeneration or the object is demonstrably wrong.
- Never create placeholder data, mock columns, fake metadata, guessed factor
  levels, fallback objects, or columns "just in case."
- Do not save extra CSV, RDS, RData, TSV, XLSX, JSON, plot-data, metadata,
  provenance, parameter, or intermediate files unless the user explicitly asks.
- Do not save RDS files in `results/`; downstream result files in `results/`
  must be CSV only.
- Do not save downstream analysis results to `data/`; `data/` is for critical
  upstream reusable inputs.
- Do not convert gene symbols to Ensembl, Entrez, or any other identifier type
  without explicit user permission.
- Do not create `_v2`, `_v3`, `_final`, `_fixed`, `_cleaned`, `_new`, or similar
  filename variants. Edit the stable file; Git tracks history.
- Do not rename outputs for cosmetic edits. Overwrite the stable output path when
  the analytical identity is unchanged.
- Do not wipe entire output directories with broad `unlink()`, `file.remove()`,
  `clear_dir()`, or similar cleanup logic unless the user explicitly requests it.
- Do not define utilities already present in `src/`, call private helper
  functions from top-level scripts, or scatter local functions through a script.
- Do not post-process SVG files with string replacement. Fix the plot object,
  `ggsave()` call, plotting helper, or shared save helper.
- Do not use broad regex substitutions to namespace or rewrite R code. Make
  targeted edits and run `parse` or `check` after small batches.
- During review-only work, use `preflight` or `parse` before `check` when broad
  formatting diffs would obscure the behavioral change.
- After editing R scripts, run `tools/r_codex_utils check path/to/script.R`.
  When behavior must be validated, execute maintained scripts with
  `tools/r_codex_utils script`. If the script writes artifacts, verify them with
  `--expect-output`; if it is a sourced helper, validation script, or
  object-building script with no file output, run without `--expect-output` and
  report that no artifact was expected.
- After editing `.Rmd`/`.qmd`, run `tools/r_codex_utils check path/to/report.Rmd`
  for chunk syntax. Use `tools/r_codex_utils render ... --expect-output ...`
  when the document artifact must be regenerated or inline R syntax must be
  validated.

## 2. Script Structure

Every new script must be complete and immediately executable. Do not deliver
fragments, snippets, placeholders, or code containing `...`.

Use this order unless the project has a clear reason not to:

1. Header comment block
2. Source packages, utilities, and data
3. Define parameters and paths
4. Define local helper functions, if needed
5. Main analysis
6. Create figures and tables
7. Save outputs
8. End-of-script summary

### 2.1 Header Block

Every script begins with a concise R-comment header:

```r
# Created:
# 2026-05-23
#
# Inputs:
# - src/packages.R: project package loader
# - scripts/LS1/source_data_LS1.R: loads canonical ls1 objects
# - ls1_tpm: tpm matrix from the source-data loader
# - ls1_metadata: metadata from the source-data loader
#
# Outputs:
# - figures/LS1/example_analysis/LS1_example_plot.svg
#
# Purpose:
# Calculate sample-level mean expression and save a summary figure.
#
# Notes:
# Loads canonical objects, checks sample alignment, creates one svg figure, and
# does not regenerate counts, metadata, dds, tpm, vst, or deg objects.
```

Inputs means every data file, data frame, matrix, list, object, or sourced object
the script uses directly. If a source-data script loads many objects, list the
source-data script once and list only the key objects needed for auditability.

The header should tell a future reader what the script needs, what it creates,
what analytical work it performs, and any important maintenance notes.

### 2.2 Section Headers

Use clear numbered section headers. Header text should be lowercase and
professionally worded. Natural separators such as `/` are fine when they improve
readability.

```r
# 0.0 source packages / data -----------------
# 1.0 define parameters -----------------
# 1.1 define contrasts / gene sets -----------------
# 1.2 define local helper functions, if needed -----------------
# 2.0 run analysis -----------------
# 3.0 create figures and tables -----------------
# 4.0 save outputs -----------------
# 5.0 end-of-script summary -----------------
```

Keep dashed lines moderate in length. Do not make decorative banners.

## 3. Project Layout, Paths, and Outputs

Use the existing project convention when one is clear. Otherwise use this layout:

```text
PROJECT_ROOT/
  PROJECT.Rproj
  .Rprofile
  src/
    packages.R
    utilities.R
    plot/ enrichment/ scoring/
  scripts/{EXPERIMENT_ID}/
  data/{EXPERIMENT_ID}/
    nf-core/ counts/ degs/
  results/{EXPERIMENT_ID}/
  figures/{EXPERIMENT_ID}/{analysis_subfolder}/
```

Use the experiment ID consistently in script names, data folders, result folders,
figure folders, and saved output names.

### 3.1 Folder Boundaries

Project files must go to the correct top-level folder unless the user explicitly
requests a different location: scripts and report source files in
`scripts/{EXPERIMENT_ID}/`; figures in
`figures/{EXPERIMENT_ID}/{analysis_subfolder}/`; critical upstream reusable data
in `data/{EXPERIMENT_ID}/`; explicitly requested downstream result tables in
`results/{EXPERIMENT_ID}/`; and explicitly requested publication-facing
workbooks in `manuscript_tables/`.

Do not put scripts in `results/`, figures in `results/`, figures in `data/`,
downstream result tables in `data/`, or reusable upstream data in `results/`.

`data/` is for reusable upstream project data: raw/cleaned metadata, raw and
filtered counts, normalized expression matrices, TPM, VST, TMM-normalized CPM,
DESeq2 normalized counts, DESeq2 `dds` objects, gene maps, and
filtered/unfiltered DEG tables. DEG tables are downstream statistically, but
upstream operationally because many later analyses depend on them.

`results/` is for downstream final analysis tables: GO/GSEA enrichment, module
scores, pathway scores, overlap summaries, correlation summaries, and similar
CSV outputs. Do not include helper-return objects, model objects, list columns,
provenance files, parameter dumps, contrast bookkeeping, duplicate CSV/RDS pairs,
or intermediate objects.

### 3.2 Output Folder Depth

Output folders should be shallow, predictable, and analysis-oriented.

Default to `figures/{EXPERIMENT_ID}/{analysis_type}/` and
`results/{EXPERIMENT_ID}/{analysis_type}/`. Use one additional subfolder only
when it materially improves navigation, usually for analyses that produce many
outputs across multiple contrasts or gene sets, such as
`figures/ZRN01/gsea/Tri21_vs_Di21/`.

Do not create unnecessary subfolders for simple analyses such as PCA, volcano
plots, scatterplots, lineplots, heatmaps, or barplots. Encode subgroup, lineage,
condition, method, or contrast in the filename when that is sufficient, for
example `figures/ZRN01/pca/ZRN01_pca_em.svg` rather than
`figures/ZRN01/pca/EM/ZRN01_pca.svg`.

### 3.3 Temporary Analyses

Use `tmp/` only when the user explicitly says the analysis is temporary,
exploratory, or only meant to test something.

For temporary analyses, keep all scripts and outputs inside `tmp/`: scripts in
`tmp/scripts/`, figures in `tmp/figures/`, and temporary results, tables, logs,
or serialized objects under `tmp/`. Do not write temporary-analysis files to
`scripts/`, `figures/`, `results/`, `data/`, or the project root.

Active scripts must follow the script naming and order conventions and live in
`scripts/{EXPERIMENT_ID}/`. Deprecated scripts may live in a clearly labeled
`deprecated/` folder but must not be sourced by active scripts. Exploratory
scripts belong in `tmp/scripts/`.

### 3.4 Output Declaration, Stability, and Cleanup

Every saved output must have a path declared in parameters and listed in the
header. Avoid surprise files created inside loops or helpers. Create output
directories explicitly before saving:

```r
base::dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)
```

Use stable, descriptive output filenames without version suffixes. If the output
has the same analytical identity, overwrite the same stable path.

Rename an output only when it represents a genuinely different analysis,
contrast, dataset, method, normalization, gene set, threshold, transformed axis,
or other methodologically meaningful parameter. Do not rename for cosmetic edits,
label wording, axis styling, color changes, export settings, or layout tweaks.

When a script changes an output filename, folder, extension, or analytical
identity, check for stale SVG, CSV, RDS, XLSX, JSON, and other old outputs from
the same script. Remove stale files only when they are clearly superseded,
unreferenced, not a distinct older analysis, and not user-curated. If ambiguous,
report the candidates and ask.

Do not create `test.R`, `scratch.R`, `tmp.csv`, `debug.rds`, or similar files in
the project. Use `tools/r_codex_utils chunk`, an interactive scratch session, or
`tempdir()` unless the user explicitly requests a temporary project artifact.

## 4. Naming Rules

### 4.1 Script Names

Use `NN_analysis[_scope_or_contrast][_EXPERIMENTID].R`. `NN` is a two-digit
order prefix; the main name should be short and analysis-first. Include the
experiment ID when the folder does not already make scope clear or when multiple
experiments are involved.

Prefer concise tokens: `source_data`, `metadata`, `counts`, `degs`, `pca`,
`volcano`, `gsea`, `go`, `heatmap`, `lineplot`, `barplot`, `scatter`. Examples:
`01_source_data_DSHC1.R`, `03_pca_DSHC1.R`, `05_gsea_Tri21vDi21.R`.

Before creating a script, inspect `scripts/{EXPERIMENT_ID}/` and choose the next
logical number. Do not renumber existing scripts unless requested. Use one
consistent preprocessing/source-data style within the project, such as
`00_source_data_EXPERIMENT.R`, `01_metadata_EXPERIMENT.R`,
`02_counts_EXPERIMENT.R`, and `03_degs_EXPERIMENT.R`.

### 4.2 Figure Names

Figure file names must be descriptive, stable, and begin with the experiment ID.
Use `{EXPERIMENT_ID}_{plot_type_or_analysis_type}_{scope}[_{qualifier}].{ext}`,
for example `LS1_volcano_Tri21ctrlD7vDi21ctrlD7_sarcomere.svg` or
`DSHC1_gsea_Tri21ctrlvDi21ctrl_sarcomere.svg`.

The second token should describe the plot or analysis type (`barplot`,
`scatter`, `volcano`, `dotplot`, `lineplot`, `gsea`, `heatmap`, `pca`). Remaining
tokens should make the biological or analytical scope clear. Include method,
parameter, normalization, subset, lineage, or contrast labels only when they
change the analytical identity. Do not force a rigid template when a clearer
descriptive name is needed.

### 4.3 Upstream Data Names

Files saved under `data/{EXPERIMENT_ID}/` must be critical upstream reusable
files and should begin with the experiment ID.

Use `{EXPERIMENT_ID}_{data_type}[_{scope_or_normalization}][_{filter_state}].{ext}`.
Stable data-type tokens include `metadata`, `raw_counts`, `filtered_counts`,
`tpm`, `vst`, `deseq2_normalized_counts`, `tmm_cpm`, `dds`,
`gene_id_to_name`, and `degs`.

Good examples: `DSHC1_metadata.rds`, `DSHC1_tpm.rds`,
`DSHC1_gene_id_to_name.rds`, `DSHC1_degs_Tri21ctrlD7vDi21ctrlD7_filtered.csv`.
Avoid ambiguous names such as `results.rds`, `output.csv`,
`data_cleaned_final.rds`, `contrast_table.rds`, or `all_objects.rds`.

### 4.4 Downstream Result Names

Files saved under `results/{EXPERIMENT_ID}/` are downstream analysis tables and
must be CSV files only.

Use `{EXPERIMENT_ID}_{analysis_type}_{scope}[_{direction_or_qualifier}].csv`.
The second token should describe the downstream analysis type, such as `go`,
`gsea`, `enrichment`, `modulescore`, `pathwayscore`, `overlap`, `correlation`,
or `summary`. Examples: `LS1_go_Tri21ctrlD7vDi21ctrlD7_up.csv`,
`DSHC1_gsea_Tri21ctrlvDi21ctrl_sarcomere.csv`,
`DSHC1_ZRN01_correlation_lambert_tf_tpm_rank.csv`.

If a downstream analysis truly requires a serialized R object, ask the user where
it belongs; do not silently write an RDS file to `results/`.

### 4.5 Object Names

Use lowercase `snake_case` for variables, such as `metadata_ae3`,
`filtered_go_results`, `ranked_gene_table`, and `module_score_results`. Avoid
mixed case when possible, and use names that describe the biological object or
computational role. Avoid vague names such as `data`, `df2`, `tmp`, `thing`,
`x`, `final`, or `new` unless the scope is tiny and obvious.

Use suffixes consistently: DESeq2 datasets `_dds`; metadata `_metadata` or
`_meta`; count matrices `_counts` or `_matrix`; results tables `_results`, `_res`,
or `_degs`; collections as plurals such as `gene_sets` or `results_list`.

### 4.6 Function Names

Use lowercase `snake_case` for functions. Function names should start with a
short accurate verb followed by the object or biological target, such as
`plot_volcano()`, `calculate_enrichment()`, or `filter_sig_degs()`.

Avoid vague names such as `process_data()`, `do_analysis()`, or `make_plot()`
when a more specific verb-first `{action}_{object}` name is available.

## 5. Packages, Data Sourcing, and Canonical Objects

Package loading should be centralized near the top of each script:

```r
base::source('src/packages.R')
```

Do not scatter `library()` calls throughout analysis scripts unless there is a
specific project reason.

Source project functions near the start in a consistent source section. Reusable
helpers belong in `src/`, such as `src/utilities.R`, `src/plot/`,
`src/enrichment/`, or `src/scoring/`.

For bulk RNA-seq experiments, data should usually be loaded through one canonical
experiment-specific source-data script that centralizes metadata, counts,
normalized expression matrices, DESeq2 objects, DEGs, gene maps, and other
critical reusable objects.

Example pattern:

```r
base::source('scripts/{experiment_id}/source_data_{experiment_id}.R')
```

This is an example pattern, not a required literal path.

Source-data scripts must use relative project paths only. Do not manually define
paths to many individual DEG spreadsheets, count files, or metadata files across
multiple analysis scripts when a source-data script can centralize them.

Use canonical source-data loaders when they provide the needed objects. Do not
replace them with ad hoc `readRDS()`, `read.csv()`, or package setup just because
it is faster to write.

Manual loading is acceptable when the object is not loaded by the source-data
script, the script intentionally needs one specific dataset, the file is a
public/external dataset, the file belongs to a different experiment, or there is
a clear project-specific reason not to add it to the source-data loader. In
those cases, declare the path in parameters, list it in the header inputs, and
keep the loading code explicit and auditable.

Before regenerating a canonical object, check whether it already exists, which
script created it, what parameters were used, whether downstream scripts depend
on it, and whether the user requested regeneration.

DEG tables are the main output exception: filtered and unfiltered DEG outputs are
canonical reusable project data and belong in `data/{EXPERIMENT_ID}/degs/` when
the user has requested DEG generation or regeneration. Save only the result
tables that are actually needed; do not automatically save contrast
specification objects, design bookkeeping, filtered/unfiltered list objects,
summary objects, or redundant CSV/RDS pairs.

## 6. Parameters and Statistical Decisions

All important paths, thresholds, factor levels, contrasts, colors, analysis
settings, and subjective choices belong in a dedicated parameters section near
the top. Do not hide important parameters inside loops or helpers.

Use `=` only for top-level scalar parameter definitions in the parameters section
and for function arguments:

```r
database = 'GO'
seed = 30238
padj_cutoff = 0.05
log2fc_cutoff = 0.5
```

Ask or inspect project conventions before choosing DESeq2 design formulas,
contrast definitions, grouped factors, reference levels, p-value thresholds,
log2FC thresholds, GSEA ranking metrics, filtering cutoffs, batch correction
models, PCA feature-selection rules, normalization choices, or LFC shrinkage.

If a user request requires one of these choices and the project does not already
define it, present the available options with pros, cons, and tradeoffs; proceed
only after the user confirms. Do not switch between shrunken and unshrunken
results silently.

Specific defaults and constraints:

- PCA: use `scale = FALSE` unless the user explicitly requests scaling.
- Factor levels: set levels in biologically meaningful order before plotting,
  modeling, or extracting contrasts; do not guess unclear biological order.
- GSEA ranking: do not choose a ranking method by default when the user has not
  specified one and no project convention exists. Ask whether to use a statistic,
  signed transformed p-value, log2 fold change, or another project-specific
  metric.
- Specialized packages: consult documentation when uncertain about DESeq2,
  edgeR, limma, clusterProfiler, fgsea, ComplexHeatmap, or similar parameters.
- Gene identifiers: default gene-keyed objects to gene symbols in HGNC symbol
  formatting. Be explicit about each object identifier space and check that IDs
  match before joining, merging, or subsetting.
- ID conversion: convert to Ensembl, Entrez, or another identifier type only with
  explicit permission. Report duplicated and unmapped IDs rather than dropping
  them silently. Many-to-one, one-to-many, and unmapped IDs are common silent
  error sources.

When joining, merging, or subsetting by sample or gene ID, assert that no
unexpected rows are lost in the same `stopifnot()` style used in Section 10.

## 7. Functions and Code Architecture

Caller scripts should source packages/functions/data, define explicit
parameters, select experiment-specific inputs, call well-named helpers, save
requested outputs, and print compact summaries.

Caller scripts should not implement reusable plotting, loading, statistical,
saving, or formatting behavior. Before writing a new PCA, volcano plot, GSEA, GO
enrichment, TPM lineplot, heatmap, or other common analysis/plot type, inspect an
existing project script or helper of the same type and follow the established
pattern unless there is a clear reason to change it.

Before manually writing repeated analysis, plotting, loading, formatting, or
filtering code, inspect existing project utilities. Reuse user-created functions
when they already solve the problem. Redefining an existing helper is a
maintainability failure.

If the same operation is being rewritten across multiple scripts, especially with
small variations, treat that as a project-maintenance issue. The preferred
long-term solution is usually a well-named, generalizable helper in `src/`.

Do not create or modify a shared function casually. First confirm that the
repeated pattern is real, a reusable function would reduce maintenance burden,
and an equivalent helper does not already exist. Ask the user before adding or
modifying a shared project function.

Use caller scripts for experiment-specific choices: experiment ID, contrast, gene
set, data objects, lineage, treatment, timepoints, group labels, color mapping,
output path, figure dimensions, and selected genes.

Use shared helpers for general behavior: SVG cleanup, transparent-background
handling, generic p-value formatting, generic panel sizing, and reusable GO, DEG,
GSEA, volcano, scatter, or lineplot wrappers.

If a visual, formatting, or behavioral change should apply broadly across
experiments, update the shared helper default rather than adding repeated
caller-side overrides. Do not add a caller argument that exactly matches the
current helper default; after changing a helper default, review callers and
remove overrides that now match the default.

Local helper functions are acceptable only when they are short, specific to the
current script, and not a general plotting, loading, statistical, saving, or
formatting operation. Group local helpers together in the local helper section.

Do not call helper-internal or private functions from top-level scripts.
Dot-prefixed functions such as `.gsea_create_ranked_list()` or
`.concordance_fit_line()` are implementation details. If a caller needs
information only available from a private helper, ask whether to expose it
through the public helper return object or a documented shared helper.

Do not force code into a function just because it is possible. A function is
useful when it improves clarity, prevents a real error source, or captures
genuinely reusable logic. Avoid wrapper layers, generic frameworks, excessive
helpers, or complicated parameter systems unless they solve a real project
problem.

## 8. Code Formatting

Always namespace function calls with `package::function()`, including base R and
functions from `utils`, `stats`, and `grDevices`, for example
`base::mean()`, `stats::p.adjust()`, `dplyr::filter()`, and
`ggplot2::ggplot()`. Do not guess package ownership. Verify when uncertain.

Use `<-` for object creation, column reassignment, and assigning function-call
results. Use `=` only for top-level scalar parameters and function arguments.

```r
calculate_score <- function(expression_matrix, gene_set) {
  module_score <- base::colMeans(expression_matrix[gene_set, , drop = FALSE])
  module_score
}

database = 'GO'

base::set.seed(seed = seed)
```

Use single quotes for strings by default:

```r
marker_genes <- base::c('GLI1', 'PTCH1', 'PTCH2')
```

Use double quotes only when the string contains a single quote or another tool
requires them.

Use `%>%` for pipes. Do not use the base pipe `|>`. Put `%>%` at the end of the
line and continue the next step on the next line. Break pipelines at logical
steps; do not create long, hard-to-debug chains.

There is no hard character limit. Lines beyond roughly 140 characters are a
signal to consider wrapping, but do not split a clean single call just to hit a
number. Keep simple single-argument file reads and writes on one line when they
fit comfortably. Use one pipe step per line, one ggplot2 layer per line, and one
argument per line for long calls.

```r
tidyr::pivot_longer(
  cols = dplyr::all_of(tp_names),
  names_to = 'timepoint',
  values_to = 'value'
)
```

Do not put spaces immediately inside parentheses. Always put one space after
commas. Surround most infix operators with spaces, as in
`score <- mean_expression - baseline_expression` and `padj < 0.05`. Do not add
spaces around namespace, extraction, or slot operators, as in `dplyr::filter()`,
`metadata$genotype`, `metadata[['sample_id']]`, and `object@metadata`.

Comments should explain why a choice was made, document a non-obvious biological
or statistical decision, or warn about code that was tricky to get right. They
should not duplicate the code, excuse unclear code, or leave commented-out code
in final scripts. Keep comments direct, current, lowercase, and wrapped near 80
characters.

```r
# use D0 as the reference because each contrast tests developmental change
# after plating
metadata$timepoint <- stats::relevel(metadata$timepoint, ref = 'D0')
```

In ggplot2 code, place `+` at the end of the line and continue the next layer on
the next line.

Do not call `options()` or `par()` to change global R settings. Set behavior
locally through function arguments or plot objects.

## 9. Bioconductor and S4 Objects

Use accessors for S4 objects such as `DESeqDataSet`, `SummarizedExperiment`,
`SingleCellExperiment`, and `GRanges`.

```r
SummarizedExperiment::colData(dds)
DESeq2::counts(dds, normalized = TRUE)
DESeq2::results(dds, contrast = base::c('condition', 'A', 'B'))
```

Avoid direct slot access unless there is a specialized reason.

Do not use dplyr verbs directly on S4 objects. Convert metadata to a data frame
when needed, or use the appropriate accessor.

Prefer established Bioconductor classes and infrastructure when they fit the
problem. Do not invent ad hoc structures when common Bioconductor objects already
express the biology.

## 10. Console Output, Defensive Checks, and Reporting

Print useful results as plain objects at the end of the script:

```r
n_sig
summary_table
utils::head(top_results)
output_paths
```

Avoid unnecessary `cat()` wrappers when printing an object is enough. Do not
print ASCII banners, separator lines, progress art, verbose status messages, full
count matrices, full DESeq2 results, large objects, or noisy loop-by-loop logs.

Use `stopifnot()` at key workflow boundaries where silent mismatches would
invalidate results, especially after loading, filtering, joining, reordering, or
subsetting samples/genes.

```r
base::stopifnot(base::identical(base::colnames(vst_matrix), base::rownames(metadata)))
base::stopifnot(base::all(module_genes_present %in% base::rownames(vst_matrix)))
base::stopifnot(!base::any(base::duplicated(metadata$sample_id)))
```

Avoid low-value checks such as `base::is.data.frame(metadata)`,
`base::length(experiment_id) == 1`, `base::file.exists(figure_dir)`, or
`base::nrow(results_df) >= 0` when they do not guard against a real analysis
error. Sample and gene alignment errors are dangerous; always check alignment
when combining counts, TPM, VST, metadata, coordinates, scores, annotations, or
gene sets by ID.

Do not wrap analysis blocks in `tryCatch()` to hide errors. Let failures surface
so the root cause can be fixed. `tryCatch()` is acceptable only in batch loops
over many contrasts or gene sets that collect failures and report all of them at
the end.

When revising an existing script, edit only what needs to change. Preserve
existing functionality. Do not rename objects, change outputs, alter factor
levels, change thresholds, reorganize folders, or change analysis decisions
unless requested. If asked to fix a bug, fix the bug; report adjacent issues
separately.

If a script fails, read the error, identify the cause, change the code, and
rerun. Do not rerun unchanged failing code.

When finished, report what was produced, whether execution succeeded, where
outputs were written, and any relevant findings from the run.

## 11. Plotting, SVG, and Illustrator-Friendly Figures

R figures should normally be exported as SVG. All ggplot2 SVG figures must be
saved with:

```r
ggplot2::ggsave(
  filename = figure_path,
  plot = plot_obj,
  device = svglite::svglite,
  bg = 'transparent',
  fix_text_size = FALSE
)
```

Set `fix_text_size = FALSE` so text stays freely editable in Illustrator and
Inkscape. The svglite default (`TRUE`) pins each text element's width using the
SVG `textLength` attribute, which causes remaining text to stretch or compress
when edited by hand.

Use `svglite::svglite` because it produces clean SVGs and preserves text as
editable text elements. Use transparent backgrounds unless the user explicitly
requests otherwise. Specify `family = 'Nimbus Sans'` consistently in plot themes
and text layers when applicable. The named font must be installed and resolvable;
otherwise systemfonts silently substitutes a fallback.

For grouped plots, boxplots, bar plots, points, and other geoms, layers must sit
at the exact x-axis value for their group or category. Use
`position = ggplot2::position_identity()` unless the user explicitly requests
jittering or dodging. Overlapping points are acceptable. Always overlay
individual data points when displaying group-level summaries such as boxplots or
bar plots.

Text, axes, and legends:

- For `ggrepel`, specify `family = 'Nimbus Sans'`; use sensible `size`,
  `max.overlaps`, and `box.padding`; label only relevant features.
- For ComplexHeatmap, specify `fontfamily = 'Nimbus Sans'` inside every
  `grid::gpar()` for row names, column names, titles, and labels.
- Use `legend.key.size = grid::unit(0.25, 'cm')` unless the figure requires a
  different size.
- Display timepoints as plain numbers (`4`, `5`, `6`), not labels such as
  `'Day 4'`; rotate long or numerous x-axis labels with
  `angle = 45, hjust = 1`.
- For y-axes starting at zero, use
  `ggplot2::expansion(mult = c(0, 0.05))`; set explicit breaks when appropriate.

For scatterplots, volcano plots, MA plots, and other dense gene-level figures
with many points, rasterize only dense background or nonimportant point layers
when possible. Use `dpi = 600` for rasterized layers. Keep highlighted genes,
labeled genes, reference lines, axes, legends, annotations, and biologically
important elements as editable vector objects. Do not rasterize the full figure
just to reduce file size unless the user explicitly asks for that tradeoff.

Figure paths must be declared in parameters and listed in the header outputs.
Temporary figures belong in `tmp/figures/`.

Only save plot data when needed for manuscript source data, downstream review, or
reproducibility and the user explicitly asks for it. If plot data is saved,
document it in the header and parameters.

Do not create sidecar metadata/provenance files for figures, including
`.svg.meta.json` files. A figure save call should save the figure itself unless
the user explicitly requests additional metadata files.
