# IMZERO: 22JAN00 KMM expects IRAF 2.11Export or later
# IMZERO -- bring statistic of images to a common value.
# IMZERO: 02JUL96 KMM
# based on SQSKY: 08AUG94 KMM
# IMZERO: 20JUN98 KMM add global image extension
#                     replace access with imaccess where appropriate
# IMZERO: 22JAN00 KMM modify for UPSQIID including channel offset syntax

procedure imzero (input, output)

string input      {prompt="Input raw sky images"}
string output     {prompt="Output sky image"}

string norm_stat  {"median",enum="none|mean|median|mode",
                  prompt="common statistic: |none|mean|median|mode"}
string statsec    {"[50:450,50:450]",
                    prompt="Image section for calculating statistics"}
real   lthreshold {INDEF,prompt="Lower threshold for exclusion in statistics"}
real   hthreshold {INDEF,prompt="Upper threshold for exclusion in statistics"}
   
file   logfile    {"STDOUT", prompt="Log file name"}
bool   verbose    {yes,prompt="Verbose output?"}

struct  *list1, *list2, *inlist, *l_list

begin

   int    i, nin, nout, stat, c_opt, nim, maxnim, pos1e, pos1b, pos2e, pos2b,
          irootlen, orootlen
   real   rnorm, rmedian, rmode, rmean,
          ddelta, avemean, avenorm, avemedian, avemode, stddev, number,
          stddev_mean, stddev_median,stddev_mode
   string in, in1, in2, out, outfull, uniq,  sbuff, sjunk,
          img, sname, smean, smedian, smode,
          combopt, reject, scale, iroot, oroot, normstat
   file   l_log,secfile,tmp1,tmp2,meanfile,medianfile,modefile,
          infile,outfile
   bool   found
   int    nex
   string gimextn, imextn, imname, imroot

   struct line = ""

