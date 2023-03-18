# USQFOCUS - produce standard irmosaic
# SQFOCUS: 26AUG91 KMM 09SEP92 KMM
# SQFOCUS: 30NOV93 KMM upgrade to Wildfire

procedure usqfocus (j_list, output)

string j_list       {prompt="Image list for J images"}
string output       {prompt="Output image"}
string colors       {"jhkl",prompt="Ordered image colors: jhkl or subset"}
string section      {"",prompt="Image subsection [xmin:xmax,ymin:ymax]"}
int    npad         {10,prompt="Number of pixels included +/- central pixel"}
string trim_section {"[*,*]",
                       prompt="Input image section written to output image"}
real   oval	    {10000., prompt="Mosaic border pixel values"}
file   logfile      {"STDOUT", prompt="Log file name"}
bool   save_dbmos   {no, prompt="Save the IRMOSAIC database file?"}
string ref_id       {"_1", prompt='Reference image name|"_"//list_number'}
string coord_in     {"", prompt="Input initial coordinate file"}
string in_shifts    {"", prompt="Initial shift file between ref and images"}
# trim values applied to final image
string  trimlimits  {"[0:0,0:0]",prompt="trim limits on the input subrasters"}
real   cboxbig      {11., prompt="Size of coarse search box"}
real   cboxsmall    { 7., prompt="Size of small search box"}
bool   verbose      {yes, prompt="Verbose output?"}
bool   answer       {yes, prompt="Do you want to continue?", mode="q"}
bool   frameoffset  {no, prompt="Do you want to get frame offsets?", mode="q"}
bool   choffset     {no, prompt="Do you want to get channel offsets?", mode="q"}

struct  *list1,*list2,*list3,*l_list
imcur   *starco

begin

   file    tmpimg, tmptmp, tmptran, info, dbmos, l_log, moslist,cofile,
           tmp1, c1list,c2list,c3list,c4list,chcomplist,frinshifts,chinlist,
           chinshifts,frcomplist,alignlog
   int     i, nin,stat,pos1b,pos1e,nim, ncols,nrows,nxoverlap,nyoverlap,
           nxref,nyref,nxlosrc,nxhisrc,nylosrc,nyhisrc,ncolors,wcs,ref_nim,
           cnxref[4],cnyref[4]
   real    xin,yin,xref,yref
   string  jlist, in, inmos, out, mosout, img, trimg, junk,ref_name,
           colorin,color,uniq,sjunk,src,srcsub,sname,mos_name,
           key,ishifts
   bool    old_irmosaic, frgotoffset, chgotoffset, getcoords
   struct command = ""
   struct line = ""

   uniq       = mktemp ("_Tsqf")
   tmpimg     = mktemp ("tmp$sqf")
   dbmos      = mktemp ("tmp$sqf")
   tmptmp     = mktemp ("tmp$sqf")
   moslist    = mktemp ("tmp$sqf")
   tmp1       = mktemp ("tmp$sqf")
   frcomplist = mktemp ("tmp$sqf")
   chcomplist = mktemp ("tmp$sqf")
   cofile     = mktemp ("tmp$sqf")
   chinshifts = mktemp ("tmp$sqf")
   frinshifts = mktemp ("tmp$sqf")
   alignlog   = mktemp ("tmp$sqf")
   l_log      = mktemp ("tmp$sqf")

# Get positional parameters
   jlist  = j_list
   mosout = output
   mos_name = mosout
   l_list = l_log
   count (jlist, >> l_log)
   stat = fscan(l_list,nin)			# Number of images per color
   print (colors) | translit ("","^jhkl\\n",delete+,collapse-,>> l_log)
   stat = fscan(l_list,colorin)
   ncolors = strlen(colorin)		# Number of colors
   if (nin <= 1 || ncolors < 1)
      goto skip
   else
      print ("# images= ",nin,"for each of ",ncolors,"colors: ",colors)

