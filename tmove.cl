# TMOVE: 14SEP00 KMM  MODIFIED FOR UPSQIID
# TMOVE: 11JAN00 KMM; MODIFIED FOR CHANGED PROSPERO SYNTAX
# TMOVE: 04JUN99 RRJ; MODIFIED FOR N-S TIFKAM ORIENTATION OPTION
# TMOVE: 12DEC95 KMM
# TMOVE: 23AUG95 KMM
# TMOVE: 16FEB95 KMM
# TMOVE: 23JUN94 KMM
# TMOVE: 23MAR94 KMM

procedure tmove ()

#  Edit instrument and telescope string below for your configuration.
#  Default orientation for TIFKAM is E-W slit.  If slit is N-S, then
#  set 'rotate = yes' in line 76 and uncomment lines 160,161

#  You may wish to edit the "center" coordinates for the particular
#  detector configuration for use with the 'c' key

#  Install edited file in data directory and identify as an IRAF task
#  with 'task tmove=tmove.cl'.  Enter 'tmove' to execute

string instrument  {"SQIID",
                    prompt="IR instrument (SQIID|PHX|IRIM|CRSP|TIFKAM|none)?",
                        enum="SQIID|PHX|IRIM|CRSP|TIFKAM|none"}
string telescope   {"2.1m", prompt="KPNO telescope (1.3m|2.1m|4m|none)?",
                        enum="1.3m|2.1m|4m|none"}
bool   verbose     {yes,  prompt="Verbose reporting"}

imcur   *starco

begin

   int    stat, nin, nout, slen, wcs, rid, prior
   real   xin, yin, xref, yref, xshift, yshift, dist, adist, foo
   real   xscale, yscale, xcenter, ycenter
   bool   xinvert, yinvert, rotate
   string uniq,sjunk,sname,key
   struct command = ""

# Get offset between master reference and reference frames

   if (instrument == "SQIID") {
      xcenter = 256.; ycenter = 256.
      xinvert = no; yinvert = no; rotate=no
      if (telescope == "2.1m") {
         xscale = 0.69; yscale = 0.69 # K channel
      } else if (telescope == "4m") {
         xscale = 0.39; yscale = 0.39
      }
   } else if (instrument == "PHX") {
      xcenter = 128.; ycenter = 512.; rotate=no
      if (telescope == "2.1m") {
         xscale = 0.25; yscale = 0.25 # Viewer Scale
         xinvert = yes; yinvert = no
      } else if (telescope == "4m") {
         xscale = 0.125 ; yscale = 0.125 
         xinvert = no; yinvert = yes
      }
   } else if (instrument == "IRIM") {
      xcenter = 128.; ycenter = 128.; rotate=no
      if (telescope == "2.1m") {
         xinvert = no ; yinvert = yes 
         xscale = 1.09; yscale = 1.09
      } else if (telescope == "4m") {
         xinvert = no ; yinvert = yes 
         xscale = 0.60; yscale = 0.60
      }
   } else if (instrument == "CRSP") {
      xcenter = 85.; ycenter = 128.; rotate=no
      if (telescope == "2.1m") {
         xinvert = no ; yinvert = yes
         xscale = 0.61; yscale = 0.61
      } else if (telescope == "4m") {
         xinvert = yes ; yinvert = no
         xscale = 0.36; yscale = 0.36
      }

   } else if (instrument == "TIFKAM") {
      xcenter = 256.; ycenter = 502.7; rotate=yes
# Set rotate=yes if slit is N-S and uncomment lines 160, 161
      if (telescope == "2.1m") {
         xscale = 0.341 ; yscale = 0.341 
         xinvert = yes; yinvert = yes
      } else if (telescope == "4m") {
         xscale = 0.178 ; yscale = 0.178 
         xinvert = no; yinvert = yes
      }
   } else if (instrument == "none") {
         xinvert = no ; yinvert = no ; rotate=no 
   }

#   if (!xinvert && !yinvert)
#      print ("NORTH at top and EAST at left in frame XY system")
#   else if ( !xinvert && yinvert) 
#      print ("NORTH at bottom and EAST at left in frame XY system")
#   else if ( xinvert && !yinvert) 
#      print ("NORTH at top and EAST at right in frame XY system")
#   else if (xinvert && yinvert) 
#      print ("NORTH at bottom and EAST at right in frame XY system")

   print ("Use image cursor to indicate current position...")
   print ("Allowed keystrokes: |c(to center)|spacebar(here)|q(skip)|")
   while (fscan(starco,xin,yin,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)

      if (key == "c") {
         xref = xcenter; yref = ycenter
         print ("")
         print ("==> Offset position: ",xin,yin," to frame center: ",xref,yref)
         break
      } else if (key == "040") {			# 040 == spacebar
         print ("Current position is = ",xin,yin)
         print ("Indicate where you want to be..")
         while (fscan(starco,xref,yref,wcs,command) != EOF) {
            if (substr(command,1,1) == "\\")
               key = substr(command,2,4)
            else
               key = substr(command,1,1)

            if (key == "c") {
               xref = xcenter; yref = ycenter
               print ("Desired position is frame center = ",xref,yref)
               break
            } else if (key == "040") {		# 040 == spacebar
               print ("Desired position is = ",xref,yref)
               break
            } else if (key == "q") {
               print ("Safe exit!")
               goto err
            } else {
               print("Unknown key: ",key," allowed = |c|f|spacebar|q|")
               beep
            }
            break
         }
         print ("")
         print ("==> Offset position: ",xin,yin," to: ",xref,yref)
         break
      } else if (key == "q") {
         print ("Safe exit!")
         goto err
      } else {
         print("Unknown key: ",key," allowed = |f|spacebar|q|")
         beep
      }
   }

# Eastward motion of telescope is defined as positive
   xshift = 0.1*real(nint(10.0*(xscale * (xref - xin))))
# Northward motion of telescope is defined as positive
   yshift = -0.1*real(nint(10.0*(yscale * (yref - yin))))

   print(xinvert,yinvert, rotate)
   if (xinvert)
      xshift = -1.0 * xshift
   if (yinvert)
      yshift = -1.0 * yshift
  if (rotate) {
     foo = yshift; yshift = -1.0 * xshift; xshift = foo
  }

   dist = sqrt(xshift ** 2 + yshift ** 2)
   adist = 0.01*real(nint(100.0*dist))
   dist  = adist/((xscale+yscale)/2.)
   print ("Separation = ",dist," pixels : ", adist," arcsec")

   if (xshift >= 0)
      print (xshift, " east")
   else
      print (-1.0*xshift, " west")

   if (yshift >= 0)
      print (yshift, " north")
   else
      print (-1.0*yshift, " south")

   if (instrument == "TIFKAM") {
      print ("Within the PROPERO instrument control window type: offset RA=",
           xshift," DEC=",yshift)
   } else {
      print ("Within the WILDFIRE instrument control window type: toffset ",
           xshift,yshift)
   }

   err:

   xref = 0.0

   end
