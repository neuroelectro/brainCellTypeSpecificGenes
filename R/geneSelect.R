library(ogbox)
require(foreach)
require(doMC)
require(parallel)
require(reshape2)
require(cluster)
source('R/regionize.R')
geneSelect = function(designLoc,
                      exprLoc,
                      outLoc,
                      groupNames,
                      regionNames=NULL,
                      rotate = NULL,
                      cores = 4,
                      debug=NULL, 
                      sampleName = 'sampleName',
                      replicates = 'originalIndex',
                      foldChangeThresh = 10,
                      minimumExpression = 8){
    # so that I wont fry my laptop
    if (detectCores()<cores){ 
        cores = detectCores()
        print('max cores exceeded')
        print(paste('set core no to',cores))
    }
    registerDoMC(cores)
    
    #gene selector, outputs selected genes and their fold changes
    foldChange = function (group1, group2, f = 10){
        
        
        groupAverage1 = group1
        
        
        
        groupAverage2 = tryCatch({apply(group2, 2, median)},
                                 error = function(cond){
                                     print('fuu')
                                     return(group2)
                                 })
        
        g19 = groupAverage1 < 9.5 & groupAverage1 > 8
        g16 = groupAverage1  < 6
        g29 = groupAverage2 < 9.5 & groupAverage2 > 8
        g26 = groupAverage2 < 6
        # this is a late addition preventing anything that is below 8 from being
        # selected. ends up removing the the differentially underexpressed stuff as well
        gMinTresh = groupAverage1 > minimumExpression
        
        
        tempGroupAv2 = vector(length = length(groupAverage2))
        
        tempGroupAv2[g26 & g19] =apply(group2[, g26 & g19,drop=F], 2, max)
        # legacy 
        tempGroupAv2[g16 & g29] =apply(group2[, g16 & g29,drop=F], 2, min)
        
        
        #groupAverage1[5124]
        #groupAverage2[5124]
        
        
        #groupAverage1[7067]
        #groupAverage2[7067]
        
        add1 = g19 & g26 & groupAverage1>tempGroupAv2
        add2 = g29 & g16 & tempGroupAv2>groupAverage1
        
        
        fold = groupAverage1 - groupAverage2
        # take everything below 6 as the same when selecting
        # fold =  sapply(groupAverage1,max,6) - sapply(groupAverage2,max,6)
        chosen =  which(({(fold >= (log(f)/log(2))) & !(g19 & g26) } | {(fold <= log(1/f)/log(2)) &  !(g29 & g16)}| add1 | add2)&gMinTresh)
        return(
            data.frame(index = chosen, foldChange = fold[chosen])
        )
    }
    
    giveSilhouette = function(daGeneIndex,groupInfo1,groupInfo2){
        clustering = as.integer(rep(1,nrow(design))*(1:nrow(design) %in% groupInfo1)+1)
        clustering = clustering[1:nrow(design) %in% c(groupInfo1, groupInfo2)]
        data = (exprData[ (1:nrow(design) %in% c(groupInfo1, groupInfo2)),  daGeneIndex])
        cluster = list(clustering = clustering, data = data)
        silo = silhouette(cluster,dist(data))
        return(mean(silo[,3]))    
    }
    # data prep. you transpose exprData -----
    design = read.design(designLoc)
    
    allDataPre = read.csv(exprLoc, header = T)
    list[geneData, exprData] = sepExpr(allDataPre)
    
    if (!all(colnames(exprData) %in% make.names(design[[sampleName]]))){
        if(is.null(rotate)){
            print('Unless you are rotating samples, something has gone terribly wrong!')
        }
        exprData = exprData[,colnames(exprData) %in% design[[sampleName]]]
    }
    
    design = design[match(colnames(exprData),make.names(design[[sampleName]]),),]
    
    exprData = t(exprData)
    noReg = F
    if (is.null(regionNames)){
        regionNames = 'dummy'
        design[,regionNames] = 'dummy'
        noReg = T
    }
    
    # deal with region stuff ----
#     regions =
#         trimNAs(
#             trimElement(
#                 unique(
#                     unlist(
#                         strsplit(as.character(design[,regionNames]),',')))
#                 ,c('ALL','All','all','Cerebrum'))) #S pecial names
#     regionBased = expand.grid(groupNames, regions)
#     regionGroups = vector(mode = 'list', length = nrow(regionBased))
#     names(regionGroups) = paste0(regionBased$Var2,'_',regionBased$Var1)
#     
#     
#     for (i in 1:nrow(regionBased)){
#         regionGroups[[i]] = design[,as.character(regionBased$Var1[i])]
#         
#         # remove everything except the region and ALL labeled ones. for anything but cerebellum, add Cerebrum labelled ones as well
#         if (regionBased$Var2[i] == 'Cerebellum'){
#             regionGroups[[i]][!grepl(paste0('(^|,)((',regionBased$Var2[i],')|((A|a)(L|l)(l|l)))($|,)'),design[,regionNames])] = NA
#         } else {
#             # look for cerebrums
#             cerebrums = unique(regionGroups[[i]][grepl('(Cerebrum)',design[,regionNames])])
#             
#             # find which cerebrums are not represented in the region
#             cerebString = paste(cerebrums[!cerebrums %in% regionGroups[[i]][grepl(paste0('(^|,)((',regionBased$Var2[i],')|((A|a)(L|l)(l|l)))($|,)'),design[,regionNames])]],
#                                 collapse = ')|(')
#             
#             # add them as well (or not remove them as well) with all the rest of the region samples
#             regionGroups[[i]][(!grepl(paste0('(^|,)((',regionBased$Var2[i],')|((A|a)(L|l)(l|l)))($|,)'),design[,regionNames])
#                                & !(grepl(paste0('(',cerebString,')'),design[,as.character(regionBased$Var1[i])]) & grepl('Cerebrum',design[,regionNames])))] =  NA
#             
#         }
#         
#         
#     }
    regionGroups = regionize(design,regionNames,groupNames)
    # concatanate new region based groups to design and to groupNames so they'll be processed normally
    if (!noReg){
        design = cbind(design,regionGroups)
        groupNamesEn = c(groupNames, names(regionGroups))
    } else {
        groupNamesEn = groupNames
    }
    
    # generate nameGroups to loop around -----
    nameGroups = vector(mode = 'list', length = len(groupNamesEn))
    
    
    names(nameGroups) = c(groupNamesEn)
    
    for (i in 1:len(groupNamesEn)){
        nameGroups[[i]] = design[,groupNamesEn[i]]
    }
    nameGroups = nameGroups[unlist(lapply(lapply(lapply(nameGroups,unique),trimNAs),length)) > 1]
    #debug exclude
    if (!is.null(debug)){
        nameGroups = nameGroups[names(nameGroups) %in% debug]
        groupNamesEn = groupNamesEn[groupNamesEn %in% debug]
    } 
    groupNamesEn = names(nameGroups)
    
    # the main loop around groups ------
    
    # foreach (i = 1:len(nameGroups)) %dopar% {
     for (i in 1:len(nameGroups)){
         #debub point for groups
        typeNames = trimNAs(unique(nameGroups[[i]]))
        realGroups = vector(mode = 'list', length = length(typeNames))
        names(realGroups) = typeNames
        for (j in 1:length(typeNames)){
            realGroups[[j]] = which(nameGroups[[i]] == typeNames[j])
        }
        
        # if rotation is checked, get a subset of the samples. result is rounded. so too low numbers can make it irrelevant
        if (!is.null(rotate)){
            realGroups2 = lapply(realGroups,function(x){
              if(len(x)==1){
                warning('Samples with single replicates. Bad brenna! bad!')
                return(x)
              }
              sort(sample(x,len(x)-round(len(x)*rotate)))
              })
            removed = unlist(realGroups)[!unlist(realGroups) %in% unlist(realGroups2)]
            realGroups = realGroups2
        }
        tempExpr = exprData[unlist(realGroups),]
        tempDesign = design[unlist(realGroups),]
 
        
        
        # replicateMeans ------
        # inefficient if not rotating but if you are not rotating you are only doing it once anyway
        
        indexes = unique(tempDesign[[replicates]])
        repMeanExpr = sapply(1:len(indexes), function(j){
            tryCatch({
                apply(tempExpr[tempDesign[[replicates]] == indexes[j],], 2,mean)},
                error= function(e){
                    if (is.null(rotate)){
                        print('unless you are rotating its not nice that you have single replicate groups')
                        print('you must be ashamed!')
                        print(j)
                    }
                    tempExpr[tempDesign[[replicates]] == indexes[j],]
                })
        })
        repMeanExpr = t(repMeanExpr)
        repMeanDesign = tempDesign[match(indexes,tempDesign[[replicates]]),]
        
        # since realGroups is storing the original locations required for
        # silhouette store the new locations to be used with repMeanExpr here
        # use the old typeNames since that cannot change
        realGroupsRepMean =  vector(mode = 'list', length = length(typeNames))
        print(names(nameGroups)[i])
        for (j in 1:length(typeNames)){
            realGroupsRepMean[[j]] = which(repMeanDesign[,groupNamesEn[i]] == typeNames[j])
        }
        names(realGroupsRepMean) = typeNames
        
        # groupMeans ----
        #take average of every group
        
        groupAverages = sapply(realGroupsRepMean, function(j){
            groupAverage = apply(repMeanExpr[j,,drop=F], 2, mean)
            
        })
        groupAverages = t(groupAverages)
        
        # creation of output directories ----
        dir.create(paste0(outLoc ,'/Marker/' , names(nameGroups)[i] , '/'), showWarnings = F,recursive = T)
        dir.create(paste0(outLoc , '/Relax/' , names(nameGroups)[i] , '/'), showWarnings = F, recursive =T)
        if (!is.null(rotate)){
            write.table(removed,
                        file = paste0(outLoc,'/Relax/',names(nameGroups)[i] , '/removed'),
                        col.names=F)
        }
        
        # for loop around groupAverages
        for (j in 1:nrow(groupAverages)){
            # cell type specific debug point
            #if (names(realGroups)[j]=='GabaOxtr'){
            #  print('loyloy')  
            #}
            fileName = paste0(outLoc  , '/Relax/', names(nameGroups)[i], '/',  names(realGroups)[j])
            fileName2 = paste0(outLoc , '/Marker/' , names(nameGroups)[i] , '/' , names(realGroups)[j])
            
            # find markers. larger than 10 fold change to every other group
            isMarker = apply(groupAverages,2,function(x){
                all(x[-j] + log(10, base=2) < x[j])
            })  
  
            fMarker = data.frame(geneData$Gene.Symbol[isMarker], groupAverages[j,isMarker], apply(groupAverages[-j,isMarker,drop=F],2,max), apply(groupAverages[-j,isMarker,drop=F],2,min))
            fChange = foldChange(groupAverages[j, ], groupAverages[-j,,drop=F] ,foldChangeThresh)
            fChangePrint = data.frame(geneNames = geneData$Gene.Symbol[fChange$index], geneFoldChange= fChange$foldChange )
            fChangePrint = fChangePrint[order(fChangePrint$geneFoldChange, decreasing=T) ,]
            
            #silhouette. selects group members based on the original data matrix
            # puts them into two clusters to calculate silhouette coefficient
            groupInfo1 = realGroups[[j]]
            groupInfo2 = unlist(realGroups[-j])
            
            silo = vector(length = nrow(fChangePrint))
            if (!nrow(fChangePrint) == 0){
                for (t in 1:nrow(fChangePrint)){
                  # gene specific debug point
                   # if(fChangePrint$geneNames[t] == 'Lmo7'){
                   #     print('gaaaaa')
                    # }
                    silo[t] = giveSilhouette(which(geneData$Gene.Symbol == fChangePrint$geneNames[t]),
                                                   groupInfo1,
                                                   groupInfo2)
                }
                fChangePrint = cbind(fChangePrint, silo)
            } else {
                fChangePrint = data.frame(fChangePrint, silo=numeric(0))
            }
            
            
            print(fileName)
            # print(nameGroups[[i]])
            write.table(fChangePrint, quote = F, row.names = F, col.names = F, fileName)
            write.table(fMarker, quote = F, row.names = F, col.names = F, fileName2)
            
        }# end of for around groupAverages
        
    } # end of foreach loop around groups
} # end of function
