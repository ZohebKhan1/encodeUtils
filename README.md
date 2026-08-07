# encodeUtils

[![R-CMD-check](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml)
[![test coverage](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml)
[![R >= 4.6.0](https://img.shields.io/badge/R-%E2%89%A5%204.6.0-276DC3?logo=r)](https://www.r-project.org/)

The ENCODE Portal is a public database of experiments, biosamples, files, and
associated metadata produced by the ENCODE Project.

`encodeUtils` searches ENCODE metadata, selects and verifies ENCODE-related
datasets and files, reads supported file formats, and records retrieved ENCODE
metadata to improve reproducibility and citation of relevant ENCODE datasets.

The Portal exposes its records through an HTTP-based REST API that returns JSON,
which enables an R package to query accessions and metadata programmatically and
convert nested responses into R and Bioconductor objects.

The package is not affiliatedd with or endorsed by the ENCODE Project.

## Warning

Use of the programmatic API is limited to 10 GET requests/sec from any single
user, group, company or lab.

Abuse of this will result in denial of access by IP block

## Documentation

See the [getting-started vignette](https://zohebkhan1.github.io/encodeUtils/articles/get-started.html) and [function reference](https://zohebkhan1.github.io/encodeUtils/reference/)

## Functions

| Function | Purpose |
|---|---|
| [`encode_search()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_search.html) | Search ENCODE experiments, biosamples, and files. |
| [`encode_results()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_results.html) | Extract the main result table. |
| [`encode_list_files()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_list_files.html) | List files for ENCODE experiments. |
| [`encode_file_presets()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_file_presets.html) | List reusable file-selection presets. |
| [`encode_select_files()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_select_files.html) | Select files using explicit criteria. |
| [`encode_download()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_download.html) | Plan, download, and verify files. |
| [`encode_read()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_read.html) | Read supported local ENCODE files. |
| [`encode_manifest()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_manifest.html) | Create a retrieval-provenance manifest. |

## Installation

```r
BiocManager::install("encodeUtils")
```

Install the development version with:

```r
pak::pak("ZohebKhan1/encodeUtils")
```

## Example workflow

### 1. Find experiments

```r
library(encodeUtils)

discovery <- encode_search(
    organism = "mouse",
    assay = "microRNA-seq",
    organ = "heart",
    limit = 5
)

encode_results(discovery)[, c(
    "accession", "assay_title", "status"
), drop = FALSE]
```

```text
#> ENCODE experiments
#> - experiments: 5
#> Experiments:
#>   experiment        assay   status
#>  ENCSR523CTA microRNA-seq released
#>  ENCSR794QRE microRNA-seq released
#>  ENCSR576VFQ microRNA-seq released
#>  ENCSR108XJW microRNA-seq released
#>  ENCSR173OTH microRNA-seq released
```

### 2. Select files

```r
files <- encode_list_files(
    "ENCSR523CTA",
    file_format = "tsv",
    output_type = "microRNA quantifications",
    assembly = "mm10"
)

selected <- encode_select_files(
    files,
    file_accession = c("ENCFF859GWB", "ENCFF838WBE"),
    file_format = "tsv",
    output_type = "microRNA quantifications",
    assembly = "mm10",
    replicate_policy = "replicate_level"
)

selected
selected$excluded
```

```text
#> ENCODE selected files
#> - selected: 2
#> - excluded: 0
#> Selected files:
#>         file  experiment        assay     organism format
#>  ENCFF859GWB ENCSR523CTA microRNA-seq Mus musculus    tsv
#>  ENCFF838WBE ENCSR523CTA microRNA-seq Mus musculus    tsv
#>                    output assembly file_size   status
#>  microRNA quantifications     mm10  59.54 KB released
#>  microRNA quantifications     mm10  59.57 KB released
#> [1] file_accession       experiment_accession reason
#> <0 rows> (or 0-length row.names)
```

### 3. Preview the download

```r
plan <- encode_download(
    selected,
    directory = "encode-data",
    max_file_size = "100KB",
    max_total_size = "200KB",
    dry_run = TRUE
)

plan
```

```text
#> ENCODE download
#> - files: 2
#> - experiments: 1
#> - known total size: 119.11 KB
#> Download records:
#>         file format                   output file_size download
#>  ENCFF859GWB    tsv microRNA quantifications  59.54 KB  planned
#>  ENCFF838WBE    tsv microRNA quantifications  59.57 KB  planned
#>                         path
#>  encode-data/ENCFF859GWB.tsv
#>  encode-data/ENCFF838WBE.tsv
```

### 4. Download and verify the files

```r
downloaded <- encode_download(
    selected,
    directory = "encode-data",
    max_file_size = "100KB",
    max_total_size = "200KB"
)

downloaded
```

```text
#> ENCODE download
#> - files: 2
#> - experiments: 1
#> - known total size: 119.11 KB
#> Download records:
#>         file format                   output file_size   download size_ok md5_ok
#>  ENCFF859GWB    tsv microRNA quantifications  59.54 KB downloaded    TRUE   TRUE
#>  ENCFF838WBE    tsv microRNA quantifications  59.57 KB downloaded    TRUE   TRUE
#>                         path
#>  encode-data/ENCFF859GWB.tsv
#>  encode-data/ENCFF838WBE.tsv
```

### 5. Read the count tables

```r
loaded <- encode_read(
    downloaded,
    values = "raw_counts",
    row_names = "gene_id"
)

loaded
```

```text
#> ENCODE loaded files
#> - files: 2
#> - file objects: 2
#> - feature rows: 2202
#> - matrices: 1
#> Metadata:
#>         file  experiment        assay     organism assembly file_size   status
#>  ENCFF859GWB ENCSR523CTA microRNA-seq Mus musculus     mm10  59.54 KB released
#>  ENCFF838WBE ENCSR523CTA microRNA-seq Mus musculus     mm10  59.57 KB released
```

### 6. Create a SummarizedExperiment

```r
se <- encode_read(
    downloaded,
    values = "raw_counts",
    row_names = "gene_id",
    as = "SummarizedExperiment"
)

se
```

```text
#> class: SummarizedExperiment
#> dim: 2202 2
#> metadata(1): encodeUtils
#> assays(1): raw_counts
#> rownames(2202): ENSMUSG00000093015.1 ENSMUSG00000093970.1 ...
#>   ENSMUSG00000098868.1 ENSMUSG00000099228.1
#> rowData names(1): gene_id
#> colnames(2): ENCFF859GWB ENCFF838WBE
#> colData names(58): file_accession accession ... md5_verified failure_reason
```

### 7. Write a manifest

```r
manifest <- encode_manifest(loaded, path = "encode-manifest.json")

data.frame(
    manifest = basename(attr(manifest, "path")),
    files = nrow(manifest$files),
    requests = length(manifest$requests),
    matrices = nrow(manifest$matrices)
)
```

```text
#>               manifest files requests matrices
#> 1 encode-manifest.json     2        1        1
```

## Other inputs and formats

- Pass ENCSR accessions to `encode_list_files()`.
- Pass ENCFF accessions to `encode_download()`.
- Pass local paths or completed download rows to `encode_read()`.

BED, narrowPeak, and broadPeak files return `GenomicRanges::GRanges`. GFF,
GTF, BigWig, and BigBed files use `rtracklayer` when installed; FASTA files use
`Biostrings`.

Before transfer, `encode_download()` checks ENCODE-reported sizes and refuses
unknown-size files unless explicitly allowed. After transfer, it verifies the
observed size and MD5 checksum before installing each file.

## References

- [ENCODE REST API](https://www.encodeproject.org/help/rest-api/)
- [ENCODE attribution guidance](https://www.encodeproject.org/help/citing-encode/)
- Kagda MS et al. Data navigation on the ENCODE portal. *Nature
  Communications*. 2025;16:9592. doi:10.1038/s41467-025-64343-9.
