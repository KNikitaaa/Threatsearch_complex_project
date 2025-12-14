#' Enrich trace with ASN info and cleanup
#'
#' @param trace_df output of trace_parse()
#' @param asn_ranges data.frame ranges (см. asn_resolve_df)
#' @param resolver optional resolver function
#'
#' @return data.frame with asn/as_name/prefix added and some derived fields
#' @export
route_enrich <- function(trace_df, asn_ranges = NULL, resolver = NULL) {
  if (!nrow(trace_df)) return(trace_df)
  
  # добавим ASN
  enriched <- asn_resolve_df(trace_df, ip_col = "ip", asn_ranges = asn_ranges, resolver = resolver)
  
  # производные поля
  enriched$hop <- as.integer(enriched$hop)
  enriched$probe <- as.integer(enriched$probe)
  enriched$is_timeout <- is.na(enriched$ip) | enriched$status == "timeout"
  enriched$is_ok <- !enriched$is_timeout & enriched$status == "ok"
  
  enriched
}

#' Summarize route quality and AS-path
#'
#' @param trace_enriched output of route_enrich
#'
#' @return list summary
#' @export
route_summarize <- function(trace_enriched) {
  if (!nrow(trace_enriched)) {
    return(list(
      targets = character(),
      hops_max = 0L,
      probes_total = 0L,
      timeout_share = NA_real_,
      unique_asn_path = integer(),
      as_path_length = 0L
    ))
  }
  
  hops_max <- max(trace_enriched$hop, na.rm = TRUE)
  probes_total <- nrow(trace_enriched)
  
  timeout_share <- mean(trace_enriched$status == "timeout" | is.na(trace_enriched$ip), na.rm = TRUE)
  
  # AS path: берём по hop первый ненулевой ASN
  by_hop <- split(trace_enriched, trace_enriched$hop)
  hop_asn <- vapply(by_hop, function(d) {
    a <- d$asn[!is.na(d$asn)]
    if (length(a) == 0) NA_integer_ else as.integer(a[1])
  }, integer(1))
  
  # уникальный путь (с сохранением порядка)
  uniq_asn <- hop_asn[!is.na(hop_asn)]
  uniq_asn <- uniq_asn[c(TRUE, diff(uniq_asn) != 0)]
  list(
    targets = unique(trace_enriched$target),
    hops_max = as.integer(hops_max),
    probes_total = as.integer(probes_total),
    timeout_share = timeout_share,
    unique_asn_path = uniq_asn,
    as_path_length = as.integer(length(uniq_asn))
  )
}

#' Build edges between hops or ASNs
#'
#' @param trace_enriched output of route_enrich
#' @param level "ip" or "asn"
#'
#' @return data.frame edges (from,to,count)
#' @export
route_edges <- function(trace_enriched, level = c("asn", "ip")) {
  level <- match.arg(level)
  if (!nrow(trace_enriched)) return(data.frame())
  
  # Берём по hop один представитель (первый ok)
  by_hop <- split(trace_enriched, trace_enriched$hop)
  rep <- lapply(by_hop, function(d) {
    ok <- d[d$status == "ok" & !is.na(d$ip), , drop = FALSE]
    if (nrow(ok) == 0) {
      # fallback — хоть что-то
      d[1, , drop = FALSE]
    } else ok[1, , drop = FALSE]
  })
  rep <- do.call(rbind, rep)
  rep <- rep[order(rep$hop), , drop = FALSE]
  
  from <- if (level == "asn") rep$asn else rep$ip
  to <- c(from[-1], NA)
  
  edges <- data.frame(
    from = from,
    to = to,
    stringsAsFactors = FALSE
  )
  edges <- edges[!is.na(edges$from) & !is.na(edges$to), , drop = FALSE]
  if (!nrow(edges)) return(data.frame(from = character(), to = character(), count = integer()))
  
  # агрегация
  key <- paste(edges$from, edges$to, sep = "->")
  tab <- table(key)
  parts <- strsplit(names(tab), "->", fixed = TRUE)
  data.frame(
    from = vapply(parts, `[[`, character(1), 1),
    to = vapply(parts, `[[`, character(1), 2),
    count = as.integer(tab),
    stringsAsFactors = FALSE
  )
}

#' Compare two enriched traces
#'
#' @param a trace_enriched
#' @param b trace_enriched
#' @return list with summaries and differences
#' @export
route_compare <- function(a, b) {
  sa <- route_summarize(a)
  sb <- route_summarize(b)
  
  list(
    a = sa,
    b = sb,
    asn_common = intersect(sa$unique_asn_path, sb$unique_asn_path),
    asn_only_a = setdiff(sa$unique_asn_path, sb$unique_asn_path),
    asn_only_b = setdiff(sb$unique_asn_path, sa$unique_asn_path)
  )
}
