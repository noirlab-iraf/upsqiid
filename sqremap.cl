# SQREMAP: 25JUL98 KMM expects IRAF 2.11Export or later
# SQREMAP - extract objects from frame buffer and IMCNTR
# SQREMAP: 15JAN92 KMM
# SQREMAP: 25JUL98 KMM add global image extension
#                      replace access with imaccess where appropriate
#                      modify arguments to imcentroid and trapping of imcentroid
#                      output to conform to IRAF2.11
#                      modify arguments to GEOMAP to conform to IRAF2.11

procedure sqremap (objimg,objcoo,outdb)

string objimg      {prompt="Input image"}
string objcoo      {prompt="File with initial object X Y star coord"}
string outdb       {prompt='Output database id (".geodb" will be appended)'}
string refimg      {"",prompt="Reference image"}
string refcoo      {"",prompt="File with initial reference X Y star coord"}
string refmaster   {"",prompt="Master reference image image"}
string outco       {"default",prompt="Output coordinate file"}
string logfile     {"STDOUT", prompt="Log file name"}
real   bigbox      {7., prompt="Size of coarse search box"}
real   boxsize     {5., prompt="Size of final centering box"}
real   xmin        {-43.,prompt="GEOMAP: minimum x value"}
real   xmax        {300.,prompt="GEOMAP: maximum x value"}
real   ymin        {-43.,prompt="GEOMAP: minimum y value"}
real   ymax        {300.,prompt="GEOMAP: maximum y value"}
bool   zscale      {yes, prompt="DISPLAY using zscale?"}
string geometry    {"rscale",prompt="fit geometry",
                 enum="general|shift|xyscale|rotate|rscale|rxyscale"}
bool   interactive {yes, prompt="Interactive GEOMAP?"}
real   z1          {0.0, prompt="minimum greylevel to be displayed"}
real   z2          {4000.0, prompt="maximum greylevel to be displayed"}
bool   verbose     {yes, prompt="Verbose reporting"}

struct  *l_list,*list1,*list2
imcur   *starco

begin

   int    stat, nin, nout, slen, wcs, rid, prior
   real   xin, yin, xref, yref, xshift, yshift
   string uniq,sjunk,sname,base,obj_img,out_db,out_co,obj_coo,key
   file   tmp1, tmp2, tmp3, l_log, ref_xy, obj_xy, ref_shift, task
   int    nex
   string gimextn, imextn, imname, imroot
   struct line = ""
   struct command = ""

   obj_img = objimg
   obj_coo = objcoo
   out_db  = outdb
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
   
   uniq      = mktemp ("_Tsrm")
   tmp1      = uniq // ".tm1"
   tmp2      = uniq // ".tm2"
   tmp3      = uniq // ".tm3"
   ref_xy    = uniq // ".rxy"
   obj_xy    = uniq // ".oxy"
   ref_shift = uniq // ".shf"
   task      = uniq // ".tsk"
   l_log     = uniq // ".llg"

   l_list = l_log
   if (! imaccess(obj_img)) {
      print ("Object image not found!")
      goto err
   }
   if (! access(obj_coo)) {
      print ("Object coordinate file not found!")
      goto err
   }
   if (! imaccess(refimg) ) {
      print ("Reference image not found!")
      goto err
   }
   if (! access(refcoo)) {
      print ("Reference coordinate file not found!")
      goto err
   }
   if (! imaccess(refmaster)) {
      print ("Master reference image not found!")
      goto err
   }

   if (outco == "" || outco == " " || outco == "default") {
      out_co = out_db//".geoco"
   } else
      out_co = outco
   out_db   = outdb//".geodb"

   if (access(out_db)) {
      print ("Output database file already exists!")
      goto err
   }
   if (access(out_co)) {
      print ("Output coordinate file already exists!")
      goto err
   }

