# GETMAP: 22JAN00 KMM expects IRAF 2.11Export or later
# GETMAP: - extract objects from frame buffer and IMCNTR
# GETMAP: 29JUL94 KMM
# GETMAP: 11OCT94 KMM fix inversion error
# GETMAP: 22JUL98 KMM modify GEOMAP paramters to conform to IRAF2.11
# GETMAP: 22JAN00 KMM modify for UPSQIID including channel offset syntax

procedure sqremap (ref1img,obj2img,obj3img,out21db,out31db)

string ref1img     {prompt="Reference image 1"}
string obj2img     {prompt="Object image 2"}
string obj3img     {prompt="Object image 3"}
string out21db     {prompt='Output 21 database id (".geodb" will be appended)'}
string out31db     {prompt='Output 31 database id (".geodb" will be appended)'}
bool   two_objects {yes,
                     prompt="Compare two object images to reference image?"}
string logfile     {"STDOUT", prompt="Log file name"}
real   bigbox      {7., prompt="Size of coarse search box"}
real   boxsize     {5., prompt="Size of final centering box"}
real   xmin        {-43.,prompt="GEOMAP: minimum x value"}
real   xmax        {600.,prompt="GEOMAP: maximum x value"}
real   ymin        {-43.,prompt="GEOMAP: minimum y value"}
real   ymax        {600.,prompt="GEOMAP: maximum y value"}
bool   orient      {yes, prompt="Also generate oriented geomap"} 
bool   xinvert     {no,  prompt="Invert X cooordinates?"}
bool   yinvert     {yes, prompt="Invert Y cooordinates?"}
int    ncols       {512, prompt="# of columns (X dimension)"}
int    nrows       {512, prompt="# of rows    (Y dimension)"}
string geometry    {"rscale",prompt="fit geometry",
                 enum="general|shift|xyscale|rotate|rscale|rxyscale"}
bool   zscale      {yes, prompt="DISPLAY using zscale?"}
bool   interactive {yes, prompt="Interactive GEOMAP?"}
real   z1          {0.0, prompt="minimum greylevel to be displayed"}
real   z2          {4000.0, prompt="maximum greylevel to be displayed"}
int    rcolor      {209, prompt="Marking color for reference image"}
int    ocolor      {209, prompt="Marking color for object image"}
int    pointsize   {3,   prompt="Marking point size in pixels"}
# color 209 = magenta 207= yellow 215 = turquoise
bool   verbose     {yes, prompt="Verbose reporting"}

struct  *list1,*list2
imcur   *starco

begin

   int    stat, nin, nout, slen, wcs, rid, prior, frame
   real   xin, yin, xref, yref, xout, yout
   string uniq,sjunk,sname,base,obj2,obj3,out21_db,out21_co,out31_db,out31_co,
          out21_cotr,out31_cotr,out21_dbtr,out31_dbtr,ref1,key,
          out21base,out31base
   file   tmp1, tmp2, tmp3, ref_xy, obj_xy, ref_shift, task, colist,
          ref1pixco,obj2pixco,obj3pixco,ref1cotr,obj2cotr,obj3cotr
   bool   onref
   struct line = ""
   struct command = ""

   ref1 = ref1img
   obj2 = obj2img
   if (two_objects)
      obj3 = obj3img
   out21base  = out21db
   if (two_objects)
      out31base  = out31db

   uniq      = mktemp ("_Tsrm")
   tmp1      = uniq // ".tm1"
   tmp2      = uniq // ".tm2"
   tmp3      = uniq // ".tm3"
   ref1pixco = uniq // ".rc1"
   obj2pixco = uniq // ".oc2"
   obj3pixco = uniq // ".oc3"
   ref1cotr  = uniq // ".rt1"
   obj2cotr  = uniq // ".ot2"
   obj3cotr  = uniq // ".ot3"
   ref_xy    = uniq // ".rxy"
   obj_xy    = uniq // ".oxy"
   ref_shift = uniq // ".shf"
   colist    = uniq // ".col"
   task      = uniq // ".tsk"

   if (! imaccess(ref1)) {
      print ("Reference image not found!")
      goto err
   } else if (! imaccess(obj2)) {
      print ("Object 2 image ",obj2,"  not found!")
      goto err
   }
   if (two_objects) {
      if (! imaccess(obj3)) {
         print ("Object 3 image ",obj3," not found!")
         goto err
      }
   }

   out21_db   = out21base//".geodb"
   out21_co   = out21base//".geoco"
   if (access(out21_db)) {
      print ("Output database file ",out21_db,"  already exists!")
      goto err
   } else if (access(out21_co)) {
      print ("Output coordinate file ",out21_co,"  already exists!")
      goto err
   }
   if (two_objects) {
     out31_db   = out31base//".geodb"
     out31_co   = out31base//".geoco"
      if (access(out31_db)) {
         print ("Output database file ",out31_db,"  already exists!")
         goto err
      } else if (access(out31_co)) {
         print ("Output coordinate file ",out31_co,"  already exists!")
         goto err
      }
   }

