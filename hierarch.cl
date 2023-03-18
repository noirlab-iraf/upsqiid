## HIERARCH 03JUL00 KMM
## HIERARCH merge sets of IMCOMBINED IR composite images with common reference image
## HIERARCH based on MERGECOM 24APR96 KMM
##          1) Given a set of composite images which share objects in common, run XYGET
##             on the composites to produce a master XYCOM file with relative positions of
##             the composite images.
##          2) Produce file the name of the composite image according to the XYCOM file and the
##             name of the associated XYCOM file for the composite, one per line:
##             xycom_file_that produced composit | composite_name 
                  
procedure hierarch (compdb, compinfo, mergedfile)

string compdb       {prompt="hierarch file: xycom_file | composite_name"}
string compinfo     {prompt="master file produced by XYGET on composites"}
string mergedfile   {prompt="name of resultant composite image"} 
bool   subset       {no,prompt="Keep only COM_000 and mos_name COM's?"}
string mos_name     {" ",prompt="mosaic name for saved COM's"}

bool   renumber     {no, prompt="renumber secondary referenced frames?"}
bool   verify       {no, prompt="Verify alias before proceeding?"}

bool   compute_size {yes, 
                       prompt="Do you want to [re]compute image size?",mode="q"}
bool   answer       {yes, prompt="Do you want to continue?", mode="q"}

struct  *list1, *list2, *list3

begin

   int    i,stat,nim,maxnim,slen,slenmax,refnim,njunk,
          nxhiref, nxloref, nyhiref, nyloref, nxhi, nxlo, nyhi, nylo,
          nxhisrc,nxlosrc,nyhisrc,nylosrc, nxlolap,nxhilap,nylolap,nyhilap,
          nxlonew,nxhinew,nylonew,nyhinew, nxhimat,nxlomat,nyhimat,nylomat,
          nxmat0, nymat0, nxref, nyref, nxref0, nyref0,
          nxlink, nylink, nxlink0, nylink0,
          minxoffset,minyoffset, ncolsout,nrowsout
   real   zoff, zref, zref0, zlink, zlink0, xs, ys,x1,x2,y1,y2,
          xoffset, yoffset, xofftran, yofftran,
          xmat0, ymat0, xref, yref, xref0, yref0,
          xlink, ylink, xlink0, ylink0, xshift, yshift, zadj,
           xmax, xmin, ymax, ymin, oxmax,oxmin,oymax,oymin,
          xlo, xhi, ylo, yhi
   bool   firstfile, firsttime, getlink, found, max_tran, do_tran,
          new_origin, is_link, is_linkabs
   string uniq,imname,sname,refname,refmaster,slist,sjunk,soffset,encsub,
          src,srcsub,mos,mossub,mat,matsub,ref,refsub,stasub,lapsec,outsec,
          vigsec,outfile,master,reflink,prior_com,interp_shift,lap_basis,
          ref1,ref2,priordb,combinfo,infodb,refcom,refimname,infocomp
   file   info,out,dbinfo,dbout,tmp1,tmp2,comblist,matinfo,newinfo,
          cominfo,mastercom,compcom 
   struct line1 = ""
   struct line2 = ""

   infodb      = compdb
   infocomp    = compinfo
   outfile     = mergedfile
   uniq        = mktemp ("_Tmcb")
   dbout       = mktemp("tmp$mcb")
   dbinfo      = mktemp("tmp$mcb")
   matinfo     = mktemp("tmp$mcb")
   newinfo     = mktemp("tmp$mcb")
   cominfo     = mktemp("tmp$mcb")
   compcom     = mktemp("tmp$mcb")   
   mastercom   = mktemp("tmp$mcb")
   comblist    = mktemp("tmp$mcb")
   tmp1        = mktemp("tmp$mcb")
   tmp2        = mktemp("tmp$mcb")

   files (infodb,sort-,>> comblist)
   list1 = comblist
   for (i = 0; fscan(list1,sname) != EOF; i += 1) {
      print (sname) | translit ("", "|", " ") | scan (refcom,refimname)
      if (! access(refcom)) { 	 # Exit if can't find info
         print ("Cannot access info_file: ",refcom)
         goto err
      }
      print (refcom," ",refimname,>> tmp1)
      if (i == 0) master = refcom
   }
   delete (tmp1,ver-,>& "dev$null")
  
   if (! access(infocomp)) {
      print ("Cannot access composite XYCOM file: ",infocomp)
      goto err
   }
   
