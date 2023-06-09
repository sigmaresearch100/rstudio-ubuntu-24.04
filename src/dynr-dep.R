root <- rprojroot::is_rstudio_project
dep <- as.vector(
  read.csv(
    root$find_file(
      "src",
      "dynr-dep.csv"
    ),
    head = FALSE
  )
)
for (i in seq_along(dep)) {
  install.packages(
    dep[i],
    repos = c(REPO_NAME = "https://packagemanager.rstudio.com/all/__linux__/jammy/latest")
  )
}
