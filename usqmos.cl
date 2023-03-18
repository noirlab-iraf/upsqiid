# USQMOS: 22JAN00 KMM expects IRAF 2.11Export or later
# ABUMOS: - produce standard irmosaic and complete database for later proceesing
# SQMOS:  25JUL98 KMM 
# ABUMOS: 25JUL98 KMM tailor sqmos to abu
# ABUMOS: 03MAR99 KMM fix parsing of file input
# USQMOS: 22JAN00 KMM modify for UPSQIID including channel offset syntax

procedure usqmos (input, output, nxsub, nysub)

string  input        {prompt="Input images"}
string  output       {prompt="Output image"}
int     nxsub        {prompt="Number of subrasters in x"}
int     nysub        {prompt="Number of subrasters in y"}

string  trim_section {"[*,*]",
                       prompt="Input image section written to output image"}
string	null_input   {"", prompt="List of missing input images"}
string	corner       {"ll", prompt="Starting corner for the mosaic"}
string  direction    {"row", prompt="Starting direction for the mosaic"}
bool	raster       {no, prompt="Raster scan?"}
bool    median       {no, prompt="Compute the median of each subraster?"}
string  median_section {"[*,*]",
                       prompt="Input image section used to compute median"}
bool    subtract     {no, prompt="Substract median from each subraster?"}
real	oval	     {10000., prompt="Mosaic border pixel values"}
int     nimcols      {INDEF,prompt="The number of columns in the output image"}
int     nimrows      {INDEF,prompt="The number of rows in the output image"}
string  opixtype     {"",prompt="Output pixel type?"}
bool    tran         {no, prompt="Apply image transform to mosaiced images?"}
string  task_tran    {"geotran",enum="imlintran|geotran",
                     prompt="transform task: imlintran|geotran"}
string  db_tran      {"", prompt="name of database file output by GEOMAP"}
string  co_tran      {"", prompt="name of coordinate file input to GEOTRAN"}
string  geom_tran    {"linear", prompt="GEOTRAN transformation geometry"}
bool    max_tran     {"yes",prompt="Offset GEOTRAN to save  maximum image"}
string  interp_tran  {"linear", prompt="GEO(IMLIN)TRAN interpolant"}
string  bound_tran   {"nearest", prompt="GEO(IMLIN)TRAN boundary"}
real    const_tran   {0.0,
                     prompt="GEO(IMLIN)TRAN constant boundary extension value"}
bool    flux_tran    {yes, prompt="conserve flux during GEO(IMLIN)TRAN"}
bool    save_tran    {no,
                     prompt="Save the intermediate GEO(IMLIN)TRANed images?"}
bool    save_dbmos   {no, prompt="Save the IRMOSAIC database file?"}
file    logfile      {"STDOUT", prompt="Log file name"}
file    infofile     {"", prompt="Output information file name"}

struct	*list1,*l_list
 
begin

       file    tmpimg, tmp1, tmp2, tmptran, info, l_log, dbinfo
       int     nx, ny, i, nin,stat,pos1b,pos1e,nim,ixs,iys,
               ncols,nrows,ncolsout,nrowsout,nxoverlap,nyoverlap,nsubrasters,
               nxlotrim,nxhitrim,nylotrim,nyhitrim
       real    xrot,yrot,xmag,ymag,xshift,yshift,xs,ys,fxs,fys,xoff,yoff,
               xmin,xmax,ymin,ymax
       string  in, in1, in2, out, mosout, img, junk, inmos, dbmos, color,
               uniq, sjunk,src,mos,soffset,mospos,sname,smedian,
               mos_name,mos_section,mos_corner,mos_order,mos_oval
       string  sxrot,syrot,sxmag,symag,sxshift,syshift,med_sec
       bool    old_irmosaic, choff
       int     nex
       string  gimextn, imextn, imname, imroot
       
