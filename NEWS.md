## CHANGES IN VERSION 0.99.0

NEW FEATURES

    o Rename the package and repository target to encodeUtils.

    o Add the core ENCODE metadata workflow: encode_search(), encode_get(),
      encode_matrix(), encode_report(), encode_list_files(), encode_download(),
      encode_read(), encode_get_schema(), and encode_cite().

    o Add lightweight console helpers encode_browse(), encode_select(), and
      encode_filter_results().

    o Add file decision-support helpers encode_select_files(),
      encode_file_preset(), encode_file_summary(), encode_size(), and
      encode_largest_files().

    o Add encode_count() for live query-count preflights without retrieving
      full result sets.

    o Add encode_preview_download() for printable download plans with size
      lower bounds, unknown-size counts, destination paths, checksum
      availability, and required overrides.

    o Add encode_explain_selection() for tidy selected/excluded file-selection
      decisions.

    o Add ENCODE preferred-default awareness to file metadata and selection.
      encode_list_files() now surfaces preferred_default and analysis-related
      metadata when present, and encode_select_files() can use
      prefer_default = TRUE.

    o Add assay-aware file-selection presets such as chipseq_peaks,
      chipseq_signal, atacseq_peaks, rnaseq_gene_quant, and
      rnaseq_transcript_quant.

    o Add user-centered preset aliases raw_fastq, chipseq_idr_peaks,
      chipseq_signal_bigwig, rna_gene_counts, rna_gene_tpm, and
      rna_transcript_quant.

    o Add query/provenance helpers encode_query_url(), encode_filters(),
      encode_facets(), encode_search_fields(), encode_manifest(), and
      encode_write_manifest().

    o Add conservative HTTP handling with bounded retries, timeout support,
      client-side throttling, clear ENCODE error messages, and raw JSON
      preservation.

    o Add download guardrails for planned size, per-file size, existing files,
      temporary partial downloads, file-size verification, and MD5 verification.

    o Preserve successful rows in multi-file downloads when one file fails
      transfer or verification; failed rows carry download_status and
      failure_reason.

    o Add stronger local-read guardrails for FASTQ, alignment files, and indexed
      signal/annotation files.

    o Add real text and markdown citation styles and optional parent-experiment
      enrichment for file-table citations.

    o Add a package-level inst/CITATION file.

SIGNIFICANT USER-VISIBLE CHANGES

    o The package is now named encodeUtils rather than encodeapiutil.

    o Citation helpers focus on dataset and file provenance. They do not
      fabricate BibTeX records for ENCSR or ENCFF accessions.

    o encode_cite() now defaults to enrich = "auto" for bounded parent
      experiment enrichment. Use enrich = FALSE for strictly offline
      provenance tables.

    o encode_download() now refuses real downloads with missing file_size unless
      allow_unknown_size = TRUE. Dry-runs and previews report unknown-size
      counts and known-size lower bounds.

    o encode_download(verify = NULL) now correctly disables size and MD5
      verification instead of erroring during argument normalization.

    o File search results now print with the same concise ENCODE file-table
      summary used by encode_list_files(), while preserving complete metadata
      columns for downloads, manifests, and advanced inspection.

    o encode_search(), encode_get(), and encode_report(endpoint = "search") now
      default to frame = "embedded" so compact summaries include useful linked
      lab, award, and biosample metadata. Use frame = "object" for smaller
      responses.

    o encode_select_files() now uses preset rather than use for file-selection
      presets.

    o Pre-release aliases encode_files(), encode_schema(), encode_citation(),
      and encode_interactive_search() were removed in favor of the canonical
      names encode_list_files(), encode_get_schema(), encode_cite(), and
      encode_browse(..., select = TRUE).
