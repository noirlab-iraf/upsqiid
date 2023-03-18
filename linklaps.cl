# LINKLAPS: 08AUG94 KMM
# LINKLAPS: 31JAN92 10APR92
# LINKLAPS: - determines origins for mosaic frames using output of GETLAPS
#           22JUL94 KMM replace fscan with scan from pipe at key points
#           28JUL94 KMM replace type with concatenate
#           08AUG94 KMM utilize printf for formatted output

procedure linklaps (infofile)

   string infofile    {prompt="Information file produced by XYGET|GETLAPS"}

   int    nx_sub      {INDEF,prompt="Number of input images along x direction"}
   int    ny_sub      {INDEF,prompt="Number of input images along y direction"}
   int    nxrsub      {INDEF,prompt="index of x reference subraster"}
   int    nyrsub      {INDEF,prompt="index of y reference subraster"}
   string trimlimits  {"[0:0,0:0]",prompt="trim limits on the input subrasters"}
   bool   guess       {no,prompt="Guess missing links from average values?"}
   bool	  verbose     {no,prompt="verbose output?"}
   bool	  passmisc    {yes,prompt="pass thru misc output from GETLAPS?"}
   file   outfile     {"", prompt="Output information file name"}
   struct  *list1,*list2

   begin

      int    stat,ncols,nrows,nxsub,nysub,nxoverlap,nyoverlap,nsubrasters,
             pos1b,pos1e,nxlotrim,nxhitrim,nylotrim,nyhitrim,ref_nim,
             nxhi,nxlo,nyhi,nylo,nxhisrc,nxlosrc,nyhisrc,nylosrc,
             nx,ny,mos_xsize,mos_ysize,mos_xrsub,mos_yrsub,
             para_xlag,para_ylag,perp_xlag,perp_ylag,
             nxmat0, nymat0, nxmos0, nymos0, nxhimos, nxlomos, nyhimos, nylomos,
             nxhiref,nxloref,nyhiref,nyloref,nxhiobj,nxloobj,nyhiobj,nyloobj,
             gridx,gridy,paraxmax,perpxmax,paraymax,perpymax,
             ixs,iys,slen,slenmax,nim,nrshift[10,10],ncshift[10,10]
      real   mos_offset,mat_offset,net_offset,rjunk,xshift,yshift,
             rc_x0,rc_y0,cr_x0,cr_y0,xmean,ymean,xsdev,ysdev,
             fxs, fys, xs, ys, xoff, yoff,
             perpx[10,10],perpy[10,10],parax[10,10],paray[10,10]
      string out,match,in_name,uniq,imname,slist,sjunk,soffset,smoffset,
             mos_name,mos_section,mos_corner,mos_order,mos_oval,ref_id,
             topedge,bottomedge,leftedge,rightedge,
             src,srcsub,mos,mossub,mat,matsub,ref,refsub,obj,objsub,
             sformat, rcpath, crpath, sense
      file   info,dbinfo,gridinfo,mosinfo,actinfo,aveinfo,paths,
             tmp1,tmp2,tmp3,task
      bool   badlink1, badlink2
      struct line=""

      info        = infofile
      uniq        = mktemp ("_Tllp")
      dbinfo      = uniq // ".dbi"
      actinfo     = uniq // ".act"
      aveinfo     = uniq // ".ave"
      mosinfo     = uniq // ".mos"
      gridinfo    = uniq // ".grd"
      tmp1        = uniq // ".tm1"
      tmp2        = uniq // ".tm2"
      tmp3        = uniq // ".tm3"
      paths       = uniq // ".pth"
      task        = uniq // ".tsk"

# establish ID of output info file
      if (outfile == "" || outfile == " " || outfile == "default") {
         pos1e = stridx(".",info)-1
         if (pos1e > 1)
            out = substr(info,1,pos1e)//".laps"
         else
            out = info//".laps"
      } else
         out = outfile
      if (out != "STDOUT" && access(out)) {
         print ("Output_file ",out, " already exists!")
         goto skip
      } else
         print ("Output_file= ",out)

      slenmax = 0