# get IRAF global image extension
       show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
       nex     = strlen(gimextn)
       
       uniq      = mktemp ("_Tsqm")
       tmpimg    = uniq // "_img"
       tmp2      = mktemp ("tmp$sqm")
       tmp1      = mktemp ("tmp$sqm")
       tmptran   = mktemp ("tmp$sqm")
       dbinfo    = mktemp ("tmp$sqm")
       l_log     = mktemp ("tmp$sqm")

    # Get positional parameters
       in     = input
       mosout = output
       mos_name = mosout
       nx     = nxsub
       ny     = nysub
       dbmos  = "db"//mosout
       sxshift = "0.0"
       xshift = real(sxshift)
       ixs = 0
       fxs = 0.0
       xoff = 0.0
       syshift = "0.0"
       yshift = real(syshift)
       iys = 0
       fys = 0.0
       yoff = 0.0

       if (access(dbmos)) {
          print ("Mosaic output_file ",dbmos, " already exists!")
          goto skip
       }
       color = "null"; choff = no
       l_list = l_log

# check whether input stuff exists
   print (in) | translit ("", "@:", " ") | scan(in1,in2)
   if ((stridx("@",in) == 1) && (! access(in1))) {      # check input @file
      print ("Input file ",in," does not exist!")
      goto skip
   }
   sqsections (in,option="nolist")
   if (sqsections.nimages == 0) {                 # check input images
      print ("Input images in file ",in, " do not exist!")
      goto skip
   }
   if (access(mosout) || access(mosout//".imh")) { # check output collision
      print ("Output image ",mosout, " already exists!")
      goto skip
   }
 
    # establish ID of output info file
       if (infofile == "" || infofile == " " || infofile == "default")
          info = mosout//".dbmos"
       else
          info = infofile
       if (info != "STDOUT" && access(info)) {
          print ("Output_file ",info, " already exists!")
          goto skip
       } else
          print ("Output_file= ",info)
	
       if (null_input == " ") null_input = ""	# trap space
 
    # Expand input file name list removing the ".imh" extensions.
       sqsections (in, option="root",> tmp1)
       list1 = tmp1
       for (nin = 0; fscan (list1, img) != EOF; nin += 1) {
          i = strlen(img)
          if (substr(img,i-nex,i) == "."//gimextn)	# Strip off imextn
             img = substr(img,1,i-nex-1)
          print (img,>> tmpimg)  
          if (tran) {
             sname = "lt"//img//"_001" + nin
             print (sname,>> tmptran)
          }
       }
   # Get size of image subrasters
       hedit(img,"i_naxis1",".") |  scan(sjunk, sjunk, ncolsout)
       hedit(img,"i_naxis2",".") |  scan(sjunk, sjunk, nrowsout)
   # Recompute if trimmed
       print (trim_section) | translit ("", "[:,*]", "     ", >> l_log)
       if (fscan(l_list,nxlotrim,nxhitrim,nylotrim,nyhitrim) == 4) {
          nrowsout = nyhitrim - nylotrim + 1
          ncolsout = nxhitrim - nxlotrim + 1
       }
       list1 = ""; delete (tmp1, ver-, >& "dev$null")
       if (tran) {
   # Fetch info from GEOMAP database file
   # Extract values from infofile
          match ("begin",db_tran,meta-,stop-,print-) | scan(sjunk, cotran)
          match ("xmag",db_tran,meta-,stop-,print-) | scan(sjunk, sxmag)
          xmag = real(sxmag)
          match ("ymag",db_tran,meta-,stop-,print-) | scan(sjunk, symag)
          ymag = real(symag)
          match ("xrotation",db_tran,meta-,stop-,print-) | scan(sjunk, sxrot)
          xrot = real(sxrot)
          match ("yrotation",db_tran,meta-,stop-,print-) | scan(sjunk, syrot)
          yrot = real(syrot)
          match ("xshift",db_tran,meta-,stop-,print-) | scan(sjunk, sxshift)
          xs = real(sxshift)
          ixs = nint(xs)
          match ("yshift",db_tran,meta-,stop-,print-) | scan(sjunk, syshift)
          ys = real(syshift)
          iys = nint(ys)
          if (max_tran) {
             xoff = -int(xs)
             xmin = 1 + xoff; xmax = xmin + ncolsout
             yoff = -int(ys)
             ymin = 1 + yoff; ymax = ymin + nrowsout
          } else {
             xoff = 0.0
             xmin = INDEF; xmax = INDEF
             yoff = 0.0
             ymin = INDEF; ymax = INDEF
          }
          inmos = "@"//tmptran
          if (task_tran == "geotran") {
             print ("GEOTRAN dbase=",db_tran," transf=",co_tran,
                " geometry=",geom_tran," interp=",interp_tran,
                " xoffset=",xoff," yoffset=",yoff,>> logfile)
             geotran("@"//tmpimg,inmos,db_tran,co_tran,geometry=geom_tran,
                xin=INDEF,yin=INDEF,xshift=INDEF,yshift=INDEF,
                xout=INDEF,yout=INDEF,xmag=INDEF,ymag=INDEF,
                xrot=INDEF,yrot=INDEF,xmin=xmin,xmax=xmax,
                ymin=ymin,ymax=ymax,xscale=INDEF,yscale=INDEF,
                ncols=INDEF,nlines=INDEF,xsample=1.,ysample=1.,
                interpolant=interp_tran,boundary=bound_tran,constant=const_tran,
                fluxconserve=flux_tran,nxblock=256,nyblock=256,>> logfile)
          } else {
             print ("IMLINTRAN dbase=",db_tran,
                " xrot=",xrot, " yrot=",yrot," xmag=",xmag," ymag=",ymag,
                "    interp=",interp_tran, ,>> logfile)
             imlintran("@"//tmpimg,inmos,xrot,yrot,xmag,ymag,xin=INDEF,
                yin=INDEF,xout=INDEF,yout=INDEF,ncols=INDEF,nlines=INDEF,
                interpolant=interp_tran,boundary=bound_tran,constant=const_tran,
                fluxconserve+,>> logfile)
          }
       } else {
          xoff  = 0.0
          yoff  = 0.0
          sxrot = "INDEF"
          syrot = "INDEF"
          sxmag = "INDEF"
          symag = "INDEF"
          inmos = "@"//tmpimg
       }
       
       if (median) 	# Pass median_section to irmosaic
          med_sec = median_section
       else
          med_sec = ""

       irmosaic (inmos, mosout, dbmos, nx, ny, trim_section=trim_section,
          null_input=null_input,corner=corner,direction=direction,
          raster=raster,median_section=med_sec,subtract=subtract,
          nxover=-1, nyover=-1, nimcols=nimcols, nimrows=nimrows, oval=oval,
          opixtype=opixtype, verbose+,>> logfile)
       time (, >> logfile)
       print ("IRMOSAIC: done", >> logfile)

# Fetch info from IRMOSAIC database file
# Subterfuge to dodge INDEF
       delete (tmp2,verify-,>& "dev$null")
       translit (dbmos,"I","i",delete-,collapse-, > dbinfo)
       delete (l_log, verify-,>& "dev$null"); l_list = l_log
       list1 = dbinfo
# Pass IRMOSAIC database into MKMOS database
       for (nim = 0;fscan(list1,line) != EOF;nim += 1) {
          stat = fscan(line,sname,sjunk)
          if (sname == "section") {
             print ("#DB     trimsection     ",sjunk, >> info)
             print ("#DB     mediansection   ",sjunk, >> info)
          } else if (sname == "trim_section")
             print ("#DB     section         ",sjunk, >> info)
          else if (sname == "nsubrasters") {
             print ("#DB ", line, >> info)
             break
          } else
             print ("#DB ", line, >> info)
       }
 
       time() | scan(line)
       print("#DB  ",line," USQMOS:",>> info)
 
# log parameters to database file
       print("#DB     null_input      ",null_input,>> info)
       print("#DB     mosaic          ",mosout,>> info)
       print("#DB     median_compute  ",median,>> info)
       print("#DB     median_subtract ",subtract,>> info)
       print("#DBT    mos_transform   ",tran,>> info)
       if (tran) {
          print("#DBT    task_tran       ",task_tran,>> info)
          print("#DBT    db_tran         ",db_tran,>> info)
          print("#DBT    co_tran         ",cotran,>> info)
          print("#DBT    geom_tran       ",geom_tran,>> info)
          print("#DBT    xshift_tran     ",sxshift,>> info)
          print("#DBT    yshift_tran     ",syshift,>> info)
          print("#DBT    xmag_tran       ",sxmag,>> info)
          print("#DBT    ymag_tran       ",symag,>> info)
          print("#DBT    xrot_tran       ",sxrot,>> info)
          print("#DBT    yrot_tran       ",syrot,>> info)
          print("#DBT    interp_tran     ",interp_tran,>> info)
          print("#DBT    bound_tran      ",bound_tran,>> info)
          print("#DBT    const_tran      ",const_tran,>> info)
          print("#DBT    fluxconserve    ",flux_tran,>> info)
          print("#DBT    max_tran        ",max_tran,>> info)
          print("#DBT    xoffset_tran    ",xoff,>> info)
          print("#DBT    yoffset_tran    ",yoff,>> info)
       }

# Format for rest of IRMOSAIC database
# Note: format for IRMOSAIC database neither appends mos_section
#   nor transfers section from @list to image id
#	orih064[*,*]	mosorihs.imh[1029:1284,1:256]	INDEF INDEF
       for (nim = 1; fscan(list1,src,mos,smedian,soffset) != EOF; nim += 1) { 
# Strip off embedded image extension 
          pos1e = strlen(src)
          pos1b = stridx("[",src)-1
          if (pos1b > 0) {
             i = pos1b
#             if (substr(src,i-3,i) == ".imh")
#                src = substr(src,1,i-4)//substr(src,pos1b+1,pos1e)
             if (substr(src,i-nex,i) == "."//gimextn)	# Strip off imextn
                src = substr(src,1,i-nex-1)//substr(src,pos1b+1,pos1e)
          } else {
             i = pos1e
#            if (substr(src,i-3,i) == ".imh") src = substr(src,1,i-4)
             if (substr(src,i-nex,i) == "."//gimextn)	# Strip off imextn
                src = substr(src,1,i-nex-1)          

          }  
# Strip off embedded image extension
          pos1e = strlen(mos)
          pos1b = stridx("[",mos)-1
          if (pos1b > 0) {
             i = pos1b
#            if (substr(mos,i-3,i) == ".imh") {
#                mos = substr(mos,1,i-4)//substr(mos,pos1b+1,pos1e)
             if (substr(mos,i-nex,i) == "."//gimextn)	# Strip off imextn
                mos = substr(mos,1,i-nex-1)//substr(mos,pos1b+1,pos1e)
          } else {
             i = pos1e
#             if (substr(mos,i-3,i) == ".imh") mos = substr(mos,1,i-4)     
             if (substr(mos,i-nex,i) == "."//gimextn)	# Strip off imextn
                mos = substr(mos,1,i-nex-1)          

          }  
          if (soffset == "iNDEF") soffset = "0.0"
          if (smedian == "iNDEF") smedian = "0.0"
          mospos = "MOS_000" + nim
          print (mospos," ",src,"  ",mos,"  ",smedian," ",soffset,>> info)
       }

       if (!save_tran) {
          if (access(tmptran))
             imdelete("@"//tmptran,verify-, >& "dev$null")
       }    
 
skip:

       list1 = ""; l_list = ""
       if (!save_dbmos) delete (dbmos, ver-, >& "dev$null")
       delete (tmp1//","//tmp2//","//dbinfo//","//tmptran, ver-, >& "dev$null")
       imdelete (tmpimg, ver-, >& "dev$null")
       delete (uniq//"*", ver-, >& "dev$null")

end
