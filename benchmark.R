## run_benchmark.R
##
## brms / CmdStan CPU benchmark. Same model, data and settings as the
## Dec-2024 Stan forum post; wall-time as a user experiences it.
##
## Usage:
##   source("run_benchmark.R")
##   run_benchmark()                                  # this machine, 4 chains, threads = 1
##   run_benchmark(threads = 1:2, reps = 2)           # sweep with replication
##   run_benchmark(chains = 3, threads = 2)           # 6-core machine: 3 chains x 2 threads
##   run_benchmark(machine = "M4Pro 8P", threads = 2) # override the label
##
## Rule: chains x threads <= number of fast physical cores.

library(brms)
library(readr)

## ---- CPU name and number of *fast* physical cores -------------------------
## detectCores() counts P- and E-cores together on Apple Silicon and SMT
## threads on some Linux kernels -- both are the wrong number for
## "how many threads can I run without slowing down".
cpu_info <- function() {
  os <- Sys.info()[["sysname"]]
  if (os == "Darwin") {
    name <- system("sysctl -n machdep.cpu.brand_string", intern = TRUE)
    fast <- as.integer(system("sysctl -n hw.perflevel0.physicalcpu", intern = TRUE))
  } else if (os == "Linux") {
    ci      <- readLines("/proc/cpuinfo")
    name    <- trimws(sub("model name\\s*:", "", grep("model name", ci, value = TRUE)[1]))
    cores   <- as.integer(sub("cpu cores\\s*:", "", grep("cpu cores", ci, value = TRUE)[1]))
    sockets <- length(unique(grep("physical id", ci, value = TRUE)))
    fast    <- cores * max(sockets, 1)
  } else {                                          # Windows
    name <- trimws(system("wmic cpu get name", intern = TRUE)[2])
    fast <- parallel::detectCores(logical = FALSE)
  }
  list(name = name, fast_cores = fast, os = paste(os, Sys.info()[["release"]]))
}

## ---- The benchmark ---------------------------------------------------------
run_benchmark <- function(machine = NULL,
                          threads = 1,
                          chains  = 4,
                          reps    = 1,
                          data    = "https://raw.githubusercontent.com/GGLuca/brms-cpu-benchmark/refs/heads/master/benchmark.csv",
                          out     = "results.csv") {

  cpu <- cpu_info()
  if (is.null(machine)) machine <- cpu$name

  over <- threads[chains * threads > cpu$fast_cores]
  if (length(over) > 0) {
    warning(sprintf("chains = %d with threads = %s uses more than the %d fast cores on this machine; ",
                    chains, paste(over, collapse = ", "), cpu$fast_cores),
            "expect one or more chains to lag.", call. = FALSE)
  }

  benchmark <- read_csv(data, show_col_types = FALSE)

  one_run <- function(k) {
    runtime <- system.time({
      fit <- brm(
        y ~ 1 + x1 + x2 + (1 | g),
        data = benchmark, family = poisson(),
        iter = 4000, warmup = 2000,
        chains = chains, cores = chains,
        threads = if (k > 1) threading(k) else NULL,
        seed = 1234,
        prior = prior(normal(0, 1), class = b) +
          prior(constant(1), class = sd, group = g),
        backend = "cmdstanr",
        save_pars = save_pars(all = TRUE),
        refresh = 0, silent = 2
      )
    })

    ## per-chain seconds from CmdStan's own clock (warmup + sampling)
    chain_time <- rowSums(rstan::get_elapsed_time(fit$fit))

    data.frame(
      machine    = machine,
      fast_cores = cpu$fast_cores,
      chains     = chains,
      threads    = k,
      mean_chain = round(mean(chain_time), 1),                 # the benchmark number
      total_exec = round(max(chain_time), 1),                  # slowest chain
      elapsed    = round(runtime[["elapsed"]], 1),             # whole brm() call
      overhead   = round(runtime[["elapsed"]] - max(chain_time), 1),  # compile (if any) + read-back
      brms       = as.character(packageVersion("brms")),
      cmdstan    = as.character(cmdstanr::cmdstan_version()),
      r          = R.version.string,
      os         = cpu$os,
      date       = format(Sys.Date())
    )
  }

  results <- do.call(rbind, lapply(threads, function(k) {
    message(sprintf("[%s] chains = %d, threads = %d  (%d of %d fast cores)",
                    machine, chains, k, chains * k, cpu$fast_cores))
    do.call(rbind, lapply(seq_len(reps), function(i) one_run(k)))
  }))

  write_csv(results, out, append = file.exists(out))
  print(results, row.names = FALSE)
  invisible(results)
}
