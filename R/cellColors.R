library(viridis)

cellColors = function(){
    
    coloring = c(Oligo = 'darkgreen',
                 Bergmann = 'palegreen',
                 MotorCholin = 'darkorange4',
                 Cholin = 'darkorange',
                 Spiny = 'blanchedalmond',
                 Gluta = 'slategray',
                 Basket = 'mediumpurple4',
                 Golgi = 'orchid',
                 Pyramidal = 'turquoise',
                 Purkinje = 'purple',
                 Inter = 'pink',
                 CerebGranule = 'thistle',
                 DentateGranule = 'thistle3',
                 Microglia = 'white',
                 # Gaba = 'firebrick4',
                 Astrocyte = 'yellow',
                 GabaPV = 'firebrick2',
                 Stem = 'blue' ,
                 Ependymal = 'orange',
                 Serotonergic = 'darkolivegreen',
                 Hypocretinergic = 'cadetblue',
                 Dopaminergic = 'gray0',
                 Th_positive_LC = 'blueviolet',
                 GabaVIPReln = 'firebrick4',
                 GabaRelnCalb = 'firebrick3',
                 GabaSSTReln = 'firebrick1',
                 GabaReln = 'firebrick',
                 GabaVIPReln = 'firebrick4',
                 GabaReln = 'firebrick',
                 Pyramidal_Thy1 = 'turquoise',
                 PyramidalCorticoThalam = 'blue',
                 Pyramidal_Glt_25d2 = 'blue4',
                 Pyramidal_S100a10 ='deepskyblue3',
                 Glia = viridis(2)[1],
                 Neuron = viridis(2)[2]
                 
    )
    
    return(coloring)
}
