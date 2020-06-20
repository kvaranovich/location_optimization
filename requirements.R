'%notin%' <- function(x,y) !('%in%'(x,y))
installed_pkgs <- installed.packages()

required_packages <- list(
  "dplyr",
  "ggplot2",
  "ggmap",
  "gifsky",
  "gganimate"
)

for (pkg in required_packages) {
  if (pkg %notin% installed_pkgs) {
    install.packages(pkg)
  }
}
