#' Traceroute core runner
#'
#' Runs traceroute/tracert, returns raw output strings + metadata.
#'
#' @param target Host/domain/IP.
#' @param max_hops Maximum hops.
#' @param timeout Timeout (sec). For tracert interpretation differs.
#' @param queries Number of probes per hop (Linux/mac traceroute).
#' @param method Execution method: "system" (via system2).
#' @param ... Additional parameters (not used yet).
#'
#' @return Object of class trace_raw (list).
#' @export
trace_run <- function(target,
                      max_hops = 30,
                      timeout  = 2,
                      queries  = 3,
                      method   = c("system"),
                      ...) {
  
  method <- match.arg(method)
  os <- detect_os()
  
  cmd <- trace_cmd_build(
    target = target,
    os = os,
    max_hops = max_hops,
    timeout = timeout,
    queries = queries
  )
  
  out <- safe_system2(cmd$command, cmd$args)
  
  res <- list(
    target = target,
    raw = out,
    meta = list(
      os = os,
      command = cmd$command,
      args = cmd$args,
      max_hops = max_hops,
      timeout = timeout,
      queries = queries
    )
  )
  class(res) <- c("trace_raw", class(res))
  res
}

#' Run traceroute for many targets
#'
#' @param targets character vector.
#' @param parallel logical (пока FALSE — заглушка).
#' @inheritParams trace_run
#'
#' @return list of trace_raw
#' @export
trace_run_many <- function(targets,
                           max_hops = 30,
                           timeout  = 2,
                           queries  = 3,
                           method   = c("system"),
                           parallel = FALSE,
                           ...) {
  method <- match.arg(method)
  if (parallel) {
    warning("parallel=TRUE not implemented yet; running sequentially.")
  }
  lapply(targets, function(tg) trace_run(
    target = tg,
    max_hops = max_hops,
    timeout = timeout,
    queries = queries,
    method = method,
    ...
  ))
}

#' Build traceroute command by OS
#'
#' @param target host/ip
#' @param os linux|mac|windows
#' @param max_hops integer
#' @param timeout numeric seconds
#' @param queries integer
#'
#' @return list(command=..., args=...)
#' @export
trace_cmd_build <- function(target,
                            os = c("linux", "mac", "windows"),
                            max_hops = 30,
                            timeout  = 2,
                            queries  = 3) {
  os <- match.arg(os)
  
  if (os == "windows") {
    # tracert: -h max_hops; -w timeout_ms
    cmd <- "tracert"
    args <- c("-h", as.character(max_hops), "-w", as.character(as.integer(timeout * 1000)), target)
    return(list(command = cmd, args = args))
  }
  
  # linux/mac traceroute: -m max_hops; -w timeout; -q queries
  cmd <- "traceroute"
  args <- c(
    "-m", as.character(max_hops),
    "-w", as.character(timeout),
    "-q", as.character(queries),
    target
  )
  list(command = cmd, args = args)
}

#' Check traceroute availability
#'
#' @return TRUE/FALSE
#' @export
trace_check_available <- function() {
  os <- detect_os()
  bin <- if (os == "windows") "tracert" else "traceroute"
  nzchar(Sys.which(bin))
}
