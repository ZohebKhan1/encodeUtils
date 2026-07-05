#' Search ENCODE metadata
#'
#' Find ENCODE experiments, files, or other records. The search returns matching
#' metadata rows and the total number of matches. It does not download data
#' files.
#'
#' The result prints as a compact table. Use `encode_results()` to extract the
#' table. Use `print(x, verbose = TRUE)` to show the query URL, active filters,
#' and ENCODE facets.
#'
#' @param type ENCODE object type to search, such as `"Experiment"` or `"File"`.
#'   Use `"Experiment"` to find datasets and `"File"` to find individual files.
#'   Use `NULL` only for mixed free-text searches.
#' @param filters Named list of ENCODE search filters. ENCODE field names,
#'   dot notation, and negated filters such as `"control_type!="` are accepted.
#' @param search Optional free-text search term.
#' @param organism Optional organism filter. Common values such as `"mouse"`,
#'   `"human"`, `"Mus musculus"`, and `"Homo sapiens"` are accepted.
#' @param assay Optional assay filter. Common values such as `"rna-seq"`,
#'   `"atac-seq"`, `"chip-seq"`, `"histone chip-seq"`, and `"tf chip-seq"`
#'   are expanded to ENCODE assay names.
#' @param assay_type Optional broad assay category, such as `"Transcription"`,
#'   `"DNA accessibility"`, or `"DNA binding"`.
#' @param biosample Optional biosample or tissue term. This is added to the
#'   free-text query so broader terms such as `"brain"` can find forebrain,
#'   midbrain, hindbrain, cortex, and related ENCODE biosample terms.
#' @param biosample_type Optional biosample class, such as `"tissue"`,
#'   `"cell line"`, `"primary cell"`, or `"organoid"`.
#' @param organ Optional organ facet, such as `"brain"`, `"heart"`, or
#'   `"liver"`.
#' @param cell Optional cell facet, such as `"T cell"`, `"neural cell"`, or
#'   `"stem cell"`.
#' @param system Optional anatomical system facet, such as `"immune system"` or
#'   `"central nervous system"`.
#' @param life_stage Optional life-stage filter, such as `"embryonic"`,
#'   `"postnatal"`, `"adult"`, or `"fetal"`. `"fetal"` is treated as
#'   `"embryonic"` for ENCODE mouse development searches.
#' @param sex Optional sex filter, such as `"female"`, `"male"`, or `"mixed"`.
#' @param disease Optional disease term.
#' @param treatment Optional biosample-treatment term.
#' @param cellular_component Optional subcellular fraction term, such as
#'   `"nucleus"` or `"cytosol"`.
#' @param development If `TRUE`, restrict experiments to organism-development
#'   series records.
#' @param exclude_controls If `TRUE`, remove ENCODE control experiments from
#'   the search result.
#' @param target Optional ChIP-seq target label, such as `"TBX5"` or
#'   `"H3K27ac"`.
#' @param target_category Optional target category, such as `"histone"` or
#'   `"transcription factor"`.
#' @param file_format Optional file-format filter used when `type = "File"`,
#'   such as `"fastq"`, `"bed"`, `"bigWig"`, or `"tsv"`.
#' @param output_type Optional file-output filter used when `type = "File"`,
#'   such as `"reads"`, `"gene quantifications"`, or `"IDR ranked peaks"`.
#' @param assembly Optional genome-assembly filter used when `type = "File"`,
#'   such as `"GRCh38"` or `"mm10"`.
#' @param status Optional ENCODE status filter. The default keeps released
#'   records only. Use `NULL` to omit the status filter.
#' @param limit Number of records to return, or the explicit string `"all"`.
#' @param metadata Amount of linked metadata to request. `"full"` gives richer
#'   lab, organism, biosample, and target columns. `"basic"` requests fewer
#'   fields.
#' @param include_facets Whether to keep ENCODE facet counts in the result
#'   object for verbose printing.
#' @param quiet If `FALSE`, print a concise query status message.
#'
#' @return Search results. `encode_results()` extracts the result table.
#' @export
#'
#' @examples
#' res <- try(
#'   encode_search(
#'     type = "Experiment",
#'     organism = "mouse",
#'     assay = "rna-seq",
#'     organ = "heart",
#'     limit = 1,
#'     quiet = TRUE
#'   ),
#'   silent = TRUE
#' )
#' if (!inherits(res, "try-error")) {
#'   encode_results(res)
#' }
#'
#' chip <- try(
#'   encode_search(
#'     type = "Experiment",
#'     organism = "mouse",
#'     assay = "histone chip-seq",
#'     target = "H3K27ac",
#'     organ = "heart",
#'     exclude_controls = TRUE,
#'     limit = 1,
#'     quiet = TRUE
#'   ),
#'   silent = TRUE
#' )
encode_search <- function(
                          type = "Experiment",
                          filters = list(),
                          search = NULL,
                          organism = NULL,
                          assay = NULL,
                          assay_type = NULL,
                          biosample = NULL,
                          biosample_type = NULL,
                          organ = NULL,
                          cell = NULL,
                          system = NULL,
                          life_stage = NULL,
                          sex = NULL,
                          disease = NULL,
                          treatment = NULL,
                          cellular_component = NULL,
                          development = FALSE,
                          exclude_controls = FALSE,
                          target = NULL,
                          target_category = NULL,
                          file_format = NULL,
                          output_type = NULL,
                          assembly = NULL,
                          status = "released",
                          limit = 25,
                          metadata = c("full", "basic"),
                          include_facets = TRUE,
                          quiet = FALSE) {
  metadata_request <- encode_metadata_request(metadata)
  frame <- metadata_request$frame
  metadata <- metadata_request$metadata
  encode_validate_filters(filters)
  encode_validate_limit(limit)
  filters <- encode_add_file_search_filters(
    type = type,
    filters = filters,
    file_format = file_format,
    output_type = output_type,
    assembly = assembly
  )
  if (encode_use_file_experiment_search(
    type = type,
    organism = organism,
    assay = assay,
    assay_type = assay_type,
    biosample = biosample,
    biosample_type = biosample_type,
    organ = organ,
    cell = cell,
    system = system,
    life_stage = life_stage,
    sex = sex,
    disease = disease,
    treatment = treatment,
    cellular_component = cellular_component,
    development = development,
    exclude_controls = exclude_controls,
    target = target,
    target_category = target_category
  )) {
    return(encode_search_files_via_experiments(
      filters = filters,
      search = search,
      organism = organism,
      assay = assay,
      assay_type = assay_type,
      biosample = biosample,
      biosample_type = biosample_type,
      organ = organ,
      cell = cell,
      system = system,
      life_stage = life_stage,
      sex = sex,
      disease = disease,
      treatment = treatment,
      cellular_component = cellular_component,
      development = development,
      exclude_controls = exclude_controls,
      target = target,
      target_category = target_category,
      status = status,
      limit = limit,
      frame = frame,
      metadata = metadata,
      include_facets = include_facets,
      quiet = quiet
    ))
  }
  standard <- encode_standard_search_filters(
    type = type,
    organism = organism,
    assay = assay,
    assay_type = assay_type,
    biosample_type = biosample_type,
    organ = organ,
    cell = cell,
    system = system,
    life_stage = life_stage,
    sex = sex,
    disease = disease,
    treatment = treatment,
    cellular_component = cellular_component,
    development = development,
    exclude_controls = exclude_controls,
    target = target,
    target_category = target_category
  )
  filters <- encode_merge_search_filters(standard, filters)
  search <- encode_search_terms(search, biosample)

  query <- encode_search_query(
    type = type,
    filters = filters,
    search = search,
    status = status,
    limit = limit,
    frame = frame
  )

  if (!isTRUE(quiet)) {
    shown_type <- type %||% "mixed"
    cli::cli_inform("Querying ENCODE search ({.field {shown_type}}, limit {.val {limit}}).")
  }

  response <- encode_perform_json("/search/", query = query, allow_search_404 = TRUE)
  raw <- response$data
  graph <- raw$`@graph` %||% list()
  facets <- if (isTRUE(include_facets)) {
    encode_facets(raw)
  } else {
    encode_facets(list())
  }
  results <- encode_flatten_search_results(graph, type = type)
  filters <- encode_active_filters(raw, query)
  results <- encode_attach_metadata(
    results,
    query_url = response$url,
    retrieved_at = response$retrieved_at,
    filters = filters
  )
  results <- encode_class_search_results(results, type = type)

  result <- list(
    results = results,
    raw = raw,
    total = encode_total(raw, graph),
    filters = filters,
    facets = facets,
    columns = encode_columns(raw),
    url = response$url,
    query_url = response$url,
    encode_base_url = encode_base_url(),
    frame = frame,
    metadata = metadata,
    limit = limit,
    total_results = encode_total(raw, graph),
    requested_limit = limit,
    request = response[c("status_code", "content_type", "retrieved_at")]
  )
  class(result) <- c("encode_search_result", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "ENCODE search successfully returned {nrow(results)} of {result$total} matching record(s)."
    )
    cli::cli_inform(
      "Returned {encode_result_kind(type)}. Print the result to view records, or use {.code encode_results()} for the result table."
    )
  }
  result
}

