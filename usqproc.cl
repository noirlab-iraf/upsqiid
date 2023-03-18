# USQPROC: 18JUN00 KMM expects IRAF 2.11Export or later
# BASPROC: - process raw UPSQIID image data: basic sky subtraction
#            and flatfield correction
# SQPROC:  19JUL98 KMM 
# ABUPROC: 25JUL98 KMM tailor sqproc to abu
# BASPROC: 02AUG98 KMM rename as BASPROC
# BASPROC: 16AUG98 KMM modified imexpr to produce explicitly real for setpix
# BASPROC: 03MAR99 KMM fix parsing of file input
# USQPROC: 01MAR00 KMM modify for UPSQIID including channel offset syntax and
#                      image orientation
# USQPROC: 18JUN00 KMM replace default for reject_value with -1e7 (was -1e8) to
#                        get setpix to work rith floating point images 

procedure usqproc (input, output, flatimage, blankimage, scaleimage)

string  input       {prompt="Input raw images"}
string  output      {prompt="Output image descriptor: @list||.ext||%in%out%"}
string  flatimage   {prompt="Input flat field image name"}
string  blankimage  {prompt="Input blank field image name"}
string  scaleimage  {prompt="Input scale image name"}

string  opt_norm    {"none",enum="none|mean|median|mode",
                     prompt="Normalization: |none|mean|median|mode|"}
string  sec_norm    {"[100:400,100:400]",
                     prompt="Image section for calculating norm"}
real    result_norm {0.0,prompt="Resultant value after normalization"}
real    int_time    {5.00,prompt="Integration_time"}
real    delay_time  {0.00,prompt="Delay_time"}
bool    rescale     {no,prompt="Rescale scaleimage to make sky?"}

bool    fixpix      {no,prompt="Run FIXPIX on data?"}
string  badpix      {"badpix", prompt="badpix file in FIXPIX format"}
bool    setpix      {no,prompt="Run SETPIX on data?"}
string  maskimage   {"badmask", prompt="untransposed bad pixel image mask"}
real    svalue      {0, prompt="pixel value for masked pixels (eg -1.0e7)"}

bool    orient      {no,prompt="Orient image with N up and E left"}
real    lowerlim    {INDEF,prompt="Lower limit for exclusion in stats"}
real    upperlim    {INDEF,prompt="Upper limit for exclusion in stats"}

bool	verbose     {yes,prompt="Verbose output?"}
file    logfile     {"STDOUT",prompt="logfile name"}

struct  *inlist,*outlist,*l_list

begin

   int    nin, irootlen, orootlen, stat, pos1b, pos1e, pos2b, pos2e, n_opt,
          nxlotrim,nxhitrim,nylotrim,nyhitrim, ncols, nrows
   real   rnorm, rmean, rmedian, rmode, fract, scalenorm, rawmedian,
          blankave, blankmid
   string in,in1,in2,out,iroot,oroot,uniq,sopt,img,sname,sout,sbuff,sjunk,
          smean, smedian, smode, front, srcsub, color
   file   blank,  nflat, infile, outfile, im1, im2, im3, tmp1, tmp2, l_log,
          task, boximg, scaleimg
   bool   found
   int    nex
   string gimextn, imextn, imname, imroot

   struct line = ""

# Assign positional parameters to local variables
   in          = input
   out         = output
   nflat       = flatimage
   blank       = blankimage
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)

   n_opt       = 0
   if (rescale)
      scaleimg  = scaleimage
   sopt        = opt_norm
   if (sopt == "none")   n_opt = 0
   if (sopt == "mean")   n_opt = 1
   if (sopt == "median") n_opt = 2
   if (sopt == "mode")   n_opt = 3

   uniq        = mktemp ("_Tirp")
   infile      = mktemp ("tmp$irp")
   outfile     = mktemp ("tmp$irp")
   tmp1        = mktemp ("tmp$irp")
   tmp2        = mktemp ("tmp$irp")
   l_log       = mktemp ("tmp$irp")
   im1         = uniq // "_im1"
   im2         = uniq // "_im2"
   im3         = uniq // "_im3"
   boximg      = uniq // "_box"

