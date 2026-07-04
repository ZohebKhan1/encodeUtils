# encodeUtils get-started workflow
#
# This script demonstrates the common ENCODE workflow:
# search -> list files -> select files -> preview download -> dry-run download
# -> manifest/citation.
#
# The download steps use tempdir() and dry_run = TRUE by default so the script is
# safe to test without filling a project directory.

library(encodeUtils)

# 1. Bulk RNA-seq: mouse heart gene quantification files -----------------------

rna_experiments <- encode_search(
  type = "Experiment",
  search = "mouse heart total RNA-seq",
  status = "released",
  limit = 10,
  metadata = "full"
)

rna_files <- encode_list_files(
  rna_experiments,
  file_format = "tsv",
  output_type = "gene quantifications",
  assembly = "mm10",
  metadata = "full"
)

# Choose file IDs from the printed file table. Replace these with IDs from your
# own result if ENCODE search ordering changes.
rna_file_ids <- c("ENCFF260OJQ", "ENCFF090VKE")

rna_plan <- encode_preview_download(
  rna_files,
  file_accession = rna_file_ids,
  directory = tempdir()
)

rna_dry_run <- encode_download(
  rna_files,
  file_accession = rna_file_ids,
  directory = tempdir(),
  dry_run = TRUE
)


# 2. ATAC-seq: mouse heart peak files -----------------------------------------

atac_experiments <- encode_search(
  type = "Experiment",
  search = "mouse heart ATAC-seq",
  status = "released",
  limit = 10,
  metadata = "full"
)

atac_files <- encode_list_files(
  atac_experiments,
  file_format = "bed",
  assembly = "mm10",
  metadata = "full"
)

atac_selected <- encode_select_files(
  atac_files,
  preset = "atacseq_peaks",
  assembly = "mm10"
)

atac_plan <- encode_preview_download(
  atac_selected,
  directory = tempdir()
)


# 3. ChIP-seq: mouse heart H3K27ac peak and signal files -----------------------

chip_experiments <- encode_search(
  type = "Experiment",
  search = "mouse heart H3K27ac ChIP-seq",
  status = "released",
  limit = 10,
  metadata = "full"
)

chip_peak_files <- encode_list_files(
  chip_experiments,
  file_format = "bed",
  assembly = "mm10",
  metadata = "full"
)

chip_peaks <- encode_select_files(
  chip_peak_files,
  preset = "chipseq_idr_peaks",
  assembly = "mm10"
)

chip_signal_files <- encode_list_files(
  chip_experiments,
  file_format = "bigWig",
  assembly = "mm10",
  metadata = "full"
)

chip_signal <- encode_select_files(
  chip_signal_files,
  preset = "chipseq_signal_bigwig",
  assembly = "mm10"
)

chip_plan <- encode_preview_download(
  chip_peaks,
  directory = tempdir()
)


# 4. Reproducibility -----------------------------------------------------------

manifest <- encode_manifest(
  rna_dry_run,
  include_session = FALSE,
  path = file.path(tempdir(), "encode-rna-manifest.json")
)

encode_cite(
  rna_dry_run,
  enrich = "auto"
)


# 5. Real download -------------------------------------------------------------

# When the preview and dry-run output look correct, use a deliberate project
# directory and set dry_run = FALSE.
#
# downloaded <- encode_download(
#   rna_files,
#   file_accession = rna_file_ids,
#   directory = "data/encode/rna-seq",
#   dry_run = FALSE
# )
