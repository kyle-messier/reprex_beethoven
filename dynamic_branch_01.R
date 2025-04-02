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
        bsamples <- rsample::mc_cv(mtcars, prop = 1/3, times = 20)
        b_train <- lapply(1:nrow(bsamples), function(i){
          rsample::training(bsamples$splits[[i]])})
        b_test <- lapply(1:nrow(bsamples), function(i){
          rsample::assessment(bsamples$splits[[i]])})          
        b_cv <- lapply(1:length(b_train), \(x) rsample::vfold_cv(b_train[[x]], v = 5))
       res <- lapply(1:20, \(x) {
        list(b_cv[[x]], b_train[[x]], b_test[[x]])
        })
        },
      iteration = "list"),
      tar_target(tune_fit, {
        tune_workflow <- workflow |>
          tune::tune_grid(resamples = subsample[[1]], metrics = yardstick::metric_set(yardstick::rmse),
                          grid = 10,
                          control =  tune::control_grid(
                            verbose = TRUE,
                            save_pred = TRUE
                          ))

         best_workflow <- tune_workflow |>
          tune::select_best(metric = "rmse")

         final_wf <-  tune::finalize_workflow(workflow, best_workflow) 
         final_fit <- fit(final_wf, data = subsample[[2]]) |> butcher::butcher()
        results <- list("workflow" = final_fit, "metrics" = tune::collect_metrics(tune_workflow))


     },
     pattern = map(subsample),
     iteration = "list"),
     tar_target(oos_predict, 
     command = {
        pred <- predict(tune_fit[[1]], new_data = subsample[[3]]) |>
          dplyr::bind_cols(subsample[[3]]) |>
          dplyr::select(.pred, mpg) |>
          dplyr::mutate(.pred = round(.pred, 2), mpg = round(mpg, 2))
     },
     pattern = map(subsample, tune_fit),
     iteration = "list")
    )
  })
  tar_make()
  res <- targets::tar_read(tune_fit)
  pred <- targets::tar_read(oos_predict)
})
