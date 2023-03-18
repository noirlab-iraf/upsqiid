# CHLIST 22OCT02 KMM expects IRAF 2.11Export or later
# CHLIST - produces list of images of form id### 
#    where id is an alphanumeric base id and ### is an  integers:
#    starting at first_image, increments of delta, number images in final list
#    e.g.  deltalist dat001 3 delta=3 produces
#        dat001
#        dat004
#        dat007
# CHLIST: 09SEP93 KMM incorporates id_color indicator to all additional
#                        choices for color naming conventions
# CHLIST 21FEB94 KMM
# CHLIST 25JUL98 KMM  incoporates "none" as id_color choice
# CHLIST 22OCT02 KMM  fix for FITS

procedure chlist (first_image,number)

string  first_image {prompt="First image in sequentially numbered images"}
int     number      {prompt="Number of images in output list"}
int     delta       {1,prompt=""}
string  id_color    {"none",
             prompt="Location of color indicator? (end|none|predot|seq)",
             enum="end|none|predot|sequence" }
#   predot ==     FIRE mode: root || [jhkl] || .number
#      end == WILDFIRE mode: root || (.) number || [jhkl]
#      seq == sequence mode: root || number; number increments between colors

begin

int    nim,i,max,off
string first,name,name0,color,snim,in,img
int    nex
string imname, gimextn, imextn, imroot, chroot
file   tmp1

img = first_image
max = number

# get IRAF global image extension
show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
nex     = strlen(gimextn)

# Strip off imextn
#if (substr(img,strlen(img)-nex,strlen(img)) == "."//gimextn ) {
#  imroot = substr(img,1,strlen(img)-nex-1)
#} else
#  imroot = img

imextn = gimextn	# set to global if not explicit in input name
sqparse (img, verbose+) | scan (imroot,first,color,imextn)
if (imextn != "fits" && imextn != "imh") {
   imextn = gimextn
}
if (id_color == "end") {
   for (nim=1; nim <= max; nim += 1) {
       imname = first + (nim-1)*delta
       print (imname//color//"."//imextn)
   }
} else {
   for (nim=1; nim <= max; nim += 1) {
       imname = imroot + (nim-1)*delta
       print (imname//"."//imextn)
   }
}
#i = strlen(imroot)
#if (id_color == "end") {
#   color = substr(imroot,i,i)
#   first = substr(imroot,1,(i-1))	# drop [jhkl]
#   for (nim=1; nim <= max; nim += 1) {
#       name = first + (nim-1)*delta
#       print (name//color//"."//gimextn)
#   }
#} else {
#   for (nim=1; nim <= max; nim += 1) {
#       name = imroot + (nim-1)*delta
#       print (name//"."//gimextn)
#   }
#}

end
