# OVERLAP: 07JUL00 KMM expects IRAF 2.11Export or later
# OVERLAP: - check overlapped regions based on ZGET 14OCT98 KMM
# OVERLAP: 04MAR00 KMM
# OVERLAP: 07JUL00 KMM minor tweaks

procedure overlap (match_name,infofile,image_nums)

string match_name   {prompt="name of resultant composite image"}
file   infofile     {prompt="file produced by GETCOMBINE"}
string image_nums   {prompt="Selected image numbers|ref_id"}

file   outfile      {"", prompt="Output information file name"}
real   gxshift      {0.0, prompt="global xshift for final image"}
real   gyshift      {0.0, prompt="global yshift for final image"}
string goverlap     {"", prompt="Global overlap section (overrides all else)"}
string gsize        {"", prompt="Global image size (overrides all else)"}
# trim values applied to final image
string trimlimits   {"[0:0,0:0]",
                      prompt="added trim limits for input subrasters"}
bool   setpix       {no,prompt="Run SETPIX on data?"}
string maskimage    {"badmask", prompt="bad pixel image mask"}
bool   fixpix       {no,prompt="Run FIXPIX on data?"}
string fixfile      {"badpix", prompt="badpix file in FIXPIX format"}
string common       {"median",enum="none|adopt|mean|median|mode",
              prompt="Pre-combine common offset: |none|adopt|mean|median|mode|"}
string stat_sec     {"overlap",
                       prompt="Image section for calculating statistics"}
real   lowerlim     {INDEF,prompt="Lower limit for exclusion in IMSTATS"}
real   upperlim     {INDEF,prompt="Upper limit for exclusion in IMSTATS"}
real   to_scale     {0.0,
                   prompt="Scale to value (0 = noscale) via to_name"}
string to_name      {"INT_S", prompt="Image header to_name keyword"}
string interp_shift {"linear",enum="nearest|linear|poly3|poly5|spline3",
              prompt="IMSHIFT interpolant (nearest,linear,poly3,poly5,spline3)"}
string bound_shift  {"nearest",enum="constant|nearest|reflect|wrap",
                      prompt="IMSHIFT boundary (constant,nearest,reflect,wrap)"}
real   const_shift  {0.0,prompt="IMSHIFT Constant for boundary extension"}
real   svalue       {-1.0e8, prompt="Setpix value (<< floor)"}
real   floor        {-200., prompt="Rejection floor for imcombine"}
real   ceiling      {40000., prompt="Rejection ceiling for imcombine"}
real   ovalue       {-1000., prompt="Rejected pixel value for new image?"}
bool   size         {no, prompt="Compute image size?"}
bool   answer       {yes, prompt="Do you want to continue?", mode="q"}
bool   compute_size {yes, 
                       prompt="Do you want to [re]compute image size?",mode="q"}
bool   save_images  {no,prompt="Save images which were IMCOMBINED?"}
bool   verbose      {yes, prompt="Verbose output?"}

struct  *list1, *list2, *list3

