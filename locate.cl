# LOCATE 20DEC99 KMM 
# LOCATE locate images with respect to a reference image
# LOCATE 15JAN91 KMM
# LOCATE 30JAN94 KMM
# LOCATE 13JUL94 KMM initialize shifts_found to no
#        22JUL94 KMM change list directed fscan to scan from pipe at key points
#        03DEC97 KMM modify arguments to imcentroid and trapping of imcentroid
#                      output to conform to IRAF2.11
#        15AUG98 KMM add global image extension
#        20DEC99 KMM allow skipping images and choosing to use imcntr on cursor
#                      position prior to imcentroid

procedure locate (images,ref_image)

string images       {prompt="List of images to compare"}
string ref_image    {prompt="Reference image"}

string coords       {"", prompt="Input initial coordinate file"}
string in_shifts    {"", prompt="Initial shift file between ref and images"}

bool   precenter    {no, 
                     prompt="imcntr on cursor position prior to imcentroid?"}
string interp_type  {"linear", prompt="Interpolator to be used by imshift"}
real   bigbox       {11., prompt="Size of coarse search box"}
real   boxsize      { 7., prompt="Size of final centering box"}
real   background   {INDEF,
                     prompt="Absolute reference level for marginal centroid"}
real   lower        {INDEF, prompt="Lower threshold for the data"}
real   upper        {INDEF, prompt="Upper threshold for the data"}
int    niterate     {3,
                    prompt="Maximum number of centering iterations to perform"}
real   tolerance    {0.,
                  prompt="Tolerance for convergence of the centering algorithm"}
bool   getoffset    {yes, prompt="Do you want to get frame offsets?", mode="q"}
bool   display_ref  {yes,prompt="[re]display referenced image?"}
bool   zscale       {yes, prompt="DISPLAY using zscale?"}
real   z1           {0.0, prompt="minimum greylevel to be displayed"}
real   z2           {1000.0, prompt="maximum greylevel to be displayed"}
string outfile      {"STDOUT", prompt="Output information file"}
bool   verbose      {no, prompt="Verbose reporting"}

struct  *list1,*list2
imcur   *starco

begin

int    i,stat,nim,nin,lo,hi,ncomp,pos1b,pos1e,wcs,gridx,gridy,maxnim,
       nxmos0, nymos0, nxmat0, nymat0, nxref0, nyref0, nxoff0, nyoff0
int    nxlo, nxhi, nylo, nyhi, nxlonew, nxhinew, nylonew, nyhinew
real   xin, yin, xref, yref, xs, ys, fxs,fys,
       xshift,yshift,xlo,xhi,ylo,yhi
string l_images,l_coords,out,uniq,sjunk,slog,sname,key,
       ishifts,refid,img,refimg,reftag,imtag,refsub,tmpimg,
       imname,trimsec,vigsec,serr
file   cofile,alignlog,inshifts,compfile,tmp1,tmp2,includefile
bool   getcoords,gotoffset,shifts_found,trim_found
int    nex
string gimextn, imextn, imroot
      
struct command = ""
struct line = ""

l_images    = images
refimg      = ref_image
l_coords    = coords
      
# get IRAF global image extension
show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
nex     = strlen(gimextn)
            
tmp1        = mktemp ("tmp$gcm")
tmp2        = mktemp ("tmp$gcm")
compfile    = mktemp ("tmp$gcm")
inshifts    = mktemp ("tmp$gcm")
alignlog    = mktemp ("tmp$gcm")
cofile      = mktemp ("tmp$gcm")
includefile = mktemp ("tmp$gcm")      
gotoffset   = no
reftag      = refimg//"_ref"
out         = outfile

