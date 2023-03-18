# Package scripts for the UPSQIID package

# load necessary packages
     noao
# artdata is loaded to get mkpattern routine used in NIRCOMBINE
     artdata
# imred, irred, onedspec are loaded to get center routine and apcenter routine used in GETCENTERS
     imred
        irred
#     onedspec
# iis is loaded to get frame routine for IRAF2.11EXPORT
     iis
#     digiphot
#       apphot
#     tables
#     ttools
#    utilities
#    proto
#    tv
#    local

# change sqiiddir to point to SQIID directory in target system
set     upsqdir       = "home$myprog/upsqiid/"

package upsqiid

# set     helpdb          = "upsqdir$upsqiid.db"
 
### tasks
task    usqcorr         = "upsqdir$usqcorr.cl"  
task    usqdark         = "upsqdir$usqdark.cl"
task    usqflat         = "upsqdir$usqflat.cl"
task    usqmask         = "upsqdir$usqmask.cl"
task    usqmos          = "upsqdir$usqmos.cl"
task    usqproof        = "upsqdir$usqproof.cl"  
task    usqsky          = "upsqdir$usqsky.cl"  
task    usqproc         = "upsqdir$usqproc.cl"  
task    movproc         = "upsqdir$movproc.cl"
task    patproc         = "upsqdir$patproc.cl"  
task    photproc        = "upsqdir$photproc.cl"  
task    stdproc         = "upsqdir$stdproc.cl"  
task    stdreport       = "upsqdir$stdreport.cl"  
task    $cleanup        = "upsqdir$cleanup.cl"
task    chlist          = "upsqdir$chlist.cl"
task    imclip          = "upsqdir$imclip.cl"
task    imzero          = "upsqdir$imzero.cl"  
task    mkmask          = "upsqdir$mkmask.cl"
task    mergecom        = "upsqdir$mergecom.cl"  
task    nircombine      = "upsqdir$nircombine.cl"
task    recombine       = "upsqdir$recombine.cl"  
task    sqcorr          = "upsqdir$sqcorr.cl"  
task    statelist       = "upsqdir$statelist.cl"
task    where           = "upsqdir$where.cl"
task    which           = "upsqdir$which.cl"
task    xyadopt         = "upsqdir$xyadopt.cl"  
task    xyget           = "upsqdir$xyget.cl"   
task    zget            = "upsqdir$zget.cl"  
### subroutines
task    closure         = "upsqdir$closure.cl"  
task    expandnim       = "upsqdir$expandnim.cl"
task    getcenters      = "upsqdir$getcenters.cl"
task    getstar         = "upsqdir$getstar.cl"  
task    linklaps        = "upsqdir$linklaps.cl"
task    locate          = "upsqdir$locate.cl"  
task    mkframelist     = "upsqdir$mkframelist.cl"
task    mkpathtbl       = "upsqdir$mkpathtbl.cl"
task    notchlist       = "upsqdir$notchlist.cl"
task    transmat        = "upsqdir$transmat.cl" 
task    xylap           = "upsqdir$xylap.cl" 
task    xytrace         = "upsqdir$xytrace.cl"  
task    ztrace          = "upsqdir$ztrace.cl"  
### display
task    imgraph         = "upsqdir$imgraph.cl"  
task    show4           = "upsqdir$show4.cl"  
### geomap
task    getmap          = "upsqdir$getmap.cl"  
task    usqremap        = "upsqdir$usqremap.cl"  
### misc
task    imlinfit        = "upsqdir$imlinfit.cl"
task    imquadfit       = "upsqdir$imquadfit.cl"
task    imlinregress    = "upsqdir$imlinregress.cl"
### prototype
task    imparse         = "upsqdir$imparse.cl"
task    sqparse		= "upsqdir$sqparse.cl"
task	sqsections	= "upsqdir$sqsections.cl"
task    grid		= "upsqdir$grid.cl"
task    group		= "upsqdir$group.cl"
task    rechannel	= "upsqdir$rechannel.cl"
task    chorient 	= "upsqdir$chorient.cl"
task    hierarch 	= "upsqdir$hierarch.cl"
task    overlap  	= "upsqdir$overlap.cl"
task    filedir 	= "upsqdir$filedir.cl"
task    tmove    	= "upsqdir$tmove.cl"
### NAAC
task	pltnaac		= "upsqdir$pltnaac.cl"
task    pltstat         = "upsqdir$pltstat.cl"  
task    proctest	= "upsqdir$proctest.cl"
task    temp_plot	= "upsqdir$temp_plot.cl"
### external
task   fileroot		= "upsqdir$fileroot.cl"
task   iterstat		= "upsqdir$iterstat.cl"
task   minv    		= "upsqdir$minv.cl"

keep
clbye()
