# Demo traceroute workflow (without Shiny)
# Запускать из корня проекта: source("inst/extras/trace_demo.R")

targets <- c("1.1.1.1", "8.8.8.8")

if (!trace_check_available()) {
  stop("Не найден traceroute/tracert в системе. Установите утилиту или добавьте в PATH.")
}

cat("Running traceroute for:", paste(targets, collapse = ", "), "\n")

raw_list <- trace_run_many(targets, max_hops = 20, timeout = 2, queries = 3)

parsed <- trace_parse_many(raw_list)
cat("Parsed rows:", nrow(parsed), "\n")

# ---- ASN resolve integration ----
# ВАРИАНТ 1: передать asn_ranges от человека №2 (data.frame с ip_from/ip_to/asn/...)
# asn_ranges <- your_pkg::get_asn_ranges()

# ВАРИАНТ 2: передать resolver-функцию
# resolver <- function(ip_vec) your_pkg::asn_lookup(ip_vec)

asn_ranges <- NULL
resolver <- NULL

enriched <- route_enrich(parsed, asn_ranges = asn_ranges, resolver = resolver)
summ <- route_summarize(enriched)
edges <- route_edges(enriched, level = "asn")

print(summ)
print(head(edges, 20))

# Можно сохранить результаты
# write.csv(enriched, "trace_enriched.csv", row.names = FALSE)
# write.csv(edges, "trace_edges.csv", row.names = FALSE)