encode_add_file_search_filters <- function(type,
                                           filters,
                                           file_format = NULL,
                                           output_type = NULL,
                                           assembly = NULL) {
  requested <- list(
    file_format = file_format,
    output_type = output_type,
    assembly = assembly
  )
  requested <- requested[!vapply(requested, is.null, logical(1L))]
  if (length(requested) == 0L) {
    return(filters)
  }
  if (!identical(type, "File")) {
    cli::cli_abort(
      "{.arg file_format}, {.arg output_type}, and {.arg assembly} can only be used when {.code type = \"File\"}."
    )
  }
  duplicate <- intersect(names(requested), names(filters))
  if (length(duplicate) > 0L) {
    fields <- paste(duplicate, collapse = ", ")
    cli::cli_abort("Do not provide {.field {fields}} in both named arguments and {.arg filters}.")
  }
  c(filters, requested)
}

encode_use_file_experiment_search <- function(type,
                                              organism = NULL,
                                              assay = NULL,
                                              assay_type = NULL,
                                              biosample = NULL,
                                              biosample_type = NULL,
                                              organ = NULL,
                                              cell = NULL,
                                              system = NULL,
                                              life_stage = NULL,
                                              sex = NULL,
                                              disease = NULL,
                                              treatment = NULL,
                                              cellular_component = NULL,
                                              development = FALSE,
                                              exclude_controls = FALSE,
                                              target = NULL,
                                              target_category = NULL) {
  identical(type, "File") &&
    (
      !is.null(organism) ||
        !is.null(assay) ||
        !is.null(assay_type) ||
        !is.null(biosample) ||
        !is.null(biosample_type) ||
        !is.null(organ) ||
        !is.null(cell) ||
        !is.null(system) ||
        !is.null(life_stage) ||
        !is.null(sex) ||
        !is.null(disease) ||
        !is.null(treatment) ||
        !is.null(cellular_component) ||
        isTRUE(development) ||
        isTRUE(exclude_controls) ||
        !is.null(target) ||
        !is.null(target_category)
    )
}

