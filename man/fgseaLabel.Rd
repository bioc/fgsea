% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fgsea.R
\name{fgseaLabel}
\alias{fgseaLabel}
\title{Runs label-permuring gene set enrichment analysis.}
\usage{
fgseaLabel(
  pathways,
  mat,
  labels,
  nperm,
  minSize = 1,
  maxSize = nrow(mat) - 1,
  nproc = 0,
  gseaParam = 1,
  BPPARAM = NULL
)
}
\arguments{
\item{pathways}{List of gene sets to check.}

\item{mat}{Gene expression matrix. Row name should be the same as in 'pathways'}

\item{labels}{Numeric vector of labels for the correlation score of the same length as the number
of columns in `mat`}

\item{nperm}{Number of permutations to do. Minimial possible nominal p-value is about 1/nperm}

\item{minSize}{Minimal size of a gene set to test. All pathways below the threshold are excluded.}

\item{maxSize}{Maximal size of a gene set to test. All pathways above the threshold are excluded.}

\item{nproc}{If not equal to zero sets BPPARAM to use nproc workers (default = 0).}

\item{gseaParam}{GSEA parameter value, all gene-level statis are raised to the power of `gseaParam`
before calculation of GSEA enrichment scores.}

\item{BPPARAM}{Parallelization parameter used in bplapply.
Can be used to specify cluster to run. If not initialized explicitly or
by setting `nproc` default value `bpparam()` is used.}
}
\value{
A table with GSEA results. Each row corresponds to a tested pathway.
The columns are the following:
\itemize{
 \item pathway -- name of the pathway as in `names(pathway)`;
 \item pval -- an enrichment p-value;
 \item padj -- a BH-adjusted p-value;
 \item ES -- enrichment score, same as in Broad GSEA implementation;
 \item NES -- enrichment score normalized to mean enrichment of random samples of the same size;
 \item nMoreExtreme` -- a number of times a random gene set had a more
     extreme enrichment score value;
 \item size -- size of the pathway after removing genes not present in `names(stats)`.
 \item leadingEdge -- vector with indexes of leading edge genes that drive the enrichment, see \url{http://software.broadinstitute.org/gsea/doc/GSEAUserGuideTEXT.htm#_Running_a_Leading}.
}
}
\description{
Runs label-permuring gene set enrichment analysis.
}
\examples{
\donttest{
library(limma)
library(GEOquery)
es <- getGEO("GSE19429", AnnotGPL = TRUE)[[1]]
exprs(es) <- normalizeBetweenArrays(log2(exprs(es)+1), method="quantile")
es <- es[!grepl("///", fData(es)$`Gene ID`), ]
es <- es[fData(es)$`Gene ID` != "", ]
es <- es[order(apply(exprs(es), 1, mean), decreasing=TRUE), ]
es <- es[!duplicated(fData(es)$`Gene ID`), ]
rownames(es) <- fData(es)$`Gene ID`

pathways <- reactomePathways(rownames(es))
mat <- exprs(es)
labels <- as.numeric(as.factor(gsub(" .*", "", es$title)))
fgseaRes <- fgseaLabel(pathways, mat, labels, nperm = 1000, minSize = 15, maxSize = 500)
}

}
