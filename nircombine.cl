# NIRCOMBINE: 25MAR02 KMM expects IRAF 2.12Export or later
# NIRCOMBINE - produce IMCOMBINED IR image of heavily overlapped region
# NIRCOMBINE: 13OCT92 KMM
# NIRCOMBINE: incorporates Valdes' new IMCOMBINE 
# NIRCOMBINE: incorporates frame_num list to combine subset of image database
# NIRCOMBINE: 09JUN93 KMM
# NIRCOMBINE: incoporates imstack to get around 102 image limit
# NIRCOMBINE: 16FEB94 KMM
# NIRCOMBINE: fix so that all input images to imstack have the same dimension
#  02MAR94 KMM  shift internal files to avoid internal use of "type" command
#  06APR94 KMM Replace "type" with "concatenate" or "copy"
#  08APR94 KMM Remove prior imcombine version parts so that "nircomine" is the
#                current version and onircombine is the prior version.
#  27APR94 KMM Modify stack database.
#              Add apply_zero flag to allow choice of 
#                (1) applying zero-point shifts via imarith prior to imcombine,
#                    so that zeropoint adjusted results will be saved via
#                    make_stack+ or save_images+.
#                (2) submitting intensity offsets file directly to imcombine,
#                    so that zeropoint unadjusted results will be saved via
#                    make_stack+ or save_images+.
#                NB: IMCOMBINE conserves flux.  The mean of zero-point offsets
#                    is computed, the adjustments are made relative to this mean
#                    value.  The net result is that the level of the resultant
#		     image shifts by the mean value of the zero-point offsets.
#              Fix so that frame_nums=""," ","all" works to include all frames.
#              Fix bug in recovering intensity offsets from imcombine log;
#                 When less than 10 images are combined, the format is
#                     imname[n] median adjust xoff yoff
#                 However when 10 or more images are combined, the  format is:
#                     imname[ n] median adjust xoff yoff ;  n < 10
#                     imname[nn] median adjust xoff yoff ;  n >= 10
#                 Since the field count varies for ten or more images, the
#                    assumption that field 3 contained the "adjust" value
#                    fails on images 1-9 (median is extracted)
#              Replace fscan with scan from a pipe to get database parameters
#              Note: IRAF V2.10EXPORT April 1992 imcombine has an inconsistency
#                 in the sign convention on applied zeropoint.  The sign of the
#                 file based zeropoint assumes the value to be subtracted,
#                 whereas the reported number is the value to be added.  These
#                 have been reconciled to "value to be added" in the next
#                 release and current IRAFX.  zero_invert flag toggles these
#                 situations.
#  23JUN94 KMM Identify and use smallest and largest COM# when all frames are
#              requested
#  22JUL94 KMM replace fscan with scan from file a key spots
#  08AUG94 KMM utilize printf for formatted output (instead of AWK)
#  18APR96 KMM allow specification of statsec to determine zero offsets
#  17MAR98 KMM typo fixes
#  25JUL98 KMM add global image extension
#              replace access with imaccess where appropriate
#              incorporate imexpr into setpix option
#  17AUG98 KMM modified imexpr to produce explicitly real image for setpix
#              implement scale_it option to scale images to a common effective
#                 integration time (to_scale) according to image header
#                 keyword (to_name)
#  15MAY00 KMM replace default for reject_value with -1e7 (was -1e8) to
#                 get setpix to work with floating point images
#              modify geotran paramerization to match new geotran lexicon
#  17JUL00 KMM modify parsing of IMCOMBINE output in response to new IMCOMBINE
#                 output format
#  28DEC00 KMM modify for use of "gregister" instead of "geotran" 
#  06FEB00 KMM correct error in call to gregister
#  11OCT01 KMM move scale_it ahead of setpix so original headers can be accessed
#              following an invocation of gregister, original headers are lost
#              corrected scale_it to read real rather than integer header value
#  25MAR02 KMM change imcombine parameters for IRAF2.12

procedure nircombine (match_name,infofile)

string match_name   {prompt="name of resultant composite image"}
file   infofile     {prompt="file produced by XYGET|XYLAP|XYADOPT"}

string frame_nums   {"",
                   prompt="Include only selected frame numbers in MOSAIC|@list"}
file   outfile      {"", prompt="Output information file name"}
# trim values applied to final image
string trimlimits   {"[2:2,2:2]",
                      prompt="added trim limits for input subrasters"}
bool   register     {yes,prompt="Maintain input image origin and size"}
string common       {"median",enum="none|adopt|mean|median|mode",
              prompt="Pre-combine common offset: |none|adopt|mean|median|mode|"}
string comb_opt     {"median", enum="average|median",
                       prompt="Type of combine operation: |average|median|"}
string reject_opt   {"none", prompt="Type of pixel rejection operation",
                    enum="none|minmax|ccdclip|crreject|sigclip|avsigclip|pclip"}
string stat_sec     {"overlap",
                       prompt="Image section for calculating statistics"}
real   lthreshold   {-200.,prompt="Rejection floor for imcombine and stats"}
real   hthreshold   {65000.,prompt="Rejection ceiling for imcombine and stats"}
real   blank        {-1000.,prompt="Value if there are no pixels"}
bool   setpix       {no,prompt="Run SETPIX on data?"}
string maskimage    {"badmask", prompt="bad pixel image mask"}
real   svalue       {-1.0e7, prompt="Setpix value (far below lthreshold)"}
bool   fixpix       {no,prompt="Run FIXPIX on data?"}
string fixfile      {"badpix", prompt="badpix file in FIXPIX format"}
real   to_scale     {0.0,
                   prompt="Scale to value (0 = noscale) via to_name"}
