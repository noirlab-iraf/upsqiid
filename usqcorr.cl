# USQCORR: 17JAN03 KMM expects IRAF 2.11Export or later
# USQCORR - linearize SQIID raw image data 
# SQCORR: 22JUL94 KMM
# SQCORR: 19MAY94 KMM
# SQCORR: 04AUG94 KMM
# SQCORR: 25AUG94 KMM set outtype to real (auto => double!) within imexpr
# SQCORR: 19JUL98 KMM add global image extension
#                     replace access with imaccess where appropriate
# USQCORR: 06DEC01 KMM put in corrections for upgraded sqiid detectors
#                      follow "irlincor" model
#        : 17JAN03 KMM modify for 3rd order polinomial correction using available data
#
# UPSQIID CORRECTIONAL MODEL FOR ALADDIN ARRAYS:
#
#
#    (actual/obs) = a1 + a2*obs + a3*(obs)**2
#
#   Forcing a1 = 1.0:
#
#    (actual - obs)/obs = a2*obs + a3*(obs)**2
#
#     actual     = obs +a2*obs**2 + a3*(obs)**3

procedure usqcorr (input, output)

string  input       {prompt="Input raw images"}
string  output      {prompt="Output image descriptor: @list||.ext||%in%out%"}

string  sky_value   {"null",prompt="Header keyword for subtracted sky value"}
bool    sub_skycorr {no,prompt="Subtract corrected sky value"}
real    value       {0, prompt="pixel value for masked pixels"}
real    ja1         {1.00000,    prompt="J Err_fit constant a1"}
real    ja2         {4.2889e-7,  prompt="J Err_fit constant a2"}
real    ja3         {6.2522e-10, prompt="J Err_fit constant a3"}
real    ha1         {1.00000,    prompt="H Err_fit constant a1"}
real    ha2         {4.5326e-6,  prompt="H Err_fit constant a2"}
real    ha3         {4.8759e-10, prompt="H Err_fit constant a3"}
real    ka1         {1.00000,    prompt="K Err_fit constant a1"}
real    ka2         {4.4144e-6,   prompt="K Err_fit constant a2"}
real    ka3         {4.0937e-10, prompt="K Err_fit constant a3"}
real    la1         {1.00000,    prompt="L Err_fit constant a1"}
real    la2         {0.00000,    prompt="L Err_fit constant a2"}
real    la3         {0.00000,    prompt="L Err_fit constant a3"}
#real    ja1         {1.00000,    prompt="J Err_fit constant a1"}
#real    ja2         {8.9659e-2,  prompt="J Err_fit constant a2"}
#real    ja3         {0.6097,     prompt="J Err_fit constant a3"}
#real    ha1         {1.00000,    prompt="H Err_fit constant a1"}
#real    ha2         {5.8195e-2,  prompt="H Err_fit constant a2"}
#real    ha3         {0.7630,     prompt="H Err_fit constant a3"}
#real    ka1         {1.00000,    prompt="K Err_fit constant a1"}
#real    ka2         {0.1917,      prompt="K Err_fit constant a2"}
#real    ka3         {0.4284,     prompt="K Err_fit constant a3"}
#real    la1         {1.00000,    prompt="L Err_fit constant a1"}
#real    la2         {0.00000,    prompt="L Err_fit constant a2"}
#real    la3         {0.00000,    prompt="L Err_fit constant a3"}

bool	verbose     {yes,prompt="Verbose output?"}
file    logfile     {"STDOUT",prompt="logfile name"}

struct  *inlist,*outlist,*l_list

begin

   int    nin, irootlen, orootlen, stat, pos1b, pos1e, pos2b, pos2e
   real   rskycorr, rsky, bb, cc, dd, ti, td, tcorr, a1, a2, a3
   string in,in1,in2,out,iroot,oroot,uniq,sopt,img,sname,sout,sbuff,sjunk,
          smean, smedian, smode, front, srcsub, color, sexpr
   file   blank,  nflat, infile, outfile, im1, tmp1, tmp2, l_log,
          colorlist
   bool   found, choff, skycorr
   int    nex
   string gimextn, imextn, imname, imroot

   struct line = ""

