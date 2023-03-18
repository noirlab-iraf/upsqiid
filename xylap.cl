# XYLAP: 09NOV00 KMM expects IRAF 2.11Export or later
# XYLAP - produce database for matched image from mosaiced image
# XYLAP: 06APR94 KMM replace "type" with "concatenate"
# XYLAP: 22JUL94 KMM replace list-directed fscan from list with scan from pipe
#                   at key spots
# XYLAP: 25JUL94 KMM at format control via awk
# XYLAP: 08AUG94 KMM utilize printf for formatted output (instead of AWK)
# XYLAP: 15APR92 KMM
# XYLAP: 03JUN99 KMM add global image extension
# XYLAP: 23DEC99 KMM fix case where no extension on mosimage
# XYLAP: 09NOV00 KMM fix minor issues
#
## sqiid calls: getcenters linklaps xytrace transmat

procedure xylap (mosimage,basisfile)

string mosimage    {prompt="MOSAIC image name"}
string basisfile   {prompt="File produced by CENTER||IRMATCH"}
string linkfile    {"default",prompt="File with selected XY linkage paths"}
string mos_info    {"default",prompt="Images info file from IRMOSAIC|SQMOS"}

int    nx_sub      {INDEF,
                        prompt="Number of input images along x direction"}
int    ny_sub      {INDEF,
                        prompt="Number of input images along y direction"}
int    nxrsub      {INDEF,prompt="index of x reference subraster"}
int    nyrsub      {INDEF,prompt="index of y reference subraster"}
bool   guess       {no, prompt="Replace null links with average values?"}
bool   new_origin  {yes, prompt="Move origin to lower left corner?"}
# trim values applied to final image
string trimlimits  {"[0:0,0:0]",prompt="trim limits on the input subrasters"}

bool   verbose     {yes, prompt="Verbose output during LINKLAPS?"}
string outfile     {"",prompt="Output file name"}

bool   tran        {no, prompt="Request GEOTRAN mosimage before IMCOMBINE?"}
string db_tran     {"", prompt="name of database file output by GEOMAP"}
string geom_tran   {"linear", prompt="GEOTRAN transformation geometry"}
bool   max_tran    {yes, prompt="Offset GEOTRAN to save  maximum image?"}
string interp_tran {"linear", prompt="GEOTRAN interpolant"}
string bound_tran  {"nearest", prompt="GEOTRAN boundary"}
real   const_tran  {0.0, prompt="GEOTRAN constant boundary extension value"}
bool   flux_tran   {yes, prompt="Conserve flux upon GEOTRAN?"}
string interp_shift {"linear",enum="nearest|linear|poly3|poly5|spline3",
              prompt="IMSHIFT interpolant (nearest,linear,poly3,poly5,spline3)"}
string logfile     {"STDOUT",prompt="Logfile name"}

struct  *list1,*list2

begin

int    pos1e,pos1b,nim,nimref,stat,i,
       ncols,nrows,nxsub,nysub,nxoverlap,nyoverlap,nsubrasters,
       nxlotrim,nxhitrim,nylotrim,nyhitrim,
       nxhisrc,nxlosrc,nyhisrc,nylosrc,
       nxhimos,nxlomos,nyhimos,nylomos,
       nxmat0,nymat0,nxhimat,nxlomat,nyhimat,nylomat,
       ixs,iys,slen,slenmax,gridx,gridy
real   xs,ys,fxs,fys,xoff,yoff
string uniq,out,outbase,dbmos,basis,lap,cmd,sformat,soffset,img,links,
       sjunk,mos,mat,refmat,trim,src,mos_corner,mos_order,mos_name,baseid,imroot
file   info,ctrinfo,lapinfo,dbinfo,mosinfo,matinfo,tmp1,tmp2,task
bool   found
int    nex
string gimextn, imextn, imname

struct line = ""

img         = mosimage
basis       = basisfile
dbmos       = mos_info
links       = linkfile
      
# get IRAF global image extension
show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
nex     = strlen(gimextn)
        
