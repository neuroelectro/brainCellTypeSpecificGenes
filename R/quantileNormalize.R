quantileNorm = function(whichFile,outFile=NULL){
    library(preprocessCore)
    if (is.character(whichFile)){
        allDataPre = read.csv(whichFile, header = T)
    } else{
        allDataPre = whichFile
    }
    
    list[geneData,exprData]= sepExpr(allDataPre)
    
    newExprData = normalize.quantiles(as.matrix(exprData))
    # boxplot(newExprData)
    newExprData = as.data.frame(newExprData)
    colnames(newExprData) = colnames(exprData)
    newAllData = cbind(geneData, newExprData)
    if(is.character(outFile)){
        write.csv(newAllData, file = outFile, row.names=FALSE)
    }
    invisible(newAllData)
}