# display master reference image
   if (zscale) 	# DISPLAY using zscale+
      print ("display "//refmaster//" 1 zscale+ fi-" ) | cl
   else {
      print ("display "//refmaster//" 1 z1="//z1//" z2="//z2//" fi-" ) | cl
   }
# display reference image
   if (zscale) 	# DISPLAY using zscale+
      print ("display "//refimg//" 2 zscale+ fi-" ) | cl
   else {
      print ("display "//refimg//" 2 z1="//z1//" z2="//z2//" fi-" ) | cl
   }
# Get offset between master reference and reference frames
   frame (1)
   print ("Select unconfused star for master reference in frame  1")
   print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(skip)|")
   while (fscan(starco,xref,yref,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)
      if (key == "f")
         print ("Ref_coordinates= ",xref,yref)
      else if (key == "040") {			# 040 == spacebar
         imcntr (refmaster, xref, yref,>> l_log)	# Improve center
         stat = fscan(l_list,sjunk,sjunk,xref,sjunk,yref)
         print ("Submitted ref_coordinates= ",xref,yref)
         break
      } else if (key == "q") {
         print ("Offset between master and reference frames not found!")
         goto err
         break
      }
   }
   frame (2)
   print ("Select same star for reference image in frame 2")
   print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(skip)|")
   while (fscan(starco,xin,yin,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)
      if (key == "f") {
         imcntr (refimg, xin, yin,>> l_log)	# Improve center
         stat = fscan(l_list,sjunk,sjunk,xin,sjunk,yin)
         print ("Star_coordinates= ",xin,yin)
         xin = xref - xin; yin = yref - yin
         print ("Offset for frame ",i,xin,yin)
      } else if (key == "040") {		# 040 == spacebar
         print ("Selected star_coordinates= ",xin,yin)
         xshift = xref - xin; yshift = yref - yin
         print ("Submitted offset for frame ",i,xin,yin)
         print (xshift,yshift,>> ref_shift)
         break
      } else if (key == "q") {
         print ("Offset between master and reference frames not found!")
         goto err
      } else {
         print("Unknown key: ",key," allowed = |f|spacebar|q|")
         beep
      }
   }
   if (verbose) print ("Submitted frame offset:",xshift,yshift)
   imcentroid(refimg,"",refcoo,shifts=ref_shift,box=boxsize,big=bigbox,
      negative-,background=INDEF,lower=INDEF,upper=INDEF,
      niterate=3,tolerance=0,verbose+,> ref_xy)
   imcentroid(obj_img,"",obj_coo,shifts=ref_shift,box=boxsize,big=bigbox,
      negative-,background=INDEF,lower=INDEF,upper=INDEF,
      niterate=3,tolerance=0,verbose+,> obj_xy)
   fields(ref_xy,"6,2,4",lines="2-",quit-,print-,> tmp1)
   fields(obj_xy,"6,2,4",lines="2-",quit-,print-,> tmp2)
   list1 = tmp1; list2 = tmp2
   prior = 1
   while (fscan(list1,rid,xref,yref) != EOF) {
      if (nscan() != 3)
         next 
      for(i = prior; i < rid; i += 1) {
         print(i,"MISSING",>> tmp3)
      }
      print(xref,yref,>> tmp3)
      prior = rid + 1
   }

   l_list = ""; delete(l_log,verify-,>& "dev$null")
   l_list = l_log
   count(tmp1,>> l_log); count(tmp3,>> l_log)
   stat = fscan(l_list,nin); stat = fscan(l_list,nout)
   if (verbose)
     print("NOTE: ",nout," out of ",nin," stars found in ref image ",refimg,
        >> logfile)
   else
     print("NOTE: ",nout," out of ",nin," stars found in ref image ",refimg)

   list1 = ""; delete(tmp1,verify-,>& "dev$null")
   type (tmp3,> tmp1)
   delete(tmp3,verify-,>& "dev$null")
   prior = 1
   while (fscan(list2,rid,xref,yref) != EOF) {
      if (nscan() != 3)
         next 
      for(i = prior; i < rid; i += 1) {
         print(i,"MISSING",>> tmp3)
      }
      print(xref,yref,rid,>> tmp3)
      prior = rid + 1
   }

   count(tmp2,>> l_log); count(tmp3,>> l_log)
   stat = fscan(l_list,nin); stat = fscan(l_list,nout)
   if (verbose)
     print("NOTE: ",nout," out of ",nin," stars found in object image ",obj_img,
        >> logfile)
   else
     print("NOTE: ",nout," out of ",nin," stars found in object image ",obj_img)

   list2 = ""; delete(tmp2,verify-,>& "dev$null")
   type (tmp3,> tmp2)
   delete(tmp3,verify-,>& "dev$null")
   join(tmp1,tmp2,delim=" ",missing="MISSING",maxchar=161,shortest+,
      verbose+,> tmp3)
   match("MISSING",tmp3,stop+,print-,meta-,> out_co)
   if (verbose) match("MISSING",tmp3,stop-,print-,meta-,> logfile)
   count(tmp3,>> l_log); count(out_co,>> l_log)
   stat = fscan(l_list,nin); stat = fscan(l_list,nout)
   if (verbose)
     print("NOTE: ",nout," out of ",nin," stars found in both images",
        >> logfile)
   else
     print("NOTE: ",nout," out of ",nin," stars found in both images")


#   geomap (out_co,out_db,xmin,xmax,ymin,ymax,function="polynomial",
#      xxorder=2,xyorder=2,xxterms+,yxorder=2,yyorder=2,yxterms+,
#      reject=0.,calctype="double",inter=interactive,graphics="stdgraph")
## NOTE: one should test goodeness of fit for more restricted fitgeometry
   print (out_co,> task)
   geomap ("@"//task,out_db,xmin,xmax,ymin,ymax,function="polynomial",
      fitgeometry=geometry,transforms="",results=logfile,
      xxorder=2,xyorder=2,xxterms="half",yxorder=2,yyorder=2,yxterms="half",   
      reject=INDEF,calctype="double",inter=interactive,graphics="stdgraph")
      
   err:

# Finish up
   delete (uniq//"*", verify-)

   end
