# install R dependencies

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

# dynr master

git clone https://github.com/mhunter1/dynr.git
cd dynr
./configure
make clean install
cd ..
rm -rf dynr

# dynr arma

git clone -b arma https://github.com/mhunter1/dynr.git
cd dynr
./configure
make clean install
cd ..
rm -rf dynr
