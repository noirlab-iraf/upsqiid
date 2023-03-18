# XYGET: 20JUN00 KMM expects IRAF 2.11Export or later
# XYGET - determine shifts between source images
# XYGET: 07MAY92 KMM
# XYGET: 18SEP92 allow predetermined offsets in RA and DEC between images
# XYGET: 18MAY93 correct output to skip images which were not centroided
#        06APR94 KMM replace "type" with "concatenate"
#        22JUL94 KMM insert alert that SQMOS was database generated from IRMOSAIC#          database
#        08AUG94 KMM replace fscan with scan from pipe at key points
#        12DEC94 KMM fix residual errors involving "lap" parameter
#        20SEP96 KMM Reactivate @-list images input
#                    The dblist option - submit database - is not yet enabled
# XYGET: 19JUL98 KMM add global image extension
#                    replace access with imaccess where appropriate
# XYGET: 20JUN00 KMM use new expandnim to report highest frame
#                    prior behavior did all of list rather than subset requested
  
procedure xyget (images, frame_nums)

string images       {prompt="MOSAIC image name | @list of images to compare"}
string frame_nums   {prompt="Selected frame numbers within MOSAIC|@list"}
string mos_info     {"default",prompt="Images info file from IRMOSAIC|SQMOS"}
string ref_info     {"default",prompt="Reference info file from IRMOSAIC|SQMOS"}
string outfile      {"", prompt="Output info file - default: images.xycom"}

# trim values applied to final image
string trimlimits   {"[0:0,0:0]",prompt="trim limits on the input subrasters"}

string coord_in     {"", prompt="Input initial coordinate file"}
string in_shifts    {"", prompt="Initial shift file between ref and images"}
string ra_offset    {"", prompt="RA offset between ref and images: ##.#[E|W]"}
string dec_offset   {"", prompt="DEC offset between ref and images: ##.#[N|S]"}
real   scale        {1.0, prompt="Offset scale in units/pixel"}

real   bigbox       {11., prompt="Size of coarse search box"}
real   boxsize      { 7., prompt="Size of final centering box"}
bool   getoffset    {yes, prompt="Do you want to get frame offsets?", mode="q"}

bool   tran         {no, prompt="Request GEOTRAN images before IMCOMBINE?"}
string db_tran      {"", prompt="name of database file output by GEOMAP"}
# string co_tran      {"", prompt="name of coordinate file input to GEOTRAN"}
string geom_tran    {"linear", prompt="GEOTRAN transformation geometry"}
bool   max_tran     {yes, prompt="Offset GEOTRAN to save  maximum image?"}
string interp_tran  {"linear", prompt="GEOTRAN interpolant"}
string bound_tran   {"nearest", prompt="GEOTRAN boundary"}
real   const_tran   {0.0, prompt="GEOTRAN constant boundary extension value"}
bool   flux_tran    {yes, prompt="Conserve flux upon GEOTRAN?"}

bool   zscale       {yes, prompt="DISPLAY using zscale?"}
real   z1           {0.0, prompt="minimum greylevel to be displayed"}
real   z2           {1000.0, prompt="maximum greylevel to be displayed"}
bool   format       {no, prompt="Fancy file format using AWK"}
bool   verbose      {yes, prompt="Verbose reporting"}

bool   answer       {yes, prompt="Do you want to continue?", mode="q"}
bool   compute_size {yes, 
                      prompt="Do you want to [re]compute image size?",mode="q"}

struct  *list1,*list2,*list3
imcur   *starco

