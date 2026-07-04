#!/usr/bin/env Rscript

required_packages <- c("ggplot2", "dplyr", "tidyr", "forcats", "scales", "svglite")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running this script: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(quiet = TRUE)
} else {
  library(encodeUtils)
}

library(ggplot2)
library(dplyr)
library(tidyr)
library(forcats)
library(scales)

figure_dir <- "man/figures"
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

dataset_families <- list(
  "RNA-seq" = c(
    "total RNA-seq", "polyA plus RNA-seq", "polyA minus RNA-seq",
    "long read RNA-seq", "small RNA-seq", "microRNA-seq", "snRNA-seq",
    "scRNA-seq", "long read scRNA-seq", "shRNA RNA-seq",
    "CRISPR RNA-seq", "siRNA RNA-seq", "CRISPRi RNA-seq"
  ),
  "ChIP-seq" = c("TF ChIP-seq", "Histone ChIP-seq", "Control ChIP-seq"),
  "ATAC-seq" = c("ATAC-seq", "snATAC-seq")
)

palette_family <- c(
  "RNA-seq" = "#4C78A8",
  "ChIP-seq" = "#C44E52",
  "ATAC-seq" = "#55A868"
)

theme_encode <- function(base_size = 11) {
  theme_minimal(base_family = "Nimbus Sans", base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = rel(1.12), margin = margin(b = 6)),
      plot.subtitle = element_text(color = "#4d4d4d", margin = margin(b = 12)),
      plot.caption = element_text(color = "#6b6b6b", size = rel(0.82), hjust = 0),
      axis.title = element_text(color = "#333333"),
      axis.text = element_text(color = "#333333"),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.title = element_blank(),
      strip.text = element_text(face = "bold", hjust = 0),
      strip.background = element_rect(fill = "#F2F4F5", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
}

save_svg <- function(plot, filename, width, height) {
  ggplot2::ggsave(
    filename = file.path(figure_dir, filename),
    plot = plot,
    width = width,
    height = height,
    units = "in",
    device = svglite::svglite,
    bg = "white"
  )
}

matrix_result <- encode_matrix(quiet = TRUE)
assay_counts <- encode_results(matrix_result, component = "assays") |>
  as_tibble() |>
  select(assay_title, n)

family_counts <- tibble(
  dataset_type = names(dataset_families),
  n = vapply(dataset_families, function(assays) {
    sum(assay_counts$n[assay_counts$assay_title %in% assays], na.rm = TRUE)
  }, numeric(1))
) |>
  mutate(dataset_type = factor(dataset_type, levels = names(dataset_families)))

subtype_counts <- bind_rows(lapply(names(dataset_families), function(dataset_type) {
  assays <- dataset_families[[dataset_type]]
  assay_counts |>
    filter(assay_title %in% assays) |>
    mutate(dataset_type = factor(dataset_type, levels = names(dataset_families)))
})) |>
  arrange(dataset_type, desc(n)) |>
  group_by(dataset_type) |>
  slice_head(n = 8) |>
  ungroup()

caption_text <- paste0(
  "Released ENCODE Experiment records queried ",
  format(Sys.Date(), "%Y-%m-%d"),
  "."
)

family_plot <- family_counts |>
  mutate(dataset_type = fct_reorder(dataset_type, n)) |>
  ggplot(aes(x = n, y = dataset_type, fill = dataset_type)) +
  geom_col(width = 0.68) +
  geom_text(
    aes(label = comma(n)),
    hjust = -0.12,
    family = "Nimbus Sans",
    size = 3.7,
    color = "#222222"
  ) +
  scale_fill_manual(values = palette_family) +
  scale_x_continuous(labels = label_number(big.mark = ","), expand = expansion(mult = c(0, 0.18))) +
  labs(
    title = "ENCODE experiment coverage",
    x = "Released experiments",
    y = NULL,
    caption = caption_text
  ) +
  theme_encode(base_size = 12) +
  theme(legend.position = "none")

save_svg(family_plot, "encode-dataset-coverage.svg", width = 7.0, height = 3.2)

subtype_plot <- subtype_counts |>
  mutate(assay_title = fct_reorder(assay_title, n)) |>
  ggplot(aes(x = n, y = assay_title, fill = dataset_type)) +
  geom_col(width = 0.65) +
  geom_text(
    aes(label = comma(n)),
    hjust = -0.08,
    family = "Nimbus Sans",
    size = 2.8,
    color = "#222222"
  ) +
  facet_wrap(~dataset_type, scales = "free_y", ncol = 1) +
  scale_fill_manual(values = palette_family) +
  scale_x_continuous(labels = label_number(big.mark = ","), expand = expansion(mult = c(0, 0.18))) +
  labs(
    title = "Most common assay subtypes",
    x = "Released experiments",
    y = NULL,
    caption = caption_text
  ) +
  theme_encode(base_size = 10.5) +
  theme(legend.position = "none")

save_svg(subtype_plot, "encode-assay-subtypes.svg", width = 7.2, height = 7.2)

get_facets <- function(dataset_type, assays) {
  result <- encode_search(
    type = "Experiment",
    filters = list(assay_title = assays),
    status = "released",
    limit = 0,
    quiet = TRUE
  )
  encode_facets(result) |>
    as_tibble() |>
    mutate(dataset_type = factor(dataset_type, levels = names(dataset_families)))
}

facet_counts <- bind_rows(lapply(names(dataset_families), function(dataset_type) {
  get_facets(dataset_type, dataset_families[[dataset_type]])
}))

species_counts <- facet_counts |>
  filter(field == "replicates.library.biosample.donor.organism.scientific_name") |>
  transmute(dataset_type, category = "Species", term, n = count)

organ_counts <- facet_counts |>
  filter(field == "biosample_ontology.organ_slims") |>
  group_by(term) |>
  mutate(total = sum(count, na.rm = TRUE)) |>
  ungroup() |>
  filter(term %in% head(unique(term[order(total, decreasing = TRUE)]), 10)) |>
  transmute(dataset_type, category = "Organ / tissue", term, n = count)

life_stage_counts <- facet_counts |>
  filter(field == "replicates.library.biosample.life_stage") |>
  mutate(
    term = case_when(
      term %in% c("embryonic", "fetal") ~ "fetal / embryonic",
      term %in% c("adult", "child", "newborn", "postnatal") ~ "post-natal / adult",
      TRUE ~ "other / unknown"
    )
  ) |>
  group_by(dataset_type, term) |>
  summarize(n = sum(count, na.rm = TRUE), .groups = "drop") |>
  mutate(category = "Life stage") |>
  select(dataset_type, category, term, n)

breakdown_counts <- bind_rows(species_counts, organ_counts, life_stage_counts) |>
  filter(!is.na(term), !is.na(n), n > 0) |>
  group_by(category, term) |>
  mutate(term_total = sum(n, na.rm = TRUE)) |>
  ungroup() |>
  mutate(
    category = factor(category, levels = c("Species", "Organ / tissue", "Life stage")),
    term = reorder(term, term_total)
  )

breakdown_plot <- breakdown_counts |>
  ggplot(aes(x = n, y = term, fill = dataset_type)) +
  geom_col(position = position_dodge2(width = 0.78, preserve = "single"), width = 0.66) +
  facet_wrap(~category, scales = "free", axes = "all_x", ncol = 1) +
  scale_fill_manual(values = palette_family) +
  scale_x_continuous(labels = label_number(big.mark = ","), expand = expansion(mult = c(0, 0.08))) +
  labs(
    title = "ENCODE experiment metadata breakdown",
    x = "Released experiments",
    y = NULL,
    caption = caption_text
  ) +
  theme_encode(base_size = 10.5)

save_svg(breakdown_plot, "encode-metadata-breakdown.svg", width = 8.2, height = 9.2)

histone_facets <- get_facets("Histone ChIP-seq", "Histone ChIP-seq")
histone_marks <- histone_facets |>
  filter(field == "target.label") |>
  filter(!is.na(term), count > 0) |>
  arrange(desc(count)) |>
  slice_head(n = 18) |>
  mutate(term = fct_reorder(term, count))

histone_plot <- histone_marks |>
  ggplot(aes(x = count, y = term)) +
  geom_col(fill = "#8E6C8A", width = 0.68) +
  geom_text(
    aes(label = comma(count)),
    hjust = -0.08,
    family = "Nimbus Sans",
    size = 3.1,
    color = "#222222"
  ) +
  scale_x_continuous(labels = label_number(big.mark = ","), expand = expansion(mult = c(0, 0.18))) +
  labs(
    title = "Histone ChIP-seq targets in ENCODE",
    x = "Released experiments",
    y = NULL,
    caption = caption_text
  ) +
  theme_encode(base_size = 11) +
  theme(legend.position = "none")

save_svg(histone_plot, "encode-histone-chip-targets.svg", width = 7.2, height = 6.0)

message("Wrote ENCODE summary figures to ", normalizePath(figure_dir))
