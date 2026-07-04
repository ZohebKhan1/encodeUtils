#!/usr/bin/env Rscript

required_packages <- c(
  "ggplot2", "dplyr", "tidyr", "forcats", "scales", "svglite",
  "sysfonts", "showtext", "patchwork"
)
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

nimbus_fonts <- c(
  regular = "/usr/share/fonts/opentype/urw-base35/NimbusSans-Regular.otf",
  bold = "/usr/share/fonts/opentype/urw-base35/NimbusSans-Bold.otf",
  italic = "/usr/share/fonts/opentype/urw-base35/NimbusSans-Italic.otf",
  bolditalic = "/usr/share/fonts/opentype/urw-base35/NimbusSans-BoldItalic.otf"
)
missing_fonts <- nimbus_fonts[!file.exists(nimbus_fonts)]
if (length(missing_fonts) > 0L) {
  stop("Nimbus Sans font files were not found: ", paste(missing_fonts, collapse = ", "), call. = FALSE)
}

sysfonts::font_add(
  family = "Nimbus Sans",
  regular = nimbus_fonts[["regular"]],
  bold = nimbus_fonts[["bold"]],
  italic = nimbus_fonts[["italic"]],
  bolditalic = nimbus_fonts[["bolditalic"]]
)

showtext::showtext_auto(TRUE)
on.exit(showtext::showtext_auto(FALSE), add = TRUE)

dataset_levels <- c("RNA-seq", "ChIP-seq", "ATAC-seq")
palette_family <- c(
  "RNA-seq" = "#4E79A7",
  "ChIP-seq" = "#B07AA1",
  "ATAC-seq" = "#59A14F"
)

theme_encode <- function(base_size = 9.5) {
  theme_minimal(base_family = "Nimbus Sans", base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = rel(1.12), color = "#1F2933", margin = margin(b = 4)),
      plot.subtitle = element_text(color = "#52606D", margin = margin(b = 8)),
      plot.caption = element_text(color = "#6B7280", size = rel(0.78), hjust = 0),
      axis.title = element_text(color = "#323F4B"),
      axis.text = element_text(color = "#323F4B"),
      axis.text.y = element_text(margin = margin(r = 3)),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.margin = margin(t = 2),
      legend.box.margin = margin(t = -4),
      strip.text = element_text(face = "bold", hjust = 0, color = "#1F2933"),
      strip.background = element_rect(fill = "#F4F6F8", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      plot.margin = margin(8, 12, 8, 8)
    )
}

save_svg <- function(plot, filename, width = 9.0, height = 11.0) {
  path <- file.path(figure_dir, filename)
  ggplot2::ggsave(
    filename = path,
    plot = plot,
    width = width,
    height = height,
    units = "in",
    device = svglite::svglite,
    bg = "white"
  )
  path
}

classify_assay_family <- function(assay_title) {
  case_when(
    grepl("RNA-seq", assay_title, fixed = TRUE) ~ "RNA-seq",
    grepl("ChIP-seq", assay_title, fixed = TRUE) ~ "ChIP-seq",
    grepl("ATAC-seq", assay_title, fixed = TRUE) ~ "ATAC-seq",
    TRUE ~ NA_character_
  )
}

matrix_result <- encode_matrix(quiet = TRUE)
assay_counts <- encode_results(matrix_result, component = "assays") |>
  as_tibble() |>
  transmute(
    assay_title,
    n = as.numeric(n),
    dataset_type = classify_assay_family(assay_title)
  )

family_assays <- assay_counts |>
  filter(!is.na(dataset_type), n > 0) |>
  mutate(dataset_type = factor(dataset_type, levels = dataset_levels))

dataset_families <- split(family_assays$assay_title, family_assays$dataset_type, drop = TRUE)

family_counts <- family_assays |>
  group_by(dataset_type) |>
  summarize(n = sum(n, na.rm = TRUE), assay_titles = paste(assay_title, collapse = "; "), .groups = "drop") |>
  mutate(dataset_type = factor(dataset_type, levels = dataset_levels))

get_search_result <- function(dataset_type) {
  encode_search(
    type = "Experiment",
    filters = list(assay_title = dataset_families[[dataset_type]]),
    status = "released",
    limit = 0,
    quiet = TRUE
  )
}

search_results <- setNames(lapply(dataset_levels, get_search_result), dataset_levels)
search_totals <- vapply(search_results, function(x) x$total_results, numeric(1))
matrix_totals <- setNames(family_counts$n, as.character(family_counts$dataset_type))
if (!identical(as.numeric(matrix_totals[dataset_levels]), as.numeric(search_totals[dataset_levels]))) {
  stop(
    "Collapsed assay totals do not match live ENCODE search totals.\n",
    "Matrix totals: ", paste(dataset_levels, matrix_totals[dataset_levels], sep = "=", collapse = ", "), "\n",
    "Search totals: ", paste(dataset_levels, search_totals[dataset_levels], sep = "=", collapse = ", "),
    call. = FALSE
  )
}