encode_search_files_via_experiments <- function(filters,
                                                search = NULL,
                                                organism = NULL,
                                                assay = NULL,
                                                assay_type = NULL,
                                                biosample = NULL,
                                                biosample_type = NULL,
                                                organ = NULL,
                                                cell = NULL,
                                                system = NULL,
                                                life_stage = NULL,
                                                sex = NULL,
                                                disease = NULL,
                                                treatment = NULL,
                                                cellular_component = NULL,
                                                development = FALSE,
                                                exclude_controls = FALSE,
                                                target = NULL,
                                                target_category = NULL,
                                                status = "released",
                                                limit = 25,
                                                frame = "embedded",
                                                metadata = "full",
                                                include_facets = TRUE,
                                                quiet = FALSE) {
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "Querying ENCODE experiments first to support file searches with biological filters."
    )
  }
  experiment_result <- encode_search(
    type = "Experiment",
    filters = list(),
    search = search,
    organism = organism,
    assay = assay,
    assay_type = assay_type,
    biosample = biosample,
    biosample_type = biosample_type,
    organ = organ,
    cell = cell,
    system = system,
    life_stage = life_stage,
    sex = sex,
    disease = disease,
    treatment = treatment,
    cellular_component = cellular_component,
    development = development,
    exclude_controls = exclude_controls,
    target = target,
    target_category = target_category,
    status = status,
    limit = limit,
    metadata = metadata,
    include_facets = FALSE,
    quiet = TRUE
  )
  experiments <- encode_results(experiment_result)
  experiment_paths <- encode_experiment_paths(experiments)
  experiment_paths <- unique(experiment_paths[!is.na(experiment_paths) & nzchar(experiment_paths)])
  if (length(experiment_paths) == 0L) {
    results <- encode_empty_results("File")
    results <- encode_attach_metadata(
      results,
      query_url = encode_query_url(experiment_result),
      retrieved_at = experiment_result$request$retrieved_at,
      filters = experiment_result$filters
    )
    class(results) <- c("encode_file_table", "data.frame")
    result <- list(
      results = results,
      raw = list(`@graph` = list(), total = 0L),
      total = 0L,
      filters = experiment_result$filters,
      facets = encode_facets(list()),
      columns = data.frame(field = character(), title = character()),
      url = encode_query_url(experiment_result),
      query_url = encode_query_url(experiment_result),
      encode_base_url = encode_base_url(),
      frame = frame,
      metadata = metadata,
      limit = limit,
      total_results = 0L,
      requested_limit = limit,
      request = experiment_result$request
    )
    class(result) <- c("encode_search_result", "list")
    return(result)
  }

  file_filters <- c(list(dataset = experiment_paths), filters)
  query <- encode_search_query(
    type = "File",
    filters = file_filters,
    search = NULL,
    status = status,
    limit = limit,
    frame = frame
  )
  response <- encode_perform_json("/search/", query = query, allow_search_404 = TRUE)
  raw <- response$data
  graph <- raw$`@graph` %||% list()
  facets <- if (isTRUE(include_facets)) {
    encode_facets(raw)
  } else {
    encode_facets(list())
  }
  results <- encode_flatten_search_results(graph, type = "File")
  results <- encode_fill_file_experiment_metadata(results, experiments)
  active_filters <- encode_active_filters(raw, query)
  results <- encode_attach_metadata(
    results,
    query_url = response$url,
    retrieved_at = response$retrieved_at,
    filters = active_filters
  )
  results <- encode_class_search_results(results, type = "File")
  if (nrow(results) == 0L) {
    direct_result <- encode_search_files_direct_fallback(
      filters = filters,
      organism = organism,
      assay = assay,
      assay_type = assay_type,
      target = target,
      target_category = target_category,
      exclude_controls = exclude_controls,
      status = status,
      limit = limit,
      frame = frame,
      metadata = metadata,
      include_facets = include_facets,
      quiet = quiet
    )
    if (!is.null(direct_result) && nrow(direct_result$results) > 0L) {
      return(direct_result)
    }
  }

  result <- list(
    results = results,
    raw = raw,
    total = encode_total(raw, graph),
    filters = active_filters,
    facets = facets,
    columns = encode_columns(raw),
    url = response$url,
    query_url = response$url,
    encode_base_url = encode_base_url(),
    frame = frame,
    metadata = metadata,
    limit = limit,
    total_results = encode_total(raw, graph),
    requested_limit = limit,
    request = response[c("status_code", "content_type", "retrieved_at")]
  )
  class(result) <- c("encode_search_result", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform(
      "ENCODE file search returned {nrow(results)} of {result$total} file record(s) from {length(experiment_paths)} matching experiment(s)."
    )
  }
  result
}

