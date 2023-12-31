% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot.R
\name{plotGseaTable}
\alias{plotGseaTable}
\title{Plots table of enrichment graphs using ggplot and gridExtra.}
\usage{
plotGseaTable(
  pathways,
  stats,
  fgseaRes,
  gseaParam = 1,
  colwidths = c(5, 3, 0.8, 1.2, 1.2),
  pathwayLabelStyle = NULL,
  headerLabelStyle = NULL,
  valueStyle = NULL,
  axisLabelStyle = NULL,
  render = NULL
)
}
\arguments{
\item{pathways}{Pathways to plot table, as in `fgsea` function.}

\item{stats}{Gene-level stats, as in `fgsea` function.}

\item{fgseaRes}{Table with fgsea results.}

\item{gseaParam}{GSEA-like parameter. Adjusts displayed statistic values,
values closer to 0 flatten plots. Default = 1, value of 0.5 is a good
choice too.}

\item{colwidths}{Vector of five elements corresponding to column width for
grid.arrange. Can be both units and simple numeric vector, in latter case
it defines proportions, not actual sizes. If column width is set to zero, the column is not drawn.}

\item{pathwayLabelStyle}{list with style parameter adjustments for pathway labels.
For example, `list(size=10, color="red")` set the font size to 10 and color to red.
See `cowplot::draw_text` for possible options.}

\item{headerLabelStyle}{similar to `pathwayLabelStyle` but for the table header.}

\item{valueStyle}{similar to `pathwayLabelStyle` but for NES and p-value columns.}

\item{axisLabelStyle}{list with style parameter adjustments for stats axis labels.
See `ggplot2::element_text` for possible options.}

\item{render}{(deprecated)}
}
\value{
ggplot object with enrichment barcode plots
}
\description{
Plots table of enrichment graphs using ggplot and gridExtra.
}
\examples{
data(examplePathways)
data(exampleRanks)
fgseaRes <- fgsea(examplePathways, exampleRanks, minSize=15, maxSize=500)
topPathways <- fgseaRes[head(order(pval), n=15)][order(NES), pathway]
plotGseaTable(examplePathways[topPathways], exampleRanks,
              fgseaRes, gseaParam=0.5)
}