# Assign positional parameters to local variables
   in          = input
   out         = output

# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
   
   uniq        = mktemp ("_Tirp")
   infile      = mktemp ("tmp$irp")
   outfile     = mktemp ("tmp$irp")
   tmp1        = mktemp ("tmp$irp")
   tmp2        = mktemp ("tmp$irp")
   l_log       = mktemp ("tmp$irp")
   colorlist   = mktemp ("tmp$irp")
   im1         = uniq // ".im1"

   l_list = l_log
# check whether input stuff exists
   if ((stridx("@%.",out) != 1) && (stridx(",",out) <= 1)) {
# Verify format of output descriptor
      print ("Improper output descriptor format: ",out)
      print ("  Use @list or comma delimited list for fully named output")
      print ("  Use .extension for appending extension to input list")
      print ("  Use %inroot%outroot% to substitute string within input list")
      goto skip
   }

   sqsections (in,option="nolist")
   if (sqsections.nimages == 0) {			# check input images
      print ("Input images in file ",in, " do not exist!")
      goto skip
   }

# Expand input file name list
   sqsections (in, option="root") | match ("\#",meta+,stop+,print-,> infile)
   color = sqsections.ch_id
   if (color == "j") {
      a1 = ja1
      a2 = ja2
      a3 = ja3
   } else if (color == "h") {
      a1 = ha1
      a2 = ha2
      a3 = ha3
   } else if (color == "k") {
      a1 = ka1
      a2 = ka2
      a3 = ka3
   } else if (color == "l") {
      a1 = la1
      a2 = la2
      a3 = la3
   }

  if (sky_value == "null" || sky_value == "none" || sky_value == "")
     skycorr = no
   else
     skycorr = yes

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

   count(infile) | scan (pos1b); count(outfile) | scan (pos2b)
   if (pos1b != pos2b) {
      print ("Mismatch between input and output lists: ",pos1b,pos2b)
      join (tmp1,outfile)
      goto skip
   }
   nin = pos1b
   inlist = ""

# send newline if appending to existing logfile
   if (access(logfile)) print("\n",>> logfile)
# Get date
   time() | scan(line)
   delete (tmp1, ver-, >& "dev$null")
# Print date and id line
   print (line," USQCORR: ",>> logfile)
   print ("imagelist: ",nin,"images",>> logfile)
   join (infile,outfile,>> logfile)

   sexpr = "("//str(a1)//" + "//str(a2)//" *a + "//str(a3)//" *a*a)*a"

   if (verbose) {
      print ("Expression: ",sexpr)
      print ("Expression: ",sexpr,>> logfile)
   }
# Loop through data
   inlist = infile; outlist = outfile
   while ((fscan (inlist,sname) != EOF) && (fscan(outlist,sout) != EOF)) {

      if (skycorr) {
         imgets(sname,sky_value)
         rsky = real(imgets.value)
         imarith (sname,"+",rsky,im1,pixtype="r",calctype="r",hparams="")
         imexpr(sexpr,sout,im1,dims="auto",intype="real",
            outtype="real",refim="auto",range+,verbose-,exprdb="none")
         if (sub_skycorr) {
            rskycorr = (a1 + a2 * rsky + a3 * rsky*rsky) * rsky
            imarith (sout,"-",rskycorr,sout,pixtyp="r",calctyp="r",hparams="")
         }
      } else {
         imexpr(sexpr,sout,sname,dims="auto",intype="real",
            outtype="real",refim="auto",range+,verbose-,exprdb="none")
      }
      hedit (sout,"title",sout,add-,delete-,verify-,show-,update+)
      imdelete (im1, verify-,>& "dev$null")
   }

   skip:

   # Finish up
      inlist = ""; outlist = ""; l_list = ""
      delete (im1//","//tmp1//","//tmp2//","//l_log, verify-,>& "dev$null")
      delete (infile//","//outfile//","//colorlist, verify-,>& "dev$null")
   
   end
