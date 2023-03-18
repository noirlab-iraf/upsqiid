# USQDARK: 23MAR02 KMM expects IRAF 2.11export or later
# SQDARK: - Create IR dark frames.
# SQDARK:  19JUL98 KMM
# ABUDARK: 25JUL98 KMM tailor sqdark for abu
# ABUDARK: 03MAR99 KMM fix parsing of file input
# USQDARK: 21JAN00 KMM modify for UPSQIID including channel offset syntax
# USQDARK: 22FEB00 KMM change statsec default
# USQDARK: 11MAY00 KMM change statsec default to [100:400,100:400]
#          25MAR02 KMM changes to imcombine parameters for IRAF 2.12

procedure usqdark (input, output)

string input      {prompt="Input raw dark images"}
string output     {prompt="Output IMCOMBINED dark image"}

bool   stat_calc  {yes,prompt="Calculate statistics?"}
string statsec    {"[100:400,100:400]",
                    prompt="Image section for calculating statistics"}
file   logfile    {"STDOUT", prompt="Log file name"}
bool   verbose    {yes,prompt="Verbose output?"}

# IMCOMBINE parameters
string common     {"none",enum="none|mean|median|mode",
                    prompt="Pre-combine common offset: |none|median|mode|"}
string reject_opt {"minmax", prompt="Type of rejection operation",
                    enum="none|minmax|pclip"}
string comb_opt   {"average", enum="average|median",
                      prompt="Type of combine operation: |average|median|"}
real   lthreshold {INDEF,prompt="Lower threshold for exclusion in statistics"}
real   hthreshold {INDEF,prompt="Upper threshold for exclusion in statistics"}
real   blank      {0.0,prompt="Value of output pixel when all are rejected"}
string expname    {"", prompt="Image header exposure time keyword"}
int    nlow       {1, prompt="minmax: Number of low pixels to reject"}
int    nhigh      {1, prompt="minmax: Number of high pixels to reject"}
int    nkeep      {0, prompt="Min to keep (pos) or max to reject (neg)"}
real   lsigma     {3., prompt="Lower sigma clipping factor"}
real   hsigma     {3., prompt="Upper sigma clipping factor"}
real   pclip      {-0.5, prompt="pclip: Percentile clipping parameter"}
   
struct  *list1, *l_list

begin

   int    i, nin, nout, stat, pos1b, pos1e, n_opt, c_opt, nim, maxnim
   real   rnorm, rmedian, rmode,
          ddelta, avenorm, avemedian, avemode, stddev, number,
          stddev_median,stddev_mode
   string in, in1, in2, dark, out, outfull, uniq, scale, sbuff, sjunk, color,
          img, sname, smedian, smode, combopt, first, vcheck, rject
   file   rootfile,imfile,subfile,secfile,tmp1,medianfile,modefile,l_log
   bool   choff
   int    nex
   string gimextn, imextn, imname, imroot

   struct line = ""

# Assign positional parameters to local variables
   in          = input
   out         = output
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
   
   l_log       = mktemp ("tmp$sqd")
   rootfile    = mktemp ("tmp$sqd")
   imfile      = mktemp ("tmp$sqd")
   subfile     = mktemp ("tmp$sqd")
   secfile     = mktemp ("tmp$sqd")
   medianfile  = mktemp ("tmp$sqd")
   modefile    = mktemp ("tmp$sqd")
   tmp1        = mktemp ("tmp$sqd")

   reject  = reject_opt
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
   if (imaccess(out)) {				# check for output collision
      print ("Output image",out, " already exists!")
      goto skip
   }

   sqsections (in, option="root") | match ("\#",meta+,stop+,print-,> rootfile)
   outfull = out
   list1 = rootfile
   for (nin = 0; fscan (list1,img) !=EOF; nin += 1) {
      i = strlen(img)
      if (substr(img,i-nex,i) == "."//gimextn)      # Strip off imextn
         img = substr(img,1,i-nex-1)
      print (img,>> imfile)
      print (img//statsec,>> secfile)
   } 
   nout = nin

   list1 = ""; delete (tmp1, ver-, >& "dev$null")
# send 2 newlines if appending to existing logfile
   if (access(logfile)) print("\n",>> logfile)
# Get date
   time() | scan(line)

# Print date and id line
   print (line," USQDARK("//combopt//"): ",outfull ,>> logfile)
   print (line," USQDARK("//combopt//"): ",outfull)

# Determine image statistics within image subsection for producing flats

   if (stat_calc) {
      imstatistics("@"//secfile,fields="npix,midpt,mode,stddev,min,max",
         lower=lthreshold,upper=hthreshold,binwidth=0.001,format-,> tmp1)

      imstatistics(" ",fields="image,npix,midpt,mode,stddev,min,max",
         lower=lthreshold,upper=hthreshold,binwidth=0.001,format+,>> logfile)
      join(imfile,tmp1,out="STDOUT",delim=" ",miss="Missing",
         maxchar= 161, shortest-,verbose+,>> logfile)
      list1 = tmp1
      for (i = 1; fscan(list1,sjunk,smedian, smode) != EOF; i += 1) {
         if (i <= nin) {
            print(smedian,>> medianfile)
            print(smode,>> modefile)
         }
      }
      list1 = ""; delete (tmp1, ver-, >& "dev$null")

 # compute average mean, median, and mode
      average("new_sample",< medianfile) |
         scan (avemedian,stddev_median,number)
      average("new_sample",< modefile) | scan(avemode,stddev_mode,number)
      stddev_median = 0.0001*real(nint(10000.0*stddev_median))
      stddev_mode   = 0.0001*real(nint(10000.0*stddev_mode))
      print("ave_median=",avemedian," ave_mode=",avemode,>> logfile)
      print("dev_median=",stddev_median," dev_mode=",stddev_mode,
        >> logfile)
   } else {
      type (imfile, >> logfile)
   }

# Log process prior to imcombine
   print(combopt," filtering unnormalized images",>> logfile)

   print ("Performing IMCOMBINE: reject= ",reject," combine= ",
      combopt," output= ", outfull)
   print ("Performing IMCOMBINE: reject= ",reject," combine= ",
      combopt," output= ", outfull,>> logfile)
   imcombine("@"//imfile,outfull,sigma="",logfile=logfile,
      combine=combopt,reject=reject,project-,outtype="real",
      offsets="none",masktype="none",maskvalue=0,blank=blank,
      scale="none",zero=common,weight="none",statsec=statsec,
      lthreshold=lthreshold,hthreshold=hthreshold,grow=0,
      nlow=nlow,nhigh=nhigh,nkeep=nkeep,pclip=pclip,
      lsigma=lsigma,hsigma=hsigma)

   hedit (outfull,"title",outfull,add-,delete-,verify-,show-,update+)

# Finish up
skip:
   list1 = ""; l_list = ""
   delete  (l_log,ver-,>& "dev$null")
   delete  (imfile//","//subfile//","//secfile//","//tmp1,ver-,>& "dev$null")
   delete  (medianfile//","//modefile//","//rootfile,verify-,>& "dev$null")

end
