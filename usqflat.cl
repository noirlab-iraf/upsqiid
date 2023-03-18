# USQFLAT: 23MAR02 KMM expects IRAF 2.11Export or later
# USQFLAT: - Create IR flat from data frames.
# SQFLAT:  19JUL98 KMM 
# ABUFLAT: 25JUL98 KMM tailor sqflat for abu
# USQFLAT: 03MAR99 KMM fix parsing of file input
# USQFLAT: 21JAN00 KMM modify for UPSQIID including channel offset syntax
# USQFLAT: 11MAY00 KMM change statsec default to [100:400,100:400]
#          25MAR02 KMM changes to imcombine parameters for IRAF 2.12

procedure usqflat (input, output, darkimage)

string input      {prompt="Input raw sky images"}
string output     {prompt="Output normalized flat_field image"}
string darkimage  {prompt='Input dark_count image ("null"==noaction)'}

string ref_flat   {"",prompt="Reference normalized flat_field images"}
string statsec    {"[100:400,100:400]",
                    prompt="Image section for calculating statistics"}
real   lo_reset   {0.1,prompt="Lower limit for exclusion in output"}
real   hi_reset   {2.0,prompt="Upper limit for exclusion in output"}
file   logfile    {"STDOUT", prompt="Log file name"}
bool   verbose    {yes,prompt="Verbose output?"}
# IMCOMBINE parameters
string common     {"none",enum="none|mean|median|mode",
                    prompt="Pre-combine common offset: |none|median|mode|"}
string prenorm    {"median",enum="none|median|mode",
                   prompt="Pre-IMCOMBINE frame divisor:|none|median|mode|"}
string imscale    {"none",enum="none|median|mode",
                    prompt="IMCOMBINE scale option: |none|median|mode|"}
string comb_opt   {"median", enum="average|median",
                       prompt="Type of combine operation: |average|median|"}
string reject_opt {"none", prompt="Type of pixel rejection operation",
                    enum="none|minmax|ccdclip|crreject|sigclip|avsigclip|pclip"}
bool   mclip      {no, prompt="Use median, not mean, in clip algorithms"}
real   pclip      {-0.5, prompt="pclip: Percentile clipping parameter"}
real   lthreshold {INDEF,prompt="Lower threshold for exclusion in statistics"}
real   hthreshold {INDEF,prompt="Upper threshold for exclusion in statistics"}
real   blank      {0.1,prompt="Value if there are no pixels"}
string weight     {"none",prompt="Image weights"}
string expname    {"", prompt="Image header exposure time keyword"}
int    nlow       {1, prompt="minmax: Number of low pixels to reject"}
int    nhigh      {1, prompt="minmax: Number of high pixels to reject"}
int    nkeep        {0, prompt="Min to keep (pos) or max to reject (neg)"}
real   lsigma     {3., prompt="Lower sigma clipping factor"}
real   hsigma     {3., prompt="Upper sigma clipping factor"}
string rdnoise    {"0.", prompt="ccdclip: CCD readout noise (electrons)"}
string gain       {"1.", prompt="ccdclip: CCD gain (electrons/DN)"}
string snoise       {"0.", prompt="ccdclip: Sensitivity noise (fraction)"}
real   sigscale   {0.1,
                     prompt="Tolerance for sigma clipping scaling correction"}
int    grow       {0, prompt="Radius (pixels) for 1D neighbor rejection"}
   

struct  *list1, *list2, *l_list

begin

   int    i, nin, nout, stat, pos1b, pos1e, n_opt, r_opt, nim, maxnim
   real   rnorm, rmedian, rmode,
          ddelta, avenorm, avemedian, avemode, stddev, number,
          stddev_median,stddev_mode
   string in, in1, in2, dark, darkfull, out, outfull, uniq, sbuff, sjunk,
          color, scolor, img, sname, sdarksub, smedian, smode, first, vcheck,
          combopt, reject, scale, pre_norm, im_scale
   file   imfile,subfile,secfile,tmp1,tmp2,medianfile,modefile,
          tmpimg,refimg,l_log
   int    nex
   string gimextn, imextn, imname, imroot
   struct line = ""

