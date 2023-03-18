# SHOW4: 18JUN98 KMM
# SHOW4 - display 4 (sky-subtracted) sqiid frames
# SHOW4: 05OCT93 KMM
#                    Assumes imt800 for proper operation
# SHOW4: 18JUN98 KMM replace access with imaccess where appropriate

procedure show4  (first_image, frame) 

string  first_image  {prompt="First image in sequentially numbered images"}
int     frame        {prompt="Display frame #"}
string  jsky         {"null", prompt="J sky frame"}
string  hsky         {"null", prompt="H sky frame"}
string  ksky         {"null", prompt="K sky frame"}
string  lsky         {"null", prompt="L sky frame"}
bool    orient       {no, prompt="Orient N up and E left?"}
bool    zscale       {yes, prompt="automatic zcale on each frame?"}
string  ztrans       {"linear", prompt="intensity transform: log|linear|none"}
real    z1           {0.0, prompt="minimum intensity"}
real    z2           {1000.0, prompt="maximum intensity"}

struct	*l_list
 
begin

   file    l_log, simg
   int     i, nim,stat
   real    x,y
   bool    erase
   string  first, img, sky, uniq, imroot, extn

   uniq   = mktemp ("_Tsh4")
   simg   = uniq // ".img"
   l_log  = mktemp ("tmp$sh4")

# Get positional parameters
   first  = first_image
   nim = frame
   sqparse(first_image)
   imroot = sqparse.root
   extn   = sqparse.extn 

   print (imroot//"j."//extn, >> l_log)
   print (imroot//"h."//extn, >> l_log)
   print (imroot//"k."//extn, >> l_log)
   print (imroot//"l."//extn, >> l_log)
   l_list = l_log
# J channel
# H channel
# K channel
   for (i=1; (fscan(l_list, img) != EOF); i += 1) {
      if (! imaccess(img)) next
      switch (i) {
         case 1: {
            x = 0.25; y = 0.75
            erase = yes
            sky = jsky
         }
         case 2: {
            x = 0.75; y = 0.75
            erase = no
            sky = hsky
         }
         case 3: {
            x = 0.25; y = 0.25
            erase = no
            sky = ksky
         }
         case 4: {
            x = 0.75; y = 0.25
            erase = no
            sky = lsky
         }
     }
     if (sky == "" || sky == " " || sky == "null") 
        imcopy (img, simg, verbose-) 
     else {
        if (! imaccess(sky)) {
           print ("Sky image: ",sky," not found!")
           goto skip
        } else
          imarith (img,"-",sky,simg,pix="real",calc="real",hpar="")
     }
     if (orient) {
        switch (i) {
           case 1: {
           }
           case 2: {
              imcopy(simg//"[*,-*]",simg)
           }
           case 3: {
              imtranspose(simg//"[*,-*]",simg)
           }
           case 4: {
           }
        }
     }

     if (zscale) {
        display(simg,nim,xc=x,yc=y,erase=erase,zs+,zr-,fill-,ztrans=ztrans)
     } else {
        display(simg,nim,xc=x,yc=y,erase=erase,zs-,zr-,fill-,ztrans=ztrans,
          z1=z1,z2=z2)
     }
     imdelete (simg,verify-,>& "dev$null")
        
  }

skip: 

  delete (l_log,ver-,>& "dev$null")
  imdelete (simg,verify-,>& "dev$null")

end
