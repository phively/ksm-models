# Load wranglR
library(wranglR)

# Feed the libraries specified in PACKAGES.txt into wranglR's Libraries() function
Libraries(scan(file = 'PACKAGES.txt', what = 'character'))