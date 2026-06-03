# LI Lab Workflow

A research workflow template for the [Learning and Instruction Lab](https://li.ethz.ch/) at ETH Zürich, covering experiment planning through to inference.

## Contents

| Chapter | Topic |
|---|---|
| 1. Planning | Simulate data, fit pilot models, determine sample size |
| 2. Preregistration | What to preregister and how |
| 3. Wrangling | Import, clean, and reshape data |
| 4. Modelling | Fit multilevel Bayesian regression models with CmdStan/brms |
| 5. Effects | Generate and communicate inferences |

## Reproducibility

All model fits and simulation outputs are pre-compiled and stored in `models/` and `data/`. The book renders from these saved outputs by default — no waiting for models to fit.

To refit a model or rerun simulations from scratch, set `eval: true` on the relevant chunk (marked `# set eval: true to refit`). 
Model fitting requires CmdStan.

## Reading the book

🔗 [rich-ramsey.github.io/li-lab-workflow/](https://rich-ramsey.github.io/li-lab-workflow/) 

Or clone the repo and run `quarto preview` locally.

## Software

R, Quarto, brms, cmdstanr, tidyverse, faux, tidybayes.