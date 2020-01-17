# Creates a new scrat environment
scrat.new <- function(preferences=NULL)
{
  # Init the environment
  env <- new.env()
  env$color.palette.portraits <- NULL
  env$color.palette.heatmaps <- NULL
  env$t.ensID.m <- NULL
  env$Fdr.g.m <- NULL
  env$fdr.g.m <- NULL
  env$files.name <- NULL
  env$gene.info <- NULL
  env$chromosome.list <- NULL
  env$group.silhouette.coef <- NULL
  env$group.colors <- NULL
  env$group.labels <- NULL
  env$gs.def.list <- NULL
  env$samples.GSZ.scores <- NULL
  env$spot.list.correlation <- NULL
  env$spot.list.dmap <- NULL
  env$spot.list.group.overexpression <- NULL
  env$spot.list.kmeans <- NULL
  env$spot.list.overexpression <- NULL
  env$spot.list.samples <- NULL
  env$spot.list.underexpression <- NULL
  env$indata <- NULL
  env$indata.gene.mean <- NULL
  env$indata.sample.mean <- NULL
  env$metadata <- NULL
  env$n.0.m <- NULL
  env$output.paths <- NULL
  env$pat.labels <- NULL
  env$p.g.m <- NULL
  env$p.m <- NULL
  env$perc.DE.m <- NULL
  env$som.result <- NULL
  env$t.g.m <- NULL
  env$t.m <- NULL
  env$groupwise.group.colors <- NULL
  env$unique.protein.ids <- NULL
  env$WAD.g.m <- NULL
  env$pseudotime.trajectory <- NULL
  
  # Generate some additional letters
  env$LETTERS <- c(LETTERS, as.vector(sapply(1:10, function(x) {
    return(paste(LETTERS, x, sep=""))
  })))

  env$letters <- c(letters, as.vector(sapply(1:10, function(x) {
    return(paste(letters, x, sep=""))
  })))

  # Set default preferences
  env$preferences <- list(dataset.name = "Unnamed",
                          dim.1stLvlSom = "auto",
                          training.extension = 1,
                          rotate.SOM.portraits = 0,
                          flip.SOM.portraits = FALSE,
                          activated.modules = list(
                            reporting = TRUE,
                            primary.analysis = TRUE,
                            sample.similarity.analysis = TRUE,
                            geneset.analysis = TRUE,
                            geneset.analysis.exact = FALSE,
                            group.analysis = TRUE,
                            difference.analysis = TRUE ),
                          database.biomart = "ENSEMBL_MART_ENSEMBL",
                          database.host = "aug2017.archive.ensembl.org",
                          database.dataset = "auto",
                          database.id.type = "",
                          standard.spot.modules = "kmeans",
                          spot.coresize.modules = 3,
                          spot.threshold.modules = 0.95,
                          spot.coresize.groupmap = 5,
                          spot.threshold.groupmap = 0.75,
                          adjust.autogroup.number = 0,
                          pseudotime.estimation = NULL,
                          preprocessing = list(
                            count.processing = FALSE,
                            cellcycle.correction = FALSE,
                            feature.centralization = TRUE,
                            sample.quantile.normalization = TRUE ) )

  # Merge user supplied information
  if (!is.null(preferences))
  {
    env$preferences <-
      modifyList(env$preferences, preferences[names(env$preferences)])
  }
  if(!is.null(preferences$indata))
  {
    env$indata <- preferences$indata
  }
  if(!is.null(preferences$group.labels))
  {
    env$group.labels <- preferences$group.labels
  }
  if(!is.null(preferences$group.colors))
  {
    env$group.colors <- preferences$group.colors
  }
  
  return(env)
}