sections (l_images, option="full",>> compfile)
list1 = compfile
stat  = fscan(list1,img)
if (display_ref) {
   if (zscale) { 		# DISPLAY using zscale+
      print ("display "//img//" 1 zscale+ zr- fi-" ) | cl
   } else {
      print ("display "//img//" 1 zs- zr- z1="//z1//" z2="//z2//" fi-" ) | cl
   }
}
print (img,>> includefile)
if (l_coords == "" || l_coords == "null" || l_coords == " ") {	# Get position
   frame (1)
   print ("Mark target objects in reference frame:")
   print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(quit)|x(skip)|"
   while (fscan(starco,xin,yin,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)
      if (key == "f") {
         if (precenter) imcntr (refimg, xin, yin) 	# Improve center
         print ("Star_coordinates= ",xin,yin)
      } else if (key == "040") {		# 040 == spacebar
         if (precenter){
	    imcntr (refimg, xin, yin) | scan(line)	# Improve center
            print ("Star_coordinates= ",xin,yin," ;imcntr= ",line)
  # Format (Star_coordinates= xin yin ;imcntr= imageid x: xcenter y: ycenter)
            stat = fscan(line,sjunk,sjunk,xin,sjunk,yin)
	 } else {
	    print ("Star_coordinates= ",xin,yin)
	 }
         print (xin,yin,>> cofile)
      } else if (key == "q") {
         break
      } else if (key == "x") {
         break
      } else {
         print("Unknown keystroke: ",key," allowed = |f|spacebar|q|x|")
         beep
      }
   }
} else {	# Extract position from file
   match ("^SUM_COFILE",l_coords,meta+,stop-,print-,>> tmp1)
   count (tmp1) | scan(i)
   if (i > 0) {
     list2 = tmp1    
  # Format ("SUM_COFILE: ",xin,yin," ",reftag," ",line)
      while (fscan(list2,sjunk,xin,yin) != EOF) {
         print (xin,yin,>> cofile)
      }
   } else {
     list2 = l_coords
      while (fscan(list2,xin,yin) != EOF) {
         print (xin,yin,>> cofile)
      }
   }
}

if (verbose) {
   print ("Submitted star_coordinates:")
   type (cofile)
}

# Get individual frame offsets if outside range of coarse pass

if (in_shifts == "" || in_shifts == " " || in_shifts == "null") {
   if (getoffset) {
      # Select initial star in reference frame
      print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(quit)|x(skip)|"
      frame (1)
      delete (tmp2, ver-, >& "dev$null")
      print ("Select star for reference frame 1")
      while (fscan(starco,xref,yref,wcs,command) != EOF) {
         if (substr(command,1,1) == "\\")
            key = substr(command,2,4)
         else
            key = substr(command,1,1)
         if (key == "f") {
	    if (precenter) {		# Improve center
	       imcntr (refimg, xref, yref) | scan(sjunk,sjunk,xref,sjunk,yref)
	    }
            print ("Ref_coordinates= ",xref,yref)
         } else if (key == "040") {			# 040 == spacebar
            if (precenter) {		# Improve center
	       imcntr (refimg, xref, yref) | scan(sjunk,sjunk,xref,sjunk,yref)
            }   
            print ("Submitted ref_coordinates= ",xref,yref)
	    print ("Submitted offset for ref_image = 0, 0")
            print ("0 0",>> inshifts)
            gotoffset = yes
            break
         } else if (key == "q") {
            gotoffset = no
	    error (1, "No reference star selected!")
            break
	 } else if (key == "x") {
            gotoffset = no
	    error (1, "No reference star selected!")
            break
         }
      }
      # Identify selected reference star in all images
      print("Allowed keystrokes: |f(find)|spacebar(find&use)|q(quit)|x(skip)|")
      for (i = 1; fscan(list1,img) != EOF ; i += 1) { 
         if (zscale) 	# DISPLAY using zscale+
            print ("display "//img//" 2 zscale+ zr- fi-" ) | cl
         else
           print("display "//img//" 2 zs- zr- z1="//z1//" z2="//z2//" fi-") | cl
         frame (2)
         print ("Select star for image#",i," in frame 2: ", img)
         while (fscan(starco,xin,yin,wcs,command) != EOF) {
            if (substr(command,1,1) == "\\")
               key = substr(command,2,4)
            else
               key = substr(command,1,1)
            if (key == "f") {
               if (precenter) {		# Improve center	    
                  imcntr (img, xin, yin) | scan(sjunk,sjunk,xin,sjunk,yin)
               }
               print ("Star_coordinates= ",xin,yin)
               xin = xref - xin; yin = yref - yin
               print ("Offset for frame ",i,xin,yin)
            } else if (key == "040") {		# 040 == spacebar
               if (precenter) {		# Improve center	    
                  imcntr (img, xin, yin) | scan(sjunk,sjunk,xin,sjunk,yin)
               }
               print ("Selected star_coordinates= ",xin,yin)
               xin = xref - xin; yin = yref - yin
               print ("Submitted offset for frame ",i,xin,yin)
               print (xin, yin,>> inshifts)
	       print (img,>> includefile)
               break
            } else if (key == "q") {
               break	       
#            } else if (key == "q") {
#               print ("0 0",>> inshifts)
#               break
            } else if (key == "x") {
	       print ("Skipping image#",i , img)
#	       print ("# 0 0",>> inshifts)
#	       print ("# ",img,>> includefile)	       
               break
	    } else {
               print("Unknown key: ",key," allowed = |f|spacebar|q|x|")
               beep
            }
         }
      }
#      type (includefile)
      l_images = "@"//includefile
      if (verbose) print ("Submitted frame offsets:"); type (inshifts)
      if (gotoffset)
         ishifts = inshifts	# newly aquired offset file
      else
         ishifts = ""		# null offset file

   } else
      ishifts = ""		# null offset file
   
} else
    ishifts=in_shifts	# prior offset file

print ("IMCENTROID: ",l_images)
imcentroid (l_images, refimg, cofile, shifts=ishifts,
    boxsize=boxsize, bigbox=bigbox, negative-,
    background=background, lower=lower, upper=upper,
    niterate=niterate, tolerance=tolerance, verbose+,>& alignlog)
   
if (verbose) type(alignlog,>> out)		 # Log imalign output

#Extract shifts
list1 = alignlog
shifts_found = no
while (fscan (list1, sname) != EOF) {
    if (sname == "#Shifts") {
        shifts_found = yes
        break
     }
}
if (shifts_found)
   while (fscan (list1, sname, xshift,sjunk,yshift,sjunk,nim,serr) == 7)
      print ("SUM_SHIFTS: ",xshift,yshift," ",sname," ",nim,serr,>> out)
else
   error (1, "No shifts were calculated.")

# read and correct the trim section
trim_found = no
while (fscan (list1, sname, sjunk, vigsec) != EOF) {
   if (sname != "#Trim_Section")
      next
   print(vigsec) | translit ("", "[:,]", "    ") |
      scan (nxlo, nxhi, nylo, nyhi)
   # correct for boundary extension "contamination"
   if (interp_type == "poly3")
      { nxlo += 1; nxhi -= 1; nylo += 1; nyhi -= 1 }
   else if (interp_type == "poly5" || interp_type == "spline3")
      { nxlo += 2; nxhi -= 2; nylo += 2; nyhi -= 2 }

   if (1 <= nxlo && nxlo <= nxhi && 1 <= nylo && nylo <= nyhi) {
      trimsec = "["//nxlo //":"// nxhi //","// nylo //":"// nyhi//"]"
      print("OVERLAP: ",vigsec," ",trimsec," ",reftag,>> out)

    } else
      print ("Images not trimmed!  No overlap region.")

   trim_found = yes
   break
}

if (!trim_found)
   print ("Images not trimmed!  Problem with the trim section.")
   
list1 = cofile
while (fscan(list1,xin,yin,line) != EOF) {	# Report search coords
   print ("SUM_COFILE: ",xin,yin," ",reftag," ",line,>> out)
}
if (ishifts != "") {				# Report any offsets
   list1 = ishifts
   while (fscan(list1,xin,yin) != EOF) {
      print ("SUM_OFFSET: ",xin,yin," ",reftag,>> out)
   }
}

# Finish up
skip:

list1=""; list2=""
delete (tmp1//","//tmp2,ver-, >& "dev$null")
delete (alignlog//","//inshifts//","//includefile, ver-,>& "dev$null")
delete (cofile//","//compfile, ver-,>& "dev$null")

end
