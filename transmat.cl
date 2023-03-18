## TRANSMAT 16JUN94KMM
## TRANSMAT: translate MAT info to COM info
## TRANSMAT 20APR92KMM
#       06APR94 KMM replace "type" with "concatenate"
#       16JUN94 KMM fix case when traninfo file absent

procedure transmat (matfile, comfile)

string matfile      {prompt="file produced by GETCOMBINE||IRCOMBINE"}
string comfile      {prompt="name of resultant composite image"}
bool   tran         {no, prompt="Request GEOTRAN images before IMCOMBINE?"}
string db_tran      {"", prompt="name of database file output by GEOMAP"}
string geom_tran    {"linear", prompt="GEOTRAN transformation geometry"}
bool   max_tran     {yes, prompt="Offset GEOTRAN to save  maximum image?"}
string interp_tran  {"linear", prompt="GEOTRAN interpolant"}
string bound_tran   {"nearest", prompt="GEOTRAN boundary"}
real   const_tran   {0.0, prompt="GEOTRAN constant boundary extension value"}
bool   flux_tran    {yes, prompt="Conserve flux upon GEOTRAN?"}
string interp_shift {"linear",enum="nearest|linear|poly3|poly5|spline3",
              prompt="IMSHIFT interpolant (nearest,linear,poly3,poly5,spline3)"}
bool   new_origin   {no, prompt="Move origin to lower left corner?"}

bool   answer       {yes, prompt="Do you want to continue?", mode="q"}

struct  *list1, *list2, *list3, *l_list

begin

      int    i,stat,nim,maxnim,slen,slenmax,refnim,njunk,
             nxhiref, nxloref, nyhiref, nyloref,
             nxhi, nxlo, nyhi, nylo,
             nxhisrc,nxlosrc,nyhisrc,nylosrc,
             nxlolap,nxhilap,nylolap,nyhilap,
             nxlonew,nxhinew,nylonew,nyhinew,
             nxhimat,nxlomat,nyhimat,nylomat,
             nxmat0, nymat0, nxref, nyref, nxref0, nyref0,
             nxlink, nylink, nxlink0, nylink0,
             minxoffset,minyoffset, ncolsout,nrowsout
      real   zoff, zref, zref0, zlink, zlink0, xs, ys,
             xoffset, yoffset, xofftran, yofftran,
             xmat0, ymat0, xref, yref, xref0, yref0,
             xlink, ylink, xlink0, ylink0,
             xshift, yshift, zadj,
             xlo, xhi, ylo, yhi
      bool   firstfile, firsttime, getlink, found,
             prior_tran, maxtran, do_tran
      string imname,sname,refname,refmaster,slist,sjunk,soffset,encsub,
             src,srcsub,mos,mossub,mat,matsub,ref,refsub,stasub,lapsec,outsec,
             trimlimits,vigsec,outfile,master,reflink,prior_com,
             sxrot,syrot,sxmag,symag,sxshift,syshift,
             dbtran,cotran,const,geomtran,interp,bound,flux
      file   info,out,dbinfo,dbout,l_log,tmp1,tmp2,comblist,matinfo,newinfo,
             traninfo
      struct line = ""

      info        = matfile
      outfile     = comfile
      dbout       = mktemp("tmp$trm")
      dbinfo      = mktemp("tmp$trm")
      matinfo     = mktemp("tmp$trm")
      newinfo     = mktemp("tmp$trm")
      traninfo    = mktemp("tmp$trm")
      comblist    = mktemp("tmp$trm")
      tmp1        = mktemp("tmp$trm")
      tmp2        = mktemp("tmp$trm")
      l_log       = mktemp("tmp$trm")

      l_list = l_log
      if (! access(info)) { 		# Exit if can't find info
         print ("Cannot access info_file: ",info)
         goto err
      }
      master = info  
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

      time() | scan(line)
      print("#DBM ",line," TRANSMAT: ",out)
   # Log parameters 
      print("#DBM ",line," TRANSMAT: ",out,>> out)

   # Set initial values
      slenmax = 0
      nxref0 = 0; nyref0 = 0; zref0 = 0
      match ("^\#DB",master,meta+,stop-,print-) |
        match ("^\#DBI",meta+,stop+,print-, > dbinfo)
      match ("^MAT",master,meta+,stop-,print-) |
         translit ("","INDEF","00000",> matinfo)
   # Extract values from infofile
      match ("ref_image",dbinfo,meta+,stop-,print-) |
         scan(sjunk, sjunk, refname)
      match ("trimlimits",dbinfo,meta+,stop-,print-) |
         scan(sjunk, sjunk, trimlimits)
      refmaster = refname
      print("#DBM    master_file     ",master)
      print("#DBM    master_file     ",master,>> out)
      match (refname,matinfo,meta-,stop-,print-,> tmp1)
      count(tmp1) | scan(i)
      if (i == 0) {
         print("#WARNING: ref_master= ",refname," not found!")
         print("#WARNING: ref_master= ",refname," not found!",>> out)
         sjunk = substr(refname,stridx("[",refname),strlen(refname))
         print("#  searching for ref_master= ",sjunk)
         match (sjunk,matinfo,meta-,stop-,print-,>> tmp1)
         count(tmp1) | scan (i)
         if (i == 0) {
            print("#WARNING: ref_master= ",sjunk," not found either!  Exiting")
            goto err
         } else {
            list2 = tmp1
            stat = fscan(list2,imname,src)
            print("#FOUND: ",src," instead of ",refname)
            if (!answer) goto err
            refname = src
            print("#ADOPTING ",refname," as ref_master")
            print("#ADOPTING ",refname," as ref_master",>> out)
            refmaster = refname
            list2 = ""
         }
      }
      print("#DBM    master_ref      ",refmaster)
      print("#DBM    master_ref      ",refmaster,>> out)
      print("#DBM    interp_shift    ",interp_shift,>> out)
