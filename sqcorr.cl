# SQCORR: 19JUL98 KMM expects IRAF 2.11Export or later
# SQCORR - linearize SQIID raw image data 
# SQCORR: 22JUL94 KMM
# SQCORR: 19MAY94 KMM
# SQCORR: 04AUG94 KMM
# SQCORR: 25AUG94 KMM set outtype to real (auto => double!) within imexpr
# SQCORR: 19JUL98 KMM add global image extension
#                     replace access with imaccess where appropriate

#  CORRECTION MODEL:
#
#    (actual - obs)/obs = a1*(sqrt(a2/(a2 - a3 * x)) - 1.0)
#
#    actual = (1 + ymcor) * obs
#
#     ymcor = 1.0 + a1*(sqrt(a2/(a2 - a3 * x)) - 1.0)
#           = ((1.0 - a1) + (a1/sqrt(1/(1 - (a3/a2)* x)))
#
#        b1 = a1; b2 = a3/a2
#     ymcor = ((1.0 - b1) + (b1/sqrt(1/(1 - (b2)* x)))
#
#   x = observed difrrence between data at time d and ti+d
#  tcorr =  (ti + 2*td)/ti
#  actual = x*ymcor(tcorr*x)
#
#  a1 = 0.758420
#  a2 = 3.12864
#  a3 = 2.20141e-5
#  b1 = a1     = 0.75842
#  b2 = a3/a2  = 7.036316e-6

procedure sqcorr (input, output)

string  input       {prompt="Input raw images"}
string  output      {prompt="Output image descriptor: @list||.ext||%in%out%"}

real    extrapol    {1.0, prompt="Extrapolation: (int_time+2*delay_t)/int_time"}
string  sky_value   {"null",prompt="Header keyword for subtracted sky value"}
bool    sub_skycorr {no,prompt="Subtract corrected sky value"}
real    value       {0, prompt="pixel value for masked pixels"}
real    a1          {0.758420,   prompt="Err_fit constant a1"}
real    a2          {3.12864,    prompt="Err_fit constant a2"}
real    a3          {2.20141e-5, prompt="Err_fit constant a3"}
string  exposure    {"frame_tm", prompt="Header keyword for exposure time"}
real    int_time    {5.000, prompt="Integration_time"}
real    jdelay      {3.000, prompt="J channel delay_time"}
real    hdelay      {3.385, prompt="H channel delay_time"}
real    kdelay      {3.770, prompt="K channel delay_time"}
real    ldelay      {1.000, prompt="L channel delay_time"}
bool	verbose     {yes,prompt="Verbose output?"}
file    logfile     {"STDOUT",prompt="logfile name"}

struct  *inlist,*outlist,*l_list

begin

   int    nin, irootlen, orootlen, stat, pos1b, pos1e, pos2b, pos2e
   real   rskycorr, rsky, bb, cc, dd, ti, td, tcorr
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

# check whether input stuff exists
   l_list = l_log
   print (in) | translit ("", "@:", "  ") | scan(in1,in2)
   if (nscan() == 2) {			 	# color indirection requested
      choff = yes
      print (in2) | translit ("", "^jhklJHKL1234\n",del+,collapse+) |
         translit ("","JHKL1234","jhkljhkl",del-,collapse+) | scan(color)
      if (strlen (color) != strlen (in2)) {
         print ("colorlist ",in2," has colors not in jhklJHKL1234")
         goto skip
      }
      choff = yes
      nin = strlen(color)
      for (i = 1; i <= nin; i += 1) {
         sjunk = substr(color,i,i)
         print (sjunk, >> colorlist)
         sjunk = out//substr(sjunk,i,i)
         if (imaccess(sjunk)) {			# check for output collision
            print ("Output image",sjunk, " already exists!")
            goto skip
         }
      }
   } else {					# no color indirection
      choff = no
      print ("jhkl", >> colorlist)
      if (imaccess(out)) {			# check for output collision
         print ("Output image",out, " already exists!")
         goto skip
      }
   }

   if ((stridx("@",in) == 1) && (! access(in1))) {	# check input @file
      print ("Input file ",in1," does not exist!")
      goto skip
   }

   print (in) | translit ("", ":", "  ") | scan(in1,in2)
   sections (in1,option="nolist")
   if (sections.nimages == 0) {			# check input images
      print ("Input images in file ",in, " do not exist!")
      goto skip
   }

