# GETSTAR: 22JUN98 KMM expects IRAF 2.11Export or later
# GETSTAR: - locate an object in a list of images
# GETSTAR: 12SEP(5 KMM
# GETSTAR: 22JUN98 KMM modify arguments to imcentroid and trapping of imcentroid
#                      output to conform to IRAF2.11

procedure getstar (images)

string images       {prompt="List of images to compare"}

string outfile      {"STDOUT", prompt="Output information file"}
int    displ_frame  {1, prompt="Display frame #"}
string command_displ {"null", prompt="Display command string"}
bool   centroid     {no, prompt="Centroid on indicated star?"}
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
bool   zscale       {yes, prompt="DISPLAY using zscale?"}
real   z1           {-100.0, prompt="minimum greylevel to be displayed"}
real   z2           {1000.0, prompt="maximum greylevel to be displayed"}

struct  *list1
imcur   *starco

begin

      int    i,stat,nim,nin,wcs
      real   xin, yin
      string l_images,out,uniq,sjunk,slog,sname,key,img,comdispl
      file   cofile,compfile
      bool   is_stdout, external
      struct command = ""
      struct line = ""

      l_images    = images
      compfile    = mktemp ("tmp$gcm")
      cofile      = mktemp ("tmp$gcm")
      out         = outfile
      if (out == "STDOUT" || out == "" || out == " ") {
         is_stdout = yes
      } else {
         is_stdout = no
      }
      comdispl = command_displ
      if (comdispl == "null" || comdispl == "" || comdispl == " ") {
         external = no 
      } else {
         external = yes
      }

      sections (l_images, option="full",>> compfile)

      nin = displ_frame
      list1 = compfile
      print("# Allowed keystrokes: |f(find)|spacebar(find&use)|n(skip)|q(quit)")
      for (i = 1; fscan(list1,img) != EOF ; i += 1) { 
         slog = "display "//img//" "//nin
         if (external) {
            print (slog//" "//comdispl) | cl
         } else  {
            if (zscale) 	# DISPLAY using zscale+
               print (slog//" zs+ zr- fi-" ) | cl
            else
               print (slog//" zs- zr- fi- z1="//z1//" z2="//z2) | cl
         }
         frame (nin)
         delete (cofile, ver-,>& "dev$null")
         print ("# Select star for image#",i," in frame ",displ_frame)
         while (fscan(starco,xin,yin,wcs,command) != EOF) {
            if (substr(command,1,1) == "\\")
               key = substr(command,2,4)
            else
               key = substr(command,1,1)
            if (key == "f") {
               imcntr (img, xin, yin) |		# Improve center
                  scan(sjunk,sjunk,xin,sjunk,yin)
               print ("# Star_coordinates= ",xin,yin)
            } else if (key == "040") {		# 040 == spacebar
               print ("# Selected star_coordinates= ",xin,yin)
               print (xin,yin,>> cofile)
               if (centroid) {
                  imcentroid (img, "", cofile, shifts="",
	              boxsize=boxsize, bigbox=bigbox, negative-,
	              background=background, lower=lower, upper=upper,
	              niterate=niterate, tolerance=tolerance, verb+) |
                     match (img,"",stop-,print-,meta-) |
                     scan (sname,xin,sjunk,yin)
                  if (nscan() == 4) {
                     if (is_stdout)
                        print (img," ",xin,yin,"yes ",key)
                     else
                        print (img," ",xin,yin,"yes ",key,>> out)
                     break
                  } else {
                     print ("# IMCENTROID failed to converge")
                  }
               } else {
                  if (is_stdout)
                     print (img," ",xin,yin,"yes ",key)
                  else
                     print (img," ",xin,yin,"yes ",key,>> out)
                  break
               }
            } else if (key == "n" || key == "q") {
               if (is_stdout)
                  print (img," 0 0 no ",key)
               else
                  print (img," 0 0 no ",key,>> out)
               break
            } else {
               print("# Unknown key: ",key," allowed = |f|n|spacebar|q|")
               beep
            }
         }
      }

   # Finish up
skip:

      list1=""
      delete (cofile//","//compfile, ver-,>& "dev$null")

end