string to_name      {"INT_S", prompt="Image header to_name keyword"}
# bool   project      {no,prompt="Project highest dimension of input images?"}
bool   make_stack   {no,prompt="Imstack images prior to imcombine?"}
bool   apply_zero   {yes,prompt="Apply zeropoint to images prior to imcombine?"}
bool   invert_zero  {no, 
                     prompt="Invert database zeropoints prior to application?"}
# prior to IRAF 2.10 one must invert to database zeropoints when using imcombine
bool   save_images  {no,prompt="Save images which were IMCOMBINED via imstack?"}
bool   do_combine   {yes,prompt="IMCOMBINE (else IRMATCH) into final image?"}
bool   verbose      {yes, prompt="Verbose output?"}

bool   size         {no, prompt="Compute image size?"}
string interp_shift {"linear",enum="nearest|linear|poly3|poly5|spline3",
              prompt="IMSHIFT interpolant (nearest,linear,poly3,poly5,spline3)"}
string bound_shift  {"nearest",enum="constant|nearest|reflect|wrap",
                      prompt="IMSHIFT boundary (constant,nearest,reflect,wrap)"}
real   const_shift  {0.0,prompt="IMSHIFT Constant for boundary extension"}
real   gxshift      {0.0, prompt="global xshift for final image"}
real   gyshift      {0.0, prompt="global yshift for final image"}
string goverlap     {"", prompt="Global overlap section (overrides all else)"}
string gsize        {"", prompt="Global image size (overrides all else)"}
string weight       {"none",prompt="Image weights"}
bool   mclip        {no, prompt="Use median, not mean, in clip algorithms"}
real   pclip        {-0.5, prompt="pclip: Percentile clipping parameter"}
int    nlow         {1, prompt="minmax: Number of low pixels to reject"}
int    nhigh        {1, prompt="minmax: Number of high pixels to reject"}
real   lsigma       {3., prompt="Lower sigma clipping factor"}
real   hsigma       {3., prompt="Upper sigma clipping factor"}
real   sigscale     {0.1,
                     prompt="Tolerance for sigma clipping scaling correction"}
int    grow         {0, prompt="Radius (pixels) for 1D neighbor rejection"}
string expname      {"", prompt="Image header exposure time keyword"}
string rdnoise      {"0.", prompt="ccdclip: CCD readout noise (electrons)"}
string gain         {"1.", prompt="ccdclip: CCD gain (electrons/DN)"}

bool   answer       {yes, prompt="Do you want to continue?", mode="q"}
bool   compute_size {yes, 
                       prompt="Do you want to [re]compute image size?",mode="q"}

struct  *list1, *list2

begin

   int    i,stat,nim,maxnim,slen,slenmax,njunk,pos1b,pos1e,ncolsout,nrowsout,
          nxoff0,nyoff0,im_xoffset,im_yoffset,c_opt,maxsizex,maxsizey,
          ncols, nrows, nxhiref, nxloref, nyhiref, nyloref,mincom,maxcom,
          nxhi, nxlo, nyhi, nylo, nxhisrc, nxlosrc, nyhisrc, nylosrc,
          nxlotrim,nxhitrim,nylotrim,nyhitrim,
          nxlolap,nxhilap,nylolap,nyhilap,
          nxhimat,nxlomat,nyhimat,nylomat,
          nxlonew,nxhinew,nylonew,nyhinew,
          nxmat0, nymat0, nxmos0, nymos0, ixs, iys, ndim, max_nim
   real   zoff, rjunk, xin, yin, xmat, ymat, fxs, fys,
          xs, ys, xoff, yoff, g_xshift, g_yshift, xmax, xmin, ymax, ymin,
          xofftran,yofftran,gtxmax, gtxmin, gtymax, gtymin,
          oxmax,oxmin,oymax,oymin,xoffset,yoffset,
          xlo, xhi, ylo, yhi, xshift, yshift, reject_value
   real   roff, delta, rmedian, rmode, avestat, avemean, avemode, avemedian,
          rmean, stddev_mean,stddev_median,stddev_mode
   bool   do_tran, tran, max_tran, prior_tran,fluxtran,found,new_origin,update,
          project, zero_invert, scale_it
   string uniq,imname,tmpname,matchname,slist,sjunk,soffset,encsub,sopt,
          src,srcsub,mos,mossub,mat,matsub,ref,refsub,stasub,lapsec,outsec,
          vigsec,sformat,traninfo,sxrot,syrot,sxmag,symag,sxshift,syshift,
          dbtran,cotran,consttran,geomtran,interptran,boundtran,
          zero, vcheck, reject, combopt, statsec, dbpath,image_nims
   file   info,out,dbinfo,tmp1,tmp2,im1,im2,pre_zero,comblist,
          tmpimg,do1info,do2info,matinfo,newinfo,misc,
          comblog,im_offsets,ncomblist,nimlist,stacklist,combinfo,im_zero
   int    nex
   string gimextn, imextn, imroot
   bool   debug=no
   real   from_scale, mult_by
   struct line = ""

   matchname   = match_name
   info        = infofile
   g_xshift    = gxshift
   g_yshift    = gyshift
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
   
   uniq        = mktemp ("_Ticb")
   newinfo     = mktemp("tmp$icb")
   dbinfo      = mktemp("tmp$icb")
   matinfo     = mktemp("tmp$icb")
   comblist    = mktemp("tmp$icb")
   stacklist   = mktemp("tmp$icb")
   ncomblist   = mktemp("tmp$icb")
   nimlist     = mktemp("tmp$icb")
   do1info     = mktemp("tmp$icb")
   do2info     = mktemp("tmp$icb")
   tmp1        = mktemp("tmp$icb")
   tmp2        = mktemp("tmp$icb")
   combinfo    = mktemp("tmp$icb")
   misc        = mktemp("tmp$icb")
   im_offsets  = mktemp("tmp$icb")
   im_zero     = mktemp("tmp$icb")
   pre_zero    = mktemp("tmp$icb")
   comblog     = mktemp("tmp$icb")
   im1         = uniq // "_im1"
   im2         = uniq // "_im2"
   tmpimg      = uniq // "_tim"

   reject  = reject_opt
   combopt = comb_opt
   
   if (to_scale != 0)
      scale_it = yes
   else
      scale_it = no
      
   i = strlen(matchname)
   if (imaccess(matchname)) {
      print("Image ",matchname," already exists!")
      goto err
   } else if (substr(matchname,i-nex,i) == "."//gimextn)  { # Strip off imextn
      matchname = substr(matchname,1,i-nex-1)
   }  
   if (! access(info)) { 		# Exit if can't find info
      print ("Cannot access info_file: ",info)
      goto err
   }
