# STDPROC: 23MAR02 KMM expects IRAF 2.11Export or later
# MOVPROC: -- process ABU raw image data using the moving mean/median
#   from a subset of frames (within selected list distance of each frame and
#   exlcuding the given frame) to produce a SKY frame for a given frame.
#   Processes data from list number FIRST_PROC to list number LAST_PROC:
#   it creates a sky frame from the INCLUDE number of images nearest the
#   processed frame.  This is equivalent to a running mean/median (selected by
#   COMB_OPT) which excludes the image being processed. The task can handle
#   data with a regular pattern of "on" frames (IMPROC) intermixed with "off"
#   frames (IMSKIP).  IMPROC and IMSKIP can be used to avoid processing the
#   "off" frames while including them in the running sky frame.  For example,
#   a 40 frame sequence of 5 off, 10 on, 5 off, ... could be processed by
#   first_proc=6, last_proc=35, improc=10, imskip=5.  (Any last_proc greater
#   than 36 would achieve the same result.)
# ABUNOTCH: 27JUL98 KMM incorporate imexpr into setpix option
#                       tailor sqnotch for abu
# ABUNOTCH: 01AUG98 KMM enable grouped sky processing
# MOVPROC: 07AUG98 KMM rename as MOVPROC with minor parameter renaming
# MOVPROC: 16AUG98 KMM modified imexpr to produce explicitly real for setpix
# MOVPROC: 03MAR99 KMM remove blankimage option; will always compute skyframe
# STDPROC: 08MAR99 KMM setup processing for standards1
#          25MAR02 KMM changes to imcombine parameters for IRAF 2.12

procedure stdproc (input, output, flatimage)

string input      {prompt="Input raw images"}
string output     {prompt="Output image descriptor: @list||.ext||%in%out%"}
string flatimage  {prompt="Input flat field image name"}
string blankimage {prompt='Input blank field image name: "compute"==compute'}

bool   fixpix     {no,prompt="Run FIXPIX on data?"}
string badpix     {"badpix", prompt="badpix file in FIXPIX format"}
bool   setpix     {no,prompt="Run SETPIX on data?"}
string maskimage  {"badmask", prompt="untransposed bad pixel image mask"}
real   bvalue     {0.0,prompt="Value if there are no pixels"}
bool   orient     {no,prompt="Orient image with N up and E left"}

bool   verbose    {yes,prompt="Verbose output?"}
file   logfile    {"STDOUT",prompt="logfile name"}

int    include    {0, prompt="Number of included images in blankimage subset"}
int    improc     {0, prompt="Number of images to process in group"}
int    imskip     {0, prompt="Number of images to skip between process"}
int    first_proc {1, prompt="List number of first image to be processed"}
int    last_proc  {1000, prompt="List number of last image to be processed"}
bool   static     {yes, prompt="Fixed notch?"}
string darkimage  {"null",prompt='Input dark_count image ("null"==noaction)'}
string norm_opt   {"zero", enum="zero|scale|none",
                       prompt="Type of combine operation: |zero|scale|none|"}
string norm_stat  {"median",enum="none|mean|median|mode",
                    prompt="Pre-combine common offset: |none|mean|median|mode|"}
# imcombine parameters;
string comb_opt   {"median", enum="average|median",
                       prompt="Type of combine operation: |average|median|"}
string reject_opt {"none", prompt="Type of pixel rejection operation",
                    enum="none|minmax|ccdclip|crreject|sigclip|avsigclip|pclip"}
string statsec    {"[300:700,400:600]",
                    prompt="Image section for calculating statistics"}