uniq        = mktemp ("_Txyl")
lapinfo     = uniq // ".lap"
ctrinfo     = uniq // ".ctr"
task        = uniq // ".tsk"
dbinfo      = uniq // ".dbi"
mosinfo     = uniq // ".mos"
matinfo     = uniq // ".mat"
tmp1        = uniq // ".tm1"
tmp2        = uniq // ".tm2"

# check whether input stuff exists
if (dbmos == "" || dbmos == " " || substr(dbmos,1,3) == "def")
   dbmos = "default"
if (links == "" || links == " " || substr(links,1,3) == "def")
   links = "default"
   
i = strlen(img)
if (substr(img,i-nex,i) == "."//gimextn)	# Strip off imextn
   imroot = substr(img,1,i-nex-1)
else
   imroot = img
       
mos_name   = imroot
if (dbmos == "default") dbmos = mos_name//".dbmos"
baseid = "MOS_000"
if (! access(dbmos)) {
   print ("Information file ",dbmos," not found!")
   goto skip
} else if (tran && !access(db_tran)) {
   print ("GEOTRAN database file db_tran ",db_tran," not found!")
   goto skip
} else if (!access(basis)) {
   print ("Basis file ",basis," does not exist!")
   goto skip
}

   # establish ID of output info file
      if (outfile == "" || outfile == " " || outfile == "default") {
         outbase = mos_name
         out = mos_name//".xylap"
      } else {
         outbase = outfile
         out = outfile
      }
      if (out != "STDOUT" && access(out)) {
         print ("Output_file ",out, " already exists!")
         goto skip
      } else
         print ("Output_file= ",out)

# is it an IRMOSIAC or an SQMOS file?
      match ("^MOS",dbmos,meta+,stop-,print-, > tmp1)
      count (tmp1) | scan(nim)
      if (nim > 0)  		# it's an SQMOS file
         lap = "center"
      else
         lap = "irmatch"

      if (lap == "center") {

## GETCENTERS -- Procedure to compute the shifts for each subraster.
#  procedure getcenters(infofile,ctrfile)
#  string infofile    {prompt="Information file produced by MKMOS"}
#  string ctrfile     {prompt="Output file produced by CENTER"}
#  string  outfile    {"", prompt="Output information filename"}

         print ("GETCENTERS:")
         cmd = "getcenters "//dbmos//" "//basis//" out="//ctrinfo
         if (nx_sub == INDEF)
            cmd = cmd//" nx_sub=INDEF"
         else
            cmd = cmd//" nx_sub="//nx_sub
         if (ny_sub == INDEF)
            cmd = cmd//" ny_sub=INDEF"
         else
            cmd = cmd//" ny_sub="//ny_sub
         print (cmd, >> logfile)
         print (cmd) | cl

         if (links == "default") {	# Use preset linkages

## LINKLAPS determines origins for mosaic frames using output of GETCENTERS
##    and via row and column pathways
#  procedure linklaps (infofile)
#  string infofile    {prompt="Information file produced by GETLAPS"}
#  int    nx_sub      {INDEF,prompt="Number of input images along x direction"}
#  int    ny_sub      {INDEF,prompt="Number of input images along y direction"}
#  int    nxrsub      {INDEF,prompt="index of x reference subraster"}
#  int    nyrsub      {INDEF,prompt="index of y reference subraster"}
#  string trimlimits  {"[0:0,0:0]",prompt="trim limits on the input subrasters"}
#  bool	  verbose     {no,prompt="verbose output?"}
#  bool	  passmisc    {yes,prompt="pass thru misc output from GETLAPS?"}
#  file   outfile     {"", prompt="Output information file name"}

            print ("LINKLAPS:")
            cmd = "linklaps  "//ctrinfo//" out="//lapinfo//
               " verbose="//verbose//" pass+ trimlimits="//trimlimits//
               " guess="//guess
            if (nx_sub == INDEF)
               cmd = cmd//" nx_sub=INDEF"
            else
               cmd = cmd//" nx_sub="//nx_sub
            if (ny_sub == INDEF)
               cmd = cmd//" ny_sub=INDEF"
            else
               cmd = cmd//" ny_sub="//ny_sub
            if (nxrsub == INDEF)
               cmd = cmd//" nxrsub=INDEF"
            else
               cmd = cmd//" nxrsub="//nxrsub
            if (nyrsub == INDEF)
               cmd = cmd//" nyrsub=INDEF"
            else
               cmd = cmd//" nyrsub="//nyrsub
            print (cmd,>> logfile)
            print (cmd) | cl

         } else {			# Use designated linkages

## XYTRACE determines origins for mosaic frames using output of GETCENTERS
##    and arbirary pathways
# procedure xytrace (infofile,pathways)
#  file   infofile    {prompt="File produced by GETCENTERS"}
#  string linkfile    {prompt="File with selected XY linkage paths"}
#  int    nx_sub      {INDEF,prompt="Number of input images along x direction"}
#  int    ny_sub      {INDEF,prompt="Number of input images along y direction"}
#  int    nxrsub      {INDEF,prompt="index of x reference subraster"}
#  int    nyrsub      {INDEF,prompt="index of y reference subraster"}
#  string trimlimits  {"[0:0,0:0]",prompt="trim limits on the input subrasters"}
#  bool   guess       {no,prompt="Guess missing links from average values?"}
#  bool	  verbose     {no,prompt="verbose output?"}
#  bool	  passmisc    {yes,prompt="pass thru misc output from GETLAPS?"}
#  file   outfile     {"", prompt="Output information file name"}
   
            print ("XYTRACE:")
            cmd = "xytrace  "//ctrinfo//" "//links//" out="//lapinfo//
               " verbose="//verbose//" pass+ trimlimits="//trimlimits//
               " guess="//guess
            if (nx_sub == INDEF)
               cmd = cmd//" nx_sub=INDEF"
            else
               cmd = cmd//" nx_sub="//nx_sub
            if (ny_sub == INDEF)
               cmd = cmd//" ny_sub=INDEF"
            else
               cmd = cmd//" ny_sub="//ny_sub
            if (nxrsub == INDEF)
               cmd = cmd//" nxrsub=INDEF"
            else
               cmd = cmd//" nxrsub="//nxrsub
            if (nyrsub == INDEF)
               cmd = cmd//" nyrsub=INDEF"
            else
               cmd = cmd//" nyrsub="//nyrsub
            print (cmd,>> logfile)
            print (cmd) | cl

         }

      } else if (lap == "irmatch") {

         print ("IRMATCH: basis_info= ",basis)
   # Extract values from infofile
         match ("^\#DB",dbmos,meta+,stop-,print-, > dbinfo)
         match ("^MOS",dbmos,meta+,stop-,print-, > mosinfo)
   #      match ("trimsection",dbmos,meta-,stop-,print-, >> l_log)
   #      if (fscan(l_list, sjunk, sjunk, mos_section) == EOF) {
   #         l_list = l_log
   #         match ("section",dbmos,meta-,stop-,print-, >> l_log)
   #         stat = fscan(l_list, sjunk, sjunk, mos_section)
   #      }
         match ("ncols",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, ncols)
         match ("nrows",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, nrows)
         match ("nxsub",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, nxsub)
         match ("nysub",dbinfo,meta-,stop-,print-) | scan(sjunk, sjunk, nysub)
         match ("nxoverlap",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, nxoverlap)
         match ("nyoverlap",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, nyoverlap)
         match ("corner",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, mos_corner)
         match ("order",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, mos_order)
         match ("nsubrasters",dbinfo,meta-,stop-,print-) |
            scan(sjunk, sjunk, nsubrasters)
         ixs = 0
         iys = 0
   # Generate file relating path position to grid position
#         print("mkpathtbl 1 "//nsubrasters//" "//nxsub//" "//nysub//
#            " "//mos_order//" "//mos_corner//" sort- >> "//tmp2) | cl
         mkpathtbl(1,nsubrasters,nxsub,nysub,mos_order,mos_corner,sort-,
            format-,> tmp2)
    # Find information on reference subraster
         list1 = basis; list2 = tmp2
         while((fscan(list1,mos,trim,xs,ys,mat,soffset) != EOF) &&
            (fscan(list2,nim,gridx,gridy) != EOF)) {
            if (xs == 0.0 && ys == 0.0) {
               nimref = nim
               nxrsub = gridx
               nyrsub = gridy
               break
            }
         }
         slenmax = 0
         list1 = basis; list2 = tmp1
         while((fscan(list1,mos,trim,xs,ys,mat,soffset) != EOF) &&
            (fscan(list2,nim,gridx,gridy) != EOF)) {
            print (mos) | translit ("", "[:,]", "    ") |
               scan(src,nxlomos,nxhimos,nylomos,nyhimos)
            print (trim) | translit ("", "[:,]", "    ") |
               scan(nxlotrim,nxhitrim,nylotrim,nyhitrim)
            print (mat) | translit ("", "[:,]", "    ") |
               scan(sjunk,nxlomat,nxhimat,nylomat,nyhimat)
            if (substr(src,i-nex,i) == "."//gimextn)	# Strip off imextn
               imroot = substr(src,1,i-nex-1)
            src = imroot//"["//nxlomos//":"//nxhimos//","//
               nylomos//":"//nyhimos//"]"
            mat = "MAT_000" + nim
            xs = nxlomos - 1.0 + xs + nxoverlap*(gridx-nxrsub)
            ys = nylomos - 1.0 + ys + nyoverlap*(gridy-nyrsub)
            nxmat0 = nint(xs)
            nymat0 = nint(ys)
            fxs = xs - nxmat0
            fys = ys - nymat0
            fxs = 0.01*real(nint(100.0*fxs))
            fys = 0.01*real(nint(100.0*fys))
            slen = strlen(src); if (slen > slenmax) slenmax = slen
            print (mat," ",src," ",nxlotrim,nxhitrim,nylotrim,nyhitrim,
               nxmat0,nymat0,fxs,fys,soffset,>> matinfo)
         }  
      }

   # Get date and print date
      time() | scan(line)
      list1 = ""; delete (tmp1, ver-, >& "dev$null")
   # log parameters to database file
      print("#DBG ",line," GETMATCH:",>> lapinfo)
      print("#DBG    basis_info      ",basis,>> lapinfo)
      print("#DBG    lap_basis       ",lap,>> lapinfo)
      print("#DBG    trimlimits      ",trimlimits,>> lapinfo)
      if (lap == "irmatch") { # log parameters to database file
         print("#DBG    nxrsub          ",nxrsub,>> lapinfo)
         print("#DBG    nyrsub          ",nyrsub,>> lapinfo)
         print("#DBG    xoffset         ",xoff,>> lapinfo)
         print("#DBG    yoffset         ",yoff,>> lapinfo)
         concatenate (dbinfo//","//mosinfo,lapinfo,append+)
   # Fancy format
         sformat = '%-7s %'//-slenmax//
            's %3d %3d %3d %3d %4d %4d %5.2f %5.2f %9.3f\n'
         list1 = ""; list1 = matinfo
         for (i = 0; fscan(list1,img,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,xs,ys,soffset) != EOF; i += 1) {
            printf(sformat,img,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
               nxmat0,nymat0,xs,ys,real(soffset),>> lapinfo)
         }
      }

# translate database to new format:
      cmd = "transmat "//lapinfo//" "//out//" tran="//tran
      if (tran) {
         cmd = cmd//" db_tran="//db_tran//" geom_tr="//geom_tran//
            " max_tran="//max_tran//" interp_tr="//interp_tran//
            " bound="//bound_tran//" const="//const_tran//
            " flux="//flux_tran
      }
      cmd = cmd//" interp_sh="//interp_shift//" new="//new_origin
      print (cmd, >> logfile)
      print (cmd) | cl
      if (verbose) {		# capture comments and append to end
         match ("^\#DB",lapinfo,meta+,stop+,print-) |
            match ("^MOS",,meta+,stop+,print-) |
            match ("^COM",,meta+,stop+,print-,>> out)
      }

   # Finish up
      skip:
      list1 = ""; list2 = ""
      delete (uniq//"*", verify=no)

   end