# establish ID of output info file
   if (outfile == "" || outfile == " " || outfile == "default")
      out = matchname//".src"
   else
      out = outfile
   if (out != "STDOUT" && imaccess(out)) {
      print("Will overwrite output_file ",out,"!")
      if (!answer) goto err
   } else
      print ("Output_file= ",out)

   if (setpix && !imaccess(maskimage)) {	# Exit if can't find mask    
      print ("Cannot access maskimage ",maskimage)
      goto err
   }

   if (svalue >= lthreshold) {
      reject_value = lthreshold - 1.0
      print ("Resetting reject_value from ",svalue," to ",reject_value)
   } else
      reject_value = svalue

# select zero and statsec options
   c_opt = 0				# Establish common offset statistic
   if (common == "none" || common == "" || common == " ") {
      c_opt = 0
      zero="none"
   } else if (common == "adopt") {
      c_opt = 1
      if (apply_zero) {
         zero = "none"
         print ("Note: zero-points will be applied prior to IMCOMBINE.")
      } else {
         zero = "@"//im_zero 
         print ("Note: zero-points will be applied by IMCOMBINE.")
      }
   } else {
      if (common == "mean")   c_opt = 2
      if (common == "median") c_opt = 3
      if (common == "mode")   c_opt = 4
      zero = common
   }

   if (zero != "none") {
      statsec = stat_sec
      if (statsec == "" || statsec == " " || statsec == "overlap")
         statsec = "overlap"
   } else
      statsec = ""

   print("#NOTE: ",common," statistics for data within ",
      lthreshold," to ",hthreshold)

   if (setpix) {
      print ("#SETPIX to ",reject_value," using ", maskimage," mask")
   }

   if (scale_it) {
      print ("#SCALING images to ",to_scale," using ", to_name,
      " header keyword")
   }
   
   print (trimlimits) | translit ("", "[:,]", "    ") |
      scan(nxlotrim,nxhitrim,nylotrim,nyhitrim)

# Transfer appropriate information from reference to output file
   match ("^\#DB",info,meta+,stop-,print-, > dbinfo)

# count number of images, including reference images
   match ("^COM",info,meta+,stop-,print-,> tmp1)
   count(tmp1) | scan(maxcom)     # here maxcom = total number in COMfile
# test for uniqueness of COM lines
   fields (tmp1,1,lines="",quit-,print-) | sort ("",col=0,num-,rev-) |
      unique (>> tmp2)
   count(tmp1) | scan(i)
   if (i < maxcom) {
      i = maxcom - i
      print ("Warning: ",i," COM lines are not unique!")
      goto err
   }
   match ("^COM_000",tmp2,meta+,stop+,print-) | head (nl=1) | scan(sjunk)
   pos1b = stridx("_",sjunk) + 1
   mincom = int(substr(sjunk,pos1b,strlen(sjunk))) # mincom = smallest COM
   tail (tmp2,nl=1) | scan(sjunk)
   pos1b = stridx("_",sjunk) + 1
   maxcom = int(substr(sjunk,pos1b,strlen(sjunk))) # maxcom = largest COM
   delete (tmp2, ver-, >& "dev$null")

