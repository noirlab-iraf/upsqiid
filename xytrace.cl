# XYTRACE 08AUG94 KMM
## XYTRACE determines origins for mosaic frames for arbitary paths
# XYTRACE 15APR92 KMM
#         06APR94 KMM replace "type" with "concatenate" or "copy"
#         22JUL94 KMM replace fcan with scan from pipe at key points
#         25JUL94 KMM add explicit fancy output format control via awk
#         08AUG94 KMM utilize printf for formatted output (instead of AWK)

procedure xytrace (infofile,linkfile)

#   string match_name   {prompt="name of resultant composite image"}
   file   infofile     {prompt="file produced by GETCENTERS"}
   string linkfile     {prompt="File with selected XY linkage paths"}

   int    nx_sub      {INDEF,prompt="Number of input images along x direction"}
   int    ny_sub      {INDEF,prompt="Number of input images along y direction"}
   int    nxrsub      {INDEF,prompt="index of x reference subraster"}
   int    nyrsub      {INDEF,prompt="index of y reference subraster"}
   string trimlimits  {"[0:0,0:0]",prompt="trim limits on the input subrasters"}
   bool   guess       {no,prompt="Guess missing links from average values?"}
   bool	  verbose     {no,prompt="verbose output?"}
   bool	  passmisc    {yes,prompt="pass thru misc output from GETLAPS?"}
   file   outfile     {"", prompt="Output information file name"}
   struct  *list1,*list2,*list3

   begin

      int    stat,ncols,nrows,nxsub,nysub,nxoverlap,nyoverlap,nsubrasters,
             frnim,tonim,pos1e,nxlotrim,nxhitrim,nylotrim,nyhitrim,ref_nim,
             nxhi,nxlo,nyhi,nylo,nxhisrc,nxlosrc,nyhisrc,nylosrc,
             nx,ny,mos_xsize,mos_ysize,mos_xrsub,mos_yrsub,nnfr,nnto,
             nxmat0, nymat0, nxmos0, nymos0, nxhimos, nxlomos, nyhimos, nylomos,
             gridx,gridy,paraxmax,perpxmax,paraymax,perpymax,
             ixs,iys,slen,slenmax,nim,nrshift[10,10],ncshift[10,10]
      real   mos_offset,mat_offset,net_offset,rjunk,xshift,yshift,
             rc_x0,rc_y0,cr_x0,cr_y0,xmean,ymean,xsdev,ysdev,
             fxs, fys, xs, ys, xoff, yoff,
             perpx[10,10],perpy[10,10],parax[10,10],paray[10,10]
      string out,match,in_name,uniq,imname,slist,sjunk,soffset,smoffset,
             mos_name,mos_section,mos_corner,mos_order,mos_oval,ref_id,
             src,srcsub,mos,mossub,mat,matsub,ref,refsub,obj,objsub,
             sformat, rcpath, crpath, sense,snim
      file   info,dbinfo,gridinfo,mosinfo,actinfo,aveinfo,paths,miscinfo,
             tmp1,tmp2,tmp3,task,links
      bool   badlink1, badlink2, first
      struct line=""

      info        = infofile
      links       = linkfile
      uniq        = mktemp ("_Txyt")
      dbinfo      = uniq // ".dbi"
      actinfo     = uniq // ".act"
      aveinfo     = uniq // ".ave"
      mosinfo     = uniq // ".mos"
      miscinfo    = uniq // ".msc"
      gridinfo    = uniq // ".grd"
      tmp1        = uniq // ".tm1"
      tmp2        = uniq // ".tm2"
      tmp3        = uniq // ".tm3"
      paths       = uniq // ".pth"
      task        = uniq // ".tsk"

      if (!access(info)) {
         print ("Information file ",info," not found!")
         goto skip
      }
      if (!access(links)) {
         print ("Pathways file ",links," not found!")
         goto skip
      }
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
         print-, > miscinfo)
      match ("^\#",miscinfo,meta+,stop+,print-, > actinfo)
      match ("^\#DBC row_ave",info,meta+,stop-,print-, > aveinfo)
      match ("^\#DBC col_ave",info,meta+,stop-,print-, >> aveinfo)
      match ("trimsection",dbinfo,meta-,stop-,print-) |
         scan(sjunk, sjunk, mos_section)
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
      list1 = ""; delete (tmp1, ver-, >& "dev$null")
      print("#DBL ",line," XYTRACE:",>> dbinfo)
      print("#DBL    info_file       ",info,>> dbinfo)
      print("#DBL    link_file       ",links,>> dbinfo)
      print("#DBL    nxrsub          ", mos_xrsub, >> dbinfo)
      print("#DBL    nyrsub          ", mos_yrsub, >> dbinfo)
      print("#DBL    ref_image       ",ref_id,>> dbinfo)
      print("#DBL    ref_nim         ",ref_nim,>> dbinfo)

