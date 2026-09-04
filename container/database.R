datahub_r_database_profile <- function(profile = Sys.getenv(
  "DATAHUB_R_DB_PROFILE",
  unset = "MBHI"
)) {
  if (
    length(profile) != 1L ||
      is.na(profile) ||
      !nzchar(profile) ||
      !grepl("^[A-Za-z][A-Za-z0-9_]*$", profile)
  ) {
    stop(
      "database profile must start with a letter and contain only letters, numbers, and underscores",
      call. = FALSE
    )
  }

  toupper(profile)
}

datahub_r_database_config <- function(profile = Sys.getenv(
  "DATAHUB_R_DB_PROFILE",
  unset = "MBHI"
)) {
  profile <- datahub_r_database_profile(profile)
  variable <- function(suffix) paste0(profile, "_DB_", suffix)

  host_var <- variable("HOST")
  name_var <- variable("NAME")
  username_var <- variable("USERNAME")
  password_var <- variable("PASSWORD")

  values <- needenv::needenv(.vars = c(
    host_var,
    username_var,
    password_var
  ))
  database <- Sys.getenv(name_var, unset = profile)
  if (!nzchar(database)) {
    database <- profile
  }

  structure(
    list(
      profile = profile,
      host = values[[host_var]],
      database = database,
      username = values[[username_var]],
      password = values[[password_var]]
    ),
    class = c("datahub_r_database_config", "list")
  )
}

datahub_r_database_connect <- function(
  profile = Sys.getenv("DATAHUB_R_DB_PROFILE", unset = "MBHI"),
  config = datahub_r_database_config(profile)
) {

  DBI::dbConnect(
    odbc::odbc(),
    Driver = "ODBC Driver 18 for SQL Server",
    Server = config$host,
    Database = config$database,
    UID = config$username,
    PWD = config$password,
    Encrypt = "yes",
    TrustServerCertificate = "yes"
  )
}

datahub_connect <- function(profile = Sys.getenv(
  "DATAHUB_R_DB_PROFILE",
  unset = "MBHI"
)) {
  datahub_r_database_connect(profile = profile)
}
