# Network health checks (basic)
# Запуск: source("inst/extras/network_test.R")

cat("OS:", detect_os(), "\n")

ok_trace <- trace_check_available()
cat("Traceroute available:", ok_trace, "\n")
if (!ok_trace) {
  stop("Нет traceroute/tracert. Установите утилиту (Linux: traceroute пакет; Windows: обычно есть).")
}

cat("Ping 8.8.8.8:", ping_check("8.8.8.8", count = 1, timeout = 2), "\n")

# Minimal traceroute test
tgt <- "1.1.1.1"
cat("Traceroute test target:", tgt, "\n")
raw <- trace_run(tgt, max_hops = 10, timeout = 2, queries = 3)
parsed <- trace_parse(raw)

cat("Parsed hops:", length(unique(parsed$hop)), "\n")
cat("Timeout share:", mean(parsed$status == "timeout" | is.na(parsed$ip), na.rm = TRUE), "\n")

# Basic assertion-style checks
if (!nrow(parsed)) stop("Парсер не вернул строк. Проверьте формат вывода traceroute для вашей ОС.")
cat("OK\n")
