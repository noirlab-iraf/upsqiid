# USQSKY: 25MAR02 KMM expects IRAF 2.12Export or later
# USQSKY: - Create IR flat from sky frames.
# SQSKY:  19JUL98 KMM 
# ABUSKY: 25JUL98 KMM tailor sqsky for abu
# ABUSKY: 03MAR99 KMM fix parsing of file input
# USQSKY: 29FEB00 KMM modify for UPSQIID including channel offset syntax
# USQSKY: 11MAY00 KMM change statsec default to [100:400,100:400]
# USQSKY: 25MAR02 KMM change imcombine parameters for IRAF2.12

procedure usqsky (input, output)

string input      {prompt="Input raw sky images"}
string output     {prompt="Output sky image"}

string darkimage  {"null",prompt='Input dark_count image ("null"==noaction)'}
string statsec    {"[100:400,100:400]",
                     prompt="Image section for calculating statistics"}
file   logfile    {"STDOUT", prompt="Log file name"}
bool   verbose    {yes,prompt="Verbose output?"}

# IMCOMBINE parameters
string comb_opt   {"median", enum="average|median",
                       prompt="Type of combine operation: |average|median|"}
string norm_opt   {"zero", enum="zero|scale|none",
                      prompt="Type of pre-combine operation: |zero|scale|none|"}
string norm_stat  {"median",enum="none|mean|median|mode",
                  prompt="Pre-combine common statistic: |none|mean|median|mode"}
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
int    nkeep      {0, prompt="Min to keep (pos) or max to reject (neg)"}
real   lsigma     {3., prompt="Lower sigma clipping factor"}
real   hsigma     {3., prompt="Upper sigma clipping factor"}
string rdnoise    {"0.", prompt="ccdclip: CCD readout noise (electrons)"}
string gain       {"1.", prompt="ccdclip: CCD gain (electrons/DN)"}
string snoise     {"0.", prompt="ccdclip: Sensitivity noise (fraction)"}
real   sigscale   {0.1,
                     prompt="Tolerance for sigma clipping scaling correction"}
int    grow       {0, prompt="Radius (pixels) for 1D neighbor rejection"}
   


struct  *list1, *l_list

begin

   int    i, nin, nout, stat, nim, maxnim
   real   rnorm, rmedian, rmode,
          ddelta, avemean, avenorm, avemedian, avemode, stddev, number,
          stddev_mean, stddev_median,stddev_mode
   string in, in1, in2, dark, out, outfull, uniq,  sbuff, sjunk, color,
          img, sname, sdarksub, smean, smedian, smode, first, vcheck,
          combopt, reject, scale, darkfull, scolor,
          normstat, scaleopt, zeroopt
   file   imfile,subfile,secfile,tmp1,tmp2,meanfile,medianfile,modefile,
          l_log,rootfile
   struct line = ""
   int    nex
   string gimextn, imextn, imname, imroot

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
   meanfile    = mktemp ("tmp$sqf")
   tmp1        = mktemp ("tmp$sqf")
   tmp2        = mktemp ("tmp$sqf")
   rootfile    = mktemp ("tmp$sqf")

   reject   = reject_opt
   combopt  = comb_opt
   normstat = norm_stat
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
   
# check whether input stuff exists
   l_list = l_log
   print (in) | translit ("", "@:", "  ") | scan(in1,n2)
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
      print ("Output image ",out, " already exists!")
      goto skip
   }
   if ((dark != "null") && (!imaccess(dark))) {
      print ("Blank image ",dark, " does not exist!")
      goto skip
   }

   sqsections (in, option="root") | match ("\#",meta+,stop+,print-,> rootfile)
   outfull = out
   darkfull = dark
# Generate temporary data list for dark subtracted frames
#   option="root" truncates lines beyond imextn
   list1 = rootfile  
   for (nin = 0; fscan (list1,img) !=EOF; nin += 1) {
# Strip off imextn     
      if (substr(img,strlen(img)-nex,strlen(img)) == "."//gimextn )  {
         imroot = substr(img,1,strlen(img)-nex-1)
         img = imroot
      }
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
   print (line," USQSKY: ",outfull,>> logfile) 	# Print date and id line
   print (line," USQSKY: ",outfull)
   print ("SUBTRACTED DARK= ",darkfull,>> logfile)

   if (darkfull == "null")
      imcopy("@"//imfile,"@"//subfile,verbose-)
   else		 # Subtract the dark image from the raw input images.
      imarith("@"//imfile,"-",darkfull,"@"//subfile,pix="",calc="",hparam="")

# Determine image statistics within image subsection for producing flats

   print ("imagelist: ",nout,"images",>> logfile)
# Log process prior to imcombine
   if (normstat != "none") {
      print(combopt," filtering unnormalized images offset to a common ",
         normstat," within ",statsec,>> logfile)
   } else {
      print(combopt," filtering unnormalized images",>> logfile)
   }
# Generate sky frame
   print ("Performing IMCOMBINE: reject= ",reject," combine= ",
      combopt," norm_opt= ",norm_opt," output= ", outfull)
   print ("Performing IMCOMBINE: reject= ",reject," combine= ",
      combopt," norm_opt= ",norm_opt," output= ", outfull,>> logfile)
   imcombine("@"//subfile,outfull,sigma="",logfile=logfile,
      combine=combopt,reject=reject,project-,outtype="real",
      offsets="none",masktype="none",maskvalue=0,blank=blank,
      scale=scaleopt,zero=zeroopt,weight=weight,statsec=statsec,
      expname=expname,lthreshold=lthreshold,hthreshold=hthreshold,
      nlow=nlow,nhigh=nhigh,nkeep=nkeep,mclip=mclip,lsigma=lsigma,
      hsigma=hsigma,expname=expname,rdnoise=rdnoise,gain=gain,
      sigscale=sigscale,snoise=snoise,pclip=pclip,grow=grow)

   if (darkfull != "null")
      imarith(outfull,"+",darkfull,outfull,pixtype="",calctype="",hparams="")

   hedit (outfull,"title",outfull,add-,delete-,verify-,show-,update+)
      
# Finish up

skip:
   list1 = ""; l_list = ""
   imdelete(uniq//"*.imh",verify-)
   imdelete("@"//subfile,verify-,>& "dev$null")
   delete  (rootfile//","//uniq//"*",verify-,>& "dev$null")
   delete  (l_log//","//tmp2,verify-,>& "dev$null")
   delete  (imfile//","//subfile//","//secfile//","//tmp1,ver-,>& "dev$null")
   delete  (medianfile//","//modefile//","//meanfile,verify-,>& "dev$null")

end