encode_search_files_direct_fallback <- function(filters,
                                                organism = NULL,
                                                assay = NULL,
                                                assay_type = NULL,
                                                target = NULL,
                                                target_category = NULL,
                                                exclude_controls = FALSE,
                                                status = "released",
                                                limit = 25,
                                                frame = "embedded",
                                                metadata = "full",
                                                include_facets = TRUE,
                                                quiet = FALSE) {
  direct_limit <- encode_direct_file_fallback_limit(limit)
  if (is.null(direct_limit)) {
    return(NULL)
  }
  standard <- encode_standard_search_filters(
    type = NULL,
    organism = NULL,
    assay = assay,
    assay_type = assay_type,
    biosample_type = NULL,
    organ = NULL,
    cell = NULL,
    system = NULL,
    life_stage = NULL,
    sex = NULL,
    disease = NULL,
    treatment = NULL,
    cellular_component = NULL,
    development = FALSE,
    exclude_controls = exclude_controls,
    target = target,
    target_category = target_category
  )
  standard <- encode_direct_file_standard_filters(standard)
  direct_filters <- c(filters, standard)
  query <- encode_search_query(
    type = "File",
    filters = direct_filters,
    search = NULL,
    status = status,
    limit = direct_limit,
    frame = frame
  )
  response <- encode_perform_json("/search/", query = query, allow_search_404 = TRUE)
  raw <- response$data
  graph <- raw$`@graph` %||% list()
  results <- encode_flatten_search_results(graph, type = "File")
  experiment_paths <- unique(results$dataset[!is.na(results$dataset) & nzchar(results$dataset)])
  experiments <- encode_fetch_experiment_metadata_for_files(experiment_paths, metadata = metadata)
  results <- encode_fill_file_experiment_metadata(results, experiments)
  results <- encode_filter_file_results_locally(results, organism = organism)
  results <- encode_limit_search_rows(results, limit)
  active_filters <- encode_active_filters(raw, query)
  results <- encode_attach_metadata(
    results,
    query_url = response$url,
    retrieved_at = response$retrieved_at,
    filters = active_filters
  )
  results <- encode_class_search_results(results, type = "File")
  facets <- if (isTRUE(include_facets)) {
    encode_facets(raw)
  } else {
    encode_facets(list())
  }
  result <- list(
    results = results,
    raw = raw,
    total = nrow(results),
    filters = active_filters,
    facets = facets,
    columns = encode_columns(raw),
    url = response$url,
    query_url = response$url,
    encode_base_url = encode_base_url(),
    frame = frame,
    metadata = metadata,
    limit = limit,
    total_results = nrow(results),
    requested_limit = limit,
    request = response[c("status_code", "content_type", "retrieved_at")]
  )
  class(result) <- c("encode_search_result", "list")
  if (!isTRUE(quiet) && nrow(results) > 0L) {
    cli::cli_inform(
      "Direct ENCODE file search returned {nrow(results)} locally filtered file record(s)."
    )
  }
  result
}

