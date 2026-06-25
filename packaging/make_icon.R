# Render a 256x256 PNG of the GenoSuite mark (hex + neighbour-joining tree).
# build.ps1 wraps this PNG into GenoSuite.ico.
args <- commandArgs(trailingOnly = TRUE)
out  <- if (length(args) >= 1) args[1] else "icon.png"

png(out, width = 256, height = 256, bg = "transparent")
par(mar = c(0, 0, 0, 0)); plot.new(); plot.window(xlim = c(0, 256), ylim = c(0, 256), asp = 1)

a <- (seq(90, 330, by = 60)) * pi / 180
polygon(128 + 120 * cos(a), 128 + 120 * sin(a), col = "#1f7a3d", border = "#19632f", lwd = 6)

seg <- function(x0, y0, x1, y1) segments(x0, y0, x1, y1, col = "white", lwd = 11, lend = 1)
seg(74, 128, 120, 128)                 # root stem
seg(120, 80, 120, 176)                 # backbone
seg(120, 176, 150, 176); seg(150, 152, 150, 200)
seg(150, 152, 185, 152); seg(150, 200, 185, 200)
seg(120, 80, 150, 80);   seg(150, 56, 150, 104)
seg(150, 56, 185, 56);   seg(150, 104, 185, 104)
points(rep(185, 4), c(56, 104, 152, 200), pch = 19, col = "#f9a825", cex = 2.6)

dev.off()
cat("ICON PNG:", out, "\n")