# Assign positional parameters to local variables

   in         = input
   out        = output
   dark       = darkimage
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)

   uniq        = mktemp ("_Tsqf")
   l_log       = mktemp ("tmp$sqf")
   imfile      = mktemp ("tmp$sqf")
   subfile     = mktemp ("tmp$sqf")
   secfile     = mktemp ("tmp$sqf")
   medianfile  = mktemp ("tmp$sqf")
   modefile    = mktemp ("tmp$sqf")
   tmp1        = mktemp ("tmp$sqf")
   tmp2        = mktemp ("tmp$sqf")
   tmpimg      = uniq // "_img"
   refimg      = uniq // "_rim"

   reject  = reject_opt
   im_scale = imscale
   pre_norm = prenorm
   if (pre_norm == "none")   n_opt = 0
   if (pre_norm == "median") n_opt = 2
   if (pre_norm == "mode")   n_opt = 3
   if (im_scale == "none")   r_opt = 0
   if (im_scale == "median") r_opt = 2
   if (im_scale == "mode")   r_opt = 3
   
   combopt = comb_opt

# check whether input stuff exists
   l_list = l_log
   print (in) | translit ("", "@:", "  ") | scan(in1,in2)
   if ((stridx("@",in) == 1) && (! access(in1))) {	# check input @file
      print ("Input file ",in1," does not exist!")
      goto skip
   }
   sqsections (in,option="nolist")
   if (sqsections.nimages == 0) {			# check input images
      print ("Input images in file ",in, " do not exist!")
      goto skip
   }
   
   if (imaccess(out)) {		# check for output collision
      print ("Output image",out, " already exists!")
      goto skip
   }
   if ((dark != "null") && (!imaccess(dark))) {
      print ("Blank image ",dark, " does not exist!")
      goto skip
   }
   
   sqsections (in, option="root") | match ("\#",meta+,stop+,print-,> tmp1)
   outfull = out
   darkfull = dark
