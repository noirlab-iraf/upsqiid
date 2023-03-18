# PHOTPROC: 03JUN99 KMM expects IRAF 2.11Export or later 
# PHOTPROC -- Center and do photometry for processed standards
# STDPROC:  13MAR99 KMM setup processing for standards
# PHOTPROC: 18MAR99 KMM initial setup for photometry
# PHOTPROC: 03JUN99 KMM replace DAOFIND with STARFIND

procedure photproc (input)

string input      {prompt="Input images"}
#string output     {prompt="Output image descriptor: @list||.ext||%in%out%"}

bool   verbose    {yes,prompt="Verbose output?"}
file   logfile    {"STDOUT",prompt="logfile name"}

##int    include    {0, prompt="Number of included images in blankimage subset"}
#int    improc     {5, prompt="Number of images to process in group"}
##int    imskip     {0, prompt="Number of images to skip between process"}
#int    first_proc {1, prompt="List number of first image to be processed"}
#int    last_proc  {1000, prompt="List number of last image to be processed"}

bool   docenter   {yes, prompt="Find coordinates of standards?"}
bool   interactive {no, prompt="Find stars inteactively?"}
string findsub    {"[350:700,350:700]", prompt="Section for finding standards"}

#real   fthreshold { 25.,   prompt="Threshold in sigma for feature detection"}
#real   fsigma     { INDEF, prompt="Standard deviation of background in counts"}
#real   fdatamin   { -25.,  prompt="Minimum good data value"}
#real   fdatamax   { INDEF, prompt="Maximum good data value"}
#real   fwhm       { 5., prompt="FWHM of the PSF in scale units"}

real   sthreshold { 250.,
                     prompt="Detection threshold above local background in ADU"}
real   ssigma     { INDEF, prompt="Standard deviation of background in counts"}
real   sdatamin   { INDEF, prompt="Minimum good data value"}
real   sdatamax   { INDEF, prompt="Maximum good data value"}
real   shwhm      { 2., prompt="HWHM of the PSF in scale units"}		      
real   sradius    { 2.5,prompt="Fitting radius in HWHM"}
real   ssepmin    { 5.0,prompt="Minimum separation in HWHM"}
int    snpixmin   { 5,  prompt="Minimum number of good pixels above background"}
real   numsig     { 1.0,   
                      prompt="Floor below median in sigma for good data value"}
		      
bool   dophot     {yes, prompt="Run QPHOT on standards"}
real   qcbox      { 5., prompt="Centering box width in pixels"}
real   qannulus   { 10., prompt="Inner radius of sky annulus in pixels"}
real   qdannulus  { 3., prompt="Width of the sky annulus in pixels"}
string qapertures { "5,6,7,8,9,10", prompt="List of photometry apertures"}
real   qzmag      { 25., prompt="Zero point of magnitude scale"}
string qexposure  { "INT_S", prompt="Exposure time image header keyword"}
string qairmass   { "AIRMAS", prompt="Airmass image header key word"}
string qfilter    { "", prompt="Filter image header keyword"}
string filter     { "", prompt="Filter name?"}
string qstarid    { "", prompt="Star ID image header keyword"}
string starid     { "", prompt="Star ID?"}

real   lthreshold {INDEF,prompt="Lower threshold for exclusion in statistics"}
real   hthreshold {INDEF,prompt="Upper threshold for exclusion in statistics"}
   
struct  *inlist,*outlist,*imglist,*l_list

begin

   int    nin, irootlen, orootlen, stat, pos1b, pos1e, pos2b, pos2e,
          nxlotrim,nxhitrim,nylotrim,nyhitrim, ncols, nrows,
          img_num, first_in, last_in, ilist, gnum
   real   rnorm, rmean, rmedian, rmode, fract, rawmedian
   string in,in1,in2,out,iroot,oroot,uniq,img,sname,sout,sbuff,sjunk,
          smean, smedian, smode, front, srcsub, 
          combopt, zeroopt, scaleopt, normstat, reject
   file   skyimg,  nflat, infile, outfile, im1, im2, im3, tmp1, tmp2, tmp3,
          tmp4, tmp5, l_log, task
   bool   found
   bool   debug=no
   int    nex
   string gimextn, imextn, imname, imroot
   int    include, imskip, sub_num,
          nxhi, nxlo, nyhi, nylo, nxhisrc, nxlosrc, nyhisrc, nylosrc
   real   rsdev, rmin, xcen, ycen, rmag
   string imsky, imobj, imprior, imnext
   struct line = ""