encode_direct_file_standard_filters <- function(filters) {
  if ("assay_term_name" %in% names(filters) &&
      identical(filters$assay_term_name, "ChIP-seq")) {
    filters$assay_term_name <- NULL
    filters$assay_title <- c("TF ChIP-seq", "Histone ChIP-seq")
  }
  filters
}

encode_direct_file_fallback_limit <- function(limit) {
  if (identical(limit, "all")) {
    return(NULL)
  }
  limit <- as.integer(limit)
  as.character(max(100L, limit * 20L))
}

encode_filter_file_results_locally <- function(results, organism = NULL) {
  if (!is.data.frame(results) || nrow(results) == 0L) {
    return(results)
  }
  organism <- encode_standard_organism(organism)
  if (!is.null(organism) && "organism" %in% names(results)) {
    keep <- !is.na(results$organism) & results$organism %in% organism
    results <- results[keep, , drop = FALSE]
  }
  results
}

encode_limit_search_rows <- function(results, limit) {
  if (identical(limit, "all") || nrow(results) == 0L) {
    return(results)
  }
  limit <- as.integer(limit)
  results[seq_len(min(limit, nrow(results))), , drop = FALSE]
}

encode_class_search_results <- function(results, type) {
  if (identical(type, "File")) {
    class(results) <- c("encode_file_table", "data.frame")
  }
  if (identical(type, "Experiment")) {
    class(results) <- c("encode_experiment_table", "data.frame")
  }
  results
}

encode_search_query <- function(
                                type,
                                filters,
                                search,
                                status,
                                limit,
                                frame) {
  query <- list(format = "json", frame = frame)

  if (!is.null(type)) {
    query$type <- type
  }
  if (!is.null(status)) {
    query$status <- status
  }
  if (!is.null(search)) {
    query$searchTerm <- search
  }
  query$limit <- as.character(limit)

  c(query, filters)
}

encode_standard_search_filters <- function(type,
                                           organism = NULL,
                                           assay = NULL,
                                           assay_type = NULL,
                                           biosample_type = NULL,
                                           organ = NULL,
                                           cell = NULL,
                                           system = NULL,
                                           life_stage = NULL,
                                           sex = NULL,
                                           disease = NULL,
                                           treatment = NULL,
                                           cellular_component = NULL,
                                           development = FALSE,
                                           exclude_controls = FALSE,
                                           target = NULL,
                                           target_category = NULL) {
  filters <- list()
  organism <- encode_standard_organism(organism)
  assay <- encode_standard_assay(assay)
  assay_type <- encode_standard_assay_type(assay_type)
  biosample_type <- encode_standard_biosample_type(biosample_type)
  organ <- encode_standard_values(organ, "organ")
  cell <- encode_standard_values(cell, "cell")
  system <- encode_standard_values(system, "system")
  life_stage <- encode_standard_life_stage(life_stage, organism = organism)
  sex <- encode_standard_sex(sex)
  disease <- encode_standard_values(disease, "disease")
  treatment <- encode_standard_values(treatment, "treatment")
  cellular_component <- encode_standard_values(cellular_component, "cellular_component")
  exclude_controls <- encode_standard_flag(exclude_controls, "exclude_controls")
  target <- encode_standard_values(target, "target")
  target_category <- encode_standard_target_category(target_category)

  if (!is.null(organism)) {
    filters[[encode_standard_field(type, "organism")]] <- organism
  }
  if (!is.null(assay)) {
    filters[[encode_standard_assay_field(type, assay$field)]] <- assay$value
  }
  if (!is.null(assay_type)) {
    filters[[encode_standard_field(type, "assay_type")]] <- assay_type
  }
  if (!is.null(biosample_type)) {
    filters[[encode_standard_field(type, "biosample_type")]] <- biosample_type
  }
  if (!is.null(organ)) {
    filters[[encode_standard_field(type, "organ")]] <- organ
  }
  if (!is.null(cell)) {
    filters[[encode_standard_field(type, "cell")]] <- cell
  }
  if (!is.null(system)) {
    filters[[encode_standard_field(type, "system")]] <- system
  }
  if (!is.null(life_stage)) {
    filters[[encode_standard_field(type, "life_stage")]] <- life_stage
  }
  if (!is.null(sex)) {
    filters[[encode_standard_field(type, "sex")]] <- sex
  }
  if (!is.null(disease)) {
    filters[[encode_standard_field(type, "disease")]] <- disease
  }
  if (!is.null(treatment)) {
    filters[[encode_standard_field(type, "treatment")]] <- treatment
  }
  if (!is.null(cellular_component)) {
    filters[[encode_standard_field(type, "cellular_component")]] <- cellular_component
  }
  if (isTRUE(development)) {
    filters[[encode_standard_field(type, "development")]] <- "OrganismDevelopmentSeries"
  }
  if (isTRUE(exclude_controls)) {
    filters[[paste0(encode_standard_field(type, "control_type"), "!")]] <- "*"
  }
  if (!is.null(target)) {
    filters[[encode_standard_field(type, "target")]] <- target
  }
  if (!is.null(target_category)) {
    filters[[encode_standard_field(type, "target_category")]] <- target_category
  }

  filters
}

