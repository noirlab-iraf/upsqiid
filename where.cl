# WHERE 12APR96  KMM
## WHERE outline the individual pieces within a composite image

procedure where (infofile,d_frame)

file   infofile    {prompt="Information file produced by MKMATCH"}
int    d_frame     {prompt="Displayed frame #"}
string frame_nums  {"all",
                       prompt='Selected frame numbers: "all"="all"', mode="q"}
bool   trim      {no,
                     prompt="Outline trimmed (yes) or nontrimmed (no) images"}
int    ocolor    {209, prompt="Outline color"} # color 209 = magenta
bool   glabel    {yes, prompt="Label grids?"}
bool   answer    {yes, prompt="Do you want to continue?", mode="q"}
bool   verbose   {yes, prompt="Verbose output?"}
bool   draw_it   {yes,
                   prompt="Draw locations within composite image on display"}
file   logfile   {"STDOUT", prompt="Log file name"}

struct  *list1, *list2

begin
   int    i,stat,nim,maxnim,slen,slenmax,njunk,pos1b,pos1e,ncols,nrows,nimat,
          nxhi, nxlo, nyhi, nylo, nxhisrc, nxlosrc, nyhisrc, nylosrc,
          nxhimat,nxlomat,nyhimat,nylomat,nxmat0,nymat0
   int    xboxlo,yboxlo,xboxhi,yboxhi
   real   xin,yin,fxs,fys
   string info,imname,src,srcsub,mos,mossub,mat,matsub,key,soffset
   string uniq,slist,sjunk,image_nims
   file   cominfo,cmdfile,cofile,nimlist,tmp1,tmp2

   uniq        = mktemp ("_Tmma")
   cominfo     = mktemp ("tmp$mrk")
   cmdfile     = mktemp ("tmp$mrk")
   nimlist     = mktemp ("tmp$mrk")
   cofile      = mktemp ("tmp$mrk")
   tmp1        = mktemp ("tmp$mrk")
   tmp2        = mktemp ("tmp$mrk")

   info = infofile
   # Extract values from infofile
   fields (info,1,lines="1-9999",quit-,print-) |
       match ("^COM","",meta+,stop-,print-) |
       sort ("STDIN", col=1,numeric-,ignore+,reverse-, > tmp1)
   tail (tmp1,nlines=1) | scan (imname)
   pos1b = stridx("_",imname)+1
   maxnim = int(substr(imname,pos1b,strlen(imname)))
   match ("^COM",info,meta+,stop-,print-, > cominfo)
   if (verbose)
      type (cominfo)

   while (answer) {
      print ("Enter COM# range in combined image:")
      print ("   Special values: |*(all)|0(quit)|")
      image_nims = frame_nums
      list1 = ""; delete (nimlist,verify-,>& "dev$null")
      expandnim(image_nims,ref_nim=-1,max_nim=maxnim,>> nimlist)
      list1 = nimlist
      delete (cofile//","//cmdfile,verify-,>& "dev$null")
      while (fscan(list1,nim) != EOF) {
         list2 = cominfo
         while (fscan(list2,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,fxs,fys,soffset) != EOF) {

            pos1b = stridx("_",imname)+1
            nimat = int(substr(imname,pos1b,strlen(imname)))
            if (nimat != nim) next

            nxlo = nxmat0 + nxlosrc ; nxhi = nxmat0 + nxhisrc
            nylo = nymat0 + nylosrc ; nyhi = nymat0 + nyhisrc
            xboxlo = nxlo ; xboxhi = nxhi
            yboxlo = nylo ; yboxhi = nyhi

            matsub = "["//nxlo//":"//nxhi//","//nylo//":"//nyhi//"]"
            print (imname," ",src," ",matsub," ",soffset, >> logfile)
            print (xboxlo, yboxlo, ocolor, " b", >> cmdfile)
            print (xboxhi, yboxhi, ocolor, " b", >> cmdfile)
            print (xboxlo, yboxlo, nim, >> cofile)
            break
         }
      }
      print (xboxhi, yboxhi, ocolor, " q", >> cmdfile)
      if (draw_it) {
         tvmark(d_frame,"",autolog-,outimage="",commands=cmdfile,
           mark="point",radii="0",lengths="0",font="raster",color=ocolor,
           label-,number-,nxoffset=0,nyoffset=0,pointsize=3,txsize=1,
           interactive-)
         if (glabel) {
            tvmark(d_frame,cofile,autolog-,outimage="",commands="",
              mark="point",radii="0",lengths="0",font="raster",color=ocolor,
              label+,number-,nxoffset=0,nyoffset=0,pointsize=3,txsize=1,
              interactive-)
         }
      }
   }

err:

# Finish up
   delete (tmp1//","//tmp2//","//cofile//","//cmdfile,verify-,>& "dev$null")
   delete (cominfo//","//nimlist,verify-,>& "dev$null")
   delete (uniq//"*", verify=no, >& "dev$null")

end