# Expand input file name list
   sections (in1, option="root",> infile)
   if (choff) {	 			# Apply channel offset
      print ("Applying color offset: ",color)
      colorlist ("@"//infile,color,>> tmp2)
      delete (infile, ver-, >& "dev$null")
      type (tmp2,> infile)
      delete (tmp2, ver-, >& "dev$null")
      if (color == "j")
         td = jdelay
      else if (color == "h")
         td = hdelay
      else if (color == "k")
         td = kdelay
      else if (color == "l")
         td = ldelay
   } else 
      td = jdelay
  ti = int_time
  tcorr =  (ti + 2*td)/ti
  extrapol = tcorr

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
   print (line," SQCORR: ",>> logfile)
   print ("imagelist: ",nin,"images",>> logfile)
   join (infile,outfile,>> logfile)

   bb = 1.0 - a1
   cc = a1
   dd = a3/a2
   sexpr = "("//str(bb)//" + "//str(cc)//"/sqrt(1.0 - "//str(dd)//" *b*a))*a"
#   sexpr = "(bb + cc/sqrt(1.0 - dd * e * a)) * a"
#   sexpr = "(0.24158 + 0.75842/sqrt(1.0 - 7.03632e-6 * b * a)) * a"

   if (verbose) {
      print ("Expression: ",sexpr)
      print ("Extrapol b: ",extrapol)
      print ("Expression: ",sexpr,>> logfile)
      print ("Extrapol b: ",extrapol,>> logfile)
   }
# Loop through data
   inlist = infile; outlist = outfile
   while ((fscan (inlist,sname) != EOF) && (fscan(outlist,sout) != EOF)) {

# Get raw_median value for header
#      imgets(sname,exposure)
#      ti = real(imgets.value)
#      tcorr =  (ti + 2*td)/ti
      print(sname," ",ti,td,tcorr,extrapol)
      if (skycorr) {
         imgets(sname,sky_value)
         rsky = real(imgets.value)
         imarith (sname,"+",rsky,im1,pixtype="r",calctype="r",hparams="")
         imexpr(sexpr,sout,im1,extrapol,dims="auto",intype="real",
            outtype="real",refim="auto",range+,verbose-,exprdb="none")
         if (sub_skycorr) {
            rskycorr = (bb + cc/sqrt(1.0 - dd * rsky)) * rsky
            imarith (sout,"-",rskycorr,sout,pixtyp="r",calctyp="r",hparams="")
         }
      } else {
         imexpr(sexpr,sout,sname,extrapol,dims="auto",intype="real",
            outtype="auto",refim="auto",range+,verbose-,exprdb="none")
      }
      hedit (sout,"title",sout,add-,delete-,verify-,show-,update+)
      hedit (sout,"tcorr",tcorr,add+,delete-,verify-,show-,update+)
      imdelete (im1, verify-,>& "dev$null")
   }

   skip:

   # Finish up
      inlist = ""; outlist = ""; l_list = ""
      delete (im1//","//tmp1//","//tmp2//","//l_log, verify-,>& "dev$null")
      delete (infile//","//outfile//","//colorlist, verify-,>& "dev$null")
   
   end

#  real function y3cor(x)
#  a1 = -7.315174e-4
#  a2 =  3.244635e-6
#  a3 = -1.93612e-11
#  a4 =  5.514444e-16
#  y3cor = 1.0 + a1 + a2*x + a3*x**2 + a4*x**3
#
#  real function y2cor(x)
#  a1 = 1.924786e-3
#  a2 = 2.361529e-6
#  a3 = 2.467293e-11
#  y2cor = 1.0 + a1 + a2*x + a3*x**2
#
#  tsum =  (ti + 2*td)/ti
#  endcor = ymcor(x*tend) * x*tend - ymcor(x*tbeg) * x*tbeg
#  zm = x*ymcor(tsum*x)
#  z3 = x*y3cor(tsum*x)
#  z2 = x*y2cor(tsum*x)