encode_standard_field <- function(type, field) {
  experiment <- is.null(type) || identical(type, "Experiment")
  file <- identical(type, "File")
  dataset_prefix <- if (isTRUE(file)) "dataset." else ""
  replicate_prefix <- if (isTRUE(file)) {
    "dataset.replicates.library.biosample."
  } else if (isTRUE(experiment)) {
    "replicates.library.biosample."
  } else {
    ""
  }
  switch(
    field,
    assay_type = paste0(dataset_prefix, "assay_slims"),
    biosample_type = paste0(dataset_prefix, "biosample_ontology.classification"),
    organ = paste0(dataset_prefix, "biosample_ontology.organ_slims"),
    cell = paste0(dataset_prefix, "biosample_ontology.cell_slims"),
    system = paste0(dataset_prefix, "biosample_ontology.system_slims"),
    target_category = paste0(dataset_prefix, "target.investigated_as"),
    target = paste0(dataset_prefix, "target.label"),
    development = paste0(dataset_prefix, "related_series.@type"),
    organism = if (isTRUE(file)) {
      "dataset.replicates.library.biosample.organism.scientific_name"
    } else if (isTRUE(experiment)) {
      "replicates.library.biosample.organism.scientific_name"
    } else {
      "organism.scientific_name"
    },
    life_stage = paste0(replicate_prefix, "life_stage"),
    sex = paste0(replicate_prefix, "sex"),
    disease = paste0(replicate_prefix, "disease_term_name"),
    treatment = paste0(replicate_prefix, "treatments.treatment_term_name"),
    cellular_component = paste0(replicate_prefix, "subcellular_fraction_term_name"),
    control_type = if (isTRUE(file)) "dataset.control_type" else "control_type",
    field
  )
}

encode_standard_assay_field <- function(type, field) {
  if (identical(type, "File") && field %in% c("assay_title", "assay_term_name")) {
    return(paste0("dataset.", field))
  }
  field
}

encode_standard_organism <- function(organism) {
  organism <- encode_standard_values(organism, "organism")
  if (is.null(organism)) {
    return(NULL)
  }
  aliases <- c(
    mouse = "Mus musculus",
    mice = "Mus musculus",
    "mus musculus" = "Mus musculus",
    human = "Homo sapiens",
    humans = "Homo sapiens",
    "homo sapiens" = "Homo sapiens"
  )
  vapply(organism, function(value) {
    aliases[[tolower(value)]] %||% value
  }, character(1L), USE.NAMES = FALSE)
}

encode_standard_assay <- function(assay) {
  assay <- encode_standard_values(assay, "assay")
  if (is.null(assay)) {
    return(NULL)
  }
  values <- character()
  fields <- character()
  for (value in assay) {
    mapped <- encode_standard_one_assay(value)
    fields <- c(fields, mapped$field)
    values <- c(values, mapped$value)
  }
  fields <- unique(fields)
  if (length(fields) > 1L) {
    cli::cli_abort(
      "{.arg assay} values must map to one ENCODE assay field. Use separate searches for mixed assay groups."
    )
  }
  list(field = fields[[1L]], value = unique(values))
}

