---
title: 'GenoSuite: a self-contained desktop application for numerical-genomics analytics'
tags:
  - R
  - Shiny
  - genomics
  - population genetics
  - genomic selection
  - GWAS
authors:
  - name: Muhammad Farooqi
    orcid: 0000-0003-4918-9791
    affiliation: 1
affiliations:
  - name: Independent Researcher
    index: 1
date: 26 June 2026
bibliography: paper.bib
---

# Summary

`GenoSuite` is a free and open-source desktop application for the multivariate
and population-genetic analysis of genetic marker data. Through a single
point-and-click interface it computes genetic distance and similarity matrices,
hierarchical clustering and neighbour-joining trees, ordination by principal
component analysis (PCA) and principal coordinates analysis (PCoA), the Mantel
matrix-correlation test, diversity and population-differentiation statistics
(minor-allele frequency, heterozygosity, polymorphism information content, and
Nei's $F_{ST}$), the genomic relationship matrix, linkage disequilibrium,
genome-wide association scans, and cross-validated genomic prediction.
`GenoSuite` is implemented in R [@rcore] with the `Shiny` framework [@shiny] and
is distributed as a self-contained Windows installer that bundles R and all
dependencies, so end users run it without installing R or writing code. It is
aimed at students, breeders, and biologists who need reproducible analyses of
single-nucleotide polymorphism (SNP) and other marker data.

# Statement of need

Analysis of marker data typically proceeds through a standard sequence of
multivariate and population-genetic steps. The classical workflow—distance
matrices, clustering, ordination, and matrix comparison—has long been served by
graphical tools, while contemporary quantitative-genomics methods such as the
genomic relationship matrix, genome-wide association studies (GWAS), and genomic
prediction are available chiefly as R or command-line packages that require
programming. Many experimentalists and breeders therefore cannot easily apply
modern methods, or must combine several disparate tools.

`GenoSuite` brings both the classical and the contemporary methods into one
graphical workflow that requires no programming or proprietary software:

- **Distance and clustering.** Euclidean, Manhattan, correlation-based,
  Jaccard, and Gower distances; hierarchical clustering by UPGMA, Ward,
  complete, and single linkage; and neighbour-joining trees with export to
  Newick format [@paradis2019].
- **Ordination and matrix comparison.** Principal component analysis on the
  markers and principal coordinates analysis on the distance matrix, each with
  scree plots, and the Mantel test between two distance matrices [@oksanen2022].
- **Diversity and population structure.** Per-marker minor-allele frequency,
  observed and expected heterozygosity, polymorphism information content, and
  population differentiation by Nei's $F_{ST}$ [@nei1973].
- **Kinship and linkage.** The genomic relationship matrix following
  @vanraden2008, and pairwise linkage disequilibrium ($r^2$) with a decay plot.
- **Association and prediction.** Single-marker GWAS with principal-component
  correction for population structure, and cross-validated genomic
  prediction—genomic best linear unbiased prediction [@endelman2011;
  @meuwissen2001] together with penalised regression, random forests, gradient
  boosting, and a stacked ensemble—reporting predictive ability and genomic
  estimated breeding values.

Analyses accept comma-separated or Excel marker tables and produce interactive
figures and exportable results (distance matrices, trees, statistics, and
breeding values).

# State of the field

Graphical, install-and-run tools for marker-data analysis are dominated by the
proprietary `NTSYS-pc` [@rohlf2000], which remains widely used for distance-based
clustering and ordination but is closed-source, no longer actively developed, and
predates the genomic era—it offers no genomic relationship matrix, GWAS, or
genomic prediction. The spreadsheet add-in GenAlEx [@peakall2012] provides
population-genetic summaries within Microsoft Excel, and the free Java
application TASSEL [@bradbury2007] performs association and diversity analyses but
focuses on association mapping and does not cover numerical-taxonomy workflows or
genomic prediction. Contemporary prediction and mixed-model methods are otherwise
available mainly as R or command-line packages aimed at programmers.

`GenoSuite` complements these tools by consolidating classical
numerical-taxonomy workflows and modern quantitative-genomics methods in a single
free graphical application, and by shipping as a self-contained installer that
bundles its own R runtime so it can be installed and run without any programming
environment.

# Software design

`GenoSuite` is organised as a set of independent analysis modules that share a
common data model—a table of individuals (rows) by markers (columns), with
optional grouping and phenotype columns. Each module reads this shared input and
produces interactive figures and exportable results. Numerical routines build on
base R, `ape` [@paradis2019], `vegan` [@oksanen2022], and the companion package
`GSbench` for genomic prediction, while the graphical interface is built with
`Shiny` [@shiny] and `bslib`. For distribution, the application is assembled into
a relocatable bundle—a private copy of R [@rcore], all required packages, the
application, and a launcher—and compiled into a single Windows installer, so it
runs as a standalone desktop application without a separate R installation. The
codebase includes an automated test suite covering the analysis and prediction
functions.

# Research impact statement

By lowering the technical barrier to standard genomic analyses, `GenoSuite` is
intended to support teaching and applied plant- and animal-breeding and
conservation programmes, where reproducible analyses are needed but programming
expertise or licences for proprietary software may be unavailable. Bringing
distance and diversity analysis together with GWAS and genomic prediction in one
reproducible interface allows users to move from raw marker tables to selection
decisions without switching tools.

# AI usage disclosure

Anthropic's Claude (Claude Opus 4.x, via the Claude Code assistant) was used to
assist with the following: implementing the application and packaging code,
drafting the documentation and user manual, and drafting an initial version of
this paper. I defined the scope and selected the statistical methods, directed
the development, and reviewed, edited, tested, and validated all AI-assisted
output—for example, checking the GBLUP solver against the `rrBLUP` package. All
implemented methods are standard, published techniques in quantitative genetics.
I made all final design decisions and accept full responsibility for the work.

# Acknowledgements

I acknowledge the R community and the maintainers of the open-source packages on
which `GenoSuite` depends.

# References
