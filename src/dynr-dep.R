root <- rprojroot::is_rstudio_project
dep <- root$find_file(
  "src",
  "dynr-dep.csv"
)
for (i in seq_along(dep)) {
  install.packages(
    dep[i],
	repos = c(REPO_NAME = "https://packagemanager.rstudio.com/all/__linux__/jammy/latest")
  )
}