real   lthreshold {INDEF,prompt="Lower threshold for exclusion in statistics"}
real   hthreshold {INDEF,prompt="Upper threshold for exclusion in statistics"}
bool   mclip      {no, prompt="Use median, not mean, in clip algorithms"}
real   pclip      {-0.5, prompt="pclip: Percentile clipping parameter"}
string weight     {"none",prompt="Image weights"}
string expname    {"", prompt="Image header exposure time keyword"}
int    nlow       {1, prompt="minmax: Number of low pixels to reject"}
int    nhigh      {1, prompt="minmax: Number of high pixels to reject"}
int    nkeep      {0, prompt="Min to keep (pos) or max to reject (neg)"}
real   lsigma     {3., prompt="Lower sigma clipping factor"}
real   hsigma     {3., prompt="Upper sigma clipping factor"}
string rdnoise    {"0.", prompt="ccdclip: CCD readout noise (electrons)"}
string gain       {"1.", prompt="ccdclip: CCD gain (electrons/DN)"}
string snoise     {"0.", prompt="ccdclip: Sensitivity noise (fraction)"}
real   sigscale   {0.1,
                     prompt="Tolerance for sigma clipping scaling correction"}
int    grow       {0, prompt="Radius (pixels) for 1D neighbor rejection"}
   
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
          l_log, task
   bool   found
   bool   debug=no
   int    nex
   string gimextn, imextn, imname, imroot

   struct line = ""

# Assign positional parameters to local variables
   in          = input
   out         = output
   nflat       = flatimage
#   skyimg      = blankimage
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)  

   combopt = comb_opt
   normstat = norm_stat
   reject = reject_opt
   if (norm_opt == "zero") {
      scaleopt  = "none"
      zeroopt   = normstat
   } else if (norm_opt == "scale") {
      scaleopt  = normstat
      normstat  = normstat
      zeroopt   = "none"
   } else {
      scaleopt  = "none"
      zeroopt   = "none"
      normstat  = "none"
   }

   uniq        = mktemp ("_Tabp")
   infile      = mktemp ("tmp$abn")
   outfile     = mktemp ("tmp$abn")
   tmp1        = mktemp ("tmp$abn")
   tmp2        = mktemp ("tmp$abn")
   tmp3        = mktemp ("tmp$abn")
   l_log       = mktemp ("tmp$abn")
   im1         = uniq // "_im1"
   im2         = uniq // "_im2"
   im3         = uniq // "_im3"

# check whether input stuff exists
#   if (((skyimg != "null") && (skyimg != "compute")) &&
#      (!imaccess(skyimg))) {
#      print ("Blank image ",skyimg, " does not exist!")
#      goto skip
#   }
   if (nflat != "null" && !imaccess(nflat)) {
      print ("Flatfield image ",nflat, " does not exist!")
      goto skip
   } else if ((stridx("@%.",out) != 1) && (stridx(",",out) <= 1)) {
# Verify format of output descriptor
      print ("Improper output descriptor format: ",out)
      print ("  Use @list or comma delimited list for fully named output")
      print ("  Use .extension for appending extension to input list")
      print ("  Use %inroot%outroot% to substitute string within input list")
      goto skip
   } else if (fixpix && !access(badpix)) {
      print ("FIXPIX file ",badpix," does not exist!")
      goto skip
   } else if (setpix && !imaccess(maskimage)) {
      print ("SETPIX mask_image ",maskimage, " does not exist!")
      goto skip
   }

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
   if (access(out)) {			# check for output collision
      print ("Output image",out, " already exists!")
      goto skip
   }

# Expand input file name list
#   option="root" truncates lines beyond ".imh" including section info
   sections (in, option="root",> infile)
   
   l_list = l_log
