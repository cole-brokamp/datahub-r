#!/usr/bin/env Rscript

stopifnot(
  identical(as.character(getRversion()), "4.6.1"),
  identical(
    unname(getOption("repos")[["CRAN"]]),
    "https://packagemanager.posit.co/cran/__linux__/noble/latest"
  )
)

required <- c(
  "needenv",
  "DBI",
  "odbc",
  "dplyr",
  "dbplyr",
  "nanoparquet",
  "bit64",
  "pak",
  "renv"
)

stopifnot(
  all(vapply(required, requireNamespace, logical(1L), quietly = TRUE)),
  packageVersion("needenv") == package_version("0.1.0"),
  exists("datahub_connect", envir = globalenv(), mode = "function", inherits = FALSE),
  startsWith(
    normalizePath(.libPaths()[[1L]], mustWork = TRUE),
    normalizePath(
      path.expand("~/.local/share/datahub-r/v1/R-4.6/library"),
      mustWork = TRUE
    )
  )
)

drivers <- odbc::odbcListDrivers()
driver_names <- if (ncol(drivers) > 0L) as.character(drivers[[1L]]) else character()
stopifnot("ODBC Driver 18 for SQL Server" %in% driver_names)

message("datahub-r image smoke test passed")
