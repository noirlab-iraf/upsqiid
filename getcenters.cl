# GETCENTERS 22JUL94 KMM 
# GETCENTERS -- Procedure to compute the shifts for each subraster.  
# GETCENTERS 15APR92 KMM 
#       06APR94 KMM replace "type" with "concatenate" or copy
#       22JUL94 KMM replace fscan with scan from pipe at key points

procedure getcenters(infofile,ctrfile)

string infofile   {prompt="Information file produced by SQMOS"}
string ctrfile    {prompt="Output file produced by CENTER"}
string outfile    {"", prompt="Output information filename"}
int    nx_sub     {INDEF,prompt="Number of input images along x direction"}
int    ny_sub     {INDEF,prompt="Number of input images along y direction"}

struct  *list1,*list2,*list3,*l_list

begin

      int    ncols,nrows,nxsub,nysub,nxrsub,nyrsub,nxoverlap,nyoverlap,
             nsubrasters,pos1b,pos1e,slen,slenmax,mos_xsize,mos_ysize,
             nx,ny,stat,i,j,paraxmax,paraymax,perpxmax,perpymax,
             xrowmin,xrowmax,yrowmin,yrowmax,
             xcolmin,xcolmax,ycolmin,ycolmax,
             nxhi,nxlo,nyhi,nylo,njunk,nstat,
             nxmos0, nymos0, nxhimos, nxlomos, nyhimos, nylomos
      int    nxsize,nysize,ilimit,olimit,nshifts,nx1,ny1,nx2,ny2,r21,r22
      int    nrshift[10,10]    	# number of row shifts
      int    ncshift[10,10]    	# number of column shifts
      real   x1, y1, x2, y2, xdif, xdifm, ydif, ydifm
      real   isign, jsign, xrmed, yrmed, xcmed, ycmed
      real   parax[10,10]	# x row shifts
      real   paray[10,10]    	# y row shifts
      real   perpx[10,10]    	# x column shifts
      real   perpy[10,10]    	# y column shifts
      real   rjunk,xshift,yshift,xlag,ylag,xmean,ymean,xsdev,ysdev
      string info,out,centers,mos_corner,mos_order,mos_section,mos_name,
             mos_oval,uniq,sname,sjunk,obj,ref
      file   dbinfo,mosinfo,ctrinfo,l_log,xdata,ydata
      struct line=""

      info        = infofile
      centers     = ctrfile
      dbinfo      = mktemp("tmp$gcn")
      mosinfo     = mktemp("tmp$gcn")
      ctrinfo     = mktemp("tmp$gcn")
      xdata       = mktemp("tmp$gcn")
      ydata       = mktemp("tmp$gcn")
      l_log       = mktemp("tmp$gcn")

   # Fetch info from IRMOSAIC database file
      l_list = l_log
   # Extract values from infofile
      match ("^\#DB",info,meta+,stop-,print-, > dbinfo)
      match ("^MOS",info,meta+,stop-,print-, > mosinfo)
      match ("trimsection",dbinfo,meta-,stop-,print-, >> l_log)
      if (fscan(l_list, sjunk, sjunk, mos_section) == EOF) {
         match ("section",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, mos_section)
      }
      match ("ncols",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, ncols)
      match ("nrows",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, nrows)
      if (nx_sub == INDEF) {
         match ("nxsub",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, nxsub)
         match ("nysub",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, nysub)
         match ("nsubrasters",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, nsubrasters)
      } else {
         nxsub = int(nx_sub)
         nysub = int(ny_sub)
         nsubrasters = nxsub * nysub
      }
      match ("nxoverlap",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, nxoverlap)
      match ("nyoverlap",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, nyoverlap)
      match ("corner",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, mos_corner)
      match ("order",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, mos_order)
      match ("oval",dbinfo,meta-,stop-,print-) |
         scan(sjunk, mos_oval)
      match ("mosaic",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, mos_name)

   # Format for rest of IRMOSAIC database
   # Note: format for IRMOSAIC database neither appends mos_section
   #   nor transfers section from @list to image id
