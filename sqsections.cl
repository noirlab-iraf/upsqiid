# SQSECTIONS: 17JAN00 KMM expects IRAF 2.11Export or later
# SQSECTIONS: -- expand SECTIONS to include channel indirection
# SQSECTIONS: 17JAN00 KMM
         
procedure sqsections (images)

string images      {prompt="Image template"}

# Model: image_name == imroot//seq_mark//seq_number//channel_id//"."//imextn
#      where seq_id     == seq_mark//seq_number//channel_id      		    
#            seq_mark   == ""|"."|"_"
#            seq_number == "00|000|0000"  (number of "0"s is number of digits)
#            channel_id == ""|"j"|"h"|"k"|"l"  (SQIID)
#            imextn     == "imh|fits|fit"
#      optional appended ":"//offset indicates use offset for channel_id

string option    {"root", prompt="Option (nolist, fullname, root, section)",
                      enum = "nolist|fullname|root|section"}
int    nimages   {"", prompt="Number of images in template"}
string ch_id     {"", prompt="Returned channel_id (jhkl)"}

struct *list1

begin

string imname, revimname, imlist, extn, root, subsec, alt_section, alt_ch
int    ilen, ipos, ic, chpos, altpos, secpos1, secpos2
file   imfile

imfile   = mktemp ("tmp$sqp")

# Get query parameter.

imlist = images
ilen      = strlen(imlist)

# Extract image section
secpos1 = stridx("[", imlist)
secpos2 = stridx("]", imlist)
if (secpos1 != secpos2) {
   alt_section = substr(imlist,secpos1,secpos2)
   imlist      = substr(imlist,1,secpos1-1)//substr(imlist,secpos2+1,ilen)  
   ilen        = strlen(imlist)
} else {
   alt_section = ""
}

# Check for channel offset indicator ":"

altpos  = stridx(":",imlist)
if (altpos != 0) {	# If colon exists extract channel offset from input
   alt_ch = substr(imlist,altpos+1,ilen)
   imlist = substr(imlist,1,altpos-1)
   ilen   = strlen(imlist)
} else {
   alt_ch = ""
}

sections (imlist, option="fullname",> imfile)

list1 = imfile
while (fscan(list1,imname) != EOF) {

   ilen = strlen(imname)
# Extract image section
   secpos1 = stridx("[", imname)
   secpos2 = stridx("]", imname)
   if (secpos1 != secpos2) {
      subsec = substr(imname,secpos1,secpos2)
      imname = substr(imname,1,secpos1-1)//substr(imname,secpos2+1,ilen)  
      ilen   = strlen(imname)
   } else {
      subsec = ""
   }

# Reverse filename string character by character --> revname.
   ilen      = strlen(imname)
   revimname = ""
   for (ic=ilen; ic>=1; ic-=1) {
       revimname = revimname // substr(imname,ic,ic)
   }

# Look for the first period in the reversed name.

   ipos = stridx(".",revimname)

# If period exists, break filename into root and extension.  Otherwise,
# return null values for the extension, and the whole file name for the root.

   if (ipos != 0) {
      root = substr(imname,1,ilen-ipos)
      extn = "."//substr(imname,ilen-ipos+2,ilen)
   } else {
      root = imname
      extn = ""
   }
   
# Check for channel indicator

   if (stridx("hjkl",substr(revimname,ipos+1,ipos+1)) != 0) {
      root  = substr(imname,1,ilen-ipos-1)
      ch_id = substr(revimname,ipos+1,ipos+1)
   }
   
# use alt_ch if available to override ch_id
   
   if (alt_ch != "") ch_id = alt_ch 
   
# use alt_section if available to override subsec in list

   if (alt_section != "") subsec = alt_section
   
   if (option == "fullname") {
      print (root//ch_id//extn//subsec)
   } else if (option == "root") {
      print (root//ch_id//extn)
   } else if (option == "section") {
      print (subsec)
   }
}

nimages = sections.nimages

# Finish up
skip:

list1 = ""

delete (imfile,ver-,>& "dev$null")
end