encode_standard_one_assay <- function(assay) {
  key <- gsub("[_ -]+", " ", tolower(assay))
  key <- trimws(key)
  if (key %in% c("rna seq", "rnaseq", "bulk rna seq", "bulk rnaseq", "rna-seq")) {
    return(list(
      field = "assay_title",
      value = c("total RNA-seq", "polyA plus RNA-seq", "polyA minus RNA-seq")
    ))
  }
  if (key %in% c("total rna seq", "total rnaseq", "total rna-seq")) {
    return(list(field = "assay_title", value = "total RNA-seq"))
  }
  if (key %in% c("polya rna seq", "polya plus rna seq", "polya plus rnaseq", "poly a plus rna seq")) {
    return(list(field = "assay_title", value = "polyA plus RNA-seq"))
  }
  if (key %in% c("atac seq", "atacseq", "atac-seq")) {
    return(list(field = "assay_title", value = "ATAC-seq"))
  }
  if (key %in% c("chip seq", "chipseq", "chip-seq")) {
    return(list(field = "assay_term_name", value = "ChIP-seq"))
  }
  if (key %in% c("histone chip seq", "histone chipseq", "histone chip-seq")) {
    return(list(field = "assay_title", value = "Histone ChIP-seq"))
  }
  if (key %in% c("tf chip seq", "tf chipseq", "tf chip-seq", "transcription factor chip seq")) {
    return(list(field = "assay_title", value = "TF ChIP-seq"))
  }
  list(field = "assay_title", value = assay)
}

encode_standard_assay_type <- function(assay_type) {
  assay_type <- encode_standard_values(assay_type, "assay_type")
  if (is.null(assay_type)) {
    return(NULL)
  }
  aliases <- c(
    transcription = "Transcription",
    "dna accessibility" = "DNA accessibility",
    accessibility = "DNA accessibility",
    "dna binding" = "DNA binding",
    "single cell" = "Single cell",
    "rna binding" = "RNA binding",
    "dna methylation" = "DNA methylation",
    methylation = "DNA methylation",
    "3d chromatin structure" = "3D chromatin structure",
    "chromatin structure" = "3D chromatin structure"
  )
  vapply(assay_type, function(value) {
    aliases[[tolower(value)]] %||% value
  }, character(1L), USE.NAMES = FALSE)
}

encode_standard_biosample_type <- function(biosample_type) {
  biosample_type <- encode_standard_values(biosample_type, "biosample_type")
  if (is.null(biosample_type)) {
    return(NULL)
  }
  aliases <- c(
    tissue = "tissue",
    "cell line" = "cell line",
    cellline = "cell line",
    "primary cell" = "primary cell",
    "primary cells" = "primary cell",
    organoid = "organoid",
    organoids = "organoid",
    "whole organism" = "whole organisms",
    "whole organisms" = "whole organisms"
  )
  vapply(biosample_type, function(value) {
    aliases[[tolower(value)]] %||% value
  }, character(1L), USE.NAMES = FALSE)
}

encode_standard_life_stage <- function(life_stage, organism = NULL) {
  life_stage <- encode_standard_values(life_stage, "life_stage")
  if (is.null(life_stage)) {
    return(NULL)
  }
  is_mouse <- any(tolower(organism %||% character()) %in% "mus musculus")
  vapply(life_stage, function(value) {
    key <- gsub("[_ -]+", " ", tolower(value))
    key <- trimws(key)
    aliases <- c(
      embryo = "embryonic",
      embryonic = "embryonic",
      postnatal = "postnatal",
      adult = "adult",
      newborn = "newborn"
    )
    if (key %in% c("fetal", "foetal")) {
      return(if (isTRUE(is_mouse)) "embryonic" else "fetal")
    }
    aliases[[key]] %||% value
  }, character(1L), USE.NAMES = FALSE)
}

encode_standard_sex <- function(sex) {
  sex <- encode_standard_values(sex, "sex")
  if (is.null(sex)) {
    return(NULL)
  }
  aliases <- c(
    female = "female",
    male = "male",
    mixed = "mixed",
    "mixed sex" = "mixed",
    unknown = "unknown"
  )
  vapply(sex, function(value) {
    aliases[[tolower(value)]] %||% value
  }, character(1L), USE.NAMES = FALSE)
}