caption_text <- paste0(
  "Released ENCODE Experiment records queried ",
  format(Sys.Date(), "%Y-%m-%d"),
  ". Assay families are collapsed from ENCODE assay titles containing RNA-seq, ChIP-seq, or ATAC-seq."
)

family_plot <- family_counts |>
  mutate(dataset_type = fct_reorder(dataset_type, n)) |>
  ggplot(aes(x = n, y = dataset_type, fill = dataset_type)) +
  geom_col(width = 0.62) +
  geom_text(aes(label = comma(n)), hjust = -0.12, family = "Nimbus Sans", size = 3.2, color = "#1F2933") +
  scale_fill_manual(values = palette_family) +
  scale_x_continuous(labels = label_number(big.mark = ","), expand = expansion(mult = c(0, 0.16))) +
  labs(title = "Collapsed assay families", x = "Released experiments", y = NULL) +
  theme_encode(base_size = 9.8) +
  theme(legend.position = "none")

get_facets <- function(dataset_type) {
  encode_facets(search_results[[dataset_type]]) |>
    as_tibble() |>
    mutate(dataset_type = factor(dataset_type, levels = dataset_levels))
}

facet_counts <- bind_rows(lapply(dataset_levels, get_facets))

species_counts <- facet_counts |>
  filter(field == "replicates.library.biosample.donor.organism.scientific_name") |>
  transmute(dataset_type, category = "Species", term, n = count)

organ_counts <- facet_counts |>
  filter(field == "biosample_ontology.organ_slims") |>
  group_by(term) |>
  mutate(total = sum(count, na.rm = TRUE)) |>
  ungroup() |>
  filter(term %in% head(unique(term[order(total, decreasing = TRUE)]), 8)) |>
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
  geom_col(position = position_dodge2(width = 0.76, preserve = "single"), width = 0.62) +
  facet_wrap(~category, scales = "free", axes = "all_x", ncol = 3) +
  scale_fill_manual(values = palette_family) +
  scale_x_continuous(labels = label_number(big.mark = ","), expand = expansion(mult = c(0, 0.10))) +
  labs(title = "Species, tissue, and life-stage breakdown", x = "Released experiments", y = NULL) +
  theme_encode(base_size = 8.6) +
  theme(legend.position = "bottom")

histone_result <- encode_search(
  type = "Experiment",
  filters = list(assay_title = "Histone ChIP-seq"),
  status = "released",
  limit = 0,
  quiet = TRUE
)

histone_marks <- encode_facets(histone_result) |>
  as_tibble() |>
  filter(field == "target.label", !is.na(term), count > 0) |>
  arrange(desc(count)) |>
  slice_head(n = 16) |>
  mutate(term = fct_reorder(term, count))

histone_plot <- histone_marks |>
  ggplot(aes(x = count, y = term)) +
  geom_col(fill = "#8F6B7F", width = 0.62) +
  geom_text(aes(label = comma(count)), hjust = -0.08, family = "Nimbus Sans", size = 2.65, color = "#1F2933") +
  scale_x_continuous(labels = label_number(big.mark = ","), expand = expansion(mult = c(0, 0.16))) +
  labs(title = "Most frequent Histone ChIP-seq targets", x = "Released experiments", y = NULL) +
  theme_encode(base_size = 8.8) +
  theme(legend.position = "none")

overview_panel <- family_plot / breakdown_plot / histone_plot +
  patchwork::plot_layout(heights = c(0.85, 2.15, 1.35)) +
  patchwork::plot_annotation(
    title = "ENCODE RNA-seq, ChIP-seq, and ATAC-seq datasets",
    subtitle = "Released Experiment records grouped by assay family and summarized by common metadata fields.",
    caption = caption_text,
    tag_levels = "A",
    theme = theme_encode(base_size = 9.8) +
      theme(
        plot.title = element_text(size = 15, face = "bold"),
        plot.subtitle = element_text(size = 9.5),
        plot.caption = element_text(size = 7.2)
      )
  ) &
  theme(plot.tag = element_text(family = "Nimbus Sans", face = "bold", size = 10, color = "#1F2933"))

output_path <- save_svg(overview_panel, "encode-database-overview.svg", width = 9.2, height = 11.0)

old_figures <- file.path(
  figure_dir,
  c(
    "encode-dataset-coverage.svg",
    "encode-assay-subtypes.svg",
    "encode-metadata-breakdown.svg",
    "encode-histone-chip-targets.svg"
  )
)
unlink(old_figures[file.exists(old_figures)])

message("Wrote ENCODE summary panel to ", normalizePath(output_path))