# Expand output image list
   if (stridx("@,",out) != 0) { 		# @-list
# Output descriptor is @-list or comma delimited list
      sections (out, option="root",> outfile)
   } else {					# namelist/substitution/append
      inlist = infile
      for (nin = 0; fscan (inlist,img) !=EOF; nin += 1) {
# Get past any directory info
         if (stridx("$/",img) != 0) {
            print (img) | translit ("", "$/", "  ", >> l_log)
            stat = fscan(l_list,img,img,img,img,img,img,img,img)
         }
         i = strlen(img)
         if (substr(img,i-nex,i) == "."//gimextn)	# Strip off imextn
            img = substr(img,1,i-nex-1)
# Output descriptor indicates append or substitution based on input list
         if (stridx("%",out) > 0) { 			# substitution
            print (out) | translit ("", "%", " ") | scan(iroot,oroot)
            if (nscan() == 1) oroot = ""
            irootlen = strlen(iroot)
            while (strlen(img) >= irootlen) {
               found = no
               pos2b = stridx(substr(iroot,1,1),img)	# match first char
               pos2e = pos2b + irootlen - 1 		# presumed match end
               pos1e = strlen(img)
               if ((pos2b > 0) && (substr(img,pos2b,pos2e) == iroot)) {
                  if ((pos2b-1) > 0) 
                     sjunk = substr(img,1,pos2b-1)
                  else
                     sjunk = ""
                  print(sjunk//oroot//
                     substr(img,min(pos2e+1,pos1e),pos1e), >> outfile)
                  found = yes
                  break
               } else if (pos2b > 0) {
                  img = substr(img,pos2b+1,pos1e)    # move past first match
               } else { 				# no match
                  found = no
                  break
               }
            }
            if (! found) { 				# no match
               print ("root ",iroot," not found in ",img)
               goto skip
            }
         } else					# name/append
            print(img//out,>> outfile)
      }
   }

   count(infile) | scan(pos1b)
   count(outfile) | scan(pos2b)
   if (pos1b != pos2b) {
      print ("Mismatch between input and output lists: ",pos1b,pos2b)
      join (infile,outfile)
      goto skip
   }
   nin = pos1b
   inlist = ""
   
# Start logging info
   delete (tmp1, ver-, >& "dev$null")
# send newline if appending to existing logfile
   if (access(logfile)) print("\n",>> tmp1)
# Get date
   time() | scan(line)
# Print date and id line
   print (line," MOVPROC: ",>> tmp1)
#   print ("SUBTRACTED BLANK= ",skyimg,>> tmp1)
   print ("FLATFIELD= ",nflat,>> tmp1)
   print ("imagelist: ",nin,"images",>> tmp1)
   join (outfile,infile, >> tmp1)
   if (fixpix)  print ("FIXPIX according to ", badpix, " file",>> tmp1)
   if (setpix) {
       print ("SETPIX to ",bvalue," using ", maskimage," mask",>> tmp1)
   }
   if (orient) print("Orient ABU: IMTRANSPOSE [*,-*] -> [*,*]",>> tmp1)
   print("Statistics for data within ", lthreshold, " to ", hthreshold,
      " in section ",statsec, >> logfile)
   imstatistics ("", fields="image,npix,mean,midpt,mode,stddev,min,max",
         lower=lthreshold,upper=hthreshold,binwidth=0.001,format+,>> tmp1)
   if (verbose && logfile != "STDOUT") type(tmp1)
   type (tmp1,>> logfile)
   delete (tmp1, ver-, >& "dev$null")
   
if(debug) {##DEBUG      
   count(in) | scan(nin)
   copy(in, infile)
   copy(out, outfile)
   print(nin,include,improc,imskip)
}##DEBUG

# Loop through data
   img_num = 0
   gnum    = 0
   l_list = ""; delete (tmp1, verify-,>& "dev$null")
   inlist = infile; outlist = outfile
   copy (infile, tmp2)
   while ((fscan (inlist,sname) != EOF) && (fscan(outlist,sout) != EOF)) {

      img_num += 1
      if (img_num < first_proc) next  # skip until appropriate list number
      if (img_num > last_proc  || img_num > nin) break # terminate
      if (((img_num - first_proc) % (improc+imskip)) == 0)
         gnum +=1
print(gnum)	 
if(debug) {##DEBUG
   print(img_num, gnum, ((img_num - first_proc) % improc),
         (first_proc + gnum*improc-1),
         (first_proc + gnum*(improc+imskip)-1),
         (first_proc + (gnum-1)*improc-1),
         (first_proc + (gnum-1)*(improc+imskip)),
         (first_proc + gnum*(improc)+(gnum-1)*imskip-1))
}##DEBUG
print(first_proc + gnum*improc + (gnum-1)*imskip - 1)
      if ((img_num > (first_proc + gnum*improc + (gnum-1)*imskip - 1))) {
          next  # skip until appropriate list number
      }
# Get raw_median value for header
      imstatistics (sname//statsec,fields="midpt,mean",
         lower=lthreshold,upper=hthreshold,binwidth=0.001,format-) |
         scan (rawmedian)

      if (verbose) print ("# list_number: ",img_num,sname) 
# Subtract the blank image from the raw data images.
      if (static) {
         first_in = first_proc + gnum*improc
	 last_in  = first_in + improc + 1
      } else {
         first_in = img_num - int((include/2))
         last_in  = int((include + 1)/2) + img_num
      }
      print(first_in," ",last_in)
      if (first_in < 1) {
         last_in += (1 - first_in)
         first_in = 1
      } else if (last_in > nin) {
         first_in -= (last_in - nin)
         last_in = nin
      }
      print ("# compute sky from:  ",img_num,first_in,last_in)
      imglist = tmp2
      type(tmp2)
      for (ilist = 1; fscan(imglist,img) != EOF; ilist += 1) {
         if (ilist > last_in) break
         if ((ilist >= first_in) && (ilist != img_num)) {
            print(img,>> tmp3)
if(debug) print("sky: ",img) ##DEBUG
         }
	 type(tmp3)
	 goto asdf
      }
      imcombine("@"//tmp3,im3,sigma="",logfile=logfile,
         combine=combopt,reject=reject,project-,outtype="real",
         offsets="none",masktype="none",maskvalue=0,blank=bvalue,
         scale=scaleopt,zero=zeroopt,weight=weight,statsec=statsec,
         lthreshold=lthreshold,hthreshold=hthreshold,
         nlow=nlow,nhigh=nhigh,nkeep=nkeep,mclip=mclip,lsigma=lsigma,
         hsigma=hsigma,expname=expname,rdnoise=rdnoise,gain=gain,
         sigscale=sigscale,snoise=snoise,pclip=pclip,grow=grow)
      imarith (sname,"-",im3,im1,pixtype="r",calctype="r",hparams="")
      delete (tmp3,verify-); imdelete (im3,verify-,>& "dev$null")

# Assume rest is uniform illumination and divide by flat
      if (nflat != "null")
         imarith (im1,"/",nflat,im1,pixtype="r",calctype="r",hpar="")
# Bring to zero by subtracting selected norm within image subsection
      imstatistics (im1//statsec,
         fields="npix,mean,midpt,mode,stddev,min,max",
         lower=lthreshold, upper=hthreshold, binwidth=0.01, format-,>> tmp1)
      if(verbose) type (tmp1,>> logfile)
      l_list = tmp1 
      stat = fscan (l_list,sjunk,rmean,rmedian,rmode)
      l_list = ""; delete (tmp1, verify-)

# FIXPIX
      if (fixpix) fixpix(im1, badpix, verbose-)

# SETPIX
      if (setpix) {
# replace bad pixels with selected value
         imexpr("a=0?b:c",sout,maskimage,bvalue,im1,dims="auto",
	    outtype="real",verbose-)
      } else
         imcopy (im1, sout, verbose-,>> logfile)        

# ORIENT     
# imtranspose [*,-*] rotate 90 counter-clockwise (ABU at South Pole)
# imtranspose [-*,*] rotate 90 clockwise
# imcopy      [-*,-*] rotate 180
# imcopy      [-*,*] flip about (vertical) y-axis
# imcopy      [*,-*] flip about (horizontal) x-axis (SQIID)

      if (orient) imtranspose(sout//"[*,-*]",sout)

      hedit (sout,"title",sout,add-,delete-,verify-,show-,update+)
      hedit (sout,"raw_midpt",rawmedian,add+,delete-,verify-,show-,update+)
      hedit (sout,"pro_midpt",rmedian,add+,delete-,verify-,show-,update+)
      imglist = ""; imdelete (im1//","//im3, verify-,>& "dev$null")
   asdf:
   }
   
   skip:

   # Finish up
      inlist = ""; outlist = ""; imglist = ""; l_list = ""
      imdelete (im1//","//im2//","//im3,verify-,>& "dev$null")
      delete (tmp1//","//tmp2//","//tmp3//","//l_log, verify-,>& "dev$null")
      delete (infile//","//outfile, verify-,>& "dev$null")
   
end