# Assign positional parameters to local variables
   in          = input
#   out         = output
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)  
  
#   imskip = 0
#   include = improc - 1
   if (docenter) { # get coordinates of finder box
      print (findsub) | translit ("", "[:,]", "    ") |
         scan(nxlo,nxhi,nylo,nyhi)
      if (nscan() != 4) {
         nxlosrc = 1
	 nylosrc = 1
      }
   }
   
   uniq        = mktemp ("_Tabp")
   infile      = mktemp ("tmp$abn")
   outfile     = mktemp ("tmp$abn")
   tmp1        = mktemp ("tmp$abn")
   tmp2        = mktemp ("tmp$abn")
   tmp3        = mktemp ("tmp$abn")
   tmp4        = mktemp ("tmp$abn")
   tmp5        = mktemp ("tmp$abn")
   l_log       = mktemp ("tmp$abn")

# check whether input stuff exists

   print (in) | translit ("", "@", " ") | scan(in1)
   if ((stridx("@",in) == 1) && (! access(in1))) {	# check input @file
      print ("Input file ",in1," does not exist!")
      goto skip
   }
   sections (in,option="nolist")
   if (sections.nimages == 0) {			# check input images
      print ("Input images in file ",in, " do not exist!")
      goto skip
   }

# Expand input file name list
#   option="root" truncates lines beyond ".imh" including section info
   sections (in, option="root",> infile)
   
   l_list = l_log

   count(infile) | scan(pos1b)
   nin = pos1b
   inlist = ""
   
# Start logging info
   delete (tmp1, ver-, >& "dev$null")
# send newline if appending to existing logfile
   if (access(logfile)) print("\n",>> tmp1)
# Get date
   time() | scan(line)
# Print date and id line

   print ("imagelist: ",nin,"images",>> tmp1)
   type (infile, >> tmp1)