begin

      int    i,stat,nim,nin,lo,hi,ncomp,pos1b,pos1e,wcs,gridx,gridy,maxnim,
             ncols, nrows, nxsub, nysub, nxoverlap, nyoverlap, nsubrasters,
             mos_xsize, mos_ysize,slen,slenmax,ixs,iys,ref_nim,refnim,
             nxhisrc,nxlosrc,nyhisrc,nylosrc,nxhimat,nxlomat,nyhimat,nylomat,
             nxhiref,nxloref,nyhiref,nyloref,nxhimos,nxlomos,nyhimos,nylomos,
             nxhilap, nxlolap, nyhilap, nylolap, ncolsout, nrowsout,
             nxhitrim, nxlotrim, nyhitrim, nylotrim, nim_found,
             nxmos0, nymos0, nxmat0, nymat0, nxref0, nyref0, nxoff0, nyoff0
      int    nxlo, nxhi, nylo, nyhi, nxlonew, nxhinew, nylonew, nyhinew
      real   xin, yin, xref, yref, xs, ys, fxs,fys,xmin,xmax,ymin,ymax,
             xoffset,yoffset,xofftran,yofftran,xshift,yshift,xlo,xhi,ylo,yhi,
             xoff,yoff
      string l_comp,out,nim_name,uniq,sjunk,soffset,sname,key,vcheck,sformat,
             lap,src,srcsub,mos,mossub,mat,matsub,mos_name,ishifts,lapsec,refid,
             img,ref,refsub,nimtag,reftag,image_nims,corner,order,tmpimg,reflap,
             serr,vigsec,encsub,outsec,comsub,dbmos,imname,ref_name,baseid,
             base_ref,sxrot,syrot,sxmag,symag,sxshift,syshift,
             dbtran,cotran,const,geomtran,interp,bound,flux,
             ref_id,imagenums,ref_mos,dbrefmos,mosinfo,refinfo
      file   info,coords,cofile,refimg,alignlog,nimlist,inshifts,
             compfile,imtagfile,tmp1,tmp2,tmp3,pathinfo,dbinfo,imlist,
             traninfo,matinfo,cominfo,outshifts,dbrefinfo
      bool   mosaic,listdb,getcoords,gotoffset,found,firsttime,new_origin,
             prior_tran,do_tran,maxtran,display_ref,dblist
      int    nex, total, most, least
      string gimextn, imextn, imroot
      struct command = ""
      struct line = ""

      l_comp      = images
      imagenums   = frame_nums
      
