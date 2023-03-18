# CLOSURE: 10APR91 KMM 10APR92
# CLOSURE: - determine overlap region and mininum enclosure
#       06APR94 KMM replace "type" with "concatenate"
#       22JUL94 KMM replace fscan with scan from pipe at key points
#       08AUG94 KMM utilize printf for formatted output (instead of AWK)

procedure closure (infofile,gxshift,gyshift)

file   infofile     {prompt="file produced by XYGET|XYLAP|XYADOPT|IRCOMBINE"}
real   gxshift      {prompt="global xshift for final image"}
real   gyshift      {prompt="global yshift for final image"}
# trim values applied to final image
string trimlimits   {"[0:0,0:0]",
                      prompt="added trim limits for input subrasters"}
string interp_shift {"linear",enum="nearest|linear|poly3|poly5|spline3",
              prompt="IMSHIFT interpolant (nearest,linear,poly3,poly5,spline3)"}
bool   format       {yes,prompt="Use fancy output format"}
bool   origin       {no, prompt="Move origin to lower left corner?"}
bool   verbose      {yes, prompt="Verbose output?"}

struct  *list1, *list2

begin

      int    i,stat,nim,slen,slenmax,
             nxhi, nxlo, nyhi, nylo, nxhisrc, nxlosrc, nyhisrc, nylosrc,
             nxlotrim,nxhitrim,nylotrim,nyhitrim,nxspan,nyspan,
             nxhiref,nxloref,nyhiref,nyloref,nxhimat,nxlomat,nyhimat,nylomat,
             nxlovig,nxhivig,nylovig,nyhivig,nxlolap,nxhilap,nylolap,nyhilap,
             nxlonew,nxhinew,nylonew,nyhinew,
             nxmat0, nymat0, nxmos0, nymos0, ixs, iys, ncolsout,nrowsout
      real   zoff, rjunk, xin, yin, xmat, ymat, fxs, fys,
             xs, ys, xoff, yoff, g_xshift, g_yshift,
              xmax, xmin, ymax, ymin,oxmin,oymin,
             xoffset,yoffset, xlo, xhi, ylo, yhi, xshift, yshift
      bool   firsttime
      string uniq,imname,sjunk,soffset,encsub,info,
             src,mat,ref,outsec,lapsec,vigsec,sformat
      file   out,tmp1,matinfo,newinfo,task
      struct line = ""

      info        = infofile
      g_xshift    = gxshift
      g_yshift    = gyshift
      uniq        = mktemp ("_Tclo")
      task        = uniq // ".tsk"
      newinfo     = uniq // ".mat"
      matinfo     = mktemp("tmp$clo")
      tmp1        = mktemp("tmp$clo")


      if (! access(info)) { 		# Exit if can't find info
         print ("Cannot access info_file: ",info)
         goto err
      }

   # Set initial values
       xmin =  10000.;   xmax = -10000.;  oxmin =  10000.
       ymin =  10000.;   ymax = -10000.;  oymin =  10000.

      print (trimlimits) | translit ("", "[:,]", "    ") |
         scan(nxlotrim,nxhitrim,nylotrim,nyhitrim)
   # Read in data along direction of imcopy
      list1 = info
   # print ("COM_"//pathpos," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
   #    nxmat0,nymat0,xs,ys,soffset)
      slenmax = 0
      firsttime = yes
      for (i = 0; fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
         nxmat0,nymat0,xs,ys,soffset) != EOF; i += 1) {
   # Get sizes of source images
         if (stridx("#",imname) != 0) {
            print (imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
              nxmat0,nymat0,fxs,fys,soffset," ",line,>> newinfo)
            next
         }
         print (src) | translit ("", "[:,]", "    ") |
            scan(sjunk,nxloref,nxhiref,nyloref,nyhiref)
   # Establish image span
         nxspan  = nxhiref - nxloref + 1
         nyspan  = nyhiref - nyloref + 1
         nxhiref = nxhiref - nxloref + 1; nxloref = 1
         nyhiref = nyhiref - nyloref + 1; nyloref = 1
   # Put in additional global trims
         nxlosrc += nxlotrim; nxhisrc -= nxhitrim
         nylosrc += nylotrim; nyhisrc -= nyhitrim
   # Put in global shifts
         xs = xs + g_xshift; ys = ys + g_yshift
         ixs = nint(xs); iys = nint(ys)  
         fxs = xs - ixs; fys = ys - iys
         fxs = 0.01*real(nint(100.0*fxs))
         fys = 0.01*real(nint(100.0*fys))
         xshift =  xs + nxmat0; yshift =  ys + nymat0
         xoff   = ixs + nxmat0; yoff   = iys + nymat0
         nxlomat = nxlosrc + xoff; nxhimat = nxhisrc + xoff
         nylomat = nylosrc + yoff; nyhimat = nyhisrc + yoff
         slenmax = max(slenmax,strlen(src))
   # Recode MAT table including global trims and shifts
         nxmat0 = int(xoff); nymat0 = int(yoff)
         print (imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
           nxmat0,nymat0,fxs,fys,soffset," ",line,>> newinfo)
   # Determine size of composite image.  Note that trims are not included.
         xlo = nxloref + xshift; xhi = nxhiref + xshift
         ylo = nyloref + yshift; yhi = nyhiref + yshift
         xmin = min(xmin,xlo); xmax = max(xmax,xhi)
         ymin = min(ymin,ylo); ymax = max(ymax,yhi)
         oxmin = min (nxhiref, oxmin); oymin = min (nyhiref, oymin)
   # Determine overlap region.   Note that trims are included.
         xlo = nxlosrc + xshift; xhi = nxhisrc + xshift
         ylo = nylosrc + yshift; yhi = nyhisrc + yshift
         nxlonew = int (xlo); if (xlo > nxlonew) nxlonew += 1	# round up
         nxhinew = int (xhi); if (xhi < nxhinew) nxhinew -= 1	# round down
         nylonew = int (ylo); if (ylo > nylonew) nylonew += 1	# round up
         nyhinew = int (yhi); if (yhi < nyhinew) nyhinew -= 1	# round down
         if (firsttime) {
            nxlo = nxlonew; nxhi = nxhinew
            nylo = nylonew; nyhi = nyhinew
            xmin = nxhiref; ymin = nyhiref
#            xmin = nxhisrc; ymin = nyhisrc
            firsttime = no
         } else {
            nxlo = max (nxlo, nxlonew); nxhi = min (nxhi, nxhinew)
            nylo = max (nylo, nylonew); nyhi = min (nyhi, nyhinew)
         }
      }
   # Determine corners of minimum rectangle enclosing region
      nxlomat = int (xmin); if (xmin < nxlomat) nxlomat -= 1 # round down
      nxhimat = int (xmax); if (xmax > nxhimat) nxhimat += 1 # round up
      nylomat = int (ymin); if (ymin < nylomat) nylomat -= 1 # round down
      nyhimat = int (ymax); if (ymax > nyhimat) nyhimat += 1 # round up
      print (nxlomat,nxhimat,nylomat,nyhimat)
      xoffset = -nxlomat
      yoffset = -nylomat
      print("APPLIED_OFFSETS: ",xoffset,yoffset)

      nxlolap = nxlo; nxhilap = nxhi
      nylolap = nylo; nyhilap = nyhi
   # Compute conservative overlap region
   # Vignetting is possible downstream since IMSHIFT (and
   # other tasks) preserve the size of the input image.
   # correct for boundary extension "contamination"
      if (interp_shift == "poly3")
         { nxlolap += 1; nxhilap -= 1; nylolap += 1; nyhilap -= 1 }
      else if (interp_shift == "poly5" || interp_shift == "spline3")
         { nxlolap += 2; nxhilap -= 2; nylolap += 2; nyhilap -= 2 }

   # Calculate vignetted overlap vs. smallest image
      nxlovig = max (1, min (nxlolap, int(oxmin)))
      nxhivig = max (1, min (nxhilap, int(oxmin)))
      nylovig = max (1, min (nylolap, int(oymin)))
      nyhivig = max (1, min (nyhilap, int(oymin)))

      if (1 <= nxlovig && nxlovig <= nxhivig &&
          1 <= nylovig && nylovig <= nyhivig) {
         vigsec = "["//nxlovig//":"//nxhivig//","//nylovig//":"//nyhivig//"]"
      } else {
#         nxlovig = 0; nxhivig = 0; nylovig = 0; nyhivig = 0
         vigsec  = "[0:0,0:0]"
      }

      if (origin) {	# Recode info with null offset
         list1 = newinfo
         for (i = 0; fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,soffset) != EOF; i += 1) {
            nxmat0 += xoffset
            nymat0 += yoffset
            print (imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,xs,ys,soffset,>> tmp1)
         }
         delete (newinfo,ver-,>& "dev$null")
         rename (tmp1, newinfo)
         nxlomat += xoffset; nxhimat += xoffset
         nylomat += yoffset; nyhimat += yoffset
         nxlolap += xoffset; nxhilap += xoffset
         nylolap += yoffset; nyhilap += yoffset
         xoffset = 0
         yoffset = 0
      }

      if (1 <= nxlolap && nxlolap <= nxhilap &&
          1 <= nylolap && nylolap <= nyhilap) {
         lapsec = "["//nxlolap//":"//nxhilap//","//nylolap//":"//nyhilap//"]"
      } else {
         lapsec = "["//nxlolap//":"//nxhilap//","//nylolap//":"//nyhilap//"]"
         print ("#WARNING: overlap section: ",lapsec," is unphysical!")
      }

      encsub = "["//nxlomat//":"//nxhimat//","//nylomat//":"//nyhimat//"]"
   # Establishes origin at (0,0)
      ncolsout = nxhimat - nxlomat + 1
      nrowsout = nyhimat - nylomat + 1
      outsec  = "[1:"// ncolsout //",1:"// nrowsout //"]"
      print("ENCLOSED_REGION: ",encsub)
      print("ENCLOSED_SIZE: ",outsec)
      print("UNAPPLIED_OFFSETS: ",xoffset,yoffset)
      print("OVERLAP: ",lapsec," ",vigsec)

   # Fancy format
      sformat = '%-7s %'//-slenmax//
         's %3d %3d %3d %3d %4d %4d %5.2f %5.2f %9.3f\n'
      list1 = newinfo
      for (i = 0; fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,soffset) != EOF; i += 1) {
            printf(sformat,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,xs,ys,real(soffset))
      }
   err:

   # Finish up
      list1 = ""; list2 = ""
      delete (tmp1//","//matinfo,>& "dev$null")
      delete (newinfo//","//task,ver-,>& "dev$null")
   
   end
