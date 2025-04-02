#reprex the dynamic branching for a list of lists

library(targets)
library(tarchetypes)
library(reprex)
library(tidymodels)
library(tidyverse)
library(tune)
#nolint start
tar_dir({
tar_script({
    list(tar_target(boot_mtcars, {
        rset <- rsample::bootstraps(mtcars,times = 10) 
        rset
      },
        iteration = "list"),
      tarchetypes::tar_group_by(boot_rows,boot_mtcars, id),
      tar_target(subsample, rsample::vfold_cv(rsample::training(boot_rows$splits[[1]]), v = 5), 
        pattern = map(boot_rows), 
        iteration = "list")
    )
})
tar_make()
# Read the first row group:
b <- targets::tar_read(subsample)
# Read the second row group:
b2 <- targets::tar_read(subsample, branches = 2)
})
 