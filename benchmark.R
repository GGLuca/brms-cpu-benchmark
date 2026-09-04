# Packages

library(brms)
library(readr)
library(tidyverse)

# Data file

benchmark <- read_csv("benchmark.csv")

machine   <- "M4Max"      # label for this computer
threads   <- 3            # 1 = no within-chain threading; 2, 3, ... = threading(k)

benchmark <- read_csv("benchmark.csv", show_col_types = FALSE)

runtime   <- system.time({
  model_poisson <- brm(
    y ~ 1 + x1 + x2 + (1 | g),
    data = benchmark,
    family = poisson(),
    iter = 4000,
    warmup = 2000,
    chains = 4,
    cores = 4,
    threads = if (threads > 1) threading(threads) else NULL,
    seed = 1234,
    prior = prior(normal(0, 1), class = b) +
      prior(constant(1), class = sd, group = g),
    backend = "cmdstanr",
    save_pars = save_pars(all = TRUE)
  )
})

# timings
# per-chain seconds as reported by CmdStan (this inclues warmup and sampling)

chain_time <- rowSums(rstan::get_elapsed_time(model_poisson$fit))
mean_chain <- mean(chain_time)          # Mean chain execution time
total_exec <- max(chain_time)           # Total execution time (the slowest chain)
elapsed    <- runtime[["elapsed"]]      # Timing for the whole brm() call
overhead   <- elapsed - total_exec      # compile (if any) + code gen + read-back

result <- data.frame(
  machine     = machine,
  threads     = threads,
  mean_chain  = round(mean_chain, 1),
  total_exec  = round(total_exec, 1),
  elapsed     = round(elapsed, 1),
  overhead    = round(overhead, 1),
  brms        = as.character(packageVersion("brms")),
  cmdstan     = as.character(cmdstanr::cmdstan_version()),
  r           = R.version.string,
  date        = format(Sys.Date())
)

print(result)

# results.csv (created on first run)
write_csv(result, "results.csv", append = file.exists("results.csv"))