# establish whether ref_id is a list number or a name
   if (stridx("_",ref_id) == 1) { 		# It's a list number
      ref_nim = int (substr(ref_id,2,strlen(ref_id)))
      list1 = jlist
      for (i = 1; i <= ref_nim; i += 1) {
          stat = fscan(list1,ref_name)
      }
   } else {					# It's an image name
      ref_nim = 0
      ref_name = ref_id
   }

   print (ref_name,> chcomplist)
   for (i = 1; i <= ncolors; i += 1) {
      color = substr(colorin,i,i)
      colorlist(ref_name,color,id_color=id_color,>> chcomplist)
   }
   print (ref_name,> frcomplist)
   color = substr(colorin,1,1)
   colorlist("@"//jlist,color,id_color=id_color,section="",>> frcomplist)
       
   if (coord_in == "" || coord_in == " " || coord_in == "null")
      getcoords = yes
   else {
      getcoords = no
   }

   if (! getcoords) goto after_get		# Skip interactive part

   delete(l_log,ver-,>& "dev$null"); l_list = l_log	# Reset l_log
   list1 = ""; list1 = chcomplist
   stat  = fscan(list1,img)
   print ("display "//img//" "//1//" zscale+ fi-" ) | cl
   frame (1)
   print ("Mark target object in reference frame:")
   print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(quit)|")
   while (fscan(starco,xin,yin,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)
      if (key == "f")
         print ("Star_coordinates= ",xin,yin)
      else if (key == "040") {			# 040 == spacebar
         imcntr (img, xin, yin,>> l_log)	# Improve center
         stat = fscan (l_list, line)
         print ("Star_coordinates imcntr= ",line)
         stat = fscan(line,sjunk,sjunk,xref,sjunk,yref)
         print (xref,yref,> cofile)
         break
      } else if (key == "q")
         break
      else {
         print ("Unknown keystroke: ",key," allowed = |f|spacebar|q|"); beep
      }
   }
   delete(l_log,ver-,>& "dev$null"); l_list = l_log	# Reset l_log
# Get individual channel offsets if outside range of coarse pass
   if (ncolors > 1) {
      if (choffset) {
         print ("0 0",>> chinshifts)
         chgotoffset = yes
         print("Allowed keystrokes: |f(find)|spacebar(find&use)|q(skip)|")
         for (i = 1; fscan(list1,img) != EOF ; i += 1) { 
            print ("display "//img//" "//2//" zscale+ fi-" ) | cl
            frame (2)
            print ("Select star for image#",i," in frame 2")
            while (fscan(starco,xin,yin,wcs,command) != EOF) {
               if (substr(command,1,1) == "\\")
                  key = substr(command,2,4)
               else
                  key = substr(command,1,1)
               if (key == "f") {
                  imcntr (img, xin, yin,>> l_log)	# Improve center
                  stat = fscan(l_list,sjunk,sjunk,xin,sjunk,yin)
                  print ("Star_coordinates= ",xin,yin)
                  xin = xref - xin; yin = yref - yin
                  print ("Offset for frame ",i,xin,yin)
               } else if (key == "040") {		# 040 == spacebar
                  print ("Selected star_coordinates= ",xin,yin)
                  xin = xref - xin; yin = yref - yin
                  print ("Submitted offset for frame ",i,xin,yin)
                  print (xin,yin,>> chinshifts)
                  break
               } else if (key == "q") {
                  print ("0 0",>> chinshifts)
                  break
               } else {
                  print("Unknown key: ",key," allowed = |f|spacebar|q|")
                  beep
               }
            }
         }
         print ("Submitted channel offsets:"); type (chinshifts)
      } else {
         chgotoffset = no
      }
   }
# Get individual frame
#   list1 = ""; list1 = frlist
#   if (frameoffset) {
#      print ("0 0",>> frinshifts)
#      frgotoffset = yes
#      print("Allowed keystrokes: |f(find)|spacebar(find&use)|q(skip)|")
#      for (i = 1; fscan(list1,img) != EOF ; i += 1) { 
#         print ("display "//img//" "//2//" zscale+ fi-" ) | cl
#         frame (2)
#         print ("Select star for image#",i," in frame 2")
#         while (fscan(starco,xin,yin,wcs,command) != EOF) {
#            if (substr(command,1,1) == "\\")
#               key = substr(command,2,4)
#            else
#               key = substr(command,1,1)
#            if (key == "f") {
#               imcntr (img, xin, yin,>> l_log)	# Improve center
#               stat = fscan(l_list,sjunk,sjunk,xin,sjunk,yin)
#               print ("Star_coordinates= ",xin,yin)
#               xin = xref - xin; yin = yref - yin
#               print ("Offset for frame ",i,xin,yin)
#            } else if (key == "040") {		# 040 == spacebar
#               print ("Selected star_coordinates= ",xin,yin)
#               xin = xref - xin; yin = yref - yin
#               print ("Submitted offset for frame ",i,xin,yin)
#               print (xin,yin,>> frinshifts)
#               break
#            } else if (key == "q") {
#               print ("0 0",>> frinshifts)
#               break
#            } else {
#               print("Unknown key: ",key," allowed = |f|spacebar|q|")
#               beep
#            }
#         }
#      }
#      print ("Submitted frame offsets:"); type (frinshifts)
#   } else {
#      frgotoffset = no
#   }
#
after_get:			# Continuation after getcoords

# Locate objects in REF and other channels
   if (in_shifts == "" || in_shifts == " " || in_shifts == "null") {
      if (!chgotoffset)
         ishifts = ""
      else
         ishifts = chinshifts
   } else {
       ishifts=in_shifts
   }
   print ("IMCENTROID: ",ishifts)
   imcentroid ("@"//chcomplist,cofile,reference="",shifts=ishifts,
      bigbox=cboxbig,boxsize=cboxsmall,
      background=INDEF,lower=INDEF,upper=INDEF,niter=3,tolerance=0,
      verbose+,>> alignlog)
# prefix=prefix,interp_type="linear",boundary="constant",constant=0.,
#      if (verbose) type(alignlog,>> out)		 # Log imalign output
   match ("(",alignlog,meta-,stop-,print-,> tmp1)	# get centers
   list1 = tmp1
   stat = fscan(list1,sname,xin,sjunk,yin)		# skip reference image
   for (i = 1; i <= ncolors; i += 1) {
      color = substr(colorin,i,i)
      stat = fscan(list1,sname,xref,sjunk,yref)	# skip reference image
      cnxref[i] = nint(xref); cnyref[i] = nint(yref)
      nxlosrc = cnxref[i] - npad; nxhisrc = cnxref[i] + npad
      nylosrc = cnyref[i] - npad; nyhisrc = cnyref[i] + npad
      srcsub ="["//nxlosrc//":"//nxhisrc//","//nylosrc//":"//nyhisrc //"]"
      colorlist("@"//jlist,color,id_color=id_color,section=srcsub,>> moslist)
   }

# Locate objects in REF and other frames
#   if (in_shifts == "" || in_shifts == " " || in_shifts == "null") {
#      if (!frgotoffset)
#         ishifts = ""
#      else
#         ishifts = frinshifts
#   } else {
#       ishifts=in_shifts
#   }
#   print ("IMCENTROID: ",ishifts)
#   imcentroid ("@"//frcomplist,cofile,reference="",shifts=ishifts,
#      bigbox=cboxbig,boxsize=cboxsmall,
#      background=INDEF,lower=INDEF,upper=INDEF,niter=3,tolerance=0,
#      verbose+,>> alignlog)
## prefix=prefix,interp_type="linear",boundary="constant",constant=0.,
##      if (verbose) type(alignlog,>> out)		 # Log imalign output
#   match ("(",alignlog,meta-,stop-,print-,> tmp1)	# get centers
#   list1 = tmp1
#   stat = fscan(list1,sname,xin,sjunk,yin)		# skip reference image
#   for (i = 1; i <= ncolors; i += 1) {
#      color = substr(colorin,i,i)
#      stat = fscan(list1,sname,xref,sjunk,yref)	# skip reference image
#      cnxref[i] = nint(xref); cnyref[i] = nint(yref)
#      nxlosrc = nxref - npad; nxhisrc = nxref + npad
#      nylosrc = nyref - npad; nyhisrc = nyref + npad
#      srcsub ="["//nxlosrc//":"//nxhisrc//","//nylosrc//":"//nyhisrc //"]"
#      colorlist("@"//jlist,color,fire_mode=fire_mode,
#         section=srcsub,>> moslist)
#   }
#   type (moslist)

   irmosaic("@"//moslist,mosout,dbmos,nin,ncolors,trim_sec="",
      null_input="",corner="ll",direction="row",raster-,
      median_section="",subtract-,
      nxover=0,nyover=0,nimcols=INDEF,nimrows=INDEF,oval=oval,
      opixtype="r",verbose+,>> logfile)

# Clean up

  skip:

  delete(tmpimg//","//tmptmp//","//l_log//","//moslist,ver-,>& "dev$null")
  delete(tmp1//","//cofile,ver-,>& "dev$null")
  delete(frinshifts//","//alignlog//","//chcomplist,ver-,>& "dev$null")
  delete(chinshifts//","//alignlog//","//frcomplist,ver-,>& "dev$null")
  if (!save_dbmos) delete (dbmos, ver-, >& "dev$null")
#        delete (uniq//"*",ver-,>& "dev$null")

end