# Generate temporary data list for dark subtracted frames
   list1 = tmp1  
   for (nin = 0; fscan (list1,img) !=EOF; nin += 1) {
      i = strlen(img)
      if (substr(img,i-nex,i) == "."//gimextn)      # Strip off imextn
         img = substr(img,1,i-nex-1)
      print (img,>> imfile)
      sname = uniq//"_"//nin
      print (sname,>> subfile)
      print (sname//statsec,>> secfile)
   } 
   nout = nin

   list1 = ""; delete (tmp1, ver-, >& "dev$null")

# send 2 newlines if appending to existing logfile
   if (access(logfile)) print("\n",>> logfile)
# Get date
   time() | scan(line)
# Print date and id line
   print (line," USQFLAT: ",outfull ,>> logfile)
   print (line," USQFLAT: ",outfull)
   print ("SUBTRACTED DARK= ",darkfull,>> logfile)

   if (darkfull == "null")
      imcopy("@"//imfile,"@"//subfile,verbose-)
   else			 # Subtract the dark image from the raw input images.
      imarith("@"//imfile,"-",darkfull,"@"//subfile,pix="",calc="",hparams="")

# Get ref_flat images
   sections (ref_flat,opt="root") | match ("\#",meta+,stop+,print-,> tmp1)
   list1 = tmp1  
   for (i = nout; fscan (list1,img) !=EOF; i += 1) {
      print (img,>> imfile)
      sname = uniq//"_"//i
      print (sname,>> subfile)
      print (sname//statsec,>> secfile)
      imcopy(img,sname,verbose-)
      nout += 1
   } 
   list1 = ""; delete (tmp1, ver-, >& "dev$null")
   if (nout != nin) {
      if (comb_opt == "median" && mod(nout,2) == 0) {
         print (img,>> imfile)
         sname = uniq//"_"//nout
         print (sname,>> subfile)
         print (sname//statsec,>> secfile)
         imcopy(img,sname,verbose-)
         nout += 1
      }
   }

# Determine image statistics within image subsection for producing flats

   print ("imagelist: ",nout,"images",>> logfile)
   if (pre_norm != "none") {
      imstatistics("@"//secfile,fields="npix,midpt,mode,stddev,min,max",
         lower=lthreshold,upper=hthreshold,binwidth=0.001,format-,> tmp1)
      if (verbose) {
         imstatistics(" ",fields="image,npix,midpt,mode,stddev,min,max",
         lower=lthreshold,upper=hthreshold,binwidth=0.001,format+,>> logfile)
         join(imfile,tmp1,out="STDOUT",delim=" ",miss="Missing",
               maxchar= 161, shortest-,verbose+,>> logfile)
      } else {
         type (imfile, >> logfile)
      }
      list2 = subfile
      list1 = tmp1
      for (i = 1; ((fscan(list1,sjunk,smedian, smode) != EOF) &&
         (fscan(list2,sname) != EOF)); i += 1) {
         sbuff = sname//" "//smedian//" "//smode
         print(sbuff,>> tmp2)
# Exclude any reference flats
         if (i <= nin) {
            print(smedian,>> medianfile)
            print(smode,>> modefile)
         }
      }
      list2 = ""; list1 = ""; delete (tmp1, ver-, >& "dev$null")

# compute average mean, median, and mode
      average("new_sample",< medianfile) | 
         scan(avemedian,stddev_median,number)
      average("new_sample",< modefile) | scan(avemode,stddev_mode,number)
      stddev_median = 0.0001*real(nint(10000.0*stddev_median))
      stddev_mode   = 0.0001*real(nint(10000.0*stddev_mode))
      print("ave_median=",avemedian," ave_mode=",avemode,>> logfile)
      print("dev_median=",stddev_median," dev_mode=",stddev_mode,>> logfile)
      list1 = ""; delete (tmp1, ver-, >& "dev$null")
# Select normalization and normalize
      list1  = tmp2
      while(fscan(list1,sname,rmedian,rmode) != EOF) {
         switch(n_opt) {
           case 0:
              rnorm = 1.0
           case 2:
              rnorm = rmedian
           case 3:
              rnorm = rmode
         }
         imarith (sname,"/",rnorm,sname,pixtype="",calctype="",hparams="")
      }
      list1 = ""; delete (tmp2, ver-, >& "dev$null")
   }

# Log process prior to imcombine

   if (common != "none") {
      print(combopt," filtering images offset to a common ",
         common," divided by their ",prenorm," and scaled by their ",
         im_scale, " within ",statsec,>> logfile)
      print(combopt," filtering images offset to a common ",
         common," divided by their ",prenorm," and scaled by their ",
         im_scale, " within ",statsec)
   } else {
      print(combopt," filtering images divided by their ",prenorm,
         " and scaled by their ",im_scale, " within ",statsec,>> logfile)
      print(combopt," filtering images divided by their ",prenorm,
         " and scaled by their ",im_scale, " within ",statsec)
   }
# Generate flat shape

   print ("Performing IMCOMBINE: reject= ",reject," combine= ",
      combopt," output= ", outfull)
   print ("Performing IMCOMBINE: reject= ",reject," combine= ",
      combopt," output= ", outfull,>> logfile)
   imcombine("@"//subfile,outfull,sigma="",logfile=logfile, 
      combine=combopt,reject=reject,project-,outtype="real",
      offsets="none",masktype="none",maskvalue=0,blank=blank,
      scale=im_scale,zero=common,weight=weight,statsec=statsec,
      expname=expname,lthreshold=lthreshold,hthreshold=hthreshold,
      nlow=nlow,nhigh=nhigh,nkeep=nkeep,mclip=mclip,lsigma=lsigma,
      hsigma=hsigma,expname=expname,rdnoise=rdnoise,gain=gain,
      sigscale=sigscale,snoise=snoise,pclip=pclip,grow=grow)   

   if (im_scale != "none") {
# Renormalize with the norm of selected section.  Neccessary when imcombined
#    with imscale != "none"
#         bscale (outfull,bzero=0.0,bscale=scale,section=statsec,step=1,
#            logfile="STDOUT", noact-) 
   # Print out statistics and normalization option selected
      imstatistics (outfull//statsec,
         fields="image,npix,midpt,mode,stddev,min,max",
         lower=lthreshold,upper=hthreshold,binwidth=0.001,format-,> tmp1)
   # Print out statistics and normalization option selected
      if(verbose) type (tmp1,>> logfile)

      list1 = tmp1
      stat = fscan(list1,sname,sjunk,rmedian,rmode)
      switch (r_opt) {
         case 0:
            rnorm = 1.0
         case 2:
            rnorm = rmedian
         case 3:
            rnorm = rmode
      }
      list1 = ""; delete (tmp1, ver-, >& "dev$null")
      print("Output normalized by: ",imscale//"= ", rnorm,>> logfile)
      imarith(outfull,"/",rnorm,outfull,pixtype="",calctype="",hparams="")
   }

# Clip to within range
   if (verbose) print("Clipping output outside: ",lo_reset," to ",hi_reset)
   print("Clipping output outside: ",lo_reset," to ",hi_reset,>> logfile)
   if (lo_reset != INDEF)
      imreplace(outfull,lo_reset,lower=INDEF,upper=lo_reset)
   if (hi_reset != INDEF)
      imreplace(outfull,hi_reset,lower=hi_reset,upper=INDEF)

   hedit (outfull,"title",outfull,add-,delete-,verify-,show-,update+)

# Finish up
skip:

   imdelete(uniq//"*.imh",verify-)
   delete  (l_log//","//uniq//"*",verify-,>& "dev$null")
   delete  (imfile//","//subfile//","//secfile//","//tmp1,ver-,>& "dev$null")
   delete  (medianfile//","//modefile//","//tmp2,verify-,>& "dev$null")

end