# get IRAF global image extension
      show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
      nex     = strlen(gimextn)      

      uniq        = mktemp ("_Txyg")
      tmpimg      = uniq//"_000"
      tmp1        = mktemp ("tmp$xyg")
      tmp2        = mktemp ("tmp$xyg")
      tmp3        = mktemp ("tmp$xyg")
      dbinfo      = mktemp ("tmp$xyg")
      dbrefinfo   = mktemp ("tmp$xyg")
      traninfo    = mktemp ("tmp$xyg")
      mosinfo     = mktemp ("tmp$xyg")
      refinfo     = mktemp ("tmp$xyg")
      matinfo     = mktemp ("tmp$xyg")
      cominfo     = mktemp ("tmp$xyg")
      pathinfo    = mktemp ("tmp$xyg")
      imtagfile   = mktemp ("tmp$xyg")
      compfile    = mktemp ("tmp$xyg")
      inshifts    = mktemp ("tmp$xyg")
      outshifts   = mktemp ("tmp$xyg")
      nimlist     = mktemp ("tmp$xyg")
      imlist      = mktemp ("tmp$xyg")
      alignlog    = mktemp ("tmp$xyg")
      cofile      = mktemp ("tmp$xyg")
      coords      = mktemp ("tmp$xyg")
      refimg      = mktemp ("tmp$xyg")

      dbmos      = mos_info
      if (dbmos == "" || dbmos == " " || substr(dbmos,1,3) == "def")
         dbmos = "default"
      dbrefmos      = ref_info
      if (dbrefmos == "" || dbrefmos == " " || substr(dbrefmos,1,3) == "def")
         dbrefmos = "default"

      img = l_comp
      i = strlen(img)
      if (substr(img,i-nex,i) == "."//gimextn)	# Strip off imextn
         img = substr(img,1,i-nex-1)
      if (substr(img,1,1) == "@") {		# It's an @list of images
         img = substr(img,2,strlen(img))
         mos_name   = img
         mosaic = no
         baseid = "IMG_000"
         if (dbmos == "default")
            dbmos = mos_name//".dbmos"
         if (access(dbmos))
            dblist = yes
         else {
            dblist = no
            dbmos  = "none"
         }
   # Expand input file name list; option="root" truncates lines beyond ".imh"
         sections (l_comp,option="root") |
            match("\#",meta+,stop+,print-,> imlist)
         print("Image is an @list: dbmos= ",dbmos," using ",imagenums,
            " with baseid = ",baseid)
      } else {			  		# It's a mosaic image
         mosaic = yes
         dblist = no 
         mos_name   = img
         if (dbmos == "default")
            dbmos = mos_name//".dbmos"
         baseid = "MOS_000"
      }

      if (mosaic) {
         print("Image is a MOSAIC: dbmos= ",dbmos," using ",imagenums,
            " with baseid = ",baseid)
      } else if (dblist) {
         print("Image is a LIST-BASED: dbmos= ",dbmos," using ",imagenums,
            " with baseid = ",baseid)
      }

      ref_id = "1"
      print (imagenums) | translit ("", "|", " ") |
         scan(image_nims,ref_id,ref_mos)
      if (nscan() < 2) {
         print("Warning: no reference id found!")
         goto skip
      } else if (nscan() == 2) {
         ref_mos  = mos_name
         dbrefmos = dbmos
         print ("Reference image ",ref_mos," with ID = ",ref_id)
      } else {				# pathid in different mosaic
         print ("Note: indirect reference image ",ref_mos," with ID = ",ref_id)
         if (dbrefmos == "default")
            dbrefmos = ref_mos//".dbmos"
      }
      if ((dbmos != "default") && (dbmos != "none") && (! access(dbmos))) {
         print ("Information file ",dbmos," not found!")
         goto skip
      } else if ((dbrefmos != "default") && (dbrefmos != "none") &&
         (! access(dbrefmos))) {
         print ("Reference information file ",dbrefmos," not found!")
         goto skip
      } else if (tran && !access(db_tran)) {
         print ("GEOTRAN database file db_tran ",db_tran," not found!")
         goto skip
      }
         
   # establish ID of output info file
      if (outfile == "" || outfile == " " || outfile == "default") {
         out = mos_name//".xycom"
      } else
         out = outfile
      if (out != "STDOUT" && access(out)) {
         print("Will append to output_file ",out,"!")
         if (!answer) goto skip
         print ("Note: appending to existing output_file ",out)
      } else
         print ("Output_file= ",out)

   # establish whether ref_id is a list number or a name
      if (stridx("0123456789",ref_id) == 1) {	# It's a list number
         ref_nim = int (substr(ref_id,1,strlen(ref_id)))
         imname = baseid + ref_nim
   # locate ref_id
         if (mosaic || dblist) {
            fields (dbrefmos,"1,3",lines="1-",quit-,print-) |
               match ("^"//imname,meta+,stop-,print-) | scan (sjunk,ref_name)
         } else {
            sjunk = "000" + ref_nim
            fields (imlist,"1",lines=sjunk,quit-,print-) | scan (ref_name)
         }
         if (nscan() == 0 ) {
            print ("Warning: reference name for ref_id =",ref_id," ",imname,
               " not found!")
            goto skip
         } else
            print ("Reference image name: ",ref_name)
      } else {					# It's an image name
         ref_nim  = 0
         ref_name = ref_id
         imname = baseid + ref_nim
      }

      if (mosaic || dblist) {
         match ("^\#DB",dbmos,meta+,stop-,print-) |
            match ("^\#DBT",meta+,stop+,print-, > dbinfo)
         match("\#",dbmos,meta+,stop+,print-,> mosinfo)
         match("\#",dbrefmos,meta+,stop+,print-,> refinfo)
         match ("^\#DB",dbrefmos,meta+,stop-,print-) |
            match ("^\#DBT",meta+,stop+,print-, > dbrefinfo)
         match ("^\#DBT",dbmos,meta+,stop-,print-, > traninfo)
         count (dbinfo) | scan(i)
   # Ascertain whether dbmosfile is from IRMOSAIC or SQMOS
         if (i <= 0) {	 # It's a MOSAIC file, make SQMOS equivalent output
            print (dbmos," is an IRMOSAIC file.  SQMOS database created")
            list1 = ""; delete (tmp1,verify-,>& "dev$null")
            list1 = dbinfo 
            while (fscan(list1, sjunk, line) != EOF) {
               print("#DB ",line, >> tmp1)
               stat = fscan(line, sjunk)
               if (sjunk == "nsubrasters") break
            }
            list1 = ""; delete (dbinfo,verify-,>& "dev$null")
            copy (tmp1, dbinfo, ver-)
            delete (tmp1,verify-,>& "dev$null")
            print("#DB     mosaic          ",mos_name,>> dbinfo)
            print("#DBT    mos_tranform    ","no",>> traninfo)
         }
         if (verbose) {
            print("DBINFO:")   ; type (dbinfo)
            print("TRANINFO:") ; type (traninfo)
         }
   # Indicate GEOTRAN status of input images
         match ("mos_transform",traninfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, prior_tran)
   # Extract mosaic parameters from dbinfofile
         match ("ncols",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, ncols)
         match ("nrows",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, nrows)
         match ("nxsub",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, nxsub)
         match ("nysub",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, nysub)
         match ("nxoverlap",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, nxoverlap)
         match ("nyoverlap",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, nyoverlap)
         match ("corner",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, corner)
         match ("order",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, order)
         match ("nsubrasters",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, nsubrasters)
         ncomp = nsubrasters

         list1 = ""; delete (tmp1, ver-, >& "dev$null")
      } else {
         count(imlist) | scan (ncomp)
      }

   # Expand the range of images
      expandnim(image_nims,ref_nim=ref_nim,max_nim=ncomp,>> nimlist)
      total = expandnim.total
      least = expandnim.least
      most  = expandnim.most
print(least,most,total)      
      base_ref = ref_name
      outsec = ""

      xofftran = 0; yofftran = 0
      nxlotrim = 0; nxhitrim = 0; nylotrim = 0; nyhitrim = 0
      soffset = "0.0" 					# Null z offets
      print (trimlimits) | translit ("", "[:,]", "    ") |
         scan(nxlotrim,nxhitrim,nylotrim,nyhitrim)
      if (mosaic) {					# mosaic path
## NB: This stuff is already in field 3 of MOS_ part of database.
##     One might consider retrieving and decoding over current scheme...
##     Current scheme allows arbitrary reference image.
   # Generate appropriate mosaic subsections 
         nxlosrc = 1; nxhisrc = ncols; nylosrc = 1; nyhisrc = nrows
         nxloref = 1; nxhiref = ncols; nyloref = 1; nyhiref = nrows
         mos_xsize = ncols - nxoverlap
         mos_ysize = nrows - nyoverlap
         nxref0 = 0; nyref0 = 0
   # Generate file relating path position to grid position
         mkpathtbl(1,nsubrasters,nxsub,nysub,order,corner,sort-,format-,
            >> pathinfo)
         list1 = nimlist
         for (nin = 0; fscan (list1,nim) !=EOF; nin += 1) {
            list2 = pathinfo
            if (nim != 0) { 			# It's a list number
               imname = mos_name
               nxlosrc = 1; nxhisrc = ncols; nylosrc = 1; nyhisrc = nrows
               while (fscan (list2,i,gridx,gridy) != EOF) {
                   if (i == nim) break
               }
               nxmos0 = (gridx - 1) * mos_xsize
               nymos0 = (gridy - 1) * mos_ysize
            } else {				# It's an image name
               nxmos0 = 0; nymos0 = 0
               imname = ref_name
               if (stridx("[",imname) <= 0) {	# no subsection; read header
                  nxlosrc = 1; nylosrc = 1
                  imhead(ref_name,long-,user-) |
                     translit ("", "[:,]", "    ") | scan(sjunk,nxhisrc,nyhisrc)
               } else {				# subsection; use it
                 print (imname) | translit ("", "[:,]", "    ") |
                   scan(nxlosrc,nxhisrc,nylosrc,nyhisrc)
               }
            }
            nxlomos = nxmos0 + nxlosrc; nxhimos = nxmos0 + nxhisrc
            nylomos = nymos0 + nylosrc; nyhimos = nymos0 + nyhisrc
            mossub ="["//nxlomos//":"//nxhimos//","//nylomos//
                    ":"//nyhimos //"]"
            if (nin == 0) {			# reference image
               nim      = 0
               nimtag   = ref_mos//"_000" + nim
               nim_name = tmpimg + nim
               refimg   = nim_name
               if (ref_mos == mos_name)	{	# same mosiac
                  if (stridx("[",imname) <= 0) 	# no subsection
                     mos = imname//mossub
                  else
                     mos = imname
               } else {				# not same mosaic
                  mos = ref_name
               }
               refid  = mos   
               reftag = nimtag
            } else {
               nimtag   = mos_name//"_000" + nim
               nim_name = tmpimg + nim
               if (stridx("[",imname) <= 0) 	# no subsection
                  mos = imname//mossub
               else
                  mos = imname
            }
            print (nim_name,>> compfile)
            imcopy (mos,nim_name,ver-)
            print (nimtag," ",mos," ",nim,nxmos0,nymos0,>> imtagfile)
         }
         ncomp = nin

      } else if (dblist) {
##### FROM HERE
         list1 = ""; delete (tmp1//","//tmp2//","//tmp3,ver-, >& "dev$null")
   # Locate reference image and add to list
         list1 = mosinfo
#         for (nin = 0; fscan (list1,nim) !=EOF; nin += 1) {
         if (ref_nim != 0) {
            for (nim = 1; fscan (list1,img) !=EOF; nim += 1) {
               if (nim == ref_nim) {
                  print (img, > tmp2)
                  break
               }
            }
         } else
           print (ref_name, > tmp2)
         concatenate(imlist,tmp2,append+)
         print ("IMG_000 ",ref_name," 0 0 0",>> imtagfile)
         print (ref_name,>> compfile)
         list1 = imlist
         for (nin = 0; fscan (list1,img) !=EOF; nin += 1) {
   # Strip off trailing section
            pos1b = stridx("[",img); pos1e = stridx("]",img)
            mossub = substr(img,pos1b,pos1e)
            img = substr(img,1,pos1b-1)
            nimtag = "IMG"//"_000" + nin
            if (substr(img,i-nex,i) == "."//gimextn)	# Strip off imextn
               img = substr(img,1,i-nex-1)
            if (nim == 0) {
               refimg = img
               reftag = nimtag
            }
            print (img,>> compfile)
            print (nimtag," ",img//mossub," ",nin," 0 0",>> imtagfile)
         } 
         ncomp = nin
         list1 = ""; delete (tmp1//","//tmp2//","//tmp3,ver-, >& "dev$null")
##### TO HERE
      } else {					# image list path
         list1 = ""; delete (tmp1//","//tmp2//","//tmp3,ver-, >& "dev$null")
# Locate reference image and add to list
# imlist gets all images in input list
# nimlist gets frame_nums subset of numbers requested
         list1 = imlist	 	
         if (ref_nim != 0) {
            for (nim = 1; fscan (list1,img) !=EOF; nim += 1) {
               if (nim == ref_nim) {
                  print (img, > tmp2)
                  break
               }
            }
         } else
           print (ref_name, > tmp2)
	   
         list1 = ""; delete (tmp1, ver-, >& "dev$null")
         concatenate(imlist,tmp2,append+)
	 list1 = tmp2  
         nxlosrc = 1 ; nylosrc = 1
         for (nin = 0; fscan (list1,img) !=EOF; nin += 1) {
   # Get image dimensions
            if (nin > most) break	# stop after last frame requested
            sname = img
            imgets(sname,"i_naxis1")  ; nxhisrc = int(imgets.value)
            imgets(sname,"i_naxis2")  ; nyhisrc = int(imgets.value)
            ncolsout = nxhisrc ; nrowsout = nyhisrc        # initial estimate
            srcsub="["//nxlosrc//":"//nxhisrc//","//nylosrc//":"//nyhisrc//"]"
   # Strip off section info
            pos1b = stridx("[",img); pos1e = stridx("]",img)
            if (pos1b != 0 ) {
               mossub = substr(img,pos1b,pos1e)
               img = substr(img,1,pos1b-1)
            } else {
               mossub = ""
            }
            i = strlen(img)
            nimtag = mos_name//"_000" + nin
            if (substr(img,i-nex,i) == "."//gimextn)	# Strip off imextn
               img = substr(img,1,i-nex-1)
            if (nin == 0) {
               refimg = img
               reftag = nimtag
            }
            print (img,>> compfile)
    # Use image dimensions rather than attendent section info
            print (nimtag," ",img//srcsub," ",nin," 0 0",>> imtagfile)
         } 
         ncomp = nin
         refid = refimg
         list1 = ""; delete (tmp1//","//tmp2//","//tmp3,ver-, >& "dev$null")
#FIX SO THAT any prior GEOTRAN info is available for use
         prior_tran = no
         print("#DBT    mos_transform   ","no",>> traninfo)
      }
      if (tran) {
   # Check dbmos for GEOTRAN info.  If available and it was used, use it,
   #    else use db_tran
         match ("mos_transform",traninfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, prior_tran)
         if (prior_tran) {
            do_tran = no
            match ("db_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, dbtran)
            match ("begin",dbtran,meta-,stop-,print-) |
               scan(sjunk, cotran)
            match ("geom_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, geomtran)
            match ("interp_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, interp)
            match ("bound_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, bound)
            match ("const_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, const)
            match ("fluxconserve",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, flux)
            match ("max_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, maxtran)
            match ("xshift_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, sxshift)
            match ("yshift_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, syshift)
            match ("xoffset_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, xofftran)
            match ("yoffset_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, yofftran)
         } else {
            do_tran = yes
            dbtran = db_tran
            geomtran = geom_tran
            bound = bound_tran
            interp = interp_tran
            const = const_tran
            flux  = flux_tran
            maxtran = max_tran
   # Fetch info from GEOMAP database file for this data
            match ("begin",dbtran,meta-,stop-,print-) | scan(sjunk, cotran)
### OMIT FROM HERE?
            match ("xmag",dbtran,meta-,stop-,print-) | scan(sjunk, sxmag)
            match ("ymag",dbtran,meta-,stop-,print-) | scan(sjunk, symag)
            match ("xrot",dbtran,meta-,stop-,print-) | scan(sjunk, sxrot)
            match ("yrot",dbtran,meta-,stop-,print-) | scan(sjunk, syrot)
            match ("xshift",dbtran,meta-,stop-,print-) | scan(sjunk, sxshift)
            match ("yshift",dbtran,meta-,stop-,print-) | scan(sjunk, syshift)
### OMIT TO HERE?
   # Determine offsets for this data
            if (maxtran) {
               xofftran = -int(sxshift)
               yofftran = -int(syshift)
            } else {
               xofftran = 0.0; yofftran = 0.0
            }
   # Create new traninfo
            delete (traninfo, ver-, >& "dev$null")
            print("#DBT    mos_transform   ","no",>> traninfo)
            print("#DBT    db_tran         ",dbtran,>> traninfo)
            print("#DBT    geom_tran       ",geomtran,>> traninfo)
            print("#DBT    xshift_tran     ",sxshift,>> traninfo)	#OMIT?
            print("#DBT    yshift_tran     ",syshift,>> traninfo)	#OMIT?
            print("#DBT    xmag_tran       ",sxmag,>> traninfo)		#OMIT?
            print("#DBT    ymag_tran       ",symag,>> traninfo)		#OMIT?
            print("#DBT    xrot_tran       ",sxrot,>> traninfo)		#OMIT?
            print("#DBT    yrot_tran       ",syrot,>> traninfo)		#OMIT?
            print("#DBT    interp_tran     ",interp,>> traninfo)
            print("#DBT    bound_tran      ",bound,>> traninfo)
            print("#DBT    const_tran      ",const,>> traninfo)
            print("#DBT    fluxconserve    ",flux,>> traninfo)
            print("#DBT    max_tran        ",max_tran,>> traninfo)
            print("#DBT    xoffset_tran    ",xofftran,>> traninfo)
            print("#DBT    yoffset_tran    ",yofftran,>> traninfo)
         }
      } else {
         xofftran  = 0.0; yofftran  = 0.0
         sxrot = "INDEF"; syrot = "INDEF"
         sxmag = "INDEF"; symag = "INDEF"
         sxshift = "0.0"; syshift = "0.0"
         do_tran = no
         maxtran = no
         dbtran = ""; cotran = ""
         geomtran = ""; bound = ""; interp = ""; const = ""; flux  = ""
      }

      display_ref = yes
      if (coord_in == "" || coord_in == " " || coord_in == "null") {
         getcoords = yes
         display_ref = yes
      } else {
         getcoords = no
         display_ref = yes
         match ("SUM_COFILE",coord_in,meta-,stop-,print-,> coords)
         list1 = coords
         while (fscan(list1, sjunk, xin, yin) != EOF) {
            print (xin, yin, >> cofile )
         }
         delete (coords, ver-, >& "dev$null")
      }

      if (in_shifts == "" || in_shifts == " " || in_shifts == "null") {
         if (ra_offset == "" || ra_offset == " " || ra_offset == "null") {
            xin = 0.0
         } else {
            xin =  real(ra_offset)/scale
            if (stridx("E",ra_offset) != 0) 
               xin = -xin
         }
         if (dec_offset == "" || dec_offset == " " || dec_offset == "null") {
            yin = 0.0
         } else {
            yin =  real(dec_offset)/scale
            if (stridx("N",dec_offset) != 0)
               yin = -yin
         }
         if (xin != 0.0 || yin != 0.0) {
            print ("Using offsets: RA = ",ra_offset," (",xin," pix) DEC = ",
               dec_offset," (",yin," pix)")
            print ("0 0", >> inshifts )
            for (i = 1; i < ncomp; i += 1) {
               print (xin, yin, >> inshifts )
            }
         } else {
            display_ref = yes
            inshifts = in_shifts
         }
      } else {
# NB: This branch is unclear
         match ("SUM_OFFSET",coord_in,meta-,stop-,print-,> coords)
         list1 = coords
         while (fscan(list1, sjunk, xin, yin) != EOF) {
            print (xin, yin, >> inshifts )
         }
         delete (coords, ver-, >& "dev$null")
         display_ref = no
      }
##DEBUG: print(refimg)
##DEBUG: type(compfile)
##DEBUG: goto skip
      locate ("@"//compfile,cofile,ref_image=refimg,in_shifts=inshifts,
         bigbox=bigbox,boxsize=boxsize,interp_type=interp_tran,
         display_ref=display_ref,zscale=zscale,z1=z1,z2=z2,
         background=INDEF,lower=INDEF,upper=INDEF,niter=3,tolerance=0,
         verb+,outfile=alignlog)

      if (verbose)
          match ("^SUM",alignlog,meta+,stop+,print-,>> out) # imalign output
   #Extract shifts
      list1 = ""; delete (tmp1,ver-, >& "dev$null")
      match ("SUM_SHIFTS",alignlog,meta-,stop-,print-, > outshifts)
      count (outshifts) | scan(i)
      if (i < 1) {
         print ("No shifts found!")
         goto skip
      }
      list1 = ""; delete (tmp1,ver-, >& "dev$null")
      match ("OVERLAP",alignlog,meta-,stop-,print-, > tmp1)
      list1 = tmp1   
      count (tmp1) | scan(i)
      if (i < 1) {
         print ("No overlap found!")
         comsub = "[0:0,0:0]"
      } else { 
   # Format ("OVERLAP: ",vigsec," ",trimsec," ",reftag,>> out)
        stat = fscan(list1,sjunk,comsub)
      }
      reflap = refid//comsub

      list1 = ""; list2 = ""; delete (tmp1,ver-, >& "dev$null")
      list1 = outshifts; list2 = imtagfile
   # Format ("SUM_SHIFTS: ",xshift,yshift," ",sname," ",nim," ",serr)
      for (i = 0; fscan(list1,sjunk,xs,ys,img,nin,serr,) != EOF; i += 1) {
         if (mosaic) {
            sjunk = substr(img,stridx("_",img)+1,strlen(img))
            nim_found = int(substr(sjunk,stridx("_",sjunk)+1,strlen(sjunk)))
         } else {
            nim_found = i
         }
         while (fscan(list2,nimtag,imname,nim,nxmos0,nymos0) != EOF) {
            if (i == 0)
               sname = "COM_000"
            else
               sname = "COM_000" + nim
            if (mosaic) {
               if (nim_found == nim) {
                  print(sname," ",imname," 0 0 0 0 0 0 ",xs,ys," 0.0 ",
                     reflap,>> matinfo)
                  print("SUM_SHIFTS: ",xs,ys," ",nimtag," ",nin," ",serr,>> out)
                  break
               } else {
                  print ("Warning centroid for ",sname, " not found!")
               }
            } else {
               pos1b = stridx("[",imname)
               sjunk = substr(imname,1,pos1b-1)
               if (img == sjunk) {
                  print(sname," ",imname," 0 0 0 0 0 0 ",xs,ys," 0.0 ",
                     reflap,>> matinfo)
                  print("SUM_SHIFTS: ",xs,ys," ",nimtag," ",nin," ",serr,>> out)
                  break
               } else {
                  print ("Warning centroid for ",sname, " not found!")
               }
            }
         }
      }

      print("SUM_OVERLAP: ",refid," ",comsub," ",sname,>> out)

      list1 = ""; delete (tmp1,ver-, >& "dev$null")
      match ("SUM_COFILE",alignlog,meta-,stop-,print-,> tmp1)
      list1 = tmp1   
   # Format ("SUM_COFILE: ",xin,yin," ",reftag," ",line,>> out)
      while (fscan(list1,sjunk,xin,yin) != EOF) {
         print ("SUM_COFILE: ",xin,yin," ",reftag," ",line,>> out)
      }
      list1 = ""; delete (tmp1,ver-, >& "dev$null")
      match ("SUM_OFFSET",alignlog,meta-,stop-,print-, > tmp1)
      count (tmp1) | scan(i)
      if (i > 0) {
         list1 = tmp1; list2 = imtagfile
   # Format ("SUM_OFFSET: ",xin,yin," ",reftag,>> out)
         while((fscan(list1,sjunk,xin,yin) !=EOF) &&
            (fscan(list2,nimtag) !=EOF)) {
            print ("SUM_OFFSET: ",xin,yin," ",nimtag,>> out)
         }
      }

      list1 = ""; delete (tmp1,ver-, >& "dev$null")
      time() | scan(line)
# log parameters to database file
      print("#DBG ",line," XYGET: ",>> dbinfo)
      if (!mosaic && !dblist) print("#DBG    nsubrasters     ",ncomp,>> dbinfo)
      print("#DBG    basis_info      ",info,>> dbinfo)
      print("#DBG    mos_info        ",dbmos,>> dbinfo)
      print("#DBG    ref_info        ",dbrefmos,>> dbinfo)
      print("#DBG    image_nims      ",image_nims,>> dbinfo)
      print("#DBG    ref_image       ",refid,>> dbinfo)
      print("#DBG    ref_nim         ",ref_nim,>> dbinfo)
      print("#DBG    do_tran         ",do_tran,>> dbinfo)

      slenmax = 0
      soffset = " 0.0"
      list1 = imtagfile
# print ("COM_"//pathpos," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
#    nxmat0,nymat0,xs,ys,soffset)
#DEBUG  print("IMTAGFILE:")
#DEBUG  type (imtagfile)
#DEBUG  print ("MATINFO:")
#DEBUG  type (matinfo)
      for (i = 0; fscan(list1,nimtag,src,nim) != EOF; i += 1) {
         list2 = matinfo
# search for corresponding entry
         for (nin = 0; fscan(list2,imname,mat,nxlomat,nxhimat,nylomat,nyhimat,
            nxmat0,nymat0,xs,ys) != EOF; nin += 1) {
            pos1b = stridx("_",imname)+1
            stat = int(substr(imname,pos1b,strlen(imname)))
            if (stat == nim) {
               found = yes
               break
            }
            found = no
         }
         if (!found) {
            print("Image path position missing for ",nimtag)
            next
         }
   # Override any pre-existing SRC information
         if (!mosaic)  {
            print (src) | translit ("", "[:,]", "    ") |
               scan(sjunk,nxlosrc,nxhisrc,nylosrc,nyhisrc)
         } else {
            nxlosrc = 1; nxhisrc = ncols; nylosrc = 1; nyhisrc = nrows
         }
         if (i == 0) imname = "COM_000"
         print (imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,soffset,>> tmp2)
      }

      if (ref_nim == 0 ) {
         if (compute_size)
            new_origin = yes
         else
            new_origin = no
      } else
         new_origin = yes

      if (new_origin) print ("Will [re]optimize origin.")

   # Compute minimum rectangle enclosing region and overlap region
#DEBUG print ("TMP2:")
#DEBUG type (tmp2)
#DEBUG print (xofftran,yofftran," ",new_origin)
      closure (tmp2,xofftran,yofftran,trimlimits=trimlimits,
         interp_shift=interp_tran,origin=new_origin,verbose+,format=format,
         > tmp3)
      if (verbose) type (tmp3)
      match ("^COM",tmp3,meta+,stop-,print-, > cominfo)
      match ("^ENCLOSED_SIZE",tmp3,meta+,stop-,print-) | scan(sjunk,encsub)
      print (encsub) | translit ("", "[:,]", "    ") |
         scan(nxlomat,nxhimat,nylomat,nyhimat)
      match ("^UNAPPLIED_OFFSET",tmp3,meta+,stop-,print-) |
         scan(sjunk,xoffset,yoffset)
      match ("^OVERLAP",tmp3,meta+,stop-,print-) | scan(sjunk,lapsec,vigsec)
      print (lapsec) | translit ("", "[:,]", "    ") |
         scan(nxlolap,nxhilap,nylolap,nyhilap)
      if (lapsec == "[0:0,0:0]") lapsec = ""
      if ((lapsec == "") || (nxhilap <= nxlolap) || (nyhilap <= nylolap)) {
         print ("#WARNING! overlap section: ",lapsec," is unphysical!") 
         print ("#WARNING! overlap section: ",lapsec," is unphysical!",>> out) 
      } else {
         print ("#NOTE: overlap section: ",lapsec) 
         print ("#NOTE: overlap section: ",lapsec,>> out) 
      }
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

      print("#DBG    trimlimits      ",trimlimits,>> dbinfo)
      print("#DBG    xoffsettran     ",xofftran,>> dbinfo)
      print("#DBG    yoffsettran     ",yofftran,>> dbinfo)
      print("#DBG    out_sec         ",outsec,>> dbinfo)
   # Report minimum offsets required, but not applied to COM info
      concatenate (dbinfo//","//traninfo//","//cominfo,out,append+)

#DEBUG print ("#DEBUG imtagfile:",>> out)
#DEBUG type (imtagfile,>> out)
#DEBUG print ("#DEBUG matinfo:",>> out)
#DEBUG type (matinfo,>> out)
#DEBUG print ("#DEBUG tmp2:",>> out)
#DEBUG type (tmp2,>> out)
         
   # Finish up
skip:

      list1=""; list2=""; list3=""
      if (mosaic && access(compfile)) imdelete("@"//compfile,ver-,>& "dev$null")
      if (mosaic) imdelete (refimg, ver-,>& "dev$null")
      delete (tmp1//","//tmp2//","//tmp3//","//dbinfo,ver-, >& "dev$null")
      delete (nimlist//","//alignlog//","//inshifts, ver-,>& "dev$null")
      delete (pathinfo//","//imtagfile//","//cominfo, ver-,>& "dev$null")
      delete (refinfo//","//mosinfo, ver-,>& "dev$null")
      delete (cofile//","//compfile, ver-,>& "dev$null")
      delete (outshifts//","//traninfo//","//matinfo, ver-,>& "dev$null")
      delete (dbrefinfo//","//imlist//","//uniq//"*", ver-,>& "dev$null")

end
