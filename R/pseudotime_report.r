pipeline.pseudotimeReport <- function()
{  
  diff.test <- function(data.matrix)
  {
    suppressWarnings({ p.values <- apply(data.matrix,1,function(x)
    {
      try({
        fullModel <- vgam( x ~ sm.ns(pseudotime.trajectory, df=3), tobit(Lower = log10(0.1), lmu = "identitylink") )
        redModel <- vgam( x ~ 1, tobit(Lower = log10(0.1), lmu = "identitylink") )
        
        lrt <- lrtest(fullModel,redModel)
        return( lrt@Body["Pr(>Chisq)"][2,] )
        
      },silent = TRUE)
      
      return(1)
      
    })   })
    
    q.values <- p.adjust(p.values, method="fdr")
    
    return(list(p.values=p.values,q.values=q.values))
  }
  
  pseudotime.order <- order(pseudotime.trajectory)
  
  adj.matrix <- cor(metadata)
  for( i in 1:nrow(adj.matrix) )
  {
    o <- order(adj.matrix[i,],decreasing=TRUE)[-c(1:100)]
    w <- which(adj.matrix[i,] < 0.6)
    
    adj.matrix[i,c(o,w,i)] <- 0
  }

  
  dir.create(paste(files.name, "- Results/Pseudotime Analysis"), showWarnings=FALSE)
  
  filename <- file.path(paste(files.name, "- Results"), "Pseudotime Analysis", "Trajectory report.pdf")
  util.info("Writing:", filename)
  pdf(filename,29.7/2.54,21/2.54)
  

  # pseudotime colored correlation spanning tree
  
  layout(matrix(c(1,3,2,3),2),height=c(10,1))
  par(mar=c(0,0,4,0))
    
  g <- graph.adjacency(-adj.matrix, weighted=TRUE, mode="undirected")
  stg <- minimum.spanning.tree(g)
  E(stg)$weight <- 1
  layout.stg <- layout_with_kk(stg,maxiter=10*vcount(g))
  
  V(stg)$label <- rep("",length(V(stg)))
  V(stg)$color <- colorRampPalette(c("white","blue3"))(length(V(stg)))[rank(pseudotime.trajectory)]
  
  plot(stg, layout=layout.stg, vertex.size=ifelse(ncol(indata)<2000,4,2), main="Correlation Spanning Tree")
  
  
  # pseudotime colored correlation k-NN graph
  
  if( ncol(indata) < 2000 )
  {
    adj.matrix <- matrix( 0, ncol(metadata), ncol(metadata), dimnames=list(colnames(metadata),colnames(metadata)) )
    
    for( i in 1:ncol(adj.matrix) )
    {
      connect.samples <- which( adj.matrix[,i] >= sort(adj.matrix[,i],decreasing=T)[preferences$pseudotime.estimation$k] )
      for( x in connect.samples )
      {
        adj.matrix[connect.samples,i] = adj.matrix[connect.samples,i]
        adj.matrix[i,connect.samples] = adj.matrix[i,connect.samples]
      }
    }
    
    G.knn <- graph.adjacency( adj.matrix, weighted = TRUE, mode = "undirected" )
    layout.knn <- layout_with_mds(G.knn)
    
    V(G.knn)$label <- rep("",length(V(G.knn)))
    V(G.knn)$color <- colorRampPalette(c("white","blue3"))(length(V(G.knn)))[rank(pseudotime.trajectory)]
      
    
    plot(G.knn, layout=layout.knn, vertex.size=5, main=paste("k - nearest neighbour graph (k =",preferences$pseudotime.estimation$k,")") )

  } else frame()
  
  
  par(mar=c(2,20,2,20))
  
  image(cbind(1:1000),col=colorRampPalette(c("white","blue3"))(1000),axes=FALSE)
  box()
  mtext("pseudotime",3)
  axis(1,c(0,1),c("start","end"))

    
  # pseudotime metagene sheet
  
  layout(matrix(c(1,2,3,3,3,4,4,4,5,6),5),widths=c(1,2),heights=c(8,1,6,1,1))
  
  p.metagenes <- diff.test(metadata)$p.values
  p.metagenes[which(p.metagenes==0)] = min(p.metagenes[which(p.metagenes>0)])
  
  par(mar=c(1,2.5,4,0.5))
  image( matrix(-log10(p.metagenes),preferences$dim.1stLvlSom), col=color.palette.heatmaps(1000), axes=FALSE, main="Meta-gene significance" )
    box()
  
  par(mar=c(3,20,0,0.5))
  image( cbind(1:1000), col=color.palette.heatmaps(1000), axes=FALSE )
    axis( 1, c(0,1), c(0,round(min(log10(p.metagenes)))) )
    axis( 1, 0.5, "log10(p)", tick=FALSE )
   
    
  
  sel.metagens <- order(p.metagenes)[1:min(100,preferences$dim.1stLvlSom^2)]
  
  mask <- matrix( 1, preferences$dim.1stLvlSom, preferences$dim.1stLvlSom ) 
  mask[sel.metagens] <- NA
  
  par(mar=c(2,2.5,3,0.5))
  image( matrix(-log10(p.metagenes),preferences$dim.1stLvlSom), col=color.palette.heatmaps(1000), axes=FALSE, main="Top 100 Meta-genes" )
    box() 
    par(new=T)
  image( x=1:preferences$dim.1stLvlSom, y=1:preferences$dim.1stLvlSom, z=mask,col="white", xlab="", ylab="")
    axis(1,1,1); axis(2,1,1)
  
  
  
  hc <- hclust( dist( metadata[ sel.metagens, pseudotime.order ] ) )
    
  zlim <- range( metadata[ sel.metagens, ] )
  zlim <- c( -max(abs(zlim)), max(abs(zlim)) )
        
  par(mar=c(0,2,4,5))
  image( t(metadata[ sel.metagens[hc$order], pseudotime.order] ) , col=color.palette.heatmaps(1000), zlim=zlim, axes=FALSE, main="Meta-gene trajectory heatmap")
    axis(4, seq(0,1,length.out=length(sel.metagens)), apply(som.result$node.summary[sel.metagens,c("x","y")]+1,1,paste,collapse=" x "), tick=FALSE, las=1, cex.axis=0.6 )
  
  par(mar=c(2,2,0.5,5))
  image(cbind(1:1000),col=colorRampPalette(c("white","blue3"))(1000),axes=FALSE)
    box()
    axis(1,c(0,1),c("start","end"),line=-1,tick=FALSE ); axis(1,0.5,"pseudotime",line=-1,tick=FALSE)

  par(mar=c(2,45,1,5))
  image( cbind(1:1000), col=color.palette.heatmaps(1000), axes=FALSE )
    axis( 1, c(0,1), round(zlim,2) )
    axis( 1, 0.5, bquote( Delta~e^meta ), tick=FALSE )
  
    
  # pseudotime group sheet  
  if( length(unique(group.labels)) > 1 )
  {
    aov.res <- aov( pseudotime.trajectory ~ group.labels )
    layout(matrix(c(1,2,3,3,4,4,4,0),4),height=c(1,1,0.8,0.2))
    
    par(mar=c(0,0,0,0))
    plot(0, type="n", axes=FALSE, xlab="", ylab="", xlim=c(0,1), ylim=c(0,1))
      text(0.05, 0.94, "Groups", cex=3, adj=0)
      text(0.05, 0.75,  "Relation between groups and pseudotime (anova):", adj=0)
      text(0.05, 0.65, paste("F:", round(summary( aov.res )[[1]]$'F value'[1],2)), adj=0)
      text(0.05, 0.55, paste("p-value:", format.pval(summary( aov.res )[[1]]$'Pr(>F)'[1])), adj=0)
      
    o.groupwise <- order(match( group.labels, unique(group.labels) ))
    group.x.coods <- tapply( 1:length(group.labels), group.labels[o.groupwise], mean )[unique(group.labels)]
    group.y.coods <- tapply( pseudotime.trajectory, group.labels, mean )[unique(group.labels)]
    
    ylim <- c(-0.1,1.1)
    par(mar=c(3,4,2,0),xpd=FALSE)
    plot(pseudotime.trajectory[colnames(indata)[o.groupwise]], col=group.colors[o.groupwise], pch=16, axes=FALSE, xlab="", ylab="t", ylim=ylim )
      box()
      axis(2)
      lines(group.x.coods,group.y.coods,col="gray20")
      points(group.x.coods,group.y.coods,cex=2,pch=15,col=groupwise.group.colors)
      points(group.x.coods,group.y.coods,cex=2,pch=0,col="gray20")
      points( 1:ncol(indata), rep(ylim[1],ncol(indata)), pch=15, col=group.colors[o.groupwise] )  
      points( 1:ncol(indata), rep(ylim[2],ncol(indata)), pch=15, col=colorRampPalette(c("white","blue3"))(ncol(indata))[rank(pseudotime.trajectory)] )  
      mtext("groups",1)
      mtext("pseudotime",3)
      
    par(mar=c(3,4,2,0),xpd=FALSE)
    plot(pseudotime.trajectory[pseudotime.order], col=group.colors[pseudotime.order], pch=16, axes=FALSE, xlab="", ylab="t", ylim=ylim )
      box()
      axis(2)
      points( 1:ncol(indata), rep(ylim[1],ncol(indata)), pch=15, col=group.colors[pseudotime.order] )  
      points( 1:ncol(indata), rep(ylim[2],ncol(indata)), pch=15, col=colorRampPalette(c("white","blue3"))(ncol(indata)) )  
      mtext("groups",1)
      mtext("pseudotime",3)
      
    if( ncol(indata) < 2000 )
    {
      V(G.knn)$color <- group.colors
      par(mar=c(2,2,2,2))
      plot(G.knn, layout=layout.knn, vertex.size=5 ) 
      
    } else frame()
  }
  
  
  # pseudotime gene sheets  
  
  if( ncol(indata) < 2000 )
  {
    DE.genes <- diff.test(indata)
      
    n.genes <- 20
    trajectory.genes <- names(sort(DE.genes$p.values)[1:n.genes])
    
    
    for( x in trajectory.genes )
    {
      layout(matrix(c(1,3,4,4,2,3,4,4,5,5,5,6),4),width=c(1,1,2),height=c(1,1,0.8,0.2))
      
      par(mar=c(0,0,0,0))
      plot(0, type="n", axes=FALSE, xlab="", ylab="", xlim=c(0,1), ylim=c(0,1))
        text(0.1, 0.94, if( gene.info$names[x]!="" ) gene.info$names[x] else x, cex=3, adj=0)
        text(0.1, 0.75,  paste("ID:", x), adj=0)
        text(0.1, 0.65,  paste("(",gene.info$names[x],")"), adj=0)
        text(0.1, 0.55,  gene.info$descriptions[x], adj=0)
      
        text(0.1, 0.35, "Generalized additive model:", adj=0)
        text(0.15, 0.27,  paste("p-value =", format.pval(DE.genes$p.values[x])), adj=0)
        text(0.15, 0.19,  paste("fdr =", format.pval(DE.genes$q.values[x])), adj=0)
    
      
      par(mar=c(4.5,7,4.5,0))
      plot(0,type="n",main="localization",axes=FALSE,xlim=c(1,preferences$dim.1stLvlSom),ylim=c(1,preferences$dim.1stLvlSom),xlab="",ylab="")
        box()
        
        coord <- as.numeric( strsplit(gene.info$coordinates[x]," x ")[[1]] )
        points(coord[1],coord[2],cex=3,pch=16,col="blue3")
        points(coord[1],coord[2],cex=3)
        
       
      o.groupwise <- order(match( group.labels, unique(group.labels) ))
      group.x.coods <- tapply( 1:length(group.labels), group.labels[o.groupwise], mean )[unique(group.labels)]
      group.y.coods <- tapply( indata[x,o.groupwise], group.labels[o.groupwise], mean )[unique(group.labels)]
      
      ylim <- range(indata[x,])
      ylim <- ylim + diff(ylim)*0.1*c(-1,1)
      
      par(mar=c(3,4,2,0),xpd=FALSE)
      plot(indata[x,o.groupwise], col=group.colors[o.groupwise], pch=16, axes=FALSE, xlab="", ylab=bquote(Delta~e), ylim=ylim )
        box()
        axis(2)
        abline(h=0,lty=2,col="gray80")
        lines(group.x.coods,group.y.coods,col="gray20")
        points(group.x.coods,group.y.coods,cex=2,pch=15,col=groupwise.group.colors)
        points(group.x.coods,group.y.coods,cex=2,pch=0,col="gray20")
        points( 1:ncol(indata)-0.5, rep(ylim[1],ncol(indata)), pch=15, col=group.colors[o.groupwise] )  
  			points( 1:ncol(indata), rep(ylim[1],ncol(indata)), pch=15, col=group.colors[o.groupwise] )  
        points( 1:ncol(indata)-0.5, rep(ylim[2],ncol(indata)), pch=15, col=colorRampPalette(c("white","blue3"))(ncol(indata))[rank(pseudotime.trajectory)] )  
        points( 1:ncol(indata), rep(ylim[2],ncol(indata)), pch=15, col=colorRampPalette(c("white","blue3"))(ncol(indata))[rank(pseudotime.trajectory)] )  
        mtext("groups",1)
        mtext("pseudotime",3)
        
      par(mar=c(3,4,2,0),xpd=FALSE)
      plot(indata[x,pseudotime.order], col=group.colors[pseudotime.order], pch=16, axes=FALSE, xlab="", ylab=bquote(Delta~e), ylim=ylim )
        box()
        axis(2)
        abline(h=0,lty=2,col="gray80")
        lines( 1:ncol(indata), Get.Running.Average(indata[x,pseudotime.order],min(5,ncol(indata))), lwd=3, col="gray20" )
        points( 1:ncol(indata)-0.5, rep(ylim[1],ncol(indata)), pch=15, col=group.colors[pseudotime.order] )  
  			points( 1:ncol(indata), rep(ylim[1],ncol(indata)), pch=15, col=group.colors[pseudotime.order] )  
        points( 1:ncol(indata)-0.5, rep(ylim[2],ncol(indata)), pch=15, col=colorRampPalette(c("white","blue3"))(ncol(indata)) )  
  			points( 1:ncol(indata), rep(ylim[1],ncol(indata)), pch=15, col=group.colors[pseudotime.order] )  
        mtext("groups",1)
        mtext("pseudotime",3)
          
  
        
      if( ncol(indata) < 2000 )
      {
          
        V(G.knn)$color <- color.palette.heatmaps(1000)[1+999*(indata[x,]-min(indata[x,]))/(max(indata[x,])-min(indata[x,]))]
        
        par(mar=c(2,2,2,2))
        plot(G.knn, layout=layout.knn, vertex.size=5 )    
          
        par(mar=c(3,25,0,4))
        image( cbind(1:1000), col=color.palette.heatmaps(1000), axes=FALSE )
          axis( 1, c(0,1), round(range(indata[x,]),2) )
          axis( 1, 0.5, bquote( Delta~e ), tick=FALSE )
    
      } else frame()      
    
    }
  }
  
  dev.off()
  


  ### pseudotime CSV sheets

  out <- cbind( Rank=1:length(pseudotime.trajectory),
                Sample=names(pseudotime.trajectory)[pseudotime.order],
                Group=group.labels[pseudotime.order],
                PAT=pat.labels[pseudotime.order],
                TrajectoryScore=pseudotime.trajectory[pseudotime.order]  )

  filename <- file.path(paste(files.name, "- Results"), "CSV Sheets", "Pseudotime scores.csv")
  write.csv2(out, file=filename, row.names=FALSE)

  
  if( ncol(indata) < 2000 )
  {
    o <- order(DE.genes$p.values)
    out <- cbind(Rank=1:length(o),
                 ID=rownames(indata)[o],
                 Symbol=gene.info$names[o],
                 p.value=paste(format.pval(DE.genes$p.values[o]),"     ."),
                 fdr=paste(format.pval(DE.genes$q.values[o]),"     ."),
                 Metagene=gene.info$coordinates[o],
                 Description=gene.info$descriptions[o])
  
    filename <- file.path(paste(files.name, "- Results"), "CSV Sheets", "Pseudotime trajectory genes.csv")
    write.csv2(out, file=filename, row.names=FALSE)
  }

  # ### pseudotime ordered spot report
  # 
  # filename <- file.path(paste(files.name, "- Results"), "Pseudotime Analysis", "Spot module report.pdf")
  # util.info("Writing:", filename)
  # pdf(filename,29.7/2.54,21/2.54)
  # 
  # layout(matrix(1:18, 6, 3, byrow=TRUE),widths=c(1,4,1.5))
  # 
  # spot.list <- get(paste("spot.list.",preferences$standard.spot.modules,sep=""))
  # DE.modules <- diff.test(spot.list$spotdata)
  # 
  # for (i in 1:length(spot.list$spots))
  # {
  #   mask <- spot.list$spots[[i]]$mask
  #   l <- lm( spot.list$spotdata[i,] ~ pseudotime.trajectory )
  # 
  #   par(mar=c(0.5,3,0.5,1))
  #   
  #   image(matrix(mask, preferences$dim.1stLvlSom, preferences$dim.1stLvlSom),
  #         axes=FALSE, col ="darkgreen")
  #   
  #   axis(2, 0.95, names(spot.list$spots[i]), las=2, tick=FALSE, cex.axis=1.6)
  #   box()
  #   
  #   par(mar=c(0.5,3,0.5,1),xpd=FALSE)
  #   
  #   ylim <- range(spot.list$spotdata[i,])
  #   ylim <- ylim + diff(ylim)*0.1*c(-1,1)
  #   
  #   plot(spot.list$spotdata[i,pseudotime.order], col=group.colors[pseudotime.order], pch=16, axes=FALSE, xlab="", ylab=bquote(Delta~e), ylim=ylim )
  #     box()
  #     axis(2)
  #     abline(h=0,lty=2,col="gray80")
  #     lines( 1:ncol(indata), Get.Running.Average(spot.list$spotdata[i,pseudotime.order],min(5,ncol(indata))), lwd=3, col="gray20" )
  #     points( 1:ncol(indata), rep(ylim[1],ncol(indata)), pch=15, col=group.colors[pseudotime.order] )  
  #     points( 1:ncol(indata), rep(ylim[2],ncol(indata)), pch=15, col=colorRampPalette(c("white","blue3"))(ncol(indata)) )  
  # 
  #   par(mar=c(0.5,0,0.5,0))
  #   plot(0, type="n", axes=FALSE, xlab="", ylab="", xlim=c(0,1), ylim=c(0,1), xaxs="i", yaxs="i")
  #     text(0, 0.9, "Differential Expression (GAM):", adj=0)
  #     text(0.1, 0.7, paste("p-value:", format.pval(DE.modules$p.values[i]) ), adj=0)
  #     text(0.1, 0.6, paste("fdr:", format.pval(DE.modules$q.values[i]) ), adj=0)
  # }
  # dev.off()
  
}