encode_standard_target_category <- function(target_category) {
  target_category <- encode_standard_values(target_category, "target_category")
  if (is.null(target_category)) {
    return(NULL)
  }
  aliases <- c(
    histone = "histone",
    tf = "transcription factor",
    "transcription factor" = "transcription factor",
    "rna binding protein" = "RNA binding protein",
    rbp = "RNA binding protein",
    cofactor = "cofactor",
    cohesin = "cohesin",
    "chromatin remodeler" = "chromatin remodeler"
  )
  vapply(target_category, function(value) {
    aliases[[tolower(value)]] %||% value
  }, character(1L), USE.NAMES = FALSE)
}

encode_standard_scalar <- function(x, arg) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    cli::cli_abort("{.arg {arg}} must be one non-empty string.")
  }
  trimws(x)
}

encode_standard_values <- function(x, arg) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.character(x) || any(is.na(x))) {
    cli::cli_abort("{.arg {arg}} must be a non-empty character vector.")
  }
  x <- unique(trimws(x))
  x <- x[nzchar(x)]
  if (length(x) == 0L) {
    cli::cli_abort("{.arg {arg}} must be a non-empty character vector.")
  }
  x
}

encode_standard_flag <- function(x, arg) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be TRUE or FALSE.")
  }
  x
}

encode_merge_search_filters <- function(standard, filters) {
  if (length(filters) == 0L) {
    return(standard)
  }
  for (name in names(filters)) {
    standard[[name]] <- filters[[name]]
  }
  standard
}

encode_search_terms <- function(search, biosample = NULL) {
  biosample <- encode_standard_scalar(biosample, "biosample")
  if (is.null(search) && is.null(biosample)) {
    return(NULL)
  }
  terms <- c(search %||% character(), biosample %||% character())
  terms <- unique(trimws(terms[nzchar(trimws(terms))]))
  paste(terms, collapse = " ")
}

#' Count ENCODE search matches
#'
#' Return only the number of matching records. Use this for broad queries when
#' the row count matters but the result rows do not.
#'
#' `encode_search()` already reports both returned rows and total matches.
#'
#' @inheritParams encode_search
#' @param metadata How much linked metadata to request. The default `"basic"`
#'   keeps the count request small because no result rows are returned.
#'
#' @return A query count. Printing shows the total number of matching records.
#' @noRd
#'
encode_count <- function(
                         type = "Experiment",
                         filters = list(),
                         search = NULL,
                         status = "released",
                         metadata = c("basic", "full"),
                         quiet = FALSE) {
  metadata_request <- encode_metadata_request(metadata)
  result <- encode_search(
    type = type,
    filters = filters,
    search = search,
    status = status,
    limit = 0,
    metadata = metadata_request$metadata,
    include_facets = FALSE,
    quiet = TRUE
  )
  out <- list(
    total = result$total,
    total_results = result$total,
    filters = result$filters,
    query_url = result$query_url,
    url = result$url,
    encode_base_url = result$encode_base_url,
    metadata = metadata_request$metadata,
    frame = metadata_request$frame,
    request = result$request
  )
  class(out) <- c("encode_count_result", "list")
  if (!isTRUE(quiet)) {
    cli::cli_inform("ENCODE count successfully found {out$total} matching record(s).")
    cli::cli_inform(
      "Returned a query count. Print the result to view it."
    )
  }
  out
}

#' Filter an ENCODE result table in R
#'
#' Filter an ENCODE result table without making another web request. Values are
#' matched exactly by default.
#'
#' @param x A search result from `encode_search()` or a data frame.
#' @param filters Named list of columns and values to keep.
#' @param ignore_case Whether character matching should ignore case.
#'
#' @return A filtered data frame.
#'
#' @examples
#' results <- data.frame(
#'   accession = c("ENCSR000AAA", "ENCSR000AAB"),
#'   assay_title = c("total RNA-seq", "ChIP-seq")
#' )
#' encode_filter_results(results, list(assay_title = "total RNA-seq"))
#' @noRd
encode_filter_results <- function(x, filters = list(), ignore_case = TRUE) {
  encode_validate_filters(filters)
  table <- if (inherits(x, "encode_search_result")) {
    x$results
  } else if (is.data.frame(x)) {
    x
  } else {
    cli::cli_abort("{.arg x} must be an ENCODE search result or data frame.")
  }

  keep <- rep(TRUE, nrow(table))
  for (field in names(filters)) {
    if (!field %in% names(table)) {
      cli::cli_abort("Column {.field {field}} is not present in {.arg x}.")
    }
    values <- filters[[field]]
    column <- table[[field]]
    if (is.character(column) && isTRUE(ignore_case)) {
      column <- tolower(column)
      values <- tolower(as.character(values))
    }
    keep <- keep & column %in% values
  }
  table[keep, , drop = FALSE]
}