#      print("#DBG    do_tran         ",tran,>> out)
   # Extract values from infofile
      match ("^\#DBT",dbinfo,meta+,stop+,print-) |
         match ("^\#DBC",meta+,stop+,print-, > dbout)
      match ("^\#DBT",dbinfo,meta+,stop-,print-, > traninfo)
      prior_tran = no
      if (tran) {
   # Check dbmos for GEOTRAN info.  If available and it was used, use it,
   #    else use db_tran
         match ("mos_transform",traninfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, prior_tran)
         if (prior_tran) {
            do_tran = no
            match ("db_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, sjunk, dbtran)
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
               scan(sjunk, sxshift)
            match ("yshift_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, syshift)
            match ("xoffset_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, xofftran)
            match ("yoffset_tran",traninfo,meta-,stop-,print-) |
               scan(sjunk, yofftran)
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
            match ("xmag",dbtran,meta-,stop-,print-) | scan(sjunk, sxmag)
            match ("ymag",dbtran,meta-,stop-,print-) | scan(sjunk, symag)
            match ("xrot",dbtran,meta-,stop-,print-) | scan(sjunk, sxrot)
            match ("yrot",dbtran,meta-,stop-,print-) | scan(sjunk, syrot)
            match ("xshift",dbtran,meta-,stop-,print-) | scan(sjunk, sxshift)
            match ("yshift",dbtran,meta-,stop-,print-) | scan(sjunk, syshift)
   # Determine offsets for this data
            if (maxtran) {
               xofftran = -int(sxshift)
               yofftran = -int(syshift)
            } else {
               xofftran = 0.0; yofftran = 0.0
            }
   # Create new traninfo
            delete (traninfo, ver-, >& "dev$null")
            print("#DBT    mos_transform   ",prior_tran,>> traninfo)
            print("#DBT    db_tran         ",dbtran,>> traninfo)
            print("#DBT    geom_tran       ",geomtran,>> traninfo)
            print("#DBT    xshift_tran     ",sxshift,>> traninfo)
            print("#DBT    yshift_tran     ",syshift,>> traninfo)
            print("#DBT    xmag_tran       ",sxmag,>> traninfo)
            print("#DBT    ymag_tran       ",symag,>> traninfo)
            print("#DBT    xrot_tran       ",sxrot,>> traninfo)
            print("#DBT    yrot_tran       ",syrot,>> traninfo)
            print("#DBT    interp_tran     ",interp,>> traninfo)
            print("#DBT    bound_tran      ",bound,>> traninfo)
            print("#DBT    const_tran      ",const,>> traninfo)
            print("#DBT    fluxconserve    ",flux,>> traninfo)
            print("#DBT    max_tran        ",maxtran,>> traninfo)
            print("#DBT    xoffset_tran    ",xofftran,>> traninfo)
            print("#DBT    yoffset_tran    ",yofftran,>> traninfo)
         }
      } else {
         do_tran = no
         interp = interp_tran
         xofftran  = 0.0; yofftran  = 0.0
      }
      encsub = ""; outsec = ""
      xoffset = 0; yoffset = 0
     
      list2 = tmp1
      found = no
   # print ("COM_"//pathpos," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
   #    nxmat0,nymat0,xs,ys,soffset)
      while (fscan(list2,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
         nxmat0,nymat0,xs,ys,zoff) != EOF) {
         xref = nxmat0 + xs; yref = nymat0 + ys
         zref = zoff
         found = yes
      }
      print (src) | translit ("", "[:,]", "    ") |
         scan(ref,nxloref,nxhiref,nyloref,nyhiref)
      print("COM_000 ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
                 nxmat0,nymat0,xs,ys,zoff,>> newinfo)
      list2 = ""; list2 = matinfo
      while (fscan(list2,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
         nxmat0,nymat0,xs,ys,zoff) != EOF) {
         imname = "COM_000" +
            int(substr(imname,stridx("_",imname)+1,strlen(imname)))
         zoff -= zref
         print(imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,zoff,>> newinfo)
         print(imname," ",src," ",nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,xs,ys,zoff)
         prior_com = imname
      }
      delete (tmp1//","//dbinfo//","//matinfo,ver-,>& "dev$null")

      l_list = ""; delete (l_log, ver-, >& "dev$null"); l_list = l_log

      if (new_origin) print ("Will [re]optimize origin.")

   # Compute minimum rectangle enclosing region and overlap region
      closure (newinfo,xofftran,yofftran,trimlimits="[0:0,0:0]",
         interp_shift=interp_tran,origin=new_origin,verbose+,format+,> tmp2)
      delete (newinfo, ver-, >& "dev$null")
      match ("^COM",tmp2,meta+,stop-,print-, > newinfo)
      match ("^ENCLOSED_SIZE",tmp2,meta+,stop-,print-) | scan(sjunk,encsub)
      print (encsub) | translit ("", "[:,]", "    ") |
        scan(nxlomat,nxhimat,nylomat,nyhimat)
      match ("^UNAPPLIED_OFFSET",tmp2,meta+,stop-,print-) |
         scan(sjunk,xoffset,yoffset)
      match ("^OVERLAP",tmp2,meta+,stop-,print-) | scan(sjunk,lapsec,vigsec)
      print (lapsec) | translit ("", "[:,]", "    ") |
         scan(nxlolap,nxhilap,nylolap,nyhilap)
      if (lapsec == "[0:0,0:0]") lapsec = ""

      if (new_origin) {
   # Establishes origin at (0,0)
         ncolsout = nxhimat - nxlomat + 1
         nrowsout = nyhimat - nylomat + 1
   # Override minimum rectangle
         outsec  = "[1:"// ncolsout //",1:"// nrowsout //"]"
      }
      print("#DBM    do_tran         ",do_tran,>> dbout)
      print("#DBM    out_sec         ",encsub,>> dbout)
      print("#DBM    overlap_sec     ",lapsec,>> dbout)
      if (access(traninfo))
         concatenate (dbout//","//traninfo//","//newinfo,out,append+)
      else if (!access(traninfo))
         concatenate (dbout//","//newinfo,out,append+)

   err:

   # Finish up
      list1 = ""; list2 = ""; list3 = ""; l_list = ""
      delete (l_log,ver-,>& "dev$null")
      delete (newinfo//","//comblist//","//tmp1//","//tmp2,ver-,>& "dev$null")
      delete (traninfo//","//dbinfo//","//matinfo,ver-,>& "dev$null")
   
   end
