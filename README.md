
<!-- README.md is generated from README.Rmd. Please edit that file -->

# `brms` CPU benchmark

This repo contains a small, reproducible benchmark for how fast a modern
computer samples a typical psychology model with **brms / CmdStan**,
with wall time as a user experiences it, with and without within-chain
threading, though the times obtained with threading are of interest.

## How to run it

Copy/paste into the console, but beware of your own specs before setting
the treads argument.

``` r
source("https://raw.githubusercontent.com/GGLuca/brms-cpu-benchmark/main/run_benchmark.R")
run_benchmark(threads = 1:2, reps = 2)   # keep 4 x threads <= your fast physical cores
```

Needs R, `brms`, `cmdstanr` and a working CmdStan
(`cmdstanr::install_cmdstan()`). Each run appends one row to
`results.csv` in your working directory and prints it. The first run of
each thread setting includes compilation (visible in `overhead`); the
second is the clean one. Laptops should be plugged in and on Linux, set
the CPU governor to `performance`.

## Report it

If you wish, paste your rows as a [GitHub
issue](https://github.com/GGLuca/brms-cpu-benchmark/issues) and also
please say whether the laptop was on power (if on Windoze) and, on
Linux, which governor was active. Rows are merged into `results.csv` by
me as soon as I get them.

## The benchmark

The function uses synthetic data, which is a modified version of the
data in the [within-chain parallelization
vignette](https://cran.r-project.org/web/packages/brms/vignettes/brms_threading.html)
(Weber & Bürkner, 2025). It has 10000 observations in 1000 groups.

The model is a simple Poisson multilevel model with two predictors and
clustering (random intercept, fixed slopes), also from the vignette. It
uses 4,000 iterations per chain, the first 2,000 being warmup. The
benchmark assumes at least 4 physical cores and runs 4 chains in
parallel, one per core.

## Arguments

- The `threads` argument sets the number of within-chain threads per
  chain. At `threads = 1`, each chain runs on a single core (4 cores in
  total). At `threads = 2`, each chain’s likelihood is split across 2
  threads, so 4 × 2 = 8 cores are used; `threads = 3` uses 12 cores, and
  so on. Keep 4 × threads at or below the number of *fast* physical
  cores (P-cores on Apple Silicon; real cores, not SMT threads, on x86).
  The function will warn you when you exceed it.

- The `reps` argument sets how many times each thread setting is run
  (default at 1). With `reps = 2` you get a replicate row for every
  setting, which shows how much run-to-run variation there is, and the
  second row of each pair is free of compilation time.

- The `machine` argument is the label written to the `machine` column.
  If you leave it out the function reads the CPU name from the operating
  system. I think it is desirable like this. Pass a string
  (e.g. `"M4Pro 8P"`) to override it, if you wish so.

The `brm()` call inside `run_benchmark()`:

``` r
brm(
  y ~ 1 + x1 + x2 + (1 | g),
  data = benchmark, family = poisson(),
  iter = 4000, warmup = 2000,
  chains = 4, cores = 4,
  threads = if (k > 1) threading(k) else NULL,
  seed = 1234,
  prior = prior(normal(0, 1), class = b) +
          prior(constant(1), class = sd, group = g),
  backend = "cmdstanr",
  save_pars = save_pars(all = TRUE)
)
```

This measures end-to-end sampling time for a standard call.

## What the columns mean in the results.csv

| column | what it is | compare across machines? |
|:---|:---|:---|
| `mean_chain` | mean per-chain seconds from CmdStan’s own clock (warmup + sampling) | **yes, the benchmark** |
| `total_exec` | slowest chain; wall time of the sampling phase | yes, also |
| `elapsed` | the whole `brm()` call: code generation + compile (if any) + sampling + read-back | no |
| `overhead` | `elapsed − total_exec`; ~4–5 s when cached, 15–80 s when a compile happened | no |
| `fast_cores` | fast physical cores detected on the machine | not really |

## Results

Mean chain time in seconds; the lowest of the replicate runs is shown
(the cached run). Speed-up relative to `threads = 1` in parentheses.

| machine      | 1 thread |      2 threads |
|:-------------|---------:|---------------:|
| Apple M4 Pro |   45.4 s | 32.9 s (1.38×) |

![](figures/unnamed-chunk-5-1.png)<!-- -->

## Files

- `run_benchmark.R`. the function; `source()` it and call
  `run_benchmark()`
- `benchmark.csv`. the data
- `results.csv`. all rows so far, one per run

## References

Weber, S., & Bürkner, P.-C. (2025). *Running brms models with
within-chain parallelization* \[Package vignette\]. brms (Version
2.23.0).
<https://cran.r-project.org/web/packages/brms/vignettes/brms_threading.html>