# display reference image 1
   if (zscale) { 	# DISPLAY using zscale+
      print ("display "//ref1//" 1 zscale+ zrange- fi-" ) | cl
   } else {
      print ("display "//ref1//" 1 z1="//z1//" z2="//z2//" zrange- fi-" ) | cl
   }
# display object image 2
   if (zscale) {	# DISPLAY using zscale+
      print ("display "//obj2//" 2 zscale+ zrange- fi-" ) | cl
   } else {
      print ("display "//obj2//" 2 z1="//z1//" z2="//z2//" zrange- fi-" ) | cl
   }
# display object image 3
   if (two_objects) {
      if (zscale) { 	# DISPLAY using zscale+
         print ("display "//obj3//" 3 zscale+ zrange- fi-" ) | cl
      } else {
         print ("display "//obj3//" 3 z1="//z1//" z2="//z2//" zrang- fi-" ) | cl
      }
   }

# Get offset between master reference and reference frames
   frame (1)
   print ("Select unconfused star for reference in frame  1")
   print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(skip)|")
   while (fscan(starco,xref,yref,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)
      if (key == "f")
         print ("Ref_coordinates= ",xref,yref)
      else if (key == "040") {			# 040 == spacebar
         imcntr (ref1, xref, yref) | scan (sjunk,sjunk,xref,sjunk,yref)
         print ("Submitted ref_coordinates= ",xref,yref)
         print (xref,yref,>> ref1pixco)
         tvmark(1,ref1pixco,autolog-,outimage="",commands="",
           mark="point",radii="0",lengths="0",font="raster",color=rcolor,
           label-,number+,nxoffset=0,nyoffset=0,pointsize=pointsize,
           txsize=1,interactive-)
         break
      } else if (key == "q") {
         print ("Offset between master and reference frames not found!")
         goto err
         break
      }
   }
   frame (2)
   print ("Select same star for object image in frame 2")
   print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(skip)|")
   while (fscan(starco,xin,yin,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)
      if (key == "f") {
         imcntr (obj2, xin, yin) | scan (sjunk,sjunk,xin,sjunk,yin)
         print ("Star_coordinates= ",xin,yin)
         print ("Offset for frame ",i,xin,yin)
      } else if (key == "040") {		# 040 == spacebar
         imcntr (obj2, xin, yin) | scan (sjunk,sjunk,xin,sjunk,yin)
         print ("Selected star_coordinates= ",xin,yin)
         print (xin,yin,>> obj2pixco)
         print ("Submitted offset for frame 2",xin,yin)
         tvmark(2,obj2pixco,autolog-,outimage="",commands="",
           mark="point",radii="0",lengths="0",font="raster",color=ocolor,
           label-,number+,nxoffset=0,nyoffset=0,pointsize=pointsize,txsize=1,
           interactive-)
         break
      } else if (key == "q") {
         print ("Offset between master and reference frames not found!")
         goto err
      } else {
         print("Unknown key: ",key," allowed = |f|spacebar|q|")
         beep
      }
   }
   if (two_objects) {
      frame (3)
      print ("Select same star for object image in frame 3")
      print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(skip)|")
      while (fscan(starco,xin,yin,wcs,command) != EOF) {
         if (substr(command,1,1) == "\\")
            key = substr(command,2,4)
         else
            key = substr(command,1,1)
         if (key == "f") {
            imcntr (obj3, xin, yin) | scan (sjunk,sjunk,xin,sjunk,yin)
            print ("Star_coordinates= ",xin,yin)
            print ("Offset for frame ",i,xin,yin)
         } else if (key == "040") {		# 040 == spacebar
            imcntr (obj3, xin, yin) | scan (sjunk,sjunk,xin,sjunk,yin)
            print ("Selected star_coordinates= ",xin,yin)
            print (xin,yin,>> obj3pixco)
            print ("Submitted offset for frame 3",xin,yin)
            tvmark(3,obj3pixco,autolog-,outimage="",commands="",
              mark="point",radii="0",lengths="0",font="raster",color=ocolor,
              label-,number+,nxoffset=0,nyoffset=0,pointsize=pointsize,txsize=1,
              interactive-)
            break
         } else if (key == "q") {
            print ("Offset between master and reference frames not found!")
            goto err
         } else {
            print("Unknown key: ",key," allowed = |f|spacebar|q|")
            beep
         }
      }
   }
   frame = 1
   print ("Continue finding stars in each frame")
   print ("Allowed keystrokes: |spacebar(find&use)|q(skip)|")
   frame(1)
   print ("Select unconfused star in reference frame 1")
   while  (fscan(starco,xin,yin,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)
      if (key == "040") {		# 040 == spacebar
         if (frame == 1) {
            imcntr (ref1, xin, yin) | scan (sjunk,sjunk,xin,sjunk,yin)
            print ("Selected star_coordinates= ",xin,yin)
            print (xin,yin,>> ref1pixco)
            tvmark(1,ref1pixco,autolog-,outimage="",commands="",
              mark="point",radii="0",lengths="0",font="raster",color=rcolor,
              label-,number-,nxoffset=0,nyoffset=0,pointsize=pointsize,
              txsize=1,interactive-)
            frame = 2
            frame(2)
            print ("Select same star in object frame 2")
         } else if (frame == 2) {
            imcntr (obj2, xin, yin) | scan (sjunk,sjunk,xin,sjunk,yin)
            print ("Selected star_coordinates= ",xin,yin)
            print (xin,yin,>> obj2pixco)
            tvmark(2,obj2pixco,autolog-,outimage="",commands="",
              mark="point",radii="0",lengths="0",font="raster",color=ocolor,
              label-,number-,nxoffset=0,nyoffset=0,pointsize=pointsize,
              txsize=1,interactive-)
            if (two_objects) {
               frame = 3  
               frame(3)
               print ("Select same star in object frame 3")
            } else {
               frame = 1  
               frame(1)
               print ("Select unconfused star in reference frame 1")
            }
         } else if (frame == 3) {
            imcntr (obj3, xin, yin) | scan (sjunk,sjunk,xin,sjunk,yin)
            print ("Selected star_coordinates= ",xin,yin)
            print (xin,yin,>> obj3pixco)
            tvmark(3,obj3pixco,autolog-,outimage="",commands="",
              mark="point",radii="0",lengths="0",font="raster",color=ocolor,
              label-,number-,nxoffset=0,nyoffset=0,pointsize=pointsize,
              txsize=1,interactive-)
            frame = 1  
            frame(1)
            print ("Select unconfused star in reference frame 1")
         }
      } else if (key == "q") {
         if (frame == 1) {
            print ("Star search complete")
            break
         } else {
            beep ; beep
            print ("Star search incomplete: need to finish on object image!")
         }
      } else {
         print("Unknown key: ",key," allowed = |f|spacebar|q|")
         beep
      }
   }

   join(ref1pixco,obj2pixco,delim=" ",missing="MISSING",maxchar=161,shortest+,
      verbose+,> out21_co)
   match("MISSING",out21_co,stop-,print-,meta-) | count() | scan (nin)
   if (nin != 0) {
      print ("coordinate mis-match in ",out21_co)
      goto err
   }
   print (out21_co,> colist)
type (colist)
   
#   geomap (out21_co,out21_db,xmin,xmax,ymin,ymax,function="polynomial",
#      xxorder=2,xyorder=2,xxterms+,yxorder=2,yyorder=2,yxterms+,
#      reject=0.,calctype="double",inter=interactive,graphics="stdgraph")
## NOTE: one should test goodeness of fit for more restricted fitgeometry
   geomap ("@"//colist,out21_db,xmin,xmax,ymin,ymax,function="polynomial",
      fitgeometry=geometry,transforms="",results=logfile,
      xxorder=2,xyorder=2,xxterms="half",yxorder=2,yyorder=2,yxterms="half",   
      reject=INDEF,calctype="double",inter=interactive,graphics="stdgraph")

   if (two_objects) {
      join(ref1pixco,obj3pixco,delim=" ",missing="MISSING",maxchar=161,
         shortest+,verbose+,> out31_co)
      match("MISSING",out31_co,stop-,print-,meta-) | count() | scan (nin)
      if (nin != 0) {
         print ("coordinate mis-match in ",out31_co)
         goto err
      }
      delete (colist, verify-)
      print (out31_co, > colist)
      geomap ("@"//colist,out31_db,xmin,xmax,ymin,ymax,function="polynomial",
         fitgeometry=geometry,transforms="",results=logfile,
         xxorder=2,xyorder=2,xxterms="half",yxorder=2,yyorder=2,yxterms="half",
         reject=INDEF,calctype="double",inter=interactive,graphics="stdgraph")
   }

   if (orient) {
      list1 = ref1pixco
      while (fscan(list1, line) != EOF) {
         if (stridx("#",line) != 1) {
            stat = fscan(line, xin, yin)
            if (xinvert)
#               xout = ncols - xin
               xout = ncols - xin + 1
            else
               xout = xin
            if (yinvert)
#               yout = nrows - yin
               yout = nrows - yin + 1
            else
               yout = yin
            print (xout,yout,>>ref1cotr)
         }
      }
      list1= ""; list1 = obj2pixco
      while (fscan(list1, line) != EOF) {
         if (stridx("#",line) != 1) {
            stat = fscan(line, xin, yin)
            if (xinvert)
               xout = ncols - xin + 1
            else
               xout = xin
            if (yinvert)
               yout = nrows - yin + 1
            else
               yout = yin
            print (xout,yout,>>obj2cotr)
         }
      }
      out21_dbtr   = out21base//"tr.geodb"
      out21_cotr   = out21base//"tr.geoco"
      join(ref1cotr,obj2cotr,delim=" ",missing="MISSING",maxchar=161,
         shortest+,verbose+,> out21_cotr)
      match("MISSING",out21_cotr,stop-,print-,meta-) | count() | scan (nin)
      if (nin != 0) {
         print ("coordinate mis-match in ",out21_cotr)
         goto err
      }
      delete (colist, verify-)
      print (out21_cotr, > colist)
      geomap("@"//colist,out21_dbtr,xmin,xmax,ymin,ymax,function="polynomial",
         fitgeometry=geometry,transforms="",results=logfile,
         xxorder=2,xyorder=2,xxterms="half",yxorder=2,yyorder=2,yxterms="half",
         reject=INDEF,calctype="double",inter=interactive,graphics="stdgraph")
      if (two_objects) {
         list1= ""; list1 = obj3pixco
         while (fscan(list1, line) != EOF) {
            if (stridx("#",line) != 1) {
               stat = fscan(line, xin, yin)
               if (xinvert)
                  xout = ncols - xin + 1
               else
                  xout = xin
               if (yinvert)
                  yout = nrows - yin + 1
               else
                  yout = yin
               print (xout,yout,>>obj3cotr)
            }
         }
         out31_dbtr   = out31base//"tr.geodb"
         out31_cotr   = out31base//"tr.geoco"
         join(ref1cotr,obj3cotr,delim=" ",missing="MISSING",maxchar=161,
            shortest+,verbose+,> out31_cotr)
         match("MISSING",out31_cotr,stop-,print-,meta-) | count() | scan (nin)
         if (nin != 0) {
            print ("coordinate mis-match in ",out31_cotr)
            goto err
         }
         delete (colist, verify-)
         print (out31_cotr, > colist)
         geomap("@"//colist,out31_dbtr,xmin,xmax,ymin,ymax,
            function="polynomial",fitgeometry=geometry,transforms="",
            results=logfile,xxorder=2,xyorder=2,xxterms="half",yxorder=2,
            yyorder=2,yxterms="half",reject=INDEF,calctype="double",
            inter=interactive,graphics="stdgraph")
      }
   }

   err:

# Finish up
   list1 = ""; list2 = ""
   delete (uniq//"*", verify-)

end
