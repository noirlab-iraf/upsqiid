# CHORIENT: 12AUG00 KMM expects IRAF 2.11Export or later
# CHORIENT: 03MAR00 KMM sky orients images from SQIID image channels
#                                
# imtranspose [*,-*] rotate 90 counter-clockwise
# imtranspose [-*,*] rotate 90 clockwise
# imcopy      [-*,-*] rotate 180
# imcopy      [-*,*] flip about (vertical) y-axis
# imcopy      [*,-*] flip about (horizontal) x-axis
#                                
# The channels are oriented as follows (03MAR00 JHK; 12AUG00 JHKL):
#
#                   J           H           K          L
#
#                   W           N           S          E	
#                 S   N       W   E       E   W      N   S
#                   E           S           N          W

procedure chorient (image)

string image     {prompt="Image name"}
string channels  {".", 
   prompt='Orient these channels (eg, "j", "jhk"; "." == image only)?'}
bool   verbose   {no,  prompt="Print results"}
string newid     {"",  prompt="ID append to existing name?"}

struct *list1
begin

string extn, chimage, chid, reimage, color, im_ch
string gimextn, imextn, imname, imroot
int    ich, nin, nex
file   chlist

# get IRAF global image extension
show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
nex     = strlen(gimextn)

chlist = mktemp ("tmp$cho")

imname = image
sqparse (imname)
   extn   = sqparse.extn
   imroot = sqparse.root
   chid   = sqparse.ch_id
   
if (channels == "." || channels == "" || channels == " ") {
   color = chid
   if (color == "") {
      print ("No channel id found for ",imname)
      goto skip 
   }   
} else {     
   print (channels) | translit ("", "^HJKLhjkl\n",del+,collapse+) |
      translit ("","HJKL","hjkl",del-,collapse+) | scan (color)
}

nin = strlen(color)
for (ich = 1; ich <= nin; ich += 1) {
   print (substr(color,ich,ich), >> chlist)
}

list1 = chlist
while (fscan(list1,chid) != EOF) {
   
   chimage = imroot//chid
   if (newid == " " || newid == "")
      reimage = chimage
   else  
      reimage = imroot//newid//chid
   if (extn != "") {
      chimage = chimage//"."//extn
      reimage = reimage//"."//extn
   }  
   if (!imaccess(chimage)) {
      print ("Image ", chimage, " not found!")
      next
   }      
   imgets (chimage, "ORIENTED", >& "dev$null")
   if (imgets.value == "0" && imgets.value != "no") {
      imgets (chimage, "CHANNEL", >& "dev$null")
      im_ch = substr(imgets.value,1,1)
      print ("Orienting image ",chimage," with imheader channel ",im_ch)
      if (chid == "j") {
 	 imcopy (chimage//"[*,-*]", reimage, verbose-)     
         imtranspose (reimage//"[*,-*]", reimage)
      }
      if (chid == "h") {
#march         imtranspose (chimage//"[*,-*]", reimage)
         imcopy (chimage//"[-*,*]", reimage, verbose-)
      }
      if (chid == "k") {
         imcopy (chimage//"[*,-*]", reimage, verbose-)
      }
      if (chid == "l") {
       	 imcopy (chimage//"[-*,*]", reimage, verbose-)     
         imtranspose (reimage//"[*,-*]", reimage)
      }
      hedit (reimage, "ORIENTED", "yes", add+, update+, verify-, >& "dev$null")
   } else {
      print ("Image ",chimage, " was already oriented!")
   }
}

skip:

list1 = ""
delete (chlist, verify-, >& "dev$null")

end