#	orih064.imh	mosorihs.imh[1029:1284,1:256]	INDEF	

   # Expand default section
      if (mos_section == "[*,*]")
        mos_section = "[1:"//ncols//",1:"//nrows//"]"
      else {
#        print("WARNING: mos_section != [*,*]; CANNOT PROCESS further!")
        print("WARNING: mos_section ",mos_section," != [*,*]")
      }

   # establish ID of output info file
      if (outfile == "" || outfile == " " || outfile == "default") {
         pos1e = stridx(".",info)-1
         if (pos1e > 1)
            out = substr(info,1,pos1e)//".cinfo"
         else
            out = info//".cinfo"
      } else
         out = outfile
      if (out != "STDOUT" && access(out)) {
         print ("Output_file ",out, " already exists!")
         goto skip
      } else
         print ("#Output_file= ",out)

   # log parameters to database file
      concatenate (dbinfo//","//mosinfo,out,append+)
   # Get date and print date
      time() | scan(line)
      print("#DBC ",line," GETCENTERS:",>> out)
      print("#DBC    info_file       ",info ,>> out)
      print("#DBC    centers_file    ",centers ,>> out)
      print("#DBC    nx_sub          ",nxsub ,>> out)
      print("#DBC    ny_sub          ",nysub ,>> out)

   # Extract center information from CENTER output file
#      apselect(centers,"XCENTER,YCENTER,XERR,YERR,CIER,CERROR",expr="yes",
#         savepars-,format-,> ctrinfo)
      match ("^\#",centers,meta+,stop+,print-) | match ("null",meta-,stop+,
         print-,> ctrinfo)

      mos_xsize = ncols - nxoverlap
      mos_ysize = nrows - nyoverlap
      paraxmax = nxsub - 1
      paraymax = nysub
      perpxmax = nxsub
      perpymax = nysub - 1
   # Allocate temporary space.
      if (mos_order == "col") {
         ilimit = nysub
         olimit = nxsub
      } else {
         ilimit = nxsub
         olimit = nysub
      }

   # Clear the shift arrays.
      for (ny = 1; ny <= 10; ny += 1) {
         for (nx = 1; nx <= 10; nx += 1) {
            parax[nx,ny] = 0.0 
            paray[nx,ny] = 0.0 
            perpx[nx,ny] = 0.0 
            perpy[nx,ny] = 0.0 
            ncshift[nx,ny] = 0
            nrshift[nx,ny] = 0
         }
      }

# IR_DECODE_SHIFTS -- Procedure to accumulate shifts for each subraster.
   # Accumulate the shifts.
      nxsize = ncols - nxoverlap
      nysize = nrows - nyoverlap
      nshifts = 0
      list1 = ctrinfo
   # Get the first and second coordinate pairs.
      while ((fscan(list1,x1,y1) !=EOF) && (fscan(list1,x2,y2) !=EOF)) {
   # Compute which subraster 1 belongs to.
	 if (mod (int (x1), nxsize) == 0)
            nx1 = int (x1) / nxsize
         else
	    nx1 = int (x1) / nxsize + 1
	 if (mod (int (y1), nysize) == 0)
	    ny1 = int (y1) / nysize
	 else
	    ny1 = int (y1) / nysize + 1
   # Compute which subraster 2 belongs to.
	 if (mod (int (x2), nxsize) == 0)
	    nx2 = int (x2) / nxsize
	 else
	    nx2 = int (x2) / nxsize + 1
	 if (mod (int (y2), nysize) == 0)
	    ny2 = int (y2) / nysize
	 else
	    ny2 = int (y2) / nysize + 1

   # This is an illegal shift: the subrasters are the same or not adjacent.
	 r21 = nx1 ** 2 + ny1 ** 2
	 r22 = nx2 ** 2 + ny2 ** 2

         if (r21 == r22) {
   # Illegal shift
            print ("#Note: non-adjacent pair:",x1,y1,x2,y2)
            print ("#Note: non-adjacent pair:",x1,y1,x2,y2,>> out)
            next
         } else if (r21 < r22) {
   # Compute the shift for the first subraster.
            xdif = x2 - x1
#            if (nxoverlap < 0) {
#               if (xdif < 0.0)
#                  xdifm = xdif - nxoverlap
#               else if (xdif > 0.0)
#                  xdifm = xdif + nxoverlap
#            } else
	       xdifm = xdif
	    ydif = y2 - y1
#            if (nyoverlap < 0) {
#               if (ydif < 0.0)
#                  ydifm = ydif - nyoverlap
#            else if (ydif > 0.0)
#               ydifm = ydif + nyoverlap
#            } else
	       ydifm = ydif

            if (nx1 == nx2) {
	       perpx[nx1,ny1] = perpx[nx1,ny1] + xdif
	       perpy[nx1,ny1] = perpy[nx1,ny1] + ydifm
	       ncshift[nx1,ny1] = ncshift[nx1,ny1] + 1
	    } else if (ny1 == ny2) {
	       parax[nx1,ny1] = parax[nx1,ny1] + xdifm
	       paray[nx1,ny1] = paray[nx1,ny1] + ydif
	       nrshift[nx1,ny1] = nrshift[nx1,ny1] + 1
            } else
   # Illegal shift: this is where non-adjacent images would be handled
	       next
         } else {
   # Compute the shift for the second subraster.
            xdif = x1 - x2
#            if (nxoverlap < 0) {
#               if (xdif < 0.0)
#                 xdifm = xdif - nxoverlap
#            else if (xdif > 0.0)
#               xdifm = xdif + nxoverlap
#            } else
	       xdifm = xdif
            ydif = y1 - y2
#            if (nyoverlap < 0) {
#               if (ydif < 0.0)
#               ydifm = ydif - nyoverlap
#            else if (ydif > 0.0)
#               ydifm = ydif + nyoverlap
#            } else
	       ydifm = ydif

            if (nx1 == nx2) {
	       perpx[nx2,ny2] = perpx[nx2,ny2] + xdif
	       perpy[nx2,ny2] = perpy[nx2,ny2] + ydifm
	       ncshift[nx2,ny2] = ncshift[nx2,ny2] + 1
            } else if (ny1 == ny2) {
	       parax[nx2,ny2] = parax[nx2,ny2] + xdifm
	       paray[nx2,ny2] = paray[nx2,ny2] + ydif
	       nrshift[nx2,ny2] = nrshift[nx2,ny2] + 1
            } else
   # Illegal shift: this is where non-adjacent images would be handled
	       next
         }
         nshifts = nshifts + 1
      }

   # Compute the final shifts.
      for (j = 1; j <= nysub; j += 1) {
         for (i = 1; i <= nxsub; i += 1) {
            if (nrshift[i,j] > 0) {
               parax[i,j] = parax[i,j] / nrshift[i,j]
	       paray[i,j] = paray[i,j] / nrshift[i,j]
            }
	    if (ncshift[i,j] > 0) {
	       perpx[i,j] = perpx[i,j] / ncshift[i,j]
	       perpy[i,j] = perpy[i,j] / ncshift[i,j]
	    }
         }
      }
        
      for (ny = 1; ny <= paraymax; ny += 1) {
         nstat = 0
         for (nx = 1; nx <= paraxmax; nx += 1) {
            nxmos0 = (nx - 1)*mos_xsize
            nymos0 = (ny - 1)*mos_ysize
            nxlomos = nxmos0 + 1
            nylomos = nymos0 + 1
            nxhimos = nxmos0 + nrows
            nyhimos = nymos0 + ncols
            ref = mos_name//
               "["//nxlomos//":"//nxhimos//","//nylomos//":"//nyhimos//"]"
            obj = mos_name//
               "["//nxlomos+mos_xsize//":"//nxhimos+mos_xsize//","//
               nylomos//":"//nyhimos//"]"
            xshift = mos_xsize - parax[nx,ny]
            yshift = -paray[nx,ny]
            if (nrshift[nx,ny] > 0) {
               nstat += 1
               print(xshift, >> xdata) 
               print(yshift, >> ydata) 
            }
            xshift = 0.0001*real(nint(10000.*xshift))
            yshift = 0.0001*real(nint(10000.*yshift))
#            print("para ",(nx+1),ny,nx,ny,obj," ",ref," ",xshift,yshift,>> out)
            print("para ",nx,ny,nrshift[nx,ny],obj," ",ref," ",xshift,yshift,
               >> out)
            if (nx >= paraxmax) {
               if (nstat > 0) {
    # compute row shift statistics
                  average ("new_sample", < xdata) | scan (xmean, xsdev, njunk)
                  xmean = 0.001*real(nint(1000.*xmean))
                  average ("new_sample", < ydata) | scan (ymean, ysdev, njunk)
                  ymean = 0.001*real(nint(1000.*ymean))
                  if (njunk >= 2) {
                     xsdev = 0.001*real(nint(1000.*xsdev))
                     ysdev = 0.001*real(nint(1000.*ysdev))
                  } else {
                     xsdev = 0.0
                     ysdev = 0.0
                  }
                  print("#DBC row_ave para_laps  ",ny,njunk,xmean,ymean,
                     xsdev,ysdev,>> out)
                  delete(xdata,verify-,>& "dev$null")
                  delete(ydata,verify-,>& "dev$null")
               } else
                 print("#DBC row_ave para_laps  ",ny,"0 0.0 0.0 0.0 0.0",>> out)
            }
         }
      }
      for (ny = 1; ny <= perpymax; ny += 1) {
         nstat = 0
         for (nx = 1; nx <= perpxmax; nx += 1) {
            nxmos0 = (nx - 1)*mos_xsize
            nymos0 = (ny - 1)*mos_ysize
            nxlomos = nxmos0 + 1
            nylomos = nymos0 + 1
            nxhimos = nxmos0 + nrows
            nyhimos = nymos0 + ncols
            ref = mos_name//
               "["//nxlomos//":"//nxhimos//","//nylomos//":"//nyhimos//"]"
            obj = mos_name//
               "["//nxlomos//":"//nxhimos//","//
               nylomos+mos_ysize//":"//nyhimos+mos_ysize//"]"
            xshift = -perpx[nx,ny]
            yshift = mos_ysize - perpy[nx,ny]
            if (ncshift[nx,ny] > 0) {
               nstat += 1
               print(xshift, >> xdata) 
               print(yshift, >> ydata) 
            }
            xshift = 0.0001*real(nint(10000.*xshift))
            yshift = 0.0001*real(nint(10000.*yshift))
#            print("perp ",nx,(ny+1),nx,ny,obj," ",ref," ",xshift,yshift,>> out)
            print("perp ",nx,ny,ncshift[nx,ny],obj," ",ref," ",xshift,yshift,
               >> out)
            if (nx >= perpxmax) {
    # compute row shift statistics
               if (nstat > 0) {
                  average ("new_sample", < xdata) | scan (xmean, xsdev, njunk)
                  xmean = 0.001*real(nint(1000.*xmean))
                  average ("new_sample", < ydata) | scan (ymean, ysdev, njunk)
                  ymean = 0.001*real(nint(1000.*ymean))
                  if (njunk >= 2) {
                     xsdev = 0.001*real(nint(1000.*xsdev))
                     ysdev = 0.001*real(nint(1000.*ysdev))
                  } else {
                     xsdev = 0.0
                     ysdev = 0.0
                  }
                  print("#DBC row_ave perp_laps  ",ny,njunk,xmean,ymean,
                     xsdev,ysdev, >> out)
                  delete(xdata,verify-,>& "dev$null")
                  delete(ydata,verify-,>& "dev$null")
               } else
                 print("#DBC row_ave perp_laps  ",ny,"0 0.0 0.0 0.0 0.0",>> out)
            }
         }
      }

    # compute row and column statistics
      for (nx = 1; nx <= paraxmax; nx += 1) {
         nstat = 0
         for (ny = 1; ny <= paraymax; ny += 1) {
            if (nrshift[nx,ny] > 0) {
               nstat += 1
               print(parax[nx,ny], >> xdata) 
               print(paray[nx,ny], >> ydata) 
            }
         }
         if (nstat > 0) {
            average ("new_sample", < xdata) | scan (xmean, xsdev, njunk)
            xmean = 0.001*real(nint(1000.*xmean))
            average ("new_sample", < ydata) | scan (ymean, ysdev, njunk)
            ymean = 0.001*real(nint(1000.*ymean))
            if (njunk >= 2) {
               xsdev = 0.001*real(nint(1000.*xsdev))
               ysdev = 0.001*real(nint(1000.*ysdev))
             } else {
               xsdev = 0.0
               ysdev = 0.0
            }
            print("#DBC col_ave para_laps  ",nx,njunk,xmean,ymean,
               xsdev,ysdev,>> out)
            delete(xdata,verify-,>& "dev$null")
            delete(ydata,verify-,>& "dev$null")
         } else
            print("#DBC col_ave para_laps  ",nx,"0 0.0 0.0 0.0 0.0", >> out)
      }
      for (nx = 1; nx <= perpxmax; nx += 1) {
         nstat = 0
         for (ny = 1; ny <= perpymax; ny += 1) {
            if (ncshift[nx,ny] > 0) {
               nstat += 1
               print(perpx[nx,ny], >> xdata) 
               print(perpy[nx,ny], >> ydata) 
            }
         }
         if (nstat > 0) {
            average ("new_sample", < xdata) | scan (xmean, xsdev, njunk)
            xmean = 0.001*real(nint(1000.*xmean))
            average ("new_sample", < ydata) | scan (ymean, ysdev, njunk)
            ymean = 0.001*real(nint(1000.*ymean))
            if (njunk >= 2) {
               xsdev = 0.001*real(nint(1000.*xsdev))
               ysdev = 0.001*real(nint(1000.*ysdev))
            } else {
               xsdev = 0.0
               ysdev = 0.0
            }
            print("#DBC col_ave perp_laps  ",nx,njunk,xmean,ymean,
               xsdev,ysdev,>> out)
            delete(xdata,verify-,>& "dev$null")
            delete(ydata,verify-,>& "dev$null")
         } else
            print("#DBC col_ave perp_laps  ",nx,"0 0.0 0.0 0.0 0.0", >> out)
      }
        
   # Finish up
      skip:
      delete (dbinfo//","//mosinfo//","//ctrinfo,verify-,>& "dev$null")
      delete (l_log//","//xdata//","//ydata,verify-,>& "dev$null")

   end
