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
    orcid: 0000-0000-0000-0000
    affiliation: 1
affiliations:
  - name: Independent Researcher
    index: 1
date: 25 June 2026
bibliography: paper.bib
---

# Summary

`GenoSuite` is a free, open-source desktop application for the multivariate
analysis of genetic marker data. It provides, through a single point-and-click
graphical interface, the analyses that researchers and plant/animal breeders
routinely apply to SNP and other marker datasets: genetic distance and
similarity matrices, hierarchical clustering and neighbour-joining dendrograms,
ordination (principal component analysis and principal coordinates analysis),
the Mantel matrix-correlation test, diversity statistics and population
differentiation (minor-allele frequency, heterozygosity, polymorphism
information content, and Nei's $F_{ST}$), the genomic relationship matrix,
linkage disequilibrium, genome-wide association scans, and cross-validated
genomic prediction. The application is distributed as a self-contained Windows
installer that bundles a private copy of R [@rcore] and all required packages,
so end users need not install R or write any code.

# Statement of need

Multivariate and population-genetic analysis of marker data has long been
performed in graphical tools such as `NTSYS-pc` [@rohlf2000], which remains
popular for distance-based clustering and ordination but is proprietary, no
longer actively developed, and predates the genomic era: it offers no
facilities for genome-wide association, genomic relationship matrices, or
genomic prediction. Conversely, the modern methods for these tasks are
implemented as R or command-line packages that require programming skills,
placing them out of reach for many experimentalists and breeders.

`GenoSuite` addresses this gap by combining classical numerical-taxonomy
workflows with present-day quantitative-genomics methods in one free graphical
application that requires no coding or installation of a programming
environment. Genetic distances, clustering, and ordination are computed with
base R, `ape` [@paradis2019], and `vegan` [@oksanen2022]; the genomic
relationship matrix follows @vanraden2008; and cross-validated genomic
prediction—GBLUP together with penalised regression, random forests, gradient
boosting, and a stacked ensemble—is provided through the companion package
`GSbench`, building on the mixed-model approach of @endelman2011 and the
genomic-selection framework of @meuwissen2001. The interface is built with
`Shiny` [@shiny] and packaged as a relocatable bundle so it launches as a
standalone desktop window.

`GenoSuite` is intended for teaching, exploratory analysis, and applied breeding
programmes where an accessible, reproducible, and self-contained tool is more
practical than a scripted workflow.

# Acknowledgements

We acknowledge the R community and the maintainers of the open-source packages
on which `GenoSuite` depends.

# References
