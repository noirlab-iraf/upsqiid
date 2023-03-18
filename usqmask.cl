# USQMASK: 21JAN00 KMM expects IRAF 2.11Export or later
# USQMASK: - mask bad pixels to preset value 
# SQMASK:  19JUL98 KMM add global image extension
# ABUMASK: 25JUL98 KMM tailor sqmask for abu
#                      incorporate imexpr
# ABUMASK: 16AUG98 KMM modified imexpr to produce explicitly real image
# USQMASK: 21JAN00 KMM modify for UPSQIID including channel offset syntax

procedure usqmask (input, output)

string  input       {prompt="Input raw images"}
string  output      {prompt="Output image descriptor: @list||.ext||%in%out%"}
string  maskimage   {"badmask", prompt="bad pixel image mask"}
real    value       {0, prompt="pixel value for masked pixels"}

bool	verbose     {yes,prompt="Verbose output?"}

struct  *inlist,*outlist,*l_list

begin

   int    nin, irootlen, orootlen, stat, pos1b, pos1e, pos2b, pos2e, n_opt,
          nxlotrim,nxhitrim,nylotrim,nyhitrim, ncols, nrows
   real   rnorm, rmean, rmedian, rmode, fract, scalenorm, rawmedian
   string in,in1,in2,out,iroot,oroot,uniq,sopt,img,sname,sout,sbuff,sjunk,
          smean, smedian, smode, front, srcsub, color
   file   blank,  nflat, infile, outfile, tmp1, tmp2, l_log, task
   int    nex
   string gimextn, imextn, imname, imroot
   struct line = ""
   bool   choff, found
   
# Assign positional parameters to local variables
   in          = input
   out         = output
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
   
   uniq        = mktemp ("_Tmsk")
   infile      = mktemp ("tmp$msk")
   outfile     = mktemp ("tmp$msk")
   tmp1        = mktemp ("tmp$msk")
   tmp2        = mktemp ("tmp$msk")
   l_log       = mktemp ("tmp$msk")

   l_list = l_log
# check whether input stuff exists
   if ((stridx("@%.",out) != 1) && (stridx(",",out) <= 1)) {
# Verify format of output descriptor
      print ("Improper output descriptor format: ",out)
      print ("  Use @list or comma delimited list for fully named output")
      print ("  Use .extension for appending extension to input list")
      print ("  Use %inroot%outroot% to substitute string within input list")
      goto skip
   } else if (!access(maskimage)) {
      print ("SETPIX mask_image ",maskimage, " does not exist!")
      goto skip
   }

# check whether input stuff exists
   l_list = l_log
   print (in) | translit ("", "@:", " ") | scan(in1,in2)
   if ((stridx("@",in) == 1) && (! access(in1))) {	# check input @file
      print ("Input file ",in1," does not exist!")
      goto skip
   }
   sqsections (in1,option="nolist")
   if (sqsections.nimages == 0) {			# check input images
      print ("Input images in file ",in, " do not exist!")
      goto skip
   }

   if (access(out)) {			# check for output collision
      print ("Output image",out, " already exists!")
      goto skip
   }

# Expand input file name list
   sqsections (in, option="root",> infile)

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
         if (substr(img,i-nex,i) == "."//gimextn)	# Strip off imextn
            img = substr(img,1,i-nex-1)
# Output descriptor indicates append or substitution based on input list
         if (stridx("%",out) > 0) { 			# substitution
            print (out) | translit ("", "%", " ", >> l_log)
            stat = (fscan(l_list,iroot,oroot))
            if (stat == 1) oroot = ""
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

   count(infile, >> l_log); count(outfile, >> l_log)
   stat = fscan(l_list,pos1b); stat = fscan(l_list,pos2b)
   if (pos1b != pos2b) {
      print ("Mismatch between input and output lists: ",pos1b,pos2b)
      join (tmp1,outfile)
      goto skip
   }
   nin = pos1b
   inlist = ""

# Sets bad pix to -1 and good to zero within the mask
   print ("SETPIX to ",value," using ", maskimage," mask",>> logfile)

# Loop through data
   inlist = infile; outlist = outfile
   while ((fscan (inlist,sname) != EOF) && (fscan(outlist,sout) != EOF)) {
      imexpr("a=0?b:c",sout,maskimage,value,sname,dims="auto",
         outtype="real",verbose-)
   }

   skip:

# Finish up
   inlist = ""; outlist = ""; l_list = ""
   delete (tmp1//","//tmp2//","//l_log, verify-,>& "dev$null")
   delete (infile//","//outfile, verify-,>& "dev$null")
   
end
