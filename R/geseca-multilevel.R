#' Runs multilevel Monte-Carlo variant for performing gene sets co-regulation analysis
#'
#' This function is based on the adaptive multilevel splitting Monte Carlo approach
#' and allows to estimate arbitrarily small P-values for the task of analyzing
#' variance along a set of genes.
#' @param E expression matrix, rows corresponds to genes, columns corresponds to samples.
#' @param pathways List of gene sets to check.
#' @param minSize Minimal size of a gene set to test. All pathways below the threshold are excluded.
#' @param maxSize Maximal size of a gene set to test. All pathways above the threshold are excluded.
#' @param scale a logical value indicating whether the gene expression should be scaled to have unit variance before the analysis takes place.
#' The default is FALSE The value is passed to \link[base]{scale}.
#' @param sampleSize sample size for conditional sampling.
#' @param eps This parameter sets the boundary for calculating P-values.
#' @param nproc If not equal to zero sets BPPARAM to use nproc workers (default = 0).
#' @param BPPARAM Parallelization parameter used in bplapply.
#' @param nPermSimple Number of permutations in the simple geseca implementation
#' for preliminary estimation of P-values.
#'
#' @import BiocParallel
#' @import fastmatch
#' @import data.table
#' @return A table with GESECA results. Each row corresponds to a tested pathway. The columns are the following
#' \itemize{
#' \item pathway -- name of the pathway as in `names(pathways)`;
#' \item pctVar -- percent of explained variance along gene set;
#' \item pval -- P-value that corresponds to the gene set score;
#' \item padj -- a BH-adjusted p-value;
#' \item size -- size of the pathway after removing genes not present in `rownames(E)`.
#' }
#'
#' @examples
#' data("exampleExpressionMatrix")
#' data("examplePathways")
#' gr <- geseca(exampleExpressionMatrix, examplePathways, minSize=15, maxSize=500)
#' @export
geseca <- function(E,
                   pathways,
                   minSize     = 1,
                   maxSize     = Inf,
                   scale       = FALSE,
                   sampleSize  = 101,
                   eps         = 1e-50,
                   nproc       = 0,
                   BPPARAM     = NULL,
                   nPermSimple = 1000)
{
    if (scale && any(apply(E, 1, sd) == 0)){
        stop("Cannot rescale a constant/zero gene expression rows to unit variance")
    }
    E <- t(base::scale(t(E), scale = scale))

    checkGesecaArgs(E, pathways)
    pp <- gesecaPreparePathways(E, pathways, minSize, maxSize)
    pathwayFiltered <- pp$filtered
    pathwaySizes <- pp$sizes
    m <- length(pathwayFiltered)

    if (m == 0) {
        return(data.table(pathway = character(),
                          score   = numeric(),
                          pval    = numeric(),
                          padj    = numeric(),
                          log2err = numeric(),
                          size    = integer()))
    }

    # Throw a warning message if sample size is less than 3
    if (sampleSize < 3){
        warning("sampleSize is too small, so sampleSize = 3 is set.")
        sampleSize <- max(3, sampleSize)
    }
    if (sampleSize %% 2 == 0){
        sampleSize <-  sampleSize + 1
    }

    eps <- max(0, min(1, eps))

    pathwayScores <- sapply(pathwayFiltered, calcGesecaScores, E = E)
    BPPARAM <- setUpBPPARAM(nproc=nproc, BPPARAM=BPPARAM)

    grSimple <- gesecaSimple(E        = E,
                             pathways = pathways,
                             minSize  = minSize,
                             maxSize  = maxSize,
                             scale    = scale,
                             nperm    = nPermSimple,
                             nproc    = nproc,
                             BPPARAM  = BPPARAM)

    roughEstimator <- log2((grSimple$nMoreExtreme + 1) / (nPermSimple + 1))
    simpleError <- getSimpleError(roughEstimator, grSimple$nMoreExtreme, nPermSimple)
    multilevelError <- sapply((grSimple$nMoreExtreme + 1) / (nPermSimple + 1),
                              multilevelError, sampleSize)

    if (all(multilevelError >= simpleError)){
        grSimple[, log2err := 1/log(2) * sqrt(trigamma(nMoreExtreme + 1) -
                                                  trigamma((nPermSimple + 1)))]

        setorder(grSimple, pathway)
        grSimple[, "nMoreExtreme" := NULL]
        setcolorder(grSimple, c("pathway", "pctVar", "pval", "padj",
                                "log2err","size"))

        grSimple <- grSimple[]
        return(grSimple)
    }

    dtGrSimple <- grSimple[multilevelError >= simpleError]
    dtGrSimple[, log2err := 1 / log(2) * sqrt(trigamma(nMoreExtreme + 1) -
                                                  trigamma(nPermSimple + 1))]


    dtGrMultilevel <- grSimple[multilevelError < simpleError]
    mPathwaysList <- split(dtGrMultilevel, by = "size")

    # In most cases, this gives a speed increase with parallel launches.
    indxs <- sample(1:length(mPathwaysList))
    mPathwaysList <- mPathwaysList[indxs]



    totalVar <- sum(apply(E, 1, var))

    seed=sample.int(1e9, size=1)
    pvals <- bplapply(mPathwaysList, function(x){
        scaledScore <- x[, pctVar] # this is pctVar
        size <- unique(x[, size])
        return(gesecaCpp(E           = E,
                         inpScores   = scaledScore * size * totalVar / 100,
                         genesetSize = size,
                         sampleSize  = sampleSize,
                         seed        = seed,
                         eps         = eps))
    }, BPPARAM = BPPARAM)

    result <- rbindlist(mPathwaysList)

    result[, pval := unlist(pvals)]
    result[, log2err := multilevelError(pval, sampleSize)]
    result[pval < eps, c("pval", "log2err") := list(eps, NA)]

    result[, padj := p.adjust(pval, method = "BH")]

    result <- rbindlist(list(result, dtGrSimple), use.names = TRUE)
    result[, nMoreExtreme := NULL]

    if (nrow(result[pval==eps & is.na(log2err)])){
        warning("For some pathways, in reality P-values are less than ",
                paste(eps),
                ". You can set the `eps` argument to zero for better estimation.")
    }

    setcolorder(result, c("pathway", "pctVar", "pval", "padj",
                          "log2err","size"))
    setorder(result, pathway)


    result <- result[]
    return(result)
}

# This function finds error for rough P-value estimators and based
# on the Clopper-Pearson interval
getSimpleError <- function(roughEstimator, x, n, alpha = 0.025){
    leftBorder <- log2(qbeta(alpha,
                             shape1 = x,
                             shape2 = n - x + 1))
    rightBorder <- log2(qbeta(1 - alpha,
                              shape1 = x + 1,
                              shape2 = n - x))
    simpleError <- 0.5 * pmax(roughEstimator - leftBorder, rightBorder - roughEstimator)
    return(simpleError)
}