begin

      int    i,stat,nim,maxnim,slen,slenmax,njunk,pos1b,pos1e,mincom,maxcom,
             nxoff0,nyoff0,minxoffset,minyoffset,c_opt,ref_nim,root_nim,
             ncols, nrows, nxhiref, nxloref, nyhiref, nyloref,
             nxhi, nxlo, nyhi, nylo, nxhisrc, nxlosrc, nyhisrc, nylosrc,
             nxlotrim,nxhitrim,nylotrim,nyhitrim,
             nxlolap,nxhilap,nylolap,nyhilap,
             nxhimat,nxlomat,nyhimat,nylomat,
             nxlonew,nxhinew,nylonew,nyhinew,
             nxmat0, nymat0, nxmos0, nymos0, ixs, iys, ncolsout,nrowsout
      real   zoff, rjunk, xin, yin, xmat, ymat, fxs, fys,
             xs, ys, xoff, yoff, g_xshift, g_yshift, xmax, xmin, ymax, ymin,
             xofftran,yofftran,gtxmax, gtxmin, gtymax, gtymin,
             oxmax,oxmin,oymax,oymin,xoffset,yoffset,
             xlo, xhi, ylo, yhi, xshift, yshift, reject_value
      real   roff, delta, rmedian, rmode, avestat, avemean, avemode, avemedian,
             refstat, rmean, stddev_mean,stddev_median,stddev_mode
      bool   firsttime, do_tran, tran, max_tran, prior_tran, fluxtran,
             new_origin, found, scale_it
      string uniq,tmpname,matchname,slist,sjunk,soffset,encsub,statsec,
             src,srcsub,mos,mossub,mat,matsub,ref,refsub,stasub,lapsec,outsec,
             vigsec,sformat,traninfo,sxrot,syrot,sxmag,symag,sxshift,syshift,
             dbtran,cotran,consttran,geomtran,interptran,boundtran,imagenums,
             refname,image_nims,ref_id,ref_name,dbpath,img,vcheck,lapsize
      file   info,out,dbinfo,tmp1,tmp2,im1,im2,statlist,statfile,comblist,
             tmpimg,zinfo,doinfo,matinfo,newinfo,task,misc,
             actinfo,nimlist,procfile,imlist
      int    nex
      string gimextn, imextn, imname, imroot
      real   from_scale, mult_by
        
      struct line = ""

      matchname   = match_name
      info        = infofile
      imagenums   = image_nums
      g_xshift    = gxshift
      g_yshift    = gyshift
      
