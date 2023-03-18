# SQPARSE: 17JAN00 KMM expects IRAF 2.11Export or later
# SQPARSE: -- separate out image root, channel_id, section, extension, offset
# SQPARSE: 16OCT02 KMM add parsing for seqnum and imroot
#                      add output option

procedure sqparse (image)

string image      {prompt="Image name"}

# Model: image_name == imroot//seq_mark//seq_number//channel_id//"."//imextn
#      where seq_id     == seq_mark//seq_number//channel_id      		    
#            seq_mark   == ""|"."|"_"
#            seq_number == "00|000|0000"  (number of "0"s is number of digits)
#            channel_id == ""|"j"|"h"|"k"|"l"  (SQIID)
#            imextn     == "imh|fits|fit"
#      optional appended ":"//offset indicates use offset for channel_id

string root      {"", prompt="Returned filename root sans channel"}
string chroot    {"", prompt="Returned filename root with channel"}
string ch_id     {"", prompt="Returned channel_id (jhkl)"}
string alt_ch    {"", prompt="Returned alternative channel(s)"}
string extn	 {"", prompt="Returned image extension"}
string section   {"", prompt="Returned image section"}
string number_id {"000", prompt="image number template results image?"}
string option    {"full", prompt="Printed output option",
                   enum="seq|full"}
bool   verbose   {no, prompt="Print results"}

begin

string imname, revimname, seqnum, imroot
int    ilen, ipos, ic, chpos, altpos, secpos1, secpos2
#file   imfile, rootfile, secfile

#rootfile = mktemp ("tmp$sqp")
#secfile  = mktemp ("tmp$sqp")
#imfile   = mktemp ("tmp$sqp")

# Get query parameter.

imname = image
ilen   = strlen(imname)

# Extract image section
secpos1 = stridx("[", imname)
secpos2 = stridx("]", imname)
if (secpos1 != secpos2) {
   section = substr(imname,secpos1,secpos2)
   imname  = substr(imname,1,secpos1-1)//substr(imname,secpos2+1,ilen)
} else {
   section = ""
}

# Check for channel offset indicator, first colon in reversed name

altpos  = stridx(":",imname)
if (altpos != 0) {	# If colon exists extract channel offset from filename
   alt_ch = substr(imname,altpos+1,ilen)
   imname = substr(imname,1,altpos-1)
} else {
   alt_ch = ""
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
   chroot = substr(imname,1,ilen-ipos)
   extn   = substr(imname,ilen-ipos+2,ilen)
} else {
   chroot = imname
   extn = ""
}

# Check for channel indicator

chpos = stridx("hjkl",substr(revimname,ipos+1,ilen))

# If channel indicator exists, break filename into root and channel.  Otherwise,
# return null values for the root, and the file name sans extension for
# the root.

if (chpos != 1) {
   ch_id  = ""
   root   = chroot
} else {
   ch_id = substr(revimname,ipos+1,ipos+1)
   root  = substr(imname,1,ilen-ipos-1)
}   
ilen   = strlen(root)
ic     = strlen(number_id)
imroot = substr(root,1,ilen-ic)
seqnum = substr(root,ilen-ic+1,ilen)

if (verbose) {
   if (option == "seq") {
     print (imroot," ",seqnum," ",ch_id," ",extn)
   } else {
     print (chroot," ",root," ",ch_id," ",extn," ",alt_ch," ",section,
          " ",imroot," ",seqnum)
   }
}

#delete (imfile//","//secfile//","//rootfile,ver-,>& "dev$null")
end