# Assign positional parameters to local variables

   in         = input
   out        = output
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
      
   if (substr(out,i-nex,i) == "."//gimextn)	# Strip off imextn
      out = substr(out,1,i-nex-1)

   infile      = mktemp ("tmp$sqf")
   outfile     = mktemp ("tmp$sqf")
   secfile     = mktemp ("tmp$sqf")
   medianfile  = mktemp ("tmp$sqf")
   modefile    = mktemp ("tmp$sqf")
   meanfile    = mktemp ("tmp$sqf")
   tmp1        = mktemp ("tmp$sqf")
   tmp2        = mktemp ("tmp$sqf")
   l_log       = mktemp ("tmp$sqf")

# check IRAF version
   normstat = norm_stat
   if (norm_stat == "none")   c_opt = 0
   if (norm_stat == "mean")   c_opt = 1
   if (norm_stat == "median") c_opt = 2
   if (norm_stat == "mode")   c_opt = 3

   print (in) | translit ("", "@:", "  ") | scan(in1,in2)
   if ((stridx("@",in) == 1) && (! access(in1))) {	# check input @file
      print ("Input file ",in1," does not exist!")
      goto skip
   }
   print (in) | translit ("", ":", " ") | scan(in2)
   sqsections (in2,option="nolist")
   if (sqsections.nimages == 0) {                 # check input images
      print ("Input images in file ",in, " do not exist!")
      goto skip
   }
   if ((stridx("@%.",out) != 1) && (stridx(",",out) <= 1)) {
# Verify format of output descriptor
      print ("Improper output descriptor format: ",out)
      print ("  Use @list or comma delimited list for fully named output")
      print ("  Use .extension for appending extension to input list")
      print ("  Use %inroot%outroot% to substitute string within input list")
      goto skip
   }

# Expand input file name list
#   option="root" truncates lines beyond ".imh" including section info
   sqsections (in1, option="root") | match ("\#",meta+,stop+,print-,> infile)
# Generate image section file
   list1 = infile
   for (nin = 0; fscan (list1,img) !=EOF; nin += 1) {
# Strip off trailing ".imh"
      i = strlen(img)
      if (substr(img,i-3,i) == ".imh") img = substr(img,1,i-4)
      print (img//statsec,>> secfile)
   }

# Expand output image list
   if (stridx("@,",out) != 0) {                 # @-list
# Output descriptor is @-list or comma delimited list
      sqsections (out, option="root",> outfile)
   } else {                                     # namelist/substitution/append
      inlist = infile
      for (nin = 0; fscan (inlist,img) !=EOF; nin += 1) {
# Get past any directory info
         if (stridx("$/",img) != 0) {
            print (img) | translit ("", "$/", "  ", >> l_log)
            stat = fscan(l_list,img,img,img,img,img,img,img,img)
         }
         if (substr(img,i-nex,i) == "."//gimextn)	# Strip off imextn
            img = substr(img,1,i-nex-1)
# Output descriptor indicates append or substitution based on input list
         if (stridx("%",out) > 0) {                     # substitution
            print (out) | translit ("", "%", " ") | scan(iroot,oroot)
            if (nscan() == 1) oroot = ""
            irootlen = strlen(iroot)
            while (strlen(img) >= irootlen) {
               found = no
               pos2b = stridx(substr(iroot,1,1),img)    # match first char
               pos2e = pos2b + irootlen - 1             # presumed match end
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
               } else {                                 # no match
                  found = no
                  break
               }
            }
            if (! found) {                              # no match
               print ("root ",iroot," not found in ",img)
               goto skip
            }
         } else                                 # name/append
            print(img//out,>> outfile)
      }
   }
   count(infile)  | scan(pos1b)
   count(outfile) | scan(pos2b)
   if (pos1b != pos2b) {
      print ("Mismatch between input and output lists: ",pos1b,pos2b)
      goto skip
   }
   nin = pos1b

# Determine image statistics within image subsection

   imstatistics("@"//secfile,fields="npix,mean,midpt,mode,stddev,min,max",
      lower=lthreshold,upper=hthreshold,binwidth=0.001,format-,> tmp1)
   if (verbose) {
      imstatistics(" ",fields="image,npix,mean,midpt,mode,stddev,min,max",
      lower=lthreshold,upper=hthreshold,binwidth=0.001,format+,>> logfile)
      join(infile,tmp1,out="STDOUT",delim=" ",miss="Missing",
         maxchar= 161, shortest-,verbose+,>> logfile)
   } else {
      type (infile, >> logfile)
   }
   list2 = infile
   list1 = tmp1
   for (i = 1; ((fscan(list1,sjunk,smean, smedian, smode) != EOF) &&
      (fscan(list2,sname) != EOF)); i += 1) {
      sbuff = sname//" "//smean//" "//smedian//" "//smode
      print(sbuff,>> tmp2)
# Exclude any reference flats
      if (i <= nin) {
         print(smean,>> meanfile)
         print(smedian,>> medianfile)
         print(smode,>> modefile)
      }
   }
   list2 = ""; list1 = ""; delete (tmp1, ver-, >& "dev$null")

# compute average mean, median, and mode
   average("new_sample",< meanfile) | scan(avemean,stddev_mean,number)
   average("new_sample",< medianfile) |
      scan(avemedian,stddev_median,number)
   average("new_sample",< modefile) | scan(avemode,stddev_mode,number)
   stddev_mean   = 0.0001*real(nint(10000.0*stddev_mean))
   stddev_median = 0.0001*real(nint(10000.0*stddev_median))
   stddev_mode   = 0.0001*real(nint(10000.0*stddev_mode))
   print("ave_mean=",avemean,"a ve_median=",avemedian,
      " ave_mode=",avemode,>> logfile)
   print("dev_mean=",stddev_mean,"dev_median=",stddev_median,
      " dev_mode=",stddev_mode,>> logfile)
   list1 = ""; delete (tmp1, ver-, >& "dev$null")
   if (normstat != "none") {
      switch(c_opt) {
         case 0:
            avenorm = 0.0
         case 1:
            avenorm = avemean
         case 2:
            avenorm = avemedian
         case 3:
            avenorm = avemode
      }
   }
   if (normstat != "none") {
      print("Generating images offset to a common ",
         normstat," of ",avenorm," within ",statsec,>> logfile)
   }
   
# Select normalization and normalize
   list2  = outfile
   list1  = tmp2
   while((fscan(list1,img,rmean,rmedian,rmode) != EOF) &&
      (fscan(list2,sname) != EOF)) {
      if (normstat != "none") {
         switch(c_opt) {
           case 0:
              ddelta = 0.0
           case 1:
              ddelta = rmean - avenorm
           case 2:
              ddelta = rmedian - avenorm
           case 3:
              ddelta = rmode - avenorm
         }
      imarith (img,"-",ddelta,sname,pixtype="",calctype="",hparams="",verb+)
      }
   }

# Finish up
skip:
   list1 = ""; list2 = ""; inlist = ""
   delete  (infile//","//tmp1//","//l_log,verify-,>& "dev$null")
   delete  (outfile//","//secfile//","//tmp2,ver-,>& "dev$null")
   delete  (medianfile//","//modefile//","//meanfile,verify-,>& "dev$null")

end
