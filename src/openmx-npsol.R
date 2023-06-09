# https://vipbg.vcu.edu/vipbg/OpenMx2/software/getOpenMx.R

#if (version$major < 4 && (.Platform$OS.type == "windows" || Sys.info()["sysname"] == "Darwin")) {
#  stop("Binaries for R versions less than 4 are no longer available. Please use CRAN binaries.")
#}
if (interactive()) {
   cat(paste0("You are now installing the latest version of OpenMx, compiled with NPSOL, that is available for R-", version$major), fill=TRUE)
}

top <- "https://openmx.ssri.psu.edu/software/"

# Determine install type
if (.Platform$OS.type == "windows") {
    if (!is.null(.Platform$r_arch) && .Platform$r_arch == "x64") {
        repos = c(top)
    } else {
        repos <- c(paste0(top,'32-bit/'))
    }
    type<-"win.binary"
} else {
    repos <- c(top)
    type <- getOption("pkgType")
    if(Sys.info()["sysname"] == "Darwin") {
        type=.Platform$pkgType
    }
}

# Work out dependencies
needed <- c("digest", "MASS", "snowfall", "roxygen2", "mvtnorm", "rpf", "numDeriv", "Rcpp", "RcppEigen", "StanHeaders", "BH")
available <- installed.packages()
installed <- rownames(available)
toInstall <- setdiff(needed, installed)
if(!"roxygen2" %in% toInstall) {
    roxVer <- strsplit(available["roxygen2", "Version"], split='[.]')[[1]]
    if(roxVer[1] < 3 || (roxVer[1] == 3 && roxVer[2] <= 1)) {
        toInstall <- c("roxygen", toInstall)
    }
}
if(!"rpf" %in% toInstall) {
    rpfVer <- strsplit(available["rpf", "Version"], split='[.]')[[1]]
    if(rpfVer[1] == 0 && rpfVer[2] < 36) {
        toInstall <- c("rpf", toInstall)
    }
}

if(interactive() &&
    Sys.info()["sysname"] == "Darwin" &&
    is.null(options("repos")$repos)) {
        chooseCRANmirror(graphics=FALSE)
}

# Install dependencies from default repositories (usually CRAN)
for(pkg in toInstall) {
    install.packages(pkg)
}

# Install OpenMx from the OpenMx site
install.packages(pkgs=c("OpenMx"), contriburl=contrib.url(repos, type=type), dependencies=NA, verbose=TRUE)