# Executes the scrat pipeline.
scrat.run <- function(env)
{
  util.info("Started:", env$preferences$started)
  util.info("Name:", env$preferences$dataset.name)

  #### Preparation & Calculation part ####
  
  if (!util.call(pipeline.checkInputParameters, env)) {
    return()
  }
  
  if(env$preferences$activated.modules$primary.analysis)
  {
    env$preferences$system.info <- Sys.info()
    env$preferences$session.info <- sessionInfo()
    env$preferences$started <- format(Sys.time(), "%a %d %b %Y %X")
    
    util.call(pipeline.countProcessing, env)
  }
  
  if(env$preferences$activated.modules$reporting)
  {
    # create output dirs
    dir.create(paste(env$files.name, "- Results"), showWarnings=FALSE)
    dir.create(paste(env$files.name, "- Results/CSV Sheets"), showWarnings=FALSE)

    if(env$preferences$activated.modules$primary.analysis)
    {
      util.call(pipeline.qualityCheck, env)
    } 
  }

  if(env$preferences$activated.modules$primary.analysis || env$preferences$activated.modules$geneset.analysis)
  {
    util.info("Loading gene annotation data.")
    util.call(pipeline.prepareAnnotation, env)
  }

  if(env$preferences$activated.modules$primary.analysis)
  {
    util.call(pipeline.cellcycleProcessing, env)
    
    util.info("Processing SOM. This may take several time until next notification.")
    util.call(pipeline.prepareIndata, env)
    util.call(pipeline.generateSOM, env)
    
    filename <- paste(env$files.name, "pre.RData")
    util.info("Saving environment image:", filename)
    save(env, file=filename)
    
    util.info("Processing Differential Expression Statistics")
    util.call(pipeline.calcStatistics, env)

    util.info("Detecting Spots")
    util.call(pipeline.detectSpotsSamples, env)
    util.call(pipeline.detectSpotsIntegral, env)
    util.call(pipeline.patAssignment, env)
    util.call(pipeline.groupAssignment, env)    
  }

  if (env$preferences$activated.modules$geneset.analysis)
  {
    util.info("Calculating Geneset Enrichment")
    util.call(pipeline.genesetStatisticSamples, env)
    util.call(pipeline.genesetStatisticIntegral, env)
  }
  
	 if(!is.null(env$preferences$pseudotime.estimation))
	{
		util.info("Processing Pseudotime Analysis")
		util.call(pipeline.pseudotimeEstimation, env)
	}
    
  if(env$preferences$activated.modules$primary.analysis || env$preferences$activated.modules$geneset.analysis)
  {    
    filename <- paste(env$files.name, ".RData", sep="")
    util.info("Saving environment image:", filename)
    save(env, file=filename)
    
    if (file.exists(paste(env$files.name, "pre.RData")) && file.exists(filename))
    {
      file.remove(paste(env$files.name, "pre.RData"))
    }
  }  
    
  #### Reporting part ####
  
  if(env$preferences$activated.modules$reporting)
  {
 
    if(ncol(env$indata) < 1000)
    {
      util.info("Plotting Sample Portraits")
      util.call(pipeline.sampleExpressionPortraits, env)
    } 
    
    if ( env$preferences$activated.modules$sample.similarity.analysis && ncol(env$indata) > 2)
    {    
      util.info("Plotting Sample Similarity Analysis")
      dir.create(file.path(paste(env$files.name, "- Results"), "Sample Similarity Analysis"), showWarnings=FALSE)
      
      util.call(pipeline.sampleSimilarityAnalysisED, env)
      util.call(pipeline.sampleSimilarityAnalysisCor, env)
      util.call(pipeline.sampleSimilarityAnalysisICA, env)
    }
    
    util.info("Plotting Summary Sheets (Modules & PATs)")
    util.call(pipeline.summarySheetsModules, env)
      
    if(env$preferences$activated.modules$group.analysis && length(unique(env$group.labels)) >= 2)
    {
      util.info("Processing Group-centered Analyses")
      util.call(pipeline.groupAnalysis, env)
    }
  
	  if(!is.null(env$preferences$pseudotime.estimation))
		{
			util.info("Processing Pseudotime Reports")
			util.call(pipeline.pseudotimeReport, env)
		}
  
    util.info("Generating HTML Report")
    util.call(pipeline.htmlSummary, env)
    
  }    
    
  util.info("Finished:", format(Sys.time(), "%a %b %d %X"))
}