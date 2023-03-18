# WHICH: 23MAR93 determine which images combined at designated cursor position

procedure which (infofile)

string infofile     {prompt='COMBINED image output information file ".src"'}
bool   getoffset    {yes, prompt="Do you want to get frame offsets?", mode="q"}
bool   answer       {yes, prompt="Do you want to continue?", mode="q"}

struct  *list1,*l_list
imcur   *starco

begin

   int    i,stat,nim,maxnim,slen,slenmax,njunk,pos1b,pos1e,ncols,nrows,wcs,
          nxhi, nxlo, nyhi, nylo, nxhisrc, nxlosrc, nyhisrc, nylosrc,
          nxhimat,nxlomat,nyhimat,nylomat,nxmat0,nymat0
   real   xin,yin,fxs,fys
   string info,imname,sjunk,soffset,src,srcsub,mos,mossub,mat,matsub,key
   file   l_log,tmp1,matinfo
   struct command = ""
   struct line = ""

   info        = infofile
   l_log       = mktemp("tmp$icb")
   matinfo     = mktemp("tmp$icb")
   tmp1        = mktemp("tmp$icb")

   if (! access(info)) { 		# Exit if can't find info
      print ("Cannot access info_file: ",info)
      goto err
   }

# Transfer appropriate information from reference to output file
   match ("^COM",info,meta+,stop-,print-) | match ("COM_000",meta+,stop+,
      print-, > matinfo)


   print ("Indicate positions in combined image:")
   print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(quit)|")
   while (fscan(starco,xin,yin,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)
      if (key == "f")
         print ("Coordinates= ",xin,yin)
      else if (key == "040") {			# 040 == spacebar
         print ("Coordinates= ",xin,yin)
         list1 = matinfo
         while (fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
            nxmat0,nymat0,fxs,fys,soffset) != EOF) {

            pos1b = stridx("_",imname)+1
            nim = int(substr(imname,pos1b,strlen(imname)))

            nxlo = nxmat0 + nxlosrc ; nxhi = nxmat0 + nxhisrc
            nylo = nymat0 + nylosrc ; nyhi = nymat0 + nyhisrc

            matsub = "["//nxlo//":"//nxhi//","//nylo//":"//nyhi//"]"
            if ((xin >= nxlo) && (xin <= nxhi) && (yin >= nylo) &&
               (yin <= nyhi)) {
               print (imname," ",src," ",matsub," ",soffset)
            }
         }
      } else if (key == "q")
         break
      else {
         print("Unknown keystroke: ",key," allowed = |f|spacebar|q|")
         beep
      }
   }
# Finish up

err:  list1 = ""; l_list = ""
   delete (l_log//","//tmp1//","//matinfo,ver-,>& "dev$null")
   
end