# Extract values from infofile
      match ("^\#DB",info,meta+,stop-,print-, > dbinfo)
      match ("^MOS",info,meta+,stop-,print-, > mosinfo)
      match ("^\#DB",info,meta+,stop+,print-) | match ("^M",meta+,stop+,
         print-, > actinfo)
      match ("^\#DBC row_ave",info,meta+,stop-,print-, > aveinfo)
      match ("^\#DBC col_ave",info,meta+,stop-,print-, >> aveinfo)
      match ("trimsection",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, mos_section)
      match ("ncols",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, ncols)
      match ("nrows",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, nrows)
      if (nx_sub == INDEF) {
         match ("nxsub",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, nxsub)
         match ("nysub",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, nysub)
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
      match ("mosaic",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, mos_name)

# Expand default section
      if (mos_section == "[*,*]")
        mos_section = "[1:"//ncols//",1:"//nrows//"]"
      else {
        print("WARNING: mos_section != [*,*]; CAN NOT PROCESS further!")
        goto skip
      }

# Note: format for IRMOSAIC database neither appends mos_section
#   nor transfers section from @list to image id
#	orih064.imh	mosorihs.imh[1029:1284,1:256]	INDEF	

      print (mos_section) | translit ("", "[:,]", "    ") |
         scan(nxlosrc,nxhisrc,nylosrc,nyhisrc)
      print (trimlimits) | translit ("", "[:,]", "    ") |
         scan(nxlotrim,nxhitrim,nylotrim,nyhitrim)
# Put in global trims if any
      nxlosrc = nxlosrc + nxlotrim
      nxhisrc = nxhisrc - nxhitrim
      nylosrc = nylosrc + nylotrim
      nyhisrc = nyhisrc - nyhitrim
      mos_xsize = ncols - nxoverlap
      mos_ysize = nrows - nyoverlap
      if (nxrsub == INDEF)
         mos_xrsub = int((nxsub+1)/2)
      else
         mos_xrsub = nxrsub
      if (nyrsub == INDEF)
         mos_yrsub = int((nysub+1)/2)
      else
         mos_yrsub = nyrsub
      paraxmax = nxsub - 1
      paraymax = nysub
      perpxmax = nxsub
      perpymax = nysub - 1

# Get reference subraster ref_nim and ref_id
      mkpathtbl(1,nsubrasters,nxsub,nysub,mos_order,mos_corner,sort-,format-,
         >> paths)
      list1 = paths
      while (fscan (list1,ref_nim,gridx,gridy) != EOF) {
         if ((gridx == nxrsub) && (gridy == nyrsub))
            break
      }
      nxmos0  = (gridx - 1) * mos_xsize
      nymos0  = (gridy - 1) * mos_ysize
      nxlomos = nxmos0 + 1; nxhimos = nxmos0 + ncols
      nylomos = nymos0 + 1; nyhimos = nymos0 + nrows
      ref_id  = mos_name//"["//nxlomos//":"//nxhimos//","//nylomos//
         ":"//nyhimos //"]"

# log parameters to database file
# Get date and print date
      time() | scan(line)
      print("#DBL ",line," LINKLAPS:",>> dbinfo)
      print("#DBL    info_file       ",info,>> dbinfo)
      print("#DBL    nxrsub          ", mos_xrsub, >> dbinfo)
      print("#DBL    nyrsub          ", mos_yrsub, >> dbinfo)
      print("#DBL    ref_image       ",ref_id,>> dbinfo)
      print("#DBL    ref_nim         ",ref_nim,>> dbinfo)

# Fetch adjacent frame offsets from database file
# OLD#    print("para ", nxhi,nyhi,nxlo,nylo,objsub," ",refsub,
#    print("para ",nxlo,nylo,ndata,objsub," ",refsub,
#       " ",xshift,yshift,>> info)

      for (ny = 1; ny <= 10; ny += 1) {
         for (nx = 1; nx <= 10; nx += 1) {
            parax[nx,ny] = 0.0 
            paray[nx,ny] = 0.0
            perpx[nx,ny] = 0.0
            perpy[nx,ny] = 0.0
            nrshift[nx,ny] = 0
            ncshift[nx,ny] = 0
         }
      }
      list1 = ""; list2 = actinfo
#      while (fscan(list2,sense,nxhi,nyhi,nxlo,nylo,
      while (fscan(list2,sense,nxlo,nylo,nim,
         objsub,refsub,xshift,yshift) != EOF) {
         if (sense == "para") {
            parax[nxlo,nylo] = xshift 
            paray[nxlo,nylo] = yshift 
            nrshift[nxlo,nylo] = nim
            if (nim == 0) {
               match ("^\#DBC row_ave para_laps",info,meta+,stop-,print-,> tmp1)
               list1 = tmp1
               while (fscan(list1,sjunk,sjunk,sjunk,ny,nim,
                  xshift,yshift) != EOF) {
                  if (ny == nylo) {
                     parax[nxlo,nylo] = xshift 
                     paray[nxlo,nylo] = yshift 
                     print("#DBL Note: no data for link | r "//nxlo//","//ny//
                        " |",>> dbinfo)
                     print("#DBL Note: using row_ave para_laps ",ny,
                        " for link"//" | r "//nxlo//","//ny//" |",>> dbinfo)
                     break
                  }  
               }
               list1 = ""; delete (tmp1, ver-, >& "dev$null")
            }
         } else {
            perpx[nxlo,nylo] = xshift 
            perpy[nxlo,nylo] = yshift 
            ncshift[nxlo,nylo] = nim
            if (nim == 0) {
               match ("^\#DBC row_ave perp_laps",info,meta+,stop-,print-,> tmp1)
               list1 = tmp1
               while (fscan(list1,sjunk,sjunk,sjunk,ny,nim,
                  xshift,yshift) != EOF) {
                  if (ny == nylo) {
                     perpx[nxlo,nylo] = xshift 
                     perpy[nxlo,nylo] = yshift 
                     print("#DBL Note: no data for link | c "//nxlo//"," //ny//
                        " |",>> dbinfo)
                     print("#DBL Note: using row_ave perp_laps ",ny,
                        " for link"//" | c "//nxlo//","//ny//" |",>> dbinfo)
                     break
                  }  
               }
               list1 = ""; delete (tmp1, ver-, >& "dev$null")
            }
         }
      }
   # compute origin for reference subraster
      nxmat0 = (mos_xrsub - 1)*mos_xsize
      nymat0 = (mos_yrsub - 1)*mos_ysize
   # compute origin rest of grid relative to reference grid
      if (verbose) print ("Ref    ",mos_xrsub,mos_yrsub,nxmat0,nymat0,>> tmp3)
      if (guess) {
         print ("#DBL Note: average values replace null links",>> dbinfo)
         print ("#DBL Note: average values replace null links")
      } else {
         print ("#DBL Note: null links not used in pairs",>> dbinfo)
         print ("#DBL Note: null links not used in pairs")
      }
   # setup for correct output for ll corner and row order; reorder later
      for (gridy = 1; gridy <= nysub; gridy += 1) {
         for (gridx = nxsub; gridx >= 1; gridx -= 1) {
            badlink1 = no
            badlink2 = no
            if (gridx > mos_xrsub) {
               nxlo = mos_xrsub
               nxhi = gridx-1
            } else {
               nxlo = gridx
               nxhi = mos_xrsub-1
            }
            if (gridy > mos_yrsub) {
               nylo = mos_yrsub
               nyhi = gridy-1
            } else {
               nylo = gridy
               nyhi = mos_yrsub-1
            }
            if (verbose) print("#      ",gridx,gridy," : ",nxlo,nxhi,nylo,nyhi,
               >> tmp3)
   # compute along row to ref then along column
            if (gridx != mos_xrsub) {
               rc_x0 = nxmat0
               rc_y0 = nymat0
               rcpath = "grid["//gridx//","//gridy//"] rcpath:"
               for (nx = nxlo; nx <= nxhi; nx += 1) {
                  if (nx >= mos_xrsub) {
                     rc_x0 += parax[nx,mos_yrsub]
                     rc_y0 += paray[nx,mos_yrsub]
                  } else {
                     rc_x0 -= parax[nx,mos_yrsub]
                     rc_y0 -= paray[nx,mos_yrsub]
                  }
                  rcpath = rcpath//" | r "//nx//","//mos_yrsub
                  if (verbose) print("rc row ",gridx,gridy,nx,mos_yrsub,
                     parax[nx,mos_yrsub],paray[nx,mos_yrsub],>> tmp3)
                  if (nrshift[nx,mos_yrsub] == 0) { # indicate null link
                     badlink1 = yes
                     rcpath = rcpath//" <null"
                  }
               }
               for (ny = nylo; ny <= nyhi; ny += 1) {
                  if (ny >= mos_yrsub) {
                     rc_x0 += perpx[gridx,ny]
                     rc_y0 += perpy[gridx,ny]
                  } else {
                     rc_x0 -= perpx[gridx,ny]
                     rc_y0 -= perpy[gridx,ny]
                  }
                  rcpath = rcpath//" | c "//gridx//","//ny
                  if (verbose) print("rc col ",gridx,gridy,gridx,ny,
                     perpx[gridx,ny],perpy[gridx,ny],>> tmp3)
                  if (ncshift[gridx,ny] == 0) { # indicate null link
                     badlink1 = yes
                     rcpath = rcpath//" <null"
                  }
               }
               if (verbose) print ("rc tot ",gridx,gridy,rc_x0,rc_y0,>> tmp3)
            }
   # compute along col to ref then along row
            if (gridy != mos_yrsub) {
               cr_x0 = nxmat0
               cr_y0 = nymat0
               crpath = "grid["//gridx//","//gridy//"] crpath:"
               for (ny = nylo; ny <= nyhi; ny += 1) {
                  if (ny >= mos_yrsub) {
                     cr_x0 += perpx[mos_xrsub,ny]
                     cr_y0 += perpy[mos_xrsub,ny]
                  } else {
                     cr_x0 -= perpx[mos_xrsub,ny]
                     cr_y0 -= perpy[mos_xrsub,ny]
                  }
                  crpath = crpath//" | c "//mos_xrsub//","//ny
                  if (verbose) print("cr col ",gridx,gridy,mos_xrsub,ny,
                     perpx[mos_xrsub,ny],perpy[mos_xrsub,ny],>> tmp3)
                  if (ncshift[mos_xrsub,ny] == 0) { # indicate null link
                     badlink2 = yes
                     crpath = crpath//" <null"
                  }
               }
               for (nx = nxlo; nx <= nxhi; nx += 1) {
                  if (nx >= mos_xrsub) {
                     cr_x0 += parax[nx,gridy]
                     cr_y0 += paray[nx,gridy]
                  } else {
                     cr_x0 -= parax[nx,gridy]
                     cr_y0 -= paray[nx,gridy]
                  }
                  crpath = crpath//" | r "//nx//","//gridy
                  if (verbose) print("cr row ",gridx,gridy,nx,gridy,
                     parax[nx,gridy],paray[nx,gridy],>> tmp3)
                  if (nrshift[nx,gridy] == 0) { # indicate null link
                     badlink2 = yes
                     crpath = crpath//" <null"
                  }
               }
               if (verbose) print ("cr tot ",gridx,gridy,cr_x0,cr_y0,>> tmp3)
            }
            if ((gridy != mos_yrsub) && (gridx != mos_xrsub)) {
               if (! badlink1 && ! badlink2) {
                  xmean = (rc_x0+cr_x0)/2.0
                  ymean = (rc_y0+cr_y0)/2.0
                  xsdev = abs(rc_x0-cr_x0)/2.0
                  ysdev = abs(rc_y0-cr_y0)/2.0
               } else if (guess) {
                  xmean = (rc_x0+cr_x0)/2.0
                  ymean = (rc_y0+cr_y0)/2.0
                  xsdev = abs(rc_x0-cr_x0)/2.0
                  ysdev = abs(rc_y0-cr_y0)/2.0
               } else if (! badlink1 && badlink2) {
                  xmean = rc_x0
                  ymean = rc_y0
                  xsdev = 0.0
                  ysdev = 0.0
               } else if (badlink1 && ! badlink2) {
                  xmean = cr_x0
                  ymean = cr_y0
                  xsdev = 0.0
                  ysdev = 0.0
               } else {
                  xmean = (rc_x0+cr_x0)/2.0
                  ymean = (rc_y0+cr_y0)/2.0
                  xsdev = abs(rc_x0-cr_x0)/2.0
                  ysdev = abs(rc_y0-cr_y0)/2.0
               }
               xs = 0.01*real(nint(100.0*rc_x0))
               ys = 0.01*real(nint(100.0*rc_y0))
               rcpath = rcpath//" |= "//xs//" "//ys
               xs = 0.01*real(nint(100.0*cr_x0))
               ys = 0.01*real(nint(100.0*cr_y0))
               crpath = crpath//" |= "//xs//" "//ys
               print (rcpath,>> gridinfo)
               print (crpath,>> gridinfo)
               xs = 0.01*real(nint(100.0*xmean))
               ys = 0.01*real(nint(100.0*ymean))
               fxs = 0.01*real(nint(100.0*xsdev))
               fys = 0.01*real(nint(100.0*ysdev))
               crpath = "grid["//gridx//","//gridy//"] mean= "
               print(crpath,xs,ys," dev= ",fxs,fys,>> gridinfo)
               if (verbose) {
                  print ("rcpath ",gridx, gridy, rc_x0, rc_y0,>> tmp3)
                  print ("crpath ",gridx, gridy, cr_x0, cr_y0,>> tmp3)
                  print ("mean   ",gridx, gridy, xmean, ymean,>> tmp3)
                  print ("sdev   ",gridx, gridy, xsdev, ysdev,>> tmp3)
               }
            } else if ((gridy != mos_yrsub) && (gridx == mos_xrsub)) {
               xmean = cr_x0
               ymean = cr_y0
               xsdev = 0.0
               ysdev = 0.0
               xs = 0.01*real(nint(100.0*xmean))
               ys = 0.01*real(nint(100.0*ymean))
               fxs = xsdev
               fys = ysdev
               crpath = crpath//" |= "//xs//" "//ys
               print (crpath,>> gridinfo)
               crpath = "grid["//gridx//","//gridy//"] mean= "
               print(crpath,xs,ys," dev= ",fxs,fys,>> gridinfo)
               if (verbose) {
                  print ("crpath ",gridx, gridy, cr_x0, cr_y0,>> tmp3)
                  print ("mean   ",gridx, gridy, xmean, ymean,>> tmp3)
                  print ("sdev   ",gridx, gridy, xsdev, ysdev,>> tmp3)
               }
            } else if ((gridy == mos_yrsub) && (gridx != mos_xrsub)) {
               xmean = rc_x0
               ymean = rc_y0
               xsdev = 0.0
               ysdev = 0.0
               xs = 0.01*real(nint(100.0*xmean))
               ys = 0.01*real(nint(100.0*ymean))
               fxs = xsdev
               fys = ysdev
               rcpath = rcpath//" |= "//xs//" "//ys
               print (rcpath,>> gridinfo)
               crpath = "grid["//gridx//","//gridy//"] mean= "
               print(crpath,xs,ys," dev= ",fxs,fys,>> gridinfo)
               if (verbose) {
                  print ("rcpath ",gridx, gridy, rc_x0, rc_y0,>> tmp3)
                  print ("mean   ",gridx, gridy, xmean, ymean,>> tmp3)
                  print ("sdev   ",gridx, gridy, xsdev, ysdev,>> tmp3)
               }
            } else if ((gridy == mos_yrsub) && (gridx == mos_xrsub)) {
               xs = nxmat0
               ys = nymat0
               xmean = xs
               ymean = ys
               xsdev = 0.0
               ysdev = 0.0
               fxs = xsdev
               fys = ysdev
               crpath = "grid["//gridx//","//gridy//"] mean= "
               print(crpath,xs,ys," dev= ",fxs,fys,>> gridinfo)
            }
            nxmos0 = (gridx - 1)*mos_xsize
            nymos0 = (gridy - 1)*mos_ysize
            nxlomos = nxmos0 + 1
            nylomos = nymos0 + 1
            nxhimos = nxmos0 + ncols
            nyhimos = nymos0 + nrows
            srcsub = "["//nxlomos//":"//nxhimos//","//
               nylomos//":"//nyhimos//"]"
            src = mos_name//srcsub
            ixs = nint(xmean)
            iys = nint(ymean)  
            fxs = xmean - ixs
            fys = ymean - iys
            fxs = 0.01*real(nint(100.*fxs))
            fys = 0.01*real(nint(100.*fys))
    # Find path position corresponding to grid position
            list1 = paths
            while (fscan(list1,imname,nx,ny) != EOF) {
               if (gridx == nx && gridy == ny) break
            }
            imname = "000" + int(imname)
            print ("MAT_"//imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
               ixs,iys,fxs,fys," 0.0",>> tmp1)
    # find largest source field
            slen = strlen(src)
            if (slen > slenmax) slenmax = slen
         }
      }

      concatenate(dbinfo//","//mosinfo,out,append+)
   # fancy formatter 
   # sort MAT into path order
      sort (tmp1,col=1,ignore+,num-,rev-,> tmp2)
   # Fancy format
      sformat = '%-7s %'//-slenmax//
         's %3d %3d %3d %3d %4d %4d %5.2f %5.2f %9.3f\n'
      list1 = tmp2   
      for (i = 0; fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,soffset) != EOF; i += 1) {
         printf(sformat,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,real(soffset),>> out)
      }
      concatenate(gridinfo,out,append+)
      if (passmisc) concatenate (actinfo,out,append+)
      if (verbose) concatenate (tmp3,out,append+)

   skip :

   # Finish up
      list1 = ""; list2 = ""
      delete (uniq//"*", verify=no)

   end