# Expand the range of images and extract COMlines from database

   if (frame_nums != "" && frame_nums != " " && frame_nums != "all") {
      print("Selecting image subset: ",frame_nums)
      print (frame_nums) | translit ("", "|", " ") | scan(image_nims)
      expandnim(image_nims,ref_nim=0,max_nim=maxcom,>> nimlist)
      list1 = nimlist
      for (i = 0; fscan(list1,nim) != EOF; i += 1) {
         sjunk = "COM_000" + nim
         match ("^"//sjunk,tmp1,meta+,stop-,print-,>> matinfo)
         list2 = matinfo
         for (slen = 0; fscan(list2,imname) != EOF; slen += 1) {
            pos1b = stridx("_",imname)+1
            stat = int(substr(imname,pos1b,strlen(imname)))
            if (stat == nim) {
               found = yes
               break
            }
            found = no
         }
         if (!found) {
            print("Image path position missing for ",sjunk)
            next
         }
      }
      list1 = ""; list2 = ""
   } else {
      sjunk = mincom//"-"//maxcom
      print("Selecting entire image set: ",sjunk)
      match ("^COM_",info,meta+,stop-,print-, > matinfo)
   }
   delete (tmp1, ver-, >& "dev$null")

# count number of images, excluding reference images
   match ("COM_000",matinfo,meta-,stop+,print-) | count() | scan(maxnim)
   if ((! make_stack) && (maxnim > 102)) {
      print ("Number of images: ",maxnim," exceeds 102 limit.  Use make_stack+")
      goto err
   }
# make list of temporary images
   for (nim = 1; nim <= maxnim; nim += 1) {
      tmpname = uniq//"_000" + nim
      print (tmpname//"."//gimextn, >> comblist)
   }  
   print ("#NOTE: will combine ",maxnim," images...")

# Size of output image
   list1 = tmp1; delete (tmp1, ver-, >& "dev$null")
   match ("out_sec",dbinfo,meta-,stop-,print-) |		# MIG order
      sort (col=1,ignore+,numeric-,reverse+, > tmp1)
   if (fscan(list1, sjunk, sjunk, outsec) != 3) {
      outsec = ""; ncolsout = 256; nrowsout = 256
#         outsec = "[1:256,1:256]"; ncolsout = 256; nrowsout = 256
   } else { 
      print (outsec) | translit ("", "[:,]", "    ") |
         scan(nxlosrc,nxhisrc,nylosrc,nyhisrc)
      ncolsout = nxhisrc - nxlosrc + 1
      nrowsout = nyhisrc - nylosrc + 1
   }
   list1=""; delete (tmp1, ver-, >& "dev$null")
   print ("#NOTE: prior_outsec: ",outsec)

# Get GEOTRAN info
   match ("do_tran",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, do_tran)
   if (do_tran) {		# Fetch GEOTRAN info from database file
      print ("Note: images will be GEOTRANed prior to IMSHIFT and COMBINE")
      match ("db_tran",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, dbtran)
      if (!access(dbtran)) {
         print ("GEOTRAN database file db_tran ",dbtran," not found!")
         goto err
      }
      match ("begin",dbtran,meta-,stop-,print-) | scan (sjunk,cotran)
      if (!access(cotran)) {
         print ("GEOTRAN database coord file co_tran ",cotran," not found!")
         goto err
      }
      match ("geom_tran",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, geomtran)
	 
   # handle new geotran lexicon	 
      if (geomtran != "general" && geomtran != "geometric")
         geomtran = "linear"
      else
         geomtran = "geometric"
	 
      match ("interp_tran",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, interptran)
      match ("bound_tran",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, boundtran)
      match ("const_tran",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, consttran)
      if (real(consttran) > reject_value)
         print ("Note: overriding const_tran with ",reject_value)
      match ("fluxconserve",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, fluxtran)
      match ("xoffset_tran",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, xofftran)
      match ("yoffset_tran",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, yofftran)
      match ("max_tran",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, max_tran)
   }

   time() | scan(line)
# Log parameters 
   print("#DBI ",line," IRCOMBINE:",>> dbinfo)
   print("#DBI    info_file       ",info,>> dbinfo)
   print("#DBI    global_xshift   ",g_xshift ,>> dbinfo)
   print("#DBI    global_yshift   ",g_yshift ,>> dbinfo)
   print("#DBI    global_overlap  ",goverlap,>> dbinfo)
   print("#DBI    global_size     ",gsize,>> dbinfo)
   print("#DBI    more_trimlimits ",trimlimits,>> dbinfo)
   print("#DBI    common_opt      ",common,>> dbinfo)
   print("#DBI    lthreshold      ",lthreshold,>> dbinfo)
   print("#DBI    hthreshold      ",hthreshold,>> dbinfo)
   print("#DBI    fixpix          ",fixpix,>> dbinfo)
   print("#DBI    fixfile         ",fixfile,>> dbinfo)
   print("#DBI    setpix          ",setpix,>> dbinfo)
   print("#DBI    set_mask        ",maskimage,>> dbinfo)
   print("#DBI    set_value       ",reject_value,>> dbinfo)
   print("#DBI    interp_shift    ",interp_shift,>> dbinfo)
   print("#DBI    bound_shift     ",bound_shift,>> dbinfo)
   print("#DBI    const_shift     ",const_shift,>> dbinfo)
   print("#DBI    imcomb_floor    ",lthreshold,>> dbinfo)
   print("#DBI    imcomb_ceiling  ",hthreshold,>> dbinfo)
   print("#DBI    imcomb_blank    ",blank,>> dbinfo)
   print("#DBI    apply_zero      ",apply_zero,>> dbinfo)
   if (do_tran) {
      print("#Note: Images GEOTRANed prior to IMSHIFT and COMBINE",>> dbinfo)
      if (real(consttran) > reject_value)
         print ("#Note: overriding const_tran with ",reject_value,>> dbinfo)
   }

# Put in global shifts
   xoffset = g_xshift; yoffset = g_yshift

   if (outsec == "" || size) {
      if (compute_size || outsec == "")
# Determine corners of minimum rectangle enclosing region
         new_origin = yes
      else
         new_origin = no
   } else
      new_origin = no
   if (new_origin) print ("Will optimize origin.")

# Compute minimum rectangle enclosing region and overlap region
   closure (matinfo,xoffset,yoffset,trimlimits=trimlimits,
      interp_shift=interp_shift,origin=new_origin,verbose+,>> do1info)
   match ("^COM",do1info,meta+,stop-,print-, > newinfo)
   if (verbose) type (newinfo)
   match ("^ENCLOSED_SIZE",do1info,meta+,stop-,print-) |
      scan(sjunk,encsub)
   print (encsub) | translit ("", "[:,]", "    ") |
      scan(nxlomat,nxhimat,nylomat,nyhimat)
   match ("^UNAPPLIED_OFFSET",do1info,meta+,stop-,print-) |
      scan(sjunk,xoffset,yoffset)
   match ("^OVERLAP",do1info,meta+,stop-,print-) |
      scan(sjunk,lapsec,vigsec)
   print (lapsec) | translit ("", "[:,]", "    ") |
      scan(nxlolap,nxhilap,nylolap,nyhilap)
   if (lapsec == "[0:0,0:0]") lapsec = ""

   if (new_origin) {
# Establishes origin at (0,0)
      ncolsout = nxhimat - nxlomat + 1
      nrowsout = nyhimat - nylomat + 1
# Override minimum rectangle
      outsec  = "[1:"// ncolsout //",1:"// nrowsout //"]"
   } else {	# null unapplied offsets since we don't want to apply them
      xoffset = 0
      yoffset = 0
   }

   if (gsize != "") {			# Report image composite size
      print ("#Note: computed composite image size: ", outsec)
      print ("#Note: adopted composite image size: ", gsize)
      print ("#Note: computed composite image size: ", outsec,>> dbinfo)
      outsec = gsize
      print ("#Note: adopted composite image size: ", outsec,>> dbinfo)
   } else {
      print ("#Note: computed composite image size: ", outsec)
   }

   if (goverlap != "") {
      print ("#Note: computed composite overlap region: ", lapsec)
      print ("#Note: adopted composite overlap region: ", goverlap)
      print ("#Note: computed composite overlap region: ", lapsec,>> dbinfo)
      lapsec = goverlap
      print ("#Note: adopted composite overlap region: ", lapsec,>> dbinfo)
   } else {
      print ("Computed composite overlap region: ", lapsec)
      if (lapsec == "" && c_opt > 1) { 
         print ("Null overlap: can't compute statistics")
         goto err
      }
   }

   print("#DBI    overlap_sec     ",lapsec,>> dbinfo)
   print("#DBI    out_sec         ",outsec,>> dbinfo)
        
# Mark offsets as absolute or relative
   if (register)
      print ("# Absolute",>> im_offsets)
   else
      print ("# Relative",>> im_offsets)

   maxsizex = 0; maxsizey = 0
   slenmax = 0; list1 = newinfo; list2 = comblist
# Loop through frames: fixpix|setpix|geotran|imshift|zoffset
   while (fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
      nxmat0,nymat0,fxs,fys,soffset) != EOF) {
      pos1b = stridx("_",imname)+1
      if (pos1b < 2) {
         print("Image path position (COM_pos) missing at ",imname)
         goto err
      } else
         nim = int(substr(imname,pos1b,strlen(imname)))

      if (nim == 0 ) {	 			# SKIP COM_000 REF IMAGE
         print("#NOTE: skipping COM_000 ",src)
         next
      }

      if (soffset == "INDEF") soffset = "0.0"
      zoff = real (soffset)
      slenmax = max(slenmax,strlen(src))
      srcsub = "["//nxlosrc//":"//nxhisrc//","//nylosrc//":"//nyhisrc//"]"
      nxlomat = nxmat0 + nxlosrc ; nxhimat = nxmat0 + nxhisrc
      nylomat = nymat0 + nylosrc ; nyhimat = nymat0 + nyhisrc

# scale images to common integration time
      if (scale_it) {						# SCALE
         imgets (src, to_name); from_scale = real (imgets.value)
	 if (from_scale > 0.)   
	    mult_by = to_scale/from_scale
	 else
	    mult_by = 1.0
	 if (mult_by != 1.0) {
            imarith (src,"*",mult_by,im1,pixtype="real",calctype="real",
	       hparams="")
	    print ("#NOTE: scaling ", imname, " from ", to_name, "=",
	       from_scale, "to ", to_scale,>> dbinfo)	       
            if (verbose) {
	       print ("#Scaling ", imname, " from ", to_name, "=", from_scale,
	         "to ", to_scale)
	    }       
	 } else {
            imcopy(src,im1,verbose-)
         }	   
      } else {
         imcopy(src,im1,verbose-)
      }
             
# SETPIX
      if (setpix) {
# replace bad pixels with selected value  
         imexpr("a==0?b:c",im2,maskimage,reject_value,im1,dims="auto",
	    outtype="real",verbose-)
	 imdelete(im1,verify-,>& "dev$null")
         imrename(im2,im1,verbose-) 
      }

      if (fixpix) fixpix(im1, badpix, verbose-) 	# FIXPIX

      if (do_tran) {
         print (src) | translit ("", "[:,]", "    ") |
            scan(sjunk,nxlonew,nxhinew,nylonew,nyhinew)
         ncols = nxhinew - nxlonew + 1
         nrows = nyhinew - nylonew + 1
         gtxmin = 1 + xofftran; gtxmax = gtxmin + ncols
         gtymin = 1 + yofftran; gtymax = gtymin + nrows
#         geotran(im1,im2,dbtran,cotran,geometry=geomtran,
#            xin=INDEF,yin=INDEF,xshift=INDEF,yshift=INDEF,
#            xout=INDEF,yout=INDEF,xmag=INDEF,ymag=INDEF,
#            xrot=INDEF,yrot=INDEF,xmin=gtxmin,xmax=gtxmax,
#            ymin=gtymin,ymax=gtymax,xscale=1.,yscale=1.,
#            ncols=INDEF,nlines=INDEF,xsample=1.,ysample=1.,
#            interpolant=interptran,boundary=boundtran,
#            constant=reject_value,flux=fluxtran,nxblock=256,nyblock=256)
         gregister (im1,im2,dbtran,cotran,geometry=geomtran,
             xmin=gtxmin,xmax=gtxmax,ymin=gtymin,ymax=gtymax,
#             xmin=INDEF,xmax=INDEF,ymin=INDEF,ymax=INDEF,
             ncols=INDEF,nlines=INDEF,xscale=1.,yscale=1.,xsample=1.,ysample=1.,
             interpolant=interptran,boundary=boundtran,
             constant=reject_value,fluxcon=fluxtran,nxblock=512,nyblock=512)
         imdelete(im1,verify-,>& "dev$null")
         imrename(im2,im1,verbose-)
      }
      
# shift image appropriate fractional pixel value
      stat = fscan(list2,tmpname)
      imshift(im1,tmpname,fxs,fys,shifts_file="",interp_type=interp_shift,
         boundary_type=bound_shift,constant=const_shift)	# IMSHIFT
      imdelete(im1,verify-,>& "dev$null")

# scale images to common integration time
#      if (scale_it) {						# SCALE
#         imgets (src, to_name); from_scale = int (imgets.value)
#	 if (from_scale > 0.)   
#	    mult_by = to_scale/from_scale
#	 else
#	    mult_by = 1.0
#	 if (mult_by != 1.0) {
#            imarith (tmpname,"*",mult_by,tmpname,pixtype="real",calctype="real",
#	       hparams="")
#            if (verbose) {
#	       print ("Scaling ", imname, " from ", to_name, "=", from_scale,
#	       "to ", to_scale)
#	    }       
#	 }
#      }
	           
# Note: "pre_zero" has zeropoints prior to, and "im_zero" applied by, IMCOMBINE
      if (apply_zero && c_opt == 1) {	 			# OFFSET
         imarith (tmpname,"+",zoff,tmpname,pixtype="",calctype="",hparams="")
         print (zoff,>> pre_zero)
         print ("0.0",>> im_zero)
      } else if (c_opt == 0) {
         print ("0.0",>> pre_zero)
         print ("0.0",>> im_zero)
      } else {
         print ("0.0",>> pre_zero)
         if (invert_zero)
            print (-zoff,>> im_zero)
         else
            print (zoff,>> im_zero)
      }

# Redetermine the source and destination sections
      nxlomat += xoffset; nxhimat += xoffset
      nylomat += yoffset; nyhimat += yoffset
      nxmat0  += xoffset; nymat0  += yoffset
      matsub = "["//nxlomat//":"//nxhimat//","//nylomat//":"//nyhimat//"]"
# Test for out-of-range and fix as needed
      if ((nxmat0 < 0) || (nymat0 < 0) || (nxhimat > ncolsout) ||
         (nyhimat > nrowsout)) {
         print ("#NOTE: ",src," destination ",matsub," out of range!")
         print ("#NOTE: ",src," destination ",matsub," out of range!",
            >> dbinfo)
         nxlosrc += max(0, (1 - nxlomat)); nxlomat = max(1,nxlomat)
         nylosrc += max(0, (1 - nylomat)); nylomat = max(1,nylomat)
         nxhisrc -= max(0, (nxhimat - ncolsout))
         nxhimat = min(ncolsout,nxhimat)
         nyhisrc -= max(0, (nyhimat - nrowsout))
         nyhimat = min(nrowsout,nyhimat)
      }
      matsub = "["//nxlomat//":"//nxhimat//","//nylomat//":"//nyhimat//"]"
      srcsub = "["//nxlosrc//":"//nxhisrc//","//nylosrc//":"//nyhisrc//"]"
      nxlo = nxlolap - nxlomat + nxlosrc
      nxhi = nxhilap - nxhimat + nxhisrc
      nylo = nylolap - nylomat + nylosrc
      nyhi = nyhilap - nyhimat + nyhisrc
# Determine overlap section within imshifted source image
      stasub = "["//nxlo//":"//nxhi//","//nylo//":"//nyhi//"]"
      print (tmpname," ",srcsub," ",zoff," ",matsub," ",stasub, >> do2info)
      if (! make_stack) {
         print (tmpname//srcsub,>> ncomblist)
      } else {
  mossub = "["//1//":"//(nxhisrc-nxlosrc+1)//","//1//":"//nyhisrc-nylosrc+1//"]"
         ixs = nxhisrc - nxlosrc + 1
         iys = nyhisrc - nylosrc + 1
         print (tmpname," ",srcsub," ",mossub," ",ixs,iys,>> ncomblist)
      }
# Establish offset of origin for each frame
      im_xoffset = nxlomat - 1
      im_yoffset = nylomat - 1
      print (im_xoffset,im_yoffset,tmpname//srcsub,>> im_offsets)
      if (verbose) {
         print (tmpname," ",srcsub," ",zoff," ",matsub," ",stasub)
      }
      if (((nxhisrc-nxlosrc) != (nxhimat-nxlomat)) ||
          ((nyhisrc-nylosrc) != (nyhimat-nylomat))) {
         print (tmpname," dimension mismatch!")
         print (tmpname," dimension mismatch!", >> dbinfo)
         beep
      }
      maxsizex = max((nxhisrc-nxlosrc+1),maxsizex)
      maxsizey = max((nyhisrc-nylosrc+1),maxsizey)
   }
if(debug){##DEBUG
print(maxsizex,maxsizey)
goto err
}
# Extract intensity offsets
#      fields(do2info,"3",lines="1-",print-,quit-,> im_zero)
   if (do_combine) {
      if (make_stack) {
         imdelete(tmpimg//","//im1,verify-,>& "dev$null")
#         delete(tmp2,verify-,>& "dev$null")
#         print ("repl("//reject_value//","//maxsizex//")",>> tmp2)
#         imexpr("@"//,tmpimg,outtype=real,dim=maxsizex//","//maxsizey)
         mkpattern (tmpimg,output="",pattern="constant",v1=reject_value,
           v2=0.,title="",pixtype="real",ndim=2,ncols=maxsizex,
           nlines=maxsizey)
         print ("Making uniform size images for IMSTACK ",maxsizex,maxsizey)
         list1 = ncomblist
         stasub = "[1:"//maxsizex//",1:"//maxsizey//"]"
         while (fscan(list1,src,srcsub,mossub,ixs,iys) != EOF) {
           if ((ixs < maxsizex) || (iys < maxsizey)) {
              imcopy(tmpimg,im1,verbose-)
              imcopy(src//srcsub,im1//mossub,verbose+)
              imdelete(src,verify-,>& "dev$null")
              imrename(im1,src,verbose-)
              print(src//stasub,>> stacklist)
           } else {
              print(src//srcsub,>> stacklist)
           }
         }
         imdelete(tmpimg,verify-,>& "dev$null")
         print ("Creating stack_"//matchname//"...")
         imstack ("@"//stacklist,"stack_"//matchname,title="*",pixtype="*")
         delete (ncomblist, ver-, >& "dev$null")
         print ("stack_"//matchname, > ncomblist)
         if (access(comblist) && ! save_images) {
            print ("Deleting excess images...")
            imdelete("@"//comblist,verify-,>& "dev$null")
         }
         project=yes
      } else {
         project=no
      }
      print ("Performing IMCOMBINE: reject= ",reject," combine= ",
         combopt," zero= ",zero," output= ", matchname)
      print ("#Performing IMCOMBINE: reject= ",reject," combine= ",
         combopt," zero= ",zero," output= ", matchname,>> out)
      imcombine("@"//ncomblist,tmpimg,sigma="",logfile=comblog,
         combine=combopt,reject=reject,project=project,outtype="real",
         offsets=im_offsets,masktype="none",maskvalue=0,blank=blank,
         scale="none",zero=zero,weight=weight,statsec=statsec,
         lthreshold=lthreshold,hthreshold=hthreshold,
         nlow=nlow,nhigh=nhigh,pclip=pclip,lsigma=lsigma,hsigma=hsigma,
         mclip=mclip,sigscale=sigscale,expname=expname,
         rdnoise=rdnoise,gain=gain,grow=grow)
      if (register) {
         imgets (tmpimg, "i_naxis1"); ncols = int (imgets.value)
         imgets (tmpimg, "i_naxis2"); nrows = int (imgets.value)
         if (ncols != ncolsout || nrows != nrowsout) {
            mkpattern (matchname,output="",pattern="constant",
               v1=blank,v2=0.,title="",pixtype="real",ndim=2,
               ncols=ncolsout,nlines=nrowsout,header=tmpimg)
            nxlosrc = 1; nxhisrc = min(ncols,ncolsout)
            nylosrc = 1; nyhisrc = min(nrows,nrowsout)
            srcsub = "["//nxlosrc//":"//nxhisrc//","//
               nylosrc//":"//nyhisrc//"]"
            print ("# NOTE: Restoring image origin and size: ",
               tmpimg//srcsub," -> ",matchname//srcsub,>> out)
            imcopy(tmpimg//srcsub,matchname//srcsub,verbose+)
         }
      } else
         imrename(tmpimg,matchname,verbose-)
   } else {
      print ("Performing OVERLAY:")
      imdelete(tmpimg,verify-,>& "dev$null")
      mkpattern (tmpimg,output="",pattern="constant",v1=reject_value,v2=0.,
         title="",pixtype="real",ndim=2,ncols=ncolsout,nlines=nrowsout,
         header=tmpimg)
      list1 = do2info
      for (i = 1; fscan(list1,src,srcsub,zoff,matsub) != EOF ; i += 1) {
            imcopy(src//srcsub,tmpimg//matsub,verbose+)
      }
      imrename(tmpimg,matchname,verbose-)
   }

# output information
   delete (out, ver-,>& "dev$null") # delete prior version (we said OK above)
   copy (dbinfo,out,verbose-)
# update intensity offset data
   delete(tmp2//","//matinfo//","//dbinfo,verify-,>& "dev$null")
   match ("^COM_000",newinfo,meta+,stop-,print-,> dbinfo)
# Skip reference frame
   match ("^COM_000",newinfo,meta+,stop+,print-,> matinfo)
   delete (newinfo,verify-,>& "dev$null")
   copy (dbinfo,newinfo,verbose+)

   if (do_combine) {	# extract per_image info from IMCOMBINE log
      match ("_",comblog,meta-,stop-,print-) |
         match ("combine",,meta-,stop+,print-, >> combinfo)  
# Extract number of output categories in IMCOMBINE log to stat
	 match ("Images",comblog,meta-,stop-,print-) | count() | scan(i,stat)
   }
#   
#  Images                              Offsets
#  _Ticb2469gj_001.imh[3:1022,3:1022]  314  330
#  Images                             Median    Zero   Offsets
#  _Ticb2469gj_001.imh[3:1022,3:1022]  691.71  -599.1  314  330

# Extract new database info to "newinfo" and applied zero_points to "tmp1"
   if (c_opt <= 1) {	# extract zoff from input data to avoid roundoff
      fields(matinfo,"1-11",lines="1-",print-,quit-,>> newinfo)
      fields(matinfo,"11",lines="1-",print-,quit-,>> tmp1)
   } else {		# extract zoff from IMCOMBINE log
      delete (tmp1,verify-,>& "dev$null")
      if (do_combine) {	# extract zoff to tmp1 and offsets to combinfo
         list1 = combinfo
         nim = fscan (list1,imname,src,mat,mos,ref,sjunk)
         if (stat == 4) {		# Images Median Zero Offsets 
            if (nim == 5) 		# imname[nn] median zero xoff yoff
               fields (combinfo,"3",print-,quit-,>> tmp1)
            else if (nim == 6)	# imname[ nn] median zero xoff yoff
               fields (combinfo,"4",print-,quit-,>> tmp1)
            else {
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",c_opt,nim,stat)
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",c_opt,nim,stat,>> out)
               fields (combinfo,"3",print-,quit-,>> tmp1)
            }
         } else if (stat == 3) {	# Images Zero Offsets 
            if (nim == 4) 		# imname[nn] zero xoff yoff
               fields (combinfo,"2",print-,quit-,>> tmp1)
            else if (nim == 5)		# imname[ nn] zero xoff yoff
               fields (combinfo,"3",print-,quit-,>> tmp1)
            else {
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",c_opt,nim,stat)
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",c_opt,nim,stat,>> out)
               fields (combinfo,"2",print-,quit-,>> tmp1)
            }
         } else if (stat == 2) {         # Images Offsets
 	    print ("0.00", >> tmp1)
            print ("Warning: incorrect field count in IMCOMBINE log! ",
	       imname," ",c_opt,nim,stat)
            print ("Warning: incorrect field count in IMCOMBINE log! ",
	       imname," ",c_opt,nim,stat,>> out)	    
	 } else {
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",c_opt,nim,stat)
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",c_opt,nim,stat,>> out)
         }
      } else {
         fields (do2info,"3",print-,quit-,>> tmp1)
      }
      
# check for inconsistency in number of image lines      
      count (matinfo) | scan(ixs)
      count (tmp1)    | scan(iys)
      if (ixs != iys) {
         print("Warning: lines in INFO: ",ixs," not matched to ZOFF: ",iys)
         print("Warning: lines in INFO: ",ixs," not matched to ZOFF: ",iys,
	    >> out)	 
      } 
      fields(matinfo,"1-10",lines="1-",print-,quit-) |
         join("STDIN",tmp1,out=newinfo,missing="Missing",delim=" ",
             maxchars=161,shortest-,verbose+)
   }

# update database with new COM_nnn
   sformat = '%-7s %'//-slenmax//'s %3d %3d %3d %3d %4d %4d %5.2f %5.2f %9.3f\n'
   list1 = ""; list1 = newinfo
   for (i = 0; fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
         nxmat0,nymat0,xs,ys,soffset) != EOF; i += 1) {
      printf(sformat,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,real(soffset),>>out)
   }

   if (do_combine) {	# output IMCOMBINE per_image log
      concatenate (comblog,out,append+)
   }
   if (do_combine && make_stack) {
# output STA_nnn to database for use by RECOMBINE
# format STA_nnn xoff yoff imcombine_applied_zero imstack_applied_zero
#        COM_nnn original_source_image total_applied_zero
# Assumes stat contains the number of output categories in IMCOMBINE log
# Assumes IMCOMBINE applied zero_points are in "tmp1" and in "im_zero"
# Assumes pre-IMCOMBINE applied zero_points are in "pre_zero"
      delete (tmp2//","//matinfo//","//do1info,verify-,>& "dev$null")
# extract COM_nnn and original source for later ID
      match ("^COM_000",newinfo,meta+,stop+,print-) |
         fields("STDIN","1,2,11",lines="1-",print-,quit-,>> do1info)
      list1 = ""; list1 = combinfo
      for (i = 1; fscan(list1,imname,src,mat,mos,ref,sjunk) != EOF; i += 1) {
         tmpname = "STA_000" + i
         nim = nscan ()
# format STA_nnn xoff yoff imcombine_applied_zero imstack_applied_zero
         if (c_opt == 0) {		# common = none 
            if (nim == 3)  		# imname[nn] xoff yoff
               print (tmpname," ",src," ",mat,>> tmp2)
            else if (nim == 4) 	# imname[ nn] xoff yoff
               print (tmpname," ",mat," ",mos,>> tmp2)
            else {
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",tmpname," ",c_opt,nim,stat)
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",tmpname," ",c_opt,nim,stat,>> out) 
            }
         } else if (c_opt == 1) {	# common = adopt
            if (nim == 4) 		# imname[nn] zoff xoff yoff
               print (tmpname," ",mat," ",mos,>> tmp2)
            else if (nim == 5)	# imname[ nn] zero xoff yoff
               print (tmpname," ",mos," ",ref,>> tmp2)
            else {
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",tmpname," ",c_opt,nim,stat)
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",tmpname," ",c_opt,nim,stat,>> out) 
            }
         } else {			# common = median|mean|mode
            if (nim == 5)		# imname[nn] median zero xoff yoff
               print (tmpname," ",mos," ",ref,>> tmp2)
            else if (nim == 6)	# imname[ nn] median zero xoff yoff
               print (tmpname," ",ref," ",sjunk,>> tmp2)
            else {
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",tmpname," ",c_opt,nim,stat)
               print ("Warning: incorrect field count in IMCOMBINE log! ",
	          imname," ",tmpname," ",c_opt,nim,stat,>> out)
            }
         }
      }
      delete (newinfo,verify-,>& "dev$null")
      if (invert_zero) {
         rename (im_zero,newinfo)
         list1 = newinfo
         while (fscan(list1,sjunk) != EOF) {
            print (-real(sjunk),>> im_zero)
         }
         delete (newinfo,verify-,>& "dev$null")
      }
      join(tmp2,im_zero,out="STDOUT",miss="Missing",delim=" ",maxch=161,short-,
         ver+) | join("STDIN",pre_zero,out="STDOUT",miss="Missing",delim=" ",
         maxch=161,short-,ver+) | join("STDIN",do1info,out=newinfo,
         miss="Missing",delim=" ",maxch=161,short-,verb+)
      print ("STA_000 stack_"//matchname," ",out," ",ncolsout,nrowsout,
         slenmax,>> out)
   # Fancy format
      sformat = '%-7s %3d %3d %9.3f %9.3f %-7s %'//slenmax//'s'//' %9.3f\\n'
      list1 = ""; list1 = newinfo
      for (i = 0; fscan(list1,src,nxlo,nxhi,xs,ys,mat,ref,fxs) != EOF; i += 1) {
         printf(sformat,src,nxlo,nxhi,xs,ys,mat,ref,fxs,>>out)
      }
   }
 
   if (verbose)    concatenate (do2info,out,append+)
   
# Finish up

err:  list1 = ""; list2 = ""
   imdelete(tmpimg//","//im1//","//im2, verify-,>& "dev$null")
   if (access(comblist) && ! save_images)
      imdelete("@"//comblist,verify-,>& "dev$null")
   delete (comblist//","//tmp1//","//tmp2//","//nimlist,ver-,>& "dev$null")
   delete (combinfo//","//do1info//","//do2info,ver-,>& "dev$null")
   delete (ncomblist//","//comblog,ver-,>& "dev$null")
   delete (misc//","//dbinfo//","//matinfo,ver-,>& "dev$null")
   delete (stacklist//","//pre_zero,ver-,>& "dev$null")
   delete (im_zero//","//im_offsets//","//uniq//"*",ver-,>& "dev$null")
   
end