# establish ID of output info file
   if (outfile == "" || outfile == " " || outfile == "default")
      out = master//"0"
   else
      out = outfile
   if (out != "STDOUT" && access(out)) {
      print("Will append to output_file ",out,"!")
      if (!answer) goto err
   } else
      print ("Output_file= ",out)

   time() | scan(line1)
   list1 = ""
   print("#DBM ",line1," MERGECOM: ",out)
# Log parameters 
   print("#DBM ",line1," MERGECOM: ",out,>> out)

# Extract COM lines from master composite database
   match ("^COM",compinfo,meta+,stop-,print-,> compcom)
# Work through list of files
   firstfile = yes
   firsttime  = yes
# Set initial values
   slenmax = 0
   nxref0 = 0; nyref0 = 0; zref0 = 0; njunk=0
   xmin =  10000.;  xmax = -10000.
   ymin =  10000.;  ymax = -10000.
   oxmin = 10000.; oymin = 10000.
   xref0  = 0.; yref0  = 0.; zref0  = 0.
   xlink0 = 0.; ylink0 = 0.; zlink0 = 0.
   xlink  = 0.; ylink  = 0.; zlink  = 0.
# Work through file list
   list1 = comblist
   while (fscan(list1, line1) != EOF) {
      print (line1) | translit ("", "|", " ") | scan (refcom, refimname)
      print("#DBM    merge_link      ",line1)
      print("#DBM    merge_link      ",line1,>> out)

##DEBUG: print (refcom," ",refimname)

      priordb = refcom
      sname = refcom
      match ("^\#DB",sname,meta+,stop-,print-) |
         match ("^\#DBI",meta+,stop+,print-, > dbinfo)
      match ("^COM",sname,meta+,stop-,print-,   > matinfo)
      
##DEBUG: head(matinfo)

## Extract values from infofile
#      match ("ref_image",dbinfo,meta+,stop-,print-) |
#            scan(sjunk, sjunk, refname)
      if (firstfile) {
         do_tran = no; max_tran = no
         refmaster = refimname
         print("#DBM    master_file     ",master)
         print("#DBM    master_file     ",master,>> out)
         print("#DBM    master_ref      ",refmaster)
         print("#DBM    master_ref      ",refmaster,>> out)
         copy (matinfo, mastercom, ver-)
# Extract values from infofile
         match ("do_tran",dbinfo,meta+,stop-,print-) |
            scan(sjunk, sjunk, do_tran)
         print ("Do_tran = ",do_tran)
         lap_basis = "none"
         match ("lap_basis",dbinfo,meta+,stop-,print-) |
            scan(sjunk, sjunk, lap_basis)
         print ("Lap_basis = ",lap_basis)
         if (do_tran) {
            match ("max_tran",dbinfo,meta+,stop-,print-) |
                  scan(sjunk, sjunk, max_tran)
            match ("^\#DBG",sname,meta+,stop-,print-, > tmp1)
            match ("xoffsettran",tmp1,meta-,stop-,print-) |
                  scan(sjunk, sjunk, xofftran)
            match ("yoffsettran",tmp1,meta-,stop-,print-) |
                  scan(sjunk, sjunk, yofftran)
            if (!max_tran) {
               xofftran = 0
               yofftran = 0
               }
            } else {
               xofftran = 0
               yofftran = 0
            }
            delete (tmp1, ver-, >& "dev$null")
# this is tacky!
            match ("^\#DBI",sname,meta+,stop-,print-, > tmp1) # Use IRCOMBINE
            count(tmp1) | scan(njunk)
            if (njunk < 4) {			# use MERGECOM if no IRCOMBINE
               print ("Insufficient #DBI; searching for #DB[LM]")
               delete (tmp1, ver-, >& "dev$null")
               match ("^\#DB[LM]",sname,meta+,stop-,print-, > tmp1)
               count(tmp1) | scan(njunk)
               if (njunk < 4) {		# use GETCOMBINE if no MERGE
                  delete (tmp1, ver-, >& "dev$null")
                  print ("Insufficient #DB[LM]; searching for #DB[LG]")
                  match ("^\#DB[LG]",sname,meta+,stop-,print-, > tmp1)
               }
            }
            match ("out_sec",tmp1,meta-,stop-,print-) |
               scan(sjunk, sjunk, outsec)
            interp_shift = "linear"
            match ("interp_shift",tmp1,meta-,stop-,print-) |
               scan(sjunk, sjunk, interp_shift)
            match ("^\#DB[^M]",dbinfo,meta+,stop-,print-) |
               match ("do_tran",meta+,stop+,print-, > dbout)
            delete (tmp1,ver-,>& "dev$null")
         }
         print("#DBM    merge_file      ",sname)
         print("#DBM    merge_file      ",sname,>> out)
	 
##DEBUG: print(refmaster," ",refimname)
	 	 
         if (refmaster == refimname) {	# Find position of REFERENCE
            getlink = no
            reflink = "null"
            match (refimname,compcom,meta-,stop-,print-,> tmp1)
            count(tmp1) | scan(njunk)
            if (njunk < 1) {
               print ("Reference image: ",refimname, " not found!") 
               goto err
            } 	    	    
            list2 = tmp1
            found = no
# print ("COM_"//pathpos," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
#    nxmat0,nymat0,xs,ys,soffset)
            while (fscan(list2,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,xs,ys,zoff) != EOF) {
	           print (src) | translit ("", "[:]", "   ") | scan (sjunk)	       
	           if (sjunk == refimname) {
                  xref = nxmat0 + xs; yref = nymat0 + ys
                  zref  = zoff
                  found = yes
	           }
##DEBUG: print(sjunk," ",refimname," ",found)
	        }
            if (firstfile) {
               xref0 = xref; yref0 = yref; zref0  = zref
               print (src) | translit ("", "[:,]", "    ") |
                  scan(ref,nxloref,nxhiref,nyloref,nyhiref)
            }   
         } else {			# Find position of LINK
            getlink = yes
            print ("Reference image: ",refimname, " != MASTER: ",refmaster) 
            reflink = refimname
            if (verify) {
               if (!answer)		# Will alias within master frame be OK?
                  goto err		# Exit if don't want to search for link
            }
# Find position of LINK within master list
            print ("Searching for link to: ",refimname," in master list: ",
	            compinfo)
            delete (tmp1,ver-,>& "dev$null")
            match (reflink,compcom,meta-,stop-,print-, > tmp1)
            count(tmp1) | scan(njunk)
            if (njunk < 1) {
               print ("Reference image: ",refimname, " not found!") 
               goto err
            }
            found = no	    
            list2 = tmp1
            while (fscan(list2,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,xs,ys,zoff) != EOF) {
	           print (src) | translit ("", "[:]", "   ") | scan (sjunk)
	           if (sjunk == reflink) {
                  xlink0 = nxmat0 + xs; ylink0 = nymat0 + ys
                  zlink0  = zoff
                  found = yes
	           }
            }
	    
## Find position of LINK within merge list
#            delete (tmp1,ver-,>& "dev$null")
#            match (reflink,matinfo,meta-,stop-,print-, > tmp1)
#            found = no
#            list2 = tmp1
#            while (fscan(list2,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
#               nxmat0,nymat0,xs,ys,zoff) != EOF) {
#	       print (src) | translit ("", "[:]", "   ") | scan (sjunk)
#	       if (sjunk == reflink) {
#                  xlink = nxmat0 + xs; ylink = nymat0 + ys
#                  zlink  = zoff
#                  found = yes
#	       }
#            }

         }
##DEBUG: print("REF0:  ",xref0,yref0,zref0)
##DEBUG: print("LINK0: ",xlink0,ylink0,zlink0)
##DEBUG: print("LINK   ",xlink,ylink,zlink)	 
      found = no
      list2 = matinfo
      while (fscan(list2,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
         nxmat0,nymat0,xs,ys,zoff) != EOF) {
         if (! firstfile) {
            print("#",imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
              nxmat0,nymat0,xs,ys,zoff,>> newinfo) # Comment prior
            xmat0 = nxmat0 + xs; ymat0 = nymat0 + ys
#            if (getlink) {
#               xshift = xlink - xlink0
#               yshift = ylink - ylink0
#               zadj   = zlink - zlink0
#            } else {
#               xshift = xref - xref0
#               yshift = yref - yref0
#               zadj   = zref - zref0
#            }	    
            if (getlink) {
               xshift = xlink0 - xref0
               yshift = ylink0 - yref0
               zadj   = zlink0 - zref0
            } else {
               xshift = xref0
               yshift = yref0
               zadj   = zref0
            }
##DEBUG: print ("SHIFT: ",xshift,yshift,zadj)	    
            xmat0 = xmat0 + xshift
            ymat0 = ymat0 + yshift
# Note: check zoff sign logic	    
            zoff   = zoff - zadj
            nxmat0 = nint(xmat0); nymat0 = nint(ymat0)  
            xs = xmat0 - nxmat0; ys = ymat0 - nymat0
            xs = 0.01*real(nint(100.0*xs))
            ys = 0.01*real(nint(100.0*ys))	    
            if ((imname != "COM_000")&&(src != refmaster)&&(src != reflink)) {
               if (renumber) imname = prior_com + 1	# Re-number
               print(imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
                  nxmat0,nymat0,xs,ys,zoff,>> newinfo)
# Update master COM
               print(imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
                  nxmat0,nymat0,xs,ys,zoff,>> mastercom)
               print(imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
                  nxmat0,nymat0,xs,ys,zoff)
               prior_com = imname	       
            }
         } else {
            print(imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,xs,ys,zoff,>> newinfo)
            print(imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,xs,ys,zoff)
            prior_com = imname
         }
         slen = strlen(src); if (slen > slenmax) slenmax = slen
      }
      firstfile = no
      delete (tmp1//","//dbinfo//","//matinfo,ver-,>& "dev$null")
   } 
   if (lap_basis != "adopt" ) {
      if (compute_size || outsec == "")
# Determine corners of minimum rectangle enclosing region
         new_origin = yes
      else
         new_origin = no
   } else
      new_origin = no

   xofftran = 0
   yofftran = 0

   if (subset) {
      print ("Saving COM_000 and ",mos_name," COM lines...")
      delete (tmp1,ver-,>& "dev$null")
      match ("^COM_000",newinfo,meta+,stop-,print-, > tmp1)
      match ("^COM",newinfo,meta+,stop-,print-) |
         match (mos_name,meta+,stop-,print-, >> tmp1)
      delete (newinfo,ver-,>& "dev$null")
      rename (tmp1,newinfo)
      delete (tmp1,ver-,>& "dev$null")
   }

   if (new_origin) print ("Will [re]optimize origin.")

# Compute minimum rectangle enclosing region and overlap region
   closure (newinfo,xofftran,yofftran,trimlimits="[0:0,0:0]",
      interp_shift=interp_shift,origin=new_origin,verbose+,format+,> tmp2)
   match ("^COM",tmp2,meta+,stop-,print-, > cominfo)
   match ("^ENCLOSED_SIZE",tmp2,meta+,stop-,print-) | scan(sjunk,encsub)
   print (encsub) | translit ("", "[:,]", "    ") |
      scan(nxlomat,nxhimat,nylomat,nyhimat)
   match ("^UNAPPLIED_OFFSET",tmp2,meta+,stop-,print-) |
      scan(sjunk,xoffset,yoffset)
   match ("^OVERLAP",tmp2,meta+,stop-,print-) |
      scan(sjunk,lapsec,vigsec)
   print (lapsec) | translit ("", "[:,]", "    ") |
      scan(nxlolap,nxhilap,nylolap,nyhilap)
   if (lapsec == "[0:0,0:0]") lapsec = ""

   if (new_origin) {
# Establishes origin at (0,0)
      ncolsout = nxhimat - nxlomat + 1
      nrowsout = nyhimat - nylomat + 1
# Override minimum rectangle
      outsec  = "[1:"// ncolsout //",1:"// nrowsout //"]"
   } else {	# null out unapplied offsets since we don't want to apply them
      xoffset = 0
      yoffset = 0
   }

   print("#DBM    do_tran         ",do_tran,>> dbout)
   print("#DBM    out_sec         ",outsec,>> dbout)
   print("#DBM    overlap_sec     ",lapsec,>> dbout)
   concatenate (dbout//","//cominfo,out,append+)

   err:

# Finish up
   list1 = ""; list2 = ""
   delete (mastercom//","//comblist//","//tmp1//","//tmp2,ver-,>& "dev$null")
   delete (cominfo//","//dbinfo//","//matinfo,ver-,>& "dev$null")
   delete (newinfo//","//dbout//","//compcom,ver-,>& "dev$null")
   delete (uniq//"*",ver-,>& "dev$null")
   
end
