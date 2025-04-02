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
    list(
      tar_target(workflow, {
        base_engine <-
          parsnip::linear_reg(
            mixture = parsnip::tune(),
            penalty = parsnip::tune()
          ) |>
          parsnip::set_engine("glmnet") |>
          parsnip::set_mode("regression")

        base_recipe <- recipes::recipe(mtcars) |>
          recipes::update_role(mpg, new_role = "outcome") |>
          recipes::update_role(names(mtcars[1, -1]), new_role = "predictor") 

         base_workflow <-
          workflows::workflow() |>
          workflows::add_model(base_engine) |>
          workflows::add_recipe(base_recipe)


          base_workflow 
      }),
      tar_target(subsample,
        {
        rsample::vfold_cv(mtcars, v = 10)
        },
      iteration = "list"),
      tar_target(tune_fit, {
        tune_workflow <- workflow |>
          tune::tune_grid(resamples = subsample, metrics = yardstick::metric_set(yardstick::rmse),
                          grid = 10,
                          control =  tune::control_grid(
                            verbose = TRUE,
                            save_pred = TRUE
                          ))

         best_workflow <- tune_workflow |>
          tune::select_best(metric = "rmse")

         final_wf <-  tune::finalize_workflow(workflow, best_workflow) 
         final_fit <- fit(final_wf, data = mtcars) |> butcher::butcher()
        results <- list("workflow" = final_fit, "metrics" = tune::collect_metrics(tune_workflow))


     },
     iteration = "list")
    )
  })
  tar_make()
  res <- targets::tar_read(tune_fit)
})
