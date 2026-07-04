# Internal flattening helpers for ENCODE JSON objects.

encode_total <- function(raw, graph) {
  total <- raw$total %||% raw$total_results
  if (is.null(total)) {
    length(graph)
  } else {
    total
  }
}

encode_active_filters <- function(raw, query) {
  filters <- raw$filters
  if (is.null(filters)) {
    filters <- query
  }
  encode_filter_table(filters)
}

#' Extract ENCODE facets from a result object
#'
#' @param x A search result from `encode_search()`, raw ENCODE search response,
#'   or facet table.
#'
#' @return A data frame with facet field, term, count, and title columns.
#'
#' @examples
#' raw <- list(facets = list(list(
#'   field = "assay_title",
#'   terms = list(list(key = "total RNA-seq", doc_count = 3))
#' )))
#' encode_facets(raw)
#' @noRd
encode_facets <- function(x) {
  if (inherits(x, "encode_search_result")) {
    return(x$facets)
  }
  if (is.data.frame(x)) {
    return(x)
  }

  facets <- x$facets
  if (is.null(facets) || length(facets) == 0L) {
    return(data.frame(
      field = character(),
      term = character(),
      count = integer(),
      title = character(),
      stringsAsFactors = FALSE
    ))
  }

  rows <- list()
  for (facet in facets) {
    field <- encode_scalar(facet$field)
    title <- encode_scalar(facet$title)
    terms <- facet$terms %||% list()
    if (length(terms) == 0L) {
      next
    }
    for (term in terms) {
      rows[[length(rows) + 1L]] <- data.frame(
        field = field,
        term = encode_scalar(term$key %||% term$term),
        count = encode_integer(term$doc_count %||% term$count),
        title = title,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(rows) == 0L) {
    return(data.frame(
      field = character(),
      term = character(),
      count = integer(),
      title = character(),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}

encode_columns <- function(raw) {
  columns <- raw$columns
  if (is.null(columns) || length(columns) == 0L) {
    return(data.frame(
      field = character(),
      title = character(),
      stringsAsFactors = FALSE
    ))
  }
  if (is.list(columns) && !is.null(names(columns))) {
    return(data.frame(
      field = names(columns),
      title = vapply(columns, function(x) encode_scalar(x$title %||% x), character(1L)),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(field = character(), title = character(), stringsAsFactors = FALSE)
}

encode_flatten_search_results <- function(graph, type) {
  if (length(graph) == 0L) {
    return(encode_empty_results(type))
  }

  rows <- lapply(graph, function(item) {
    object_type <- type %||% encode_first_type(item)
    if (identical(object_type, "Experiment")) {
      encode_flatten_experiment(item)
    } else if (identical(object_type, "File")) {
      encode_flatten_file(item)
    } else if (identical(object_type, "Biosample")) {
      encode_flatten_biosample(item)
    } else {
      encode_flatten_object(item)
    }
  })
  encode_bind_rows(rows)
}

encode_flatten_experiment <- function(item) {
  files <- item$files %||% list()
  data.frame(
    accession = encode_scalar(item$accession),
    id = encode_scalar(item$`@id`),
    assay_title = encode_scalar(item$assay_title),
    assay_term_name = encode_scalar(item$assay_term_name),
    target = encode_target(item$target),
    control_type = encode_collapse_vector(item$control_type),
    organism = encode_experiment_organism(item),
    sample_summary = encode_sample_summary(item),
    life_stage_age = encode_life_stage_age(item),
    sex = encode_sex(item),
    treatment = encode_treatment(item$treatments),
    biosample_summary = encode_scalar(item$biosample_summary),
    biosample_classification = encode_scalar(
      encode_pluck(item, c("biosample_ontology", "classification"))
    ),
    biosample_term_name = encode_scalar(
      encode_pluck(item, c("biosample_ontology", "term_name"))
    ),
    status = encode_scalar(item$status),
    date_released = encode_scalar(item$date_released),
    lab = encode_lab(item$lab),
    institution = encode_institution(item$lab),
    project = encode_project(item$award),
    award = encode_award(item$award),
    file_count = length(files),
    url = encode_object_url(encode_scalar(item$`@id`)),
    stringsAsFactors = FALSE
  )
}

encode_flatten_file <- function(item) {
  href <- encode_scalar(item$href)
  cloud_url <- encode_scalar(encode_pluck(item, c("cloud_metadata", "url")))
  file_size <- encode_numeric(item$file_size)
  dataset <- encode_file_dataset(item$dataset)
  date_released <- encode_scalar(item$date_released %||%
    encode_pluck(item, c("dataset", "date_released")))
  data.frame(
    file_accession = encode_scalar(item$accession),
    accession = encode_scalar(item$accession),
    id = encode_scalar(item$`@id`),
    dataset = dataset$id,
    dataset_accession = dataset$accession,
    dataset_type = dataset$type,
    experiment_accession = dataset$experiment_accession,
    assay_title = encode_scalar(item$assay_title),
    assay_term_name = encode_scalar(item$assay_term_name),
    target = encode_target(item$target %||% encode_pluck(item, c("dataset", "target"))),
    control_type = encode_collapse_vector(item$control_type %||%
      encode_pluck(item, c("dataset", "control_type"))),
    sample_summary = encode_sample_summary(item),
    life_stage_age = encode_life_stage_age(item),
    sex = encode_sex(item),
    treatment = encode_treatment(item$treatments %||% encode_pluck(item, c("dataset", "treatments"))),
    biosample_summary = encode_scalar(item$simple_biosample_summary %||% item$biosample_summary),
    biosample_type = encode_scalar(
      encode_pluck(item, c("biosample_ontology", "classification"))
    ),
    biosample_term_name = encode_scalar(
      encode_pluck(item, c("biosample_ontology", "term_name"))
    ),
    file_format = encode_scalar(item$file_format),
    file_type = encode_scalar(item$file_type),
    output_type = encode_scalar(item$output_type),
    output_category = encode_scalar(item$output_category),
    assembly = encode_scalar(item$assembly),
    genome_annotation = encode_scalar(item$genome_annotation),
    file_size = file_size,
    file_size_pretty = encode_pretty_bytes(file_size),
    md5sum = encode_scalar(item$md5sum),
    content_md5sum = encode_scalar(item$content_md5sum),
    status = encode_scalar(item$status),
    date_released = date_released,
    href = href,
    download_url = encode_download_url(href, cloud_url = NA_character_),
    cloud_url = cloud_url,
    biological_replicates = encode_collapse_vector(item$biological_replicates),
    technical_replicates = encode_collapse_vector(item$technical_replicates),
    paired_end = encode_scalar(item$paired_end),
    paired_with = encode_scalar(item$paired_with),
    read_length = encode_scalar(item$read_length),
    run_type = encode_scalar(item$run_type),
    preferred_default = encode_logical(item$preferred_default),
    analyses = encode_collapse_vector(item$analyses),
    analysis_accession = encode_analysis_accession(item$analyses),
    analysis_step_version = encode_scalar(item$analysis_step_version),
    audit_warnings = encode_audit_warnings(item$audit),
    lab = encode_lab(item$lab),
    institution = encode_institution(item$lab),
    project = encode_project(item$award),
    award = encode_award(item$award),
    organism = encode_file_organism(item),
    url = encode_object_url(encode_scalar(item$`@id`)),
    stringsAsFactors = FALSE
  )
}

encode_flatten_biosample <- function(item) {
  data.frame(
    accession = encode_scalar(item$accession),
    id = encode_scalar(item$`@id`),
    status = encode_scalar(item$status),
    organism = encode_organism(item$organism),
    summary = encode_scalar(item$summary),
    classification = encode_scalar(encode_pluck(item, c("biosample_ontology", "classification"))),
    term_name = encode_scalar(encode_pluck(item, c("biosample_ontology", "term_name"))),
    lab = encode_lab(item$lab),
    url = encode_object_url(encode_scalar(item$`@id`)),
    stringsAsFactors = FALSE
  )
}

encode_flatten_object <- function(item) {
  data.frame(
    accession = encode_scalar(item$accession),
    id = encode_scalar(item$`@id`),
    type = encode_first_type(item),
    status = encode_scalar(item$status),
    title = encode_scalar(item$title %||% item$summary %||% item$`@id`),
    url = encode_object_url(encode_scalar(item$`@id`)),
    stringsAsFactors = FALSE
  )
}

encode_empty_results <- function(type) {
  if (identical(type, "Experiment")) {
    return(encode_empty_data_frame(c(
      "accession", "id", "assay_title", "assay_term_name", "target",
      "control_type", "organism", "sample_summary", "life_stage_age", "sex",
      "treatment",
      "biosample_summary", "biosample_classification", "biosample_term_name",
      "status", "date_released", "lab", "institution", "project", "award",
      "file_count", "url"
    )))
  }
  if (identical(type, "File")) {
    return(encode_empty_data_frame(c(
      "file_accession", "accession", "id", "experiment_accession", "dataset",
      "dataset_accession", "dataset_type", "assay_title", "assay_term_name",
      "target", "control_type", "sample_summary", "life_stage_age", "sex",
      "treatment", "biosample_summary", "biosample_type", "biosample_term_name",
      "file_format", "file_type", "output_type", "output_category",
      "assembly", "file_size", "genome_annotation", "file_size_pretty",
      "md5sum", "content_md5sum", "status", "date_released", "href",
      "download_url", "cloud_url", "biological_replicates",
      "technical_replicates", "paired_end", "paired_with", "read_length",
      "run_type", "preferred_default", "analyses", "analysis_step_version",
      "analysis_accession", "audit_warnings", "lab", "institution",
      "project", "award", "organism", "url"
    )))
  }
  encode_empty_data_frame(c("accession", "id", "type", "status", "title", "url"))
}

encode_file_dataset <- function(dataset) {
  if (is.null(dataset)) {
    return(encode_file_dataset_result(NA_character_, NA_character_, NA_character_))
  }
  if (is.list(dataset)) {
    accession <- encode_scalar(dataset$accession)
    id <- encode_scalar(dataset$`@id` %||% dataset$id)
    if (is.na(accession)) {
      accession <- encode_accession_from_path(id)
    }
    type <- encode_first_type(dataset)
    if (is.na(type)) {
      type <- encode_dataset_type_from_path(id)
    }
    return(encode_file_dataset_result(accession, id, type))
  }
  id <- encode_scalar(dataset)
  encode_file_dataset_result(
    accession = encode_accession_from_path(id),
    id = id,
    type = encode_dataset_type_from_path(id)
  )
}

encode_file_dataset_result <- function(accession, id, type) {
  list(
    accession = accession,
    id = id,
    type = type,
    experiment_accession = if (identical(type, "Experiment")) accession else NA_character_
  )
}

encode_analysis_accession <- function(analyses) {
  values <- encode_collapse_vector(analyses)
  if (is.na(values)) {
    return(NA_character_)
  }
  pieces <- strsplit(values, ", ", fixed = TRUE)[[1L]]
  accessions <- vapply(pieces, encode_accession_from_path, character(1L))
  accessions <- unique(accessions[!is.na(accessions) & nzchar(accessions)])
  if (length(accessions) == 0L) {
    return(NA_character_)
  }
  paste(accessions, collapse = ", ")
}

encode_dataset_type_from_path <- function(path) {
  path <- encode_scalar(path)
  if (is.na(path)) {
    return(NA_character_)
  }
  pieces <- strsplit(gsub("^/+|/+$", "", path), "/", fixed = TRUE)[[1L]]
  if (length(pieces) == 0L || !nzchar(pieces[[1L]])) {
    return(NA_character_)
  }
  collection <- pieces[[1L]]
  switch(
    collection,
    experiments = "Experiment",
    annotations = "Annotation",
    files = "File",
    biosamples = "Biosample",
    libraries = "Library",
    replicates = "Replicate",
    collection
  )
}

encode_file_organism <- function(item) {
  organism <- encode_organism(item$organism)
  if (!is.na(organism)) {
    return(organism)
  }
  organism <- encode_scalar(encode_pluck(item, c("biosample_ontology", "organism", "scientific_name")))
  if (!is.na(organism)) {
    return(organism)
  }
  organism <- encode_scalar(encode_pluck(item, c("dataset", "organism")))
  if (!is.na(organism)) {
    return(organism)
  }
  summary <- encode_scalar(item$biosample_summary)
  if (!is.na(summary) && grepl("^Homo sapiens", summary)) {
    return("Homo sapiens")
  }
  if (!is.na(summary) && grepl("^Mus musculus", summary)) {
    return("Mus musculus")
  }
  NA_character_
}

encode_audit_warnings <- function(audit) {
  if (is.null(audit) || length(audit) == 0L) {
    return(NA_character_)
  }
  values <- unlist(audit, recursive = TRUE, use.names = FALSE)
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) {
    return(NA_character_)
  }
  paste(unique(as.character(values)), collapse = "; ")
}

encode_lab <- function(lab) {
  if (is.null(lab)) {
    return(NA_character_)
  }
  if (!is.list(lab)) {
    return(encode_accession_from_path(lab))
  }
  encode_scalar(lab$title %||% lab$name %||% lab$`@id`)
}

encode_institution <- function(lab) {
  if (is.null(lab) || !is.list(lab)) {
    return(NA_character_)
  }
  encode_scalar(lab$institute_label %||% lab$institute_name %||% lab$address1)
}

encode_project <- function(award) {
  if (is.null(award)) {
    return(NA_character_)
  }
  if (!is.list(award)) {
    return(encode_accession_from_path(award))
  }
  encode_scalar(award$project %||% award$name %||% award$`@id`)
}

encode_target <- function(target) {
  if (is.null(target)) {
    return(NA_character_)
  }
  if (!is.list(target)) {
    return(encode_accession_from_path(target))
  }
  encode_scalar(target$label %||% target$name %||% target$title %||% target$`@id`)
}

encode_sample_summary <- function(item) {
  encode_scalar(item$simple_biosample_summary %||%
    item$biosample_summary %||%
    encode_pluck(item, c("dataset", "simple_biosample_summary")) %||%
    encode_pluck(item, c("dataset", "biosample_summary")) %||%
    encode_pluck(item, c("replicates", "library", "biosample", "simple_summary")) %||%
    encode_pluck(item, c("replicates", "library", "biosample", "summary")))
}

encode_life_stage_age <- function(item) {
  value <- encode_scalar(item$life_stage_age %||%
    encode_pluck(item, c("dataset", "life_stage_age")))
  if (!is.na(value)) {
    return(value)
  }
  life_stage <- encode_scalar(encode_pluck(item, c("replicates", "library", "biosample", "life_stage")))
  age <- encode_scalar(encode_pluck(item, c("replicates", "library", "biosample", "age_display")) %||%
    encode_pluck(item, c("replicates", "library", "biosample", "age")))
  if (!is.na(life_stage) && !is.na(age)) {
    return(paste(life_stage, age))
  }
  if (!is.na(life_stage)) {
    return(life_stage)
  }
  age
}

encode_sex <- function(item) {
  value <- encode_scalar(item$sex %||%
    encode_pluck(item, c("dataset", "sex")) %||%
    encode_pluck(item, c("replicates", "library", "biosample", "sex")) %||%
    encode_pluck(item, c("replicates", "library", "biosample", "model_organism_sex")))
  if (!is.na(value)) {
    return(value)
  }
  summary <- encode_scalar(item$simple_biosample_summary %||%
    item$biosample_summary %||%
    encode_pluck(item, c("dataset", "simple_biosample_summary")) %||%
    encode_pluck(item, c("dataset", "biosample_summary")))
  if (is.na(summary)) {
    return(NA_character_)
  }
  lower <- tolower(summary)
  if (grepl("\\bmixed sex\\b", lower)) {
    return("mixed sex")
  }
  if (grepl("\\bfemale\\b", lower)) {
    return("female")
  }
  if (grepl("\\bmale\\b", lower)) {
    return("male")
  }
  NA_character_
}

encode_treatment <- function(treatments) {
  if (is.null(treatments) || length(treatments) == 0L) {
    return(NA_character_)
  }
  if (!is.list(treatments)) {
    return(encode_collapse_vector(treatments))
  }
  values <- vapply(treatments, function(treatment) {
    if (is.list(treatment)) {
      encode_scalar(treatment$summary %||% treatment$treatment_term_name %||%
        treatment$agent$title %||% treatment$agent$label %||%
        treatment$agent$name %||% treatment$`@id`)
    } else {
      encode_scalar(treatment)
    }
  }, character(1L))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) {
    return(NA_character_)
  }
  paste(unique(values), collapse = "; ")
}

encode_award <- function(award) {
  if (is.null(award)) {
    return(NA_character_)
  }
  if (!is.list(award)) {
    return(encode_accession_from_path(award))
  }
  encode_scalar(award$name %||% award$rfa %||% award$`@id`)
}

encode_organism <- function(organism) {
  if (is.null(organism)) {
    return(NA_character_)
  }
  if (!is.list(organism)) {
    return(encode_accession_from_path(organism))
  }
  encode_scalar(organism$scientific_name %||% organism$name %||% organism$`@id`)
}

encode_experiment_organism <- function(item) {
  organism <- encode_organism(item$organism)
  if (!is.na(organism)) {
    return(organism)
  }

  replicate_organism <- encode_pluck(
    item,
    c("replicates", "library", "biosample", "organism", "scientific_name")
  )
  organism <- encode_scalar(replicate_organism)
  if (!is.na(organism)) {
    return(organism)
  }

  summary <- encode_scalar(item$biosample_summary)
  if (!is.na(summary) && grepl("^Homo sapiens", summary)) {
    return("Homo sapiens")
  }
  if (!is.na(summary) && grepl("^Mus musculus", summary)) {
    return("Mus musculus")
  }
  NA_character_
}