# check whether input stuff exists
   if (nflat != "null" && !imaccess(nflat)) {
      print ("Flatfield image ",nflat, " does not exist!")
      goto skip
   } else if (blank != "null" && !imaccess(blank)) {
      print ("Blank image ",blank, " does not exist!")
      goto skip
   } else if ((stridx("@%.",out) != 1) && (stridx(",",out) <= 1)) {
# Verify format of output descriptor
      print ("Improper output descriptor format: ",out)
      print ("  Use @list or comma delimited list for fully named output")
      print ("  Use .extension for appending extension to input list")
      print ("  Use %inroot%outroot% to substitute string within input list")
      goto skip
   }

   if (setpix && !imaccess(maskimage)) {	# Exit if can't find mask
      print ("SETPIX maskimage ",sjunk, " does not exist!")
      goto skip
   } else if (fixpix && !access(badpix)) {
      print ("FIXPIX file ",badpix," does not exist!")
      goto skip
   } else if (rescale && !imaccess(scaleimg)) { # Exit if can't find image
      print ("Scale image ",sjunk, " does not exist!")
      goto skip
   }

# check whether input stuff exists
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
   if (imaccess(out)) {			# check for output collision
      print ("Output image",out, " already exists!")
      goto skip
   }

# Expand input file name list
#   option="root" truncates lines beyond ".imh" including section info
   sqsections (in, option="root",> infile)
   l_list = l_log