# get IRAF global image extension
      show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
      nex     = strlen(gimextn)
      
      uniq        = mktemp ("_Tzgt")
      task        = uniq // ".tsk"
      newinfo     = uniq // ".mat"
      dbinfo      = mktemp("tmp$zgt")
      matinfo     = mktemp("tmp$zgt")
      actinfo     = mktemp("tmp$zgt")
      comblist    = mktemp("tmp$zgt")
      statlist    = mktemp("tmp$zgt")
      statfile    = mktemp("tmp$zgt")
      nimlist     = mktemp("tmp$zgt")
      procfile    = mktemp("tmp$zgt")
      imlist      = mktemp("tmp$zgt")
      zinfo       = mktemp("tmp$zgt")
      doinfo      = mktemp("tmp$zgt")
      tmp1        = mktemp("tmp$zgt")
      tmp2        = mktemp("tmp$zgt")
      misc        = mktemp("tmp$zgt")
      im1         = uniq // "_im1"
      im2         = uniq // "_im2"
      tmpimg      = uniq // "_tim"

      if (to_scale != 0)
         scale_it = yes
      else
         scale_it = no
	 
    # setup nim process file
      if (stridx("@",imagenums) == 1) {			# @-list
         imagenums = substr(imagenums,2,strlen(imagenums))
         if (! access(imagenums)) { 		# Exit if can't find info
            print ("Cannot access image_nums file: ",imagenums)
            goto err
         } else
            copy (imagenums,procfile,verbose-)
      } else {
         print(imagenums,> procfile)
         statsec = stat_sec
      }
      print("#Process info: ",>> misc); concatenate(procfile,misc,append+)
      if (verbose) {
         print("#Process list: "); type(procfile)
      }

   # strip off trailing imextn
      img = matchname
      if (substr(img,strlen(img)-nex,strlen(img)) == "."//gimextn ) { 
         matchname = substr(img,1,strlen(img)-nex-1)
      }
      if (! access(info)) { 		# Exit if can't find info
         print ("Cannot access info_file: ",info)
         goto err
      }
   # establish ID of output info file
      if (outfile == "" || outfile == " " || outfile == "default")
         out = matchname//".ocom"
      else
         out = outfile
      if (out != "STDOUT" && access(out)) {
         print("Will overwrite output_file ",out,"!")
         if (!answer) goto err
      } else
         print ("Output_file= ",out)

      if (imaccess(matchname)) {
            print("Image ",matchname," already exists!")
	    if (!answer) goto err
      }

      c_opt = 0                         # Establish common offset statistic
      if (common == "none")   c_opt = 0
      if (common == "adopt")  c_opt = 1
      if (common == "mean")   c_opt = 2
      if (common == "median") c_opt = 3
      if (common == "mode")   c_opt = 4
      print("#NOTE: Statistics for data within ", lowerlim, " to ", upperlim)

      print (trimlimits) | translit ("", "[:,]", "    ") |
         scan(nxlotrim,nxhitrim,nylotrim,nyhitrim)

   # Transfer appropriate information from reference to output file
      match ("^\#DB",info,meta+,stop-,print-) |
         match ("out_sec",meta-,stop+,print-,> dbinfo)		# omit out_sec
   # count number of images, excluding reference images
      match ("^COM",info,meta+,stop-,print-) |
         match ("^COM_000",meta+,stop+,print-,> matinfo)
      count(matinfo) | scan(maxcom)	# here maxcom = total number in COMfile
   # test for uniqueness of COM lines
      fields (matinfo,1,lines="",quit-,print-) | sort ("",col=0,num-,rev-) |
         unique (>> tmp1) 
      count(tmp1) | scan(i)
      if (i < maxcom) {
         i = maxcom - i
         print ("Warning: ",i," COM lines are not unique!")
         goto err 
      }
      head (tmp1,nl=1) | scan(sjunk)
      pos1b = stridx("_",sjunk) + 1
      mincom = int(substr(sjunk,pos1b,strlen(sjunk))) # mincom = smallest COM
      tail (tmp1,nl=1) | scan(sjunk)
      pos1b = stridx("_",sjunk) + 1
      maxcom = int(substr(sjunk,pos1b,strlen(sjunk))) # maxcom = largest COM
      delete (tmp1, ver-, >& "dev$null")

   # make list of frames actually required       

      mkframelist ("@"//procfile,comid+,max_nim=maxcom,>> nimlist)
      count(nimlist) | scan (maxnim)	# maxnim = total number requested
      if (verbose) print ("#Note: will use ",maxnim," images.")
      
   # Size of output image
   # fetch info from reference file
#      outsec = "[1:"//ncols//",1:"//nrows//"]"
      outsec = ""
      delete (tmp1, ver-, >& "dev$null")
      match ("out_sec",info,meta-,stop-,print-) |		# MIG order
         sort (col=1,ignore+,numeric-,reverse+, > tmp1)
      list1 = tmp1
      if (fscan(list1, sjunk, sjunk, outsec) != 3) {
          outsec = ""
#         outsec = "[1:256,1:256]"; ncolsout = 256; nrowsout = 256
      } else { 
         print (outsec) | translit ("", "[:,]", "    ") |
            scan(nxlosrc,nxhisrc,nylosrc,nyhisrc)
         ncolsout = nxhisrc - nxlosrc + 1
         nrowsout = nyhisrc - nylosrc + 1
      }
      list1 = ""; delete (tmp1, ver-, >& "dev$null")
      print ("#NOTE: prior_outsec: ",outsec)

      time() | scan(line)
      list1 = ""; delete (tmp1, ver-, >& "dev$null")
   # Log parameters 
      print("#DBZ ",line," ZGET:",>> dbinfo)
      print("#DBZ    info_file       ",info,>> dbinfo)
      print("#DBZ    global_xshift   ",g_xshift ,>> dbinfo)
      print("#DBZ    global_yshift   ",g_yshift ,>> dbinfo)
      print("#DBZ    global_overlap  ",goverlap,>> dbinfo)
      print("#DBZ    global_size     ",gsize,>> dbinfo)
      print("#DBZ    more_trimlimits ",trimlimits,>> dbinfo)

      if (outsec == "" || size) {
         if (compute_size || outsec == "")
   # Determine corners of minimum rectangle enclosing region
            new_origin = yes
         else
            new_origin = no
      } else
         new_origin = no
      if (new_origin) print ("Will optimize origin.")

   # Put in global shifts
   # Compute minimum rectangle enclosing region and overlap region
      closure (matinfo,g_xshift,g_yshift,trimlimits=trimlimits,
         interp_shift=interp_shift,origin=new_origin,
         verbose+,>> tmp1)
      match ("^ENCLOSED_SIZE",tmp1,meta+,stop-,print-) | scan(sjunk,encsub)
      print (encsub) | translit ("", "[:,]", "    ") |
         scan(nxlomat,nxhimat,nylomat,nyhimat)
      match ("^UNAPPLIED_OFFSET",tmp1,meta+,stop-,print-) |
         scan(sjunk,xoffset,yoffset)
      match ("^OVERLAP",tmp1,meta+,stop-,print-) | scan(sjunk,lapsec,vigsec)
      print (lapsec) | translit ("", "[:,]", "    ") |
         scan(nxlolap,nxhilap,nylolap,nyhilap)
      if (lapsec == "[0:0,0:0]") lapsec = ""

      if (new_origin) {
   # Establishes origin at (0,0)
         ncolsout = nxhimat - nxlomat + 1
         nrowsout = nyhimat - nylomat + 1
   # Override minimum rectangle
         outsec  = "[1:"// ncolsout //",1:"// nrowsout //"]"
      } else {	# null unapplied offsets since we don't want to apply them
         xoffset = 0
         yoffset = 0
      }

      if (gsize != "") {			# Report image composite size
         print ("#NOTE: computed composite image size: ", outsec)
         print ("#NOTE: adopted composite image size: ", gsize)
         print ("#NOTE: computed composite image size: ", outsec,>> dbinfo)
         outsec = gsize
         print ("#NOTE: adopted composite image size: ", outsec,>> dbinfo)
      } else {
         print ("#NOTE: computed composite image size: ", outsec)
      }

      if (goverlap != "") {
         print ("#NOTE: computed composite overlap region: ", lapsec)
         print ("#NOTE: adopted composite overlap region: ", goverlap)
         print ("#NOTE: computed composite overlap region: ", lapsec,>> dbinfo)
         lapsec = goverlap
         print ("#NOTE: adopted composite overlap region: ", lapsec,>> dbinfo)
      } else {
         print ("#NOTE: computed composite overlap region: ", lapsec)
         if (lapsec == "" && c_opt > 1) { 
            print ("Null overlap: can't compute statistics")
            goto err
         }
      }
      print("#DBZ    overlap_sec     ",lapsec,>> dbinfo)
      print("#DBZ    out_sec         ",outsec,>> dbinfo)
        
      delete (tmp1, ver-, >& "dev$null")

   # Loop through frames, imshift and setup for imstatistics
      slenmax = 0
      list1 = nimlist
      for (i = 1; fscan(list1,sjunk) != EOF; i += 1) {
         match ("^"//sjunk,matinfo,meta+,stop-,print-) |
            scan(imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,fxs,fys,soffset)
         if (nscan() == 0) {		# skip if image not requested
            print ("Image path info missing for ", sjunk)
            goto err
         }
         pos1b = stridx("_",imname)+1
         nim = int(substr(imname,pos1b,strlen(imname)))
         tmpname = uniq//substr(imname,stridx("_",imname),strlen(imname))
         print (tmpname//"."//gimextn, >> comblist)

         if (soffset == "INDEF") soffset = "0.0"
         zoff = real (soffset)
         slenmax = max(slenmax,strlen(src))
         srcsub = "["//nxlosrc//":"//nxhisrc//","//nylosrc//":"//nyhisrc//"]"
         nxlomat = nxmat0 + nxlosrc ; nxhimat = nxmat0 + nxhisrc
         nylomat = nymat0 + nylosrc ; nyhimat = nymat0 + nyhisrc

   # Redetermine the source and destination sections
         nxlomat += xoffset; nxhimat += xoffset
         nylomat += yoffset; nyhimat += yoffset
         matsub = "["//nxlomat//":"//nxhimat//","//nylomat//":"//nyhimat//"]"
   # Test for out-of-range and fix as needed
         if ((nxlomat < 1) || (nylomat < 1) || (nxhimat > ncolsout) ||
            (nyhimat > nrowsout)) {
            print ("#NOTE: ",src," destination ",matsub," out of range!")
            print ("#NOTE: ",src," destination ",matsub," out of range!",
               >> dbinfo)
            nxlosrc += max(0, (1 - nxlomat)); nxlomat = max(1,nxlomat)
            nylosrc += max(0, (1 - nylomat)); nylomat = max(1,nylomat)
            nxhisrc -= max(0, (nxhimat - ncolsout))
            nxhimat = min(ncolsout,nxhimat)
            nyhisrc -= max(0, (nyhimat - nrowsout))
            nyhimat = min(nrowsout,nyhimat)
         }
         matsub = "["//nxlomat//":"//nxhimat//","//nylomat//":"//nyhimat//"]"
         srcsub = "["//nxlosrc//":"//nxhisrc//","//nylosrc//":"//nyhisrc//"]"
         print (tmpname," ",srcsub," ",matsub,>> doinfo)
         if (verbose) {
            print (tmpname," ",srcsub," ",zoff," ",matsub)
         }
# output mapping info
         print ("#MAP: ",imname," ",src," ",srcsub," ",matsub,>> misc)
      }
      list1 = ""; list2 = ""; delete (nimlist, ver-, >& "dev$null")

# IMAGES are now made so we can begin

   # work through the list
      list3 = procfile
      firsttime = yes
      while (fscan(list3,line) != EOF) {
   # Expand the range of images, splitting off ref_id
         print ("Processing images: ",line)
         print("#DBZ    image_nims      ",line,>> misc)
         print (line) | translit("", "|", " ") | scan(image_nims,ref_id,statsec)
         if (nscan() < 1) {
            print("Note: blank line encountered")
            break
         } else if (nscan() < 2) {
            print("Warning: no reference id found!")
            statsec = stat_sec
         } else if (nscan() < 3) {
            statsec = stat_sec
         }
         if (statsec == "" || statsec == " " || statsec == "overlap")
            statsec = "overlap"
         print("Note: will use region ",statsec)

   # establish whether ref_id is a list number or a name
         if (stridx("0123456789",ref_id) == 1) 	{	# It's a list number
            ref_nim = int(substr(ref_id,1,strlen(ref_id)))
         } else {					# It's an image name
            ref_nim = 0
            ref_name = ref_id
         }
         if (firsttime) root_nim = ref_nim
         if (image_nims == "all" || image_nims == "*")
            image_nims = mincom//"-"//maxcom

         expandnim(image_nims,ref_nim=ref_nim,max_nim=maxcom,>> nimlist)

         list2 = nimlist
   # generate list of stuff to compare
         while (fscan(list2,nim) != EOF) {
            imname = "COM_000" + nim
            match (imname,matinfo,meta+,stop-,print-,>> actinfo)
         }
         list2 = ""
         if (statsec == "overlap") {
      # get overlap region
            closure (actinfo,0.0,0.0,trimlimits="[0:0,0:0]",
               interp_shift=interp_shift,origin-,verbose-,format-) |
               match ("^OVERLAP",meta+,stop-,print-) | scan(sjunk,lapsec,vigsec)
         } else {
           lapsec = statsec
         }
         print (lapsec) | translit ("", "[:,]", "    ") |
            scan(nxlolap,nxhilap,nylolap,nyhilap)
         if (lapsec == "[0:0,0:0]") {
            print ("No overlap section")
            next
         }
	 lapsize = "["//(nxhilap - nxlolap)//":"//(nyhilap - nylolap)//"]" 
         print("#NOTE:  overlap_subsec  ",lapsec," size= ",lapsize)
         print("#DBZ    overlap_subsec  ",lapsec," size= ",lapsize,>> misc)
         list2 = actinfo
         for (i = 1; fscan(list2,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,fxs,fys,soffset) != EOF; i += 1) {
            pos1b = stridx("_",imname)+1
            nim = int(substr(imname,pos1b,strlen(imname)))
            nxlo = nxlolap - nxmat0; nxhi = nxhilap - nxmat0
            nylo = nylolap - nymat0; nyhi = nyhilap - nymat0
   # Determine overlap section within imshifted source image
            stasub = "["//nxlo//":"//nxhi//","//nylo//":"//nyhi//"]"
            tmpname = uniq//substr(imname,stridx("_",imname),strlen(imname))
            print (tmpname//stasub,>> statlist)
         }
         
	 delete (tmp1, ver-, >& "dev$null")
	 
   # Determine image statistics within overlap section for calculating offsets	 
   #   Reference is first one        
	 list2 = statlist
         stat = fscan(list2,imname)
         pos1b = strlen(uniq) + 2
         pos1e = stridx("[",imname) - 1
         refname = substr(imname,pos1b,pos1e)
         print ("0.0",>> tmp1)
         while (fscan(list2,imname,rmean,rmedian,rmode) != EOF) {
            pos1b = strlen(uniq) + 2
            pos1e = stridx("[",imname) - 1
            imname = substr(imname,pos1b,pos1e)
	    delta = 0.0
            if (imname != refname) {
               print (imname//"|"//refname," ",delta,>> zinfo)
               print (delta,>> tmp1)
            }
         }
	 firsttime = no 
         delete (tmp1//","//tmp2//","//actinfo//","//statfile//","//nimlist//
            ","//statlist, ver-,>& "dev$null")
      }
   # trace zoffsets back to reference frame
      ztrace(zinfo,root_nim) | match ("^\#",meta+,stop+,print-,> actinfo)
##      type (matinfo)
      list1 = matinfo
      for (i = 1; fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
         nxmat0,nymat0,fxs,fys,zoff) != EOF; i += 1) {
         mat = substr(imname,stridx("_",imname)+1,strlen(imname))
         list2 = actinfo; found = no
         while (fscan(list2,ref,sjunk,xs) != EOF) {
            if (mat == ref) {
               found = yes
               zoff = xs
               break
            }
         }
         if (!found) {
	    print ("WARNING: zoff for ",imname," not found!")
	    print ("WARNING: zoff for ",imname," not found!",>> misc)
	 }   
         print(imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,fxs,fys,zoff)
         print(imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,fxs,fys,zoff,>> tmp1)
      }
        
      list1 = tmp1
      refname = "COM_000" + root_nim
      while (fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
         nxmat0,nymat0,fxs,fys,zoff) != EOF) {
         if (imname == refname) {
            print("COM_000 ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,fxs,fys,zoff,> tmp2)
            break
         }
      }
      concatenate(tmp2//","//tmp1,> newinfo)

# output information
      delete (out, ver-,>& "dev$null") # delete prior version (we said OK above)
      copy(dbinfo,out,verbose-)

##   # Fancy format
##      sformat = '%-7s %'//-slenmax//
##         's %3d %3d %3d %3d %4d %4d %5.2f %5.2f %9.3f\n'
##      list1 = newinfo
##      for (i = 0; fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
##            nxmat0,nymat0,xs,ys,soffset) != EOF; i += 1) {
##         printf(sformat,imname,src,,nxlosrc,nxhisrc,nylosrc,nyhisrc,
##            nxmat0,nymat0,xs,ys,real(soffset),>> out)
##      }
      
      concatenate (misc,out,append+)
#      if (verbose) concatenate(zinfo//","//actinfo,out,append+)
   
err:

# Finish up
      list1 = ""; list2 = ""
      imdelete (tmpimg//","//im1//","//im2, verify-,>& "dev$null")
      if (access(comblist) && ! save_images)
         imdelete("@"//comblist,verify-,>& "dev$null")
      delete (imlist//","//statfile//","//statlist,ver-,>& "dev$null")
      delete (nimlist//","//comblist//","//tmp1//","//tmp2,ver-,>& "dev$null")
      delete (zinfo//","//doinfo,ver-,>& "dev$null")
      delete (misc//","//dbinfo//","//matinfo,ver-,>& "dev$null")
      delete (actinfo//","//procfile,ver-,>& "dev$null")
      delete (uniq//"*",ver-,>& "dev$null")
   
end