# Fetch adjacent frame offsets from database file
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
      list3 = actinfo
      while (fscan(list3,sense,nxlo,nylo,nim,
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
      list1 = ""; delete (tmp1, ver-, >& "dev$null")
      list2 = ""; delete (tmp2, ver-, >& "dev$null")
      tokens(links,ignore+,begin="#",end="eol",newlines+,> tmp1)
      if (verbose) type (links)
      list1 = tmp1
      frnim = 0; tonim = 0
      while (fscan(list1,snim) != EOF) {
         if (nscan() == 0) {	# signal end of path and restart
            print(frnim,frnim,>> tmp2)
            frnim = 0
            next
         } else if (frnim == 0 ) {
            frnim = int(snim)
         } else if (tonim == 0) {
            tonim = int(snim)
            print (frnim,tonim,>> tmp2)
            frnim = tonim
            tonim = 0
         }
      }
      list1 = ""; delete (tmp1, ver-, >& "dev$null")
      first = yes
      list2 = tmp2
      rc_x0 = 0; rc_y0 = 0
      while (fscan(list2,frnim,tonim) != EOF) {
         list1 = paths
         while (fscan (list1,nx,nxlo,nylo) != EOF) {
            if (nx == frnim)
               break
         }
         list1 = paths
         while (fscan (list1,nx,nxhi,nyhi) != EOF) {
            if (nx == tonim)
               break
         }
         if (first) {
            gridx = nxlo
            gridy = nylo
            rcpath = "grid["//gridx//","//gridy//"] rcpath:"
            nim = frnim
            first = no 
         }
         if (frnim == tonim) {	# end of path
            rc_x0 += nxmat0
            rc_y0 += nymat0
            xs = 0.01*real(nint(100.0*rc_x0))
            ys = 0.01*real(nint(100.0*rc_y0))
            rcpath = rcpath//" |= "//xs//" "//ys
            print (rcpath,>> gridinfo)
            if (verbose) print ("rc tot ",gridx,gridy,rc_x0,rc_y0,>> tmp3)
            print ("rcpath ",gridx, gridy, rc_x0, rc_y0)
            if (verbose) {
               print ("rcpath ",gridx, gridy, rc_x0, rc_y0,>> tmp3)
            }
            nxmos0 = (gridx - 1)*mos_xsize
            nymos0 = (gridy - 1)*mos_ysize
            nxlomos = nxmos0 + 1
            nylomos = nymos0 + 1
            nxhimos = nxmos0 + ncols
            nyhimos = nymos0 + nrows
            srcsub = "["//nxlomos//":"//nxhimos//","//nylomos//":"//nyhimos//"]"
            src = mos_name//srcsub
            ixs = nint(xs)
            iys = nint(ys)  
            fxs = xs - ixs
            fys = ys - iys
            fxs = 0.01*real(nint(100.*fxs))
            fys = 0.01*real(nint(100.*fys))
            imname = "000" + int(nim)
            print ("MAT_"//imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
               ixs,iys,fxs,fys," INDEF",>> tmp1)
    # find largest source field
            slen = strlen(src)
            if (slen > slenmax) slenmax = slen
    # reset for next path
            first = yes
            rc_x0 = 0
            rc_y0 = 0
            next
         }
         nx = min(nxlo,nxhi)
         ny = min(nylo,nyhi)
         nnfr = (nxlo - mos_xrsub) ** 2 + (nylo - mos_yrsub) ** 2
         nnto = (nxhi - mos_xrsub) ** 2 + (nyhi - mos_yrsub) ** 2
         if (nxlo == nxhi) {		# movement along column
#            if (abs(nylo - mos_yrsub) >= abs(nyhi - mos_yrsub)) {
            if (nnfr >= nnto) {
#               if (nylo >= mos_yrsub) {
               if (ny >= mos_yrsub) {
                  rc_x0 += perpx[nx,ny]
                  rc_y0 += perpy[nx,ny]
               } else {
                  rc_x0 -= perpx[nx,ny]
                  rc_y0 -= perpy[nx,ny]
               }
            } else {	# movement away from center
#               if (nylo >= mos_yrsub) {
               if (ny >= mos_yrsub) {
                  rc_x0 -= perpx[nx,ny]
                  rc_y0 -= perpy[nx,ny]
               } else {
                  rc_x0 += perpx[nx,ny]
                  rc_y0 += perpy[nx,ny]
               }
            }
            rcpath = rcpath//" | c "//nx//","//ny
            if (verbose) print("rc col ",nxlo,nylo,nxhi,nyhi,
               perpx[nx,ny],perpy[nx,ny],>> tmp3)
         } else if (nylo == nyhi) {	# movement along row
#            if (abs(nxlo - mos_xrsub) >= abs(nxhi - mos_xrsub)) {
            if (nnfr >= nnto) {
#               if (nxlo >= mos_xrsub) {
               if (nx >= mos_xrsub) {
                  rc_x0 += parax[nx,ny]
                  rc_y0 += paray[nx,ny]
               } else {
                  rc_x0 -= parax[nx,ny]
                  rc_y0 -= paray[nx,ny]
               }
            } else {	# movement away from center
#               if (nxlo >= mos_xrsub) {
               if (nx >= mos_xrsub) {
                  rc_x0 -= parax[nx,ny]
                  rc_y0 -= paray[nx,ny]
               } else {
                  rc_x0 += parax[nx,ny]
                  rc_y0 += paray[nx,ny]
               }
            }
            rcpath = rcpath//" | r "//nx//","//ny
            if (verbose) print("rc row ",nxlo,nylo,nxhi,nyhi,
               parax[nx,ny],paray[nx,ny],>> tmp3)
         } else	{			# illegal move (non-adjacent gridpoints)
            print ("ILLEGAL MOVE: nonadjacent gridpoints!",frnim,tonim)
         }
      } 
      list2 = ""; delete (tmp2, ver-, >& "dev$null")

      concatenate (dbinfo//","//mosinfo,out,append+)
   # fancy formatter 
   # sort MAT into path order
      sort (tmp1,col=1,ignore+,num-,rev-,> tmp2)
   # Fancy format
      sformat = '%-7s %'//-slenmax//
         's %3d %3d %3d %3d %4d %4d %5.2f %5.2f %9.3f\n'
      list1 = "";list1 = tmp2
      for (i = 0; fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,soffset) != EOF; i += 1) {
         printf(sformat,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,real(soffset),>> out)
      }
      concatenate (gridinfo,out,append+)
      if (passmisc) concatenate (miscinfo,out,append+)
      if (verbose) concatenate (links//","//tmp3,out,append+)

   skip :

   # Finish up
      list1 = ""; list2 = ""; list3 = ""
      delete (uniq//"*", verify=no)

   end