# Expand output image list
   if (stridx("@,",out) != 0) { 		# @-list
# Output descriptor is @-list or comma delimited list
      sqsections (out, option="root",> outfile)
   } else {					# namelist/substitution/append
      inlist = infile
      for (nin = 0; fscan (inlist,img) !=EOF; nin += 1) {
# Get past any directory info
         if (stridx("$/",img) != 0) {
            print (img) | translit ("", "$/", "  ", >> l_log)
            stat = fscan(l_list,img,img,img,img,img,img,img,img)
         }
         i = strlen(img)
         if (substr(img,i-nex,i) == "."//gimextn)      # Strip off imextn
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
     goto skip
   }
   nin = pos1b
# Get size of final image
   inlist = infile; stat = fscan (inlist,sname)
   hedit(sname,"i_naxis1",".") | scan(sjunk, sjunk, ncols)
   hedit(sname,"i_naxis2",".") | scan(sjunk, sjunk, nrows)

# send newline if appending to existing logfile
   if (access(logfile)) print("\n",>> logfile)
# Get date
   time() | scan(line)
   delete (tmp1, ver-, >& "dev$null")
# Print date and id line
   print (line," USQPROC: ",>> logfile)
   print ("SUBTRACTED BLANK= ",blank,>> logfile)
   print ("FLATFIELD= ",nflat,>> logfile)
   print ("imagelist: ",nin,"images",>> logfile)
   join (infile,outfile,>> logfile)

   if (sopt != "none")
      print ("Offset to a norm of ",result_norm,
        " by adding the difference between the RESULT_NORM and the ",
        sopt, " within ",sec_norm,>> logfile)
   if (fixpix)  print ("FIXPIX according to ", badpix, " file",>> logfile)
   if (setpix) {
       print ("SETPIX to ",svalue, " using ", maskimage," mask",>> logfile)
   }

# Need to make color specific for UPSQIID
   if (orient) print("Orient SQIID: channel dependent",>> logfile)
   
   print("Statistics for data within ", lowerlim, " to ", upperlim,
      >> logfile)
   imstatistics ("", fields="image,npix,mean,midpt,mode,stddev,min,max",
         lower=lowerlim,upper=upperlim,binwidth=0.001,format+,>> logfile)
   if (blank != "null") {
      imstatistics (blank//sec_norm,
         fields="image,npix,mean,midpt,mode,stddev,min,max",
         lower=lowerlim,upper=upperlim,binwidth=0.001,format-,>> logfile)
      imstatistics (blank//sec_norm,fields="mean,midpt",lower=lowerlim,
         upper=upperlim,binwidth=0.001,format-) | scan (blankave,blankmid)
   }
   if (rescale) {
      imstatistics (scaleimg//sec_norm,
         fields="image,npix,mean,midpt,mode,stddev,min,max",
         lower=lowerlim,upper=upperlim,binwidth=0.001,format-,> tmp1)
      type (tmp1,>> logfile)
      l_list = tmp1 
      stat = fscan (l_list,sjunk,rmean,rmedian,rmode)
      l_list = ""; delete (tmp1, verify-)
      switch (n_opt) {
         case 0:
            scalenorm = 1.0
         case 1:
            scalenorm = rmean
         case 2:
            scalenorm = rmedian
         case 3:
            scalenorm = rmode
      }
      print ("Will rescale scaleimage= ",scaleimg," with norm of ",
         scalenorm," to make sky")
      print ("Will rescale scaleimage= ",scaleimg," with norm of ",
         scalenorm," to make sky",>> logfile)
   }
# Loop through data
   inlist = infile; outlist = outfile
   while ((fscan (inlist,sname) != EOF) && (fscan(outlist,sout) != EOF)) {

# Get raw_median value for header
      imstatistics (sname//sec_norm,fields="midpt,mean",
         lower=lowerlim,upper=upperlim,binwidth=0.001,format-,> tmp1)
      l_list = tmp1; stat = fscan (l_list,rawmedian)
      l_list = ""; delete (tmp1, verify-)

# Subtract the blank image from the raw data images.
      if (blank != "null")
         imarith (sname,"-",blank,im1,pixtype="r",calctype="r",hparams="")
      else
         imarith (sname,"-",0.0,im1,pixtype="r",calctype="r",hparams="")

      if (rescale) {
         imstatistics (im1//sec_norm,
            fields="npix,mean,midpt,mode,stddev,min,max",
            lower=lowerlim, upper=upperlim, binwidth=0.01, format-,>> tmp1)

         l_list = tmp1 
         stat = fscan (l_list,sjunk,rmean,rmedian,rmode)
         l_list = ""; delete (tmp1, verify-)
         switch (n_opt) {
            case 0:
               rnorm = 0.0
            case 1:
               rnorm = rmean
            case 2:
               rnorm = rmedian
            case 3:
               rnorm = rmode
         }
         if (n_opt > 0) {
            rnorm = rnorm/scalenorm
            imarith(scaleimg,"*",rnorm,im2,pixtype="",calctype="",hparams="")
            imarith(im1,"-",im2,im1,pixtype="",calctype="",hparams="")
            imdelete (im2,verify-,>& "dev$null")
         }
      }
# Assume rest is uniform illumination and divide by flat
      if (nflat != "null")
         imarith (im1,"/",nflat,im1,pixtype="r",calctype="r",hpar="")
# Bring to zero by subtracting selected norm within image subsection
#      bscale (im1,bzero=sopt,bscale=1.0,section=sec_norm,
#             step=1, logfile="STDOUT", noact-) >> tmp1
      imstatistics (im1//sec_norm,
         fields="npix,mean,midpt,mode,stddev,min,max",
         lower=lowerlim, upper=upperlim, binwidth=0.01, format-,>> tmp1)
      if(verbose) type (tmp1,>> logfile)

      l_list = tmp1 
      stat = fscan (l_list,sjunk,rmean,rmedian,rmode)
      l_list = ""; delete (tmp1, verify-)
      switch (n_opt) {
         case 0:
            rnorm = 0.0
         case 1:
            rnorm = rmean
         case 2:
            rnorm = rmedian
         case 3:
            rnorm = rmode
      }
      if (n_opt > 0) {
         rnorm = result_norm - rnorm
         imarith (im1,"+",rnorm,im1,pixtype="",calctype="",hparams="")
      }

# FIXPIX
      if (fixpix) fixpix(im1, badpix, verbose-)

# SETPIX
      if (setpix) {
# replace bad pixels with selected value
         imexpr("a==0?b:c",sout,maskimage,svalue,im1,dims="auto",
	    outtype="real",verbose-)
      }  else
         imcopy (im1, sout, verbose-,>> logfile)        

# ORIENT: need to make color specific for UPSQIID     
# imtranspose [*,-*] rotate 90 counter-clockwise
# imtranspose [-*,*] rotate 90 clockwise
# imcopy      [-*,-*] rotate 180
# imcopy      [-*,*] flip about (vertical) y-axis
# imcopy      [*,-*] flip about (horizontal) x-axis

      if (orient) chorient(sout,channels=".",newid="")

      hedit (sout,"title",sout,add-,delete-,verify-,show-,update+)
      hedit (sout,"raw_midpt",rawmedian,add+,delete-,verify-,show-,update+)
      hedit (sout,"pro_midpt",rmedian,add+,delete-,verify-,show-,update+)
      hedit (sout,"sub_midpt",blankmid,add+,delete-,verify-,show-,update+)
      imdelete (im1, verify-,>& "dev$null")
         
   }

skip:

# Finish up
   inlist = ""; outlist = ""; l_list = ""
   imdelete (im1//","//im2//","//im3,verify-,>& "dev$null")
   delete (tmp1//","//tmp2//","//l_log, verify-,>& "dev$null")
   delete (infile//","//outfile, verify-,>& "dev$null")
   
end