# Loop through data
   img_num = 0
   gnum    = 0
   l_list = ""; delete (tmp1, verify-,>& "dev$null")
   inlist = infile
   copy (infile, tmp2)
   while ((fscan (inlist,sname) != EOF)) {
   
#      img_num += 1
#      if (img_num < first_proc)
#         next  # skip until appropriate list number      
#      if (((img_num > last_proc)  || (img_num > nin)))
#         break # terminate
#      
#      sub_num = ((img_num - first_proc) % (improc+imskip))
#      if (sub_num == 0)
#         gnum +=1
#
#      if ((img_num > (first_proc + gnum*improc + (gnum-1)*imskip - 1))) {
#          next  # skip until appropriate list number
#      }
#
#      if (verbose) print ("# list_number: ",img_num,sname)
#       
# Subtract the blank image from the raw data images.
#
#      first_in = first_proc + (gnum - 1)*improc
#      last_in  = first_in + improc - 1
#     
#         first_in = img_num - int((include/2))
#         last_in  = int((include + 1)/2) + img_num
#
#      if (first_in < 1) {
#         last_in += (1 - first_in)
#         first_in = 1
#      } else if (last_in > nin) {
#         first_in -= (last_in - nin)
#         last_in = nin
#1      }
      
      sout = sname
              
      if (docenter) {
         imstatistics (sout//findsub,
	    fields="npix,mean,midpt,mode,stddev,min,max",
            lower=lthreshold, upper=hthreshold, binwidth=0.01, format-,>> tmp1)
         if(verbose) type (tmp1,>> logfile)
         l_list = tmp1
	 stat = fscan (l_list,sjunk,rmean,rmedian,rmode,rsdev)
	 
         l_list = ""; delete (tmp1, verify-,>& "dev$null")
         rmin = rmedian - numsig*rsdev      
   
	 if (interactive) {
	   
            getstar (sout,outfile=tmp4,displ_frame=1,centroid-,bigbox=11,
               boxsize=7,background=INDEF,lower=INDEF,upper=INDEF,niterate=3,
	       tolerance=0.,zscale+,z1=0,z2=1000)
	    if (verbose) type (tmp4,>> logfile)
	    stat = 0; l_list = tmp4   
	    while (fscan(l_list,sname,xcen,ycen) != EOF) {
	       stat += 1    
	       print (xcen,ycen,stat,>> tmp5)
	       print (xcen,ycen,stat,>> logfile)
	    }
	 } else {
#            daofind (sout//findsub, output=tmp4, verify-, interactive-,
#	       fwhmpsf=5, emission+, sigma=rsdev, datamin=rmin,
#	       threshold=fthreshold)
             starfind (sout//findsub, output=tmp4, hwhmpsf=3.,
	       threshold=sthreshold, datamin=rmin, datamax=sdatamax,
	       fradius=sradius, sepmin=ssepmin, npixmin=snpixmin,
	       maglo=INDEF, maghi=INDEF,
	       roundlo=0., roundhi=0.9, sharplo=0.4, sharphi=2.0,
	       wcs="", wxformat="", wyformat="", boundary="nearest", constant=0)
	               
#        image = ""              Input image
#       output = "default"       Output star list
#      hwhmpsf = 1.              HWHM of the PSF in pixels
#    threshold = 100.            Detection threshold in ADU
#     (datamin = INDEF)          Minimum good data value in ADU
#     (datamax = INDEF)          Maximum good data value in ADU
#     (fradius = 2.5)            Fitting radius in HWHM
#      (sepmin = 5.)             Minimum separation in HWHM
#     (npixmin = 5)              Minimum number of good pixels above background
#       (maglo = INDEF)          Lower magnitude limit
#       (maghi = INDEF)          Upper magnitude limit
#     (roundlo = 0.)             Lower ellipticity limit
#     (roundhi = 0.2)            Upper ellipticity limit
#     (sharplo = 0.5)            Lower sharpness limit
#     (sharphi = 2.)             Upper sharpness limit
#         (wcs = "")             World coordinate system (logical,physical,world
#    (wxformat = "")             The x axis world coordinate format
#    (wyformat = "")             The y axis world coordinate format
#    (boundary = "nearest")      Boundary extension (nearest,constant,reflect,wr
#    (constant = 0.)             Constant for constant boundary extension
#     (nxblock = INDEF)          X dimension of working block size in pixels
#     (nyblock = 256)            Y dimension of working block size in pixels
#     (verbose = no)             Print messages about the progress of the task
          
	    if (verbose) type (tmp4,>> logfile)
#	    txdump (tmp4, "XCENTER,YCENTER,MAG,ID", yes, >> tmp1)
#	    stat = 0; l_list = tmp1
#	    while (fscan(l_list,xcen,ycen,rmag,stat) != EOF) {
            match ("^\#", tmp4, stop+, meta+, print-) | 
	       match ("[1234567890]","",stop-,meta+, print-,> tmp1)
	    stat = 0; l_list = tmp1
	    while (fscan(l_list,xcen,ycen) != EOF) {
	       stat += 1
	       xcen = xcen + nxlo - 1
	       ycen = ycen + nylo - 1	    
	       print (xcen,ycen,stat,>> tmp5)
	       print (xcen,ycen,stat,>> logfile)
	    }
	 } 
	 if (stat == 1) {
	    hedit (sout,"XCENTER",xcen,add+,delete-,verify-,show-,update+)
	    hedit (sout,"YCENTER",ycen,add+,delete-,verify-,show-,update+)
            if (dophot) {    
	       qphot(sout,qcbox,qannulus,qdannulus,qapertures,coords=tmp5,
	          zmag=qzmag, exposure=qexposure, airmass=qairmass,
		  filter=qfilter, output="default",
		  inter-,radplots-,verbose-, icommands="", gcommands="")
# txdump
#   textfiles = "*.mag.2"       Input apphot/daophot text database(s)
#       fields = "IMA,XCEN,YCEN,ITIME,XAIR,MAG" Fields to be extracted
#         expr = "yes"           Boolean expression for record selection
#     (headers = no)             Print the field headers ?
#  (parameters = no)            Print the parameters if headers is yes ?
	    }
	 } else if (stat == 0) {
	    if (verbose) print ("Warning: no objects found in ", sout//findsub)
	    print ("Warning: no objects found in ",sout//findsub,>> logfile)    	     
	 } else {
	    if (verbose) {
	       print ("Warning: too many objects found in ",sout//findsub)
	    }
	    print ("Warning: too many objects found in ",sout//findsub,
	       >> logfile)
         }
	 l_list = ""
	 delete (tmp1//","//tmp4//","//tmp5, verify-,>& "dev$null" )	 	 
      }
   }
   
skip:

# Finish up
inlist = ""; outlist = ""; imglist = ""; l_list = ""
delete (tmp1//","//tmp2//","//tmp3//","//tmp4//","//tmp5, verify-,>& "dev$null")
delete (infile//","//outfile//","//l_log, verify-, >& "dev$null")
   
end
