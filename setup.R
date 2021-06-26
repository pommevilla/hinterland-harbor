## Packages

library(vegan)
library(ggplot2)
library(reshape2)
library(corrplot)
library(here)
library(tidyverse)
library(cowplot)
library(scales)
library(phyloseq)
library(cowplot)
library(ggtext)
library(ggsignif)
library(rio)
library(microViz)

### Functions

plot_fertilizer_nmds <- function(ps, ord) {
  plot_ordination(ps, ord) + 
    geom_point(size = 4, color = "black", aes(fill = fert_level), shape = 21) + 
    # v + 
    labs(
      title = ""
    ) + 
    theme(
      # legend.position = "none"
      plot.title = element_text(hjust = 0.5),
      legend.text = element_text(size = 12),
      # legend.background = element_rect(fill = "white", size = 0.3, linetype = "solid", colour = "black"),
      legend.title = element_markdown(size = 12, hjust = 0.5),
      axis.text.x = element_text(size = 14),
      axis.text.y = element_text(size = 14),
      axis.title.x = element_text(size = 12),
      axis.title.y = element_text(size = 12),
      panel.grid = element_line(color = "gray95"),
      panel.border = element_rect(color = "black", size = 1, fill = NA)
    ) +
    scale_fill_discrete(name = "Fertilizer Level<br>
                       <span style = 'font-size:8pt;'>
                        (kg N ha<sup>-1</sup> y<sup>-1</sup>)
                       </span>") + 
    # scale_shape(guide = "none") + 
    geom_hline(yintercept = 0.0,
               colour = "grey",
               lty = 2) +
    geom_vline(xintercept = 0.0,
               colour = "grey",
               lty = 2) +
    guides(fill = guide_legend(override.aes = list(shape = 21, size = 5)))
}

estimate_richness_mod <- function(physeq, split=TRUE, measures=NULL){
  
  if( !any(otu_table(physeq)==1) ){
    # Check for singletons, and then warning if they are missing.
    # These metrics only really meaningful if singletons are included.
    warning(
      "The data you have provided does not have\n",
      "any singletons. This is highly suspicious. Results of richness\n",
      "estimates (for example) are probably unreliable, or wrong, if you have already\n",
      "trimmed low-abundance taxa from the data.\n",
      "\n",
      "We recommended that you find the un-trimmed data and retry."
    )
  }
  
  # If we are not splitting sample-wise, sum the species. Else, enforce orientation.
  if( !split ){
    OTU <- taxa_sums(physeq)		
  } else if( split ){
    OTU <- as(otu_table(physeq), "matrix")
    if( taxa_are_rows(physeq) ){ OTU <- t(OTU) }
  }
  
  # Define renaming vector:
  renamevec = c("Observed", "Chao1", "ACE", "Shannon", "Pielou", "Simpson", "InvSimpson", "SimpsonE", "Fisher")
  names(renamevec) <- c("S.obs", "S.chao1", "S.ACE", "shannon", "pielou", "simpson", "invsimpson", "simpsone", "fisher")
  # If measures was not explicitly provided (is NULL), set to all supported methods
  if( is.null(measures) ){
    measures = as.character(renamevec)
  }
  # Rename measures if they are in the old-style
  if( any(measures %in% names(renamevec)) ){
    measures[measures %in% names(renamevec)] <- renamevec[names(renamevec) %in% measures]
  }
  
  # Stop with error if no measures are supported
  if( !any(measures %in% renamevec) ){
    stop("None of the `measures` you provided are supported. Try default `NULL` instead.")
  }
  
  # Initialize to NULL
  outlist = vector("list")
  # Some standard diversity indices
  estimRmeas = c("Chao1", "Observed", "ACE")
  if( any(estimRmeas %in% measures) ){
    outlist <- c(outlist, list(t(data.frame(estimateR(OTU)))))
  }
  if( "Shannon" %in% measures ){
    outlist <- c(outlist, list(shannon = diversity(OTU, index="shannon")))
  }
  if( "Pielou" %in% measures){
    #print("Starting Pielou")
    outlist <- c(outlist, list(pielou = diversity(OTU, index = "shannon")/log(estimateR(OTU)["S.obs",])))
  }
  if( "Simpson" %in% measures ){
    outlist <- c(outlist, list(simpson = diversity(OTU, index="simpson")))
  }
  if( "InvSimpson" %in% measures ){
    outlist <- c(outlist, list(invsimpson = diversity(OTU, index="invsimpson")))
  }
  if( "SimpsonE" %in% measures ){
    #print("Starting SimpsonE")
    outlist <- c(outlist, list(simpsone = diversity(OTU, index="invsimpson")/estimateR(OTU)["S.obs",]))
  }
  if( "Fisher" %in% measures ){
    fisher = tryCatch(fisher.alpha(OTU, se=TRUE),
                      warning=function(w){
                        warning("phyloseq::estimate_richness: Warning in fisher.alpha(). See `?fisher.fit` or ?`fisher.alpha`. Treat fisher results with caution")
                        suppressWarnings(fisher.alpha(OTU, se=TRUE)[, c("alpha", "se")])
                      }
    )
    if(!is.null(dim(fisher))){
      colnames(fisher)[1:2] <- c("Fisher", "se.fisher")
      outlist <- c(outlist, list(fisher))
    } else {
      outlist <- c(outlist, Fisher=list(fisher))
    }
  }
  out = do.call("cbind", outlist)
  # Rename columns per renamevec
  namechange = intersect(colnames(out), names(renamevec))
  colnames(out)[colnames(out) %in% namechange] <- renamevec[namechange]
  # Final prune to just those columns related to "measures". Use grep.
  colkeep = sapply(paste0("(se\\.){0,}", measures), grep, colnames(out), ignore.case=TRUE)
  out = out[, sort(unique(unlist(colkeep))), drop=FALSE]
  # Make sure that you return a data.frame for reliable performance.
  out <- as.data.frame(out)
  return(out)
}

### Settings

theme_set(theme_minimal())

### Data

#### CT Numbers

data.priming <- read.csv(here("data", "priming_amoA_deltaCt.csv"), header = T) %>% 
  rename(sample_id = X) 

data.raw <- read.csv(here("data", "priming_amoA_rawCt.csv"), header = T) %>% 
  rename(sample_id = X)

data.priming.long <- data.priming %>% 
  pivot_longer(cols = amoA.001:amoA.078, names_to = "amoA", values_to = "deltaCT")

data.raw.long <- data.raw %>% 
  pivot_longer(cols = amoA.001:amoA.078, names_to = "amoA", values_to = "CT")

data.priming.long$sample_id <- fct_reorder(data.priming.long$sample_id, parse_number(data.priming.long$sample_id))

## Organism info

amoA_organism_info <- import(here("data", "amoa_mfp_qpcr_org_accessions.xlsx"), which = 5) %>% 
  select(-c(contains(c("forward", "reverse", "notes")))) 




df <- data.priming[, -1]
rownames(df) <- data.priming[, 1]

metadata <- df %>% 
  select(fert_level:field_rep) %>%
  mutate(across(everything(), as.factor))



amoa_counts <- df %>% 
  select(starts_with("amoA")) 

non_detect_counts <- data.raw.long %>%
  group_by(fert_level, amoA) %>% 
  count(CT == 40) %>% 
  rename(non_detect = `CT == 40`) %>%
  filter(non_detect == TRUE)

removes <- non_detect_counts %>% 
  pivot_wider(names_from = fert_level, values_from = n, names_prefix = "fert.") %>%
  filter(fert.0 > 30 & fert.336 > 30) %>%
  pivot_longer(cols = fert.0:fert.336, names_to = "fert_level", values_to = "n")

data.priming.reduced <- data.priming %>% 
  select(-one_of(removes$amoA))

data.priming.reduced.long <- data.priming.reduced %>% 
  select(-sample_id, field_rep) %>% 
  pivot_longer(cols = amoA.001:amoA.074)

amoA_presence_absence <- data.raw %>% 
  select(sample_id, starts_with("amoA")) %>%
  select(-one_of(removes$amoA)) %>%
  mutate(across(starts_with("amoA"), ~ ifelse(.x == 40, 0, 1))) %>%
  column_to_rownames(var = "sample_id")

amoa_tax_table <- amoA_organism_info %>% 
  select(array_name, best_blast_hits) %>% 
  column_to_rownames(var = "array_name") %>% 
  tax_table()

rownames(amoa_tax_table) <- amoA_organism_info$array_name


ps <- phyloseq(
  otu_table(amoA_presence_absence, taxa_are_rows = FALSE),
  sample_data(metadata),
  amoa_tax_table
)

