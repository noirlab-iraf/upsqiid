# IMPARSE: 14JAN00 KMM expects IRAF 2.11Export or later
# IMPARSE: -- separate out image root, channel_id, and extension
# IMPARSE: 27JUL98 KMM expects IRAF 2.11Export or later
# IMPARSE: 07AUG98 KMM add option to parse sequential image marker
#                      image_name == imroot//seq_marker//seq_number//"."//imextn
#                         where seq_marker = ""|"."|"_"
#                         and imextn  = "imh|fits|fit"
#          11FEB99 KMM add attempt to find imextn when no imextn in submitted
#                          image list
#          14JAN00 KMM add option to parse channel_id (jhkl) for sqiid

procedure imparse (input)

string input      {prompt="Input raw images"}
string imoption   {"root", prompt="SECTIONS option: nolist|full|root ?",
                     enum = "nolist|full|root"}
string ext_option {"all", prompt="Imextn search option: asis|all|select ?",
                     enum = "asis|all|select"}
# all    == search iraf imextn environmental variable for all legal imextns
# asis   == use 
# select == use only first imtype in IRAF CL "imtype parameter

# Model: image_name == imroot//seq_mark//seq_number//channel_id//"."//imextn
#      where seq_id     == seq_mark//seq_number//channel_id      		    
#            seq_mark   == ""|"."|"_"
#            seq_number == "00|000|0000"  (number of "0"s is number of digits)
#            channel_id == ""|"j"|"h"|"k"|"l"  (SQIID)
#            imextn     == "imh|fits|fit"
 
string seq_id    {"none",
              prompt='Sequential imager id template? (eg, ".00"|"000"|"0000j")'}		    
bool   sqiid     {no, prompt="Parse sqiid channel_id?"}
bool   terse     {no, prompt="Output only image root (sans imextn)?"}
int    okimages  {0, prompt="Number of selected images in template"}
int    inimages  {0, prompt="Number of images in template"}
string ch_id     {"",prompt="Channel_id ( jhkl)?"}

struct  *inlist,*elist

begin

int    nim, nok, stat, pos1b, pos1e, pos2b, pos2e, nex, seqlen, chlen, mklen
string in, in1, img, out, ext, gimextn, imextn, imroot,
       seqnum, imseq, seqmark, seqid, chid, im1, im2
file   infile, extnlist, outfile, temp1
bool   found
bool   debug=no ##DEBUG

# Assign positional parameters to local variables
in      = input

# get IRAF global image extension
show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
nex     = strlen(gimextn)

infile      = mktemp ("tmp$imp")
outfile     = mktemp ("tmp$imp")
extnlist    = mktemp ("tmp$imp")
temp1       = mktemp ("tmp$imp")

# generate image extension list
if (ext_option == "all") {
   show ("imextn") | words | match ("oif") | translit ("",":,","  ",delete-) |
        words | match ("oif",stop+, >> extnlist)
   show ("imextn") | words | match ("fxf") | translit ("",":,","  ",delete-) |
        words | match ("fxf",stop+, >> extnlist)
   show ("imextn") | words | match ("plf") | translit ("",":,","  ",delete-) |
        words | match ("plf",stop+, >> extnlist)
} else if (ext_option == "select") {
   print (gimextn, >> extnlist) 
} else
   print (gimextn, >> extnlist)
     
if(debug) {##DEBUG
   print ("Input = ",in)
   type (extnlist)
}##DEBUG

if (imoption != "nolist")
   sections (in,option=imoption,> infile)
else
   sections (in,option="root",> infile)
   
seqid   = ""
seqmark = ""
chid    = ""
if (sqiid) {	# setup SQIID paradigm
   seqid   = "000j"
   seqlen  = strlen(seqid)
   seqmark = ""
   chid    = "j"
} else {	# use seq_id
   if (seq_id == "" || seq_id == "none" || seq_id == " ") {
      seqid  = "none"
      seqlen = 0
   } else {
      seqid  = seq_id
      seqlen = strlen(seqid)
   }
   print (seqid) | translit ("","0-9a-z"," ",delete-,collapse-) | scan (seqmark)
   print (substr(seqid,strlen(seqmark)+1,seqlen) |
            translit ("","0-9"," ",delete-,collapse-) | scan (chid)
}	    
elist  = extnlist
inlist = infile
imroot = in
imseq  = imroot
seqnum = ""
nim = 0
nok = 0
mklen  = strlen(seqmark)
chlen  = strlen(chid)	
#print (seqid, " ",seqmark," ",chid,mklen,chlen,nex)

while (fscan(inlist,img) != EOF) {
   found = no
   nim = nim + 1
   elist = extnlist
   imextn = ""
   while (fscan(elist,ext) != EOF) {
      if (substr(img,strlen(img)-strlen(ext),strlen(img)) == "."//ext) {
         found = yes
         nok = nok + 1
         imextn = ext
         imroot = substr(img,1,strlen(img)-strlen(imextn)-1)
         if (imoption != "nolist") {
	     if (seqid != "none") {
  		pos1e  = strlen(imroot)
		pos1b  = pos1e - seqlen 
                imseq  = substr(imroot,1,(strlen(imroot)-seqlen))
		seqnum = substr(imroot,(strlen(imroot)-seqlen+1),(pos1e-chlen))
		if (chlen != 0) chid = substr(imroot,pos1e,pos1e)
	        print(imseq," ",imextn," ",seqnum," ",chid," ",img,>> outfile)			
	     } else		 
                print(imroot," ",imextn," ",img,>> outfile)
         }
      }
   }
   if (!found) {	# no valid extn in list
      files(img//"*", sort-) | count() | scan (stat)
      if (stat > 1) {
         print ("# Multiple image extensions for: ", img)
	 goto skip
      } else if (stat == 1) {
         files(img//"*", sort-) | scan (im2)
	 elist = extnlist
         imextn = ""
         while (fscan(elist,ext) != EOF) {
            if (substr(im2,strlen(im2)-strlen(ext),strlen(im2)) == "."//ext) {
               found = yes
               nok = nok + 1
               imextn = ext
               imroot = substr(im2,1,strlen(im2)-strlen(imextn)-1)
               if (imoption != "nolist") {
	          if (seqid != "none") {
  		     pos1e  = strlen(imroot)
		     pos1b  = pos1e - seqlen 
                     imseq  = substr(imroot,1,(strlen(imroot)-seqlen))
		  seqnum = substr(imroot,(strlen(imroot)-seqlen+1),(pos1e-chlen))
		  if (chlen != 0) chid = substr(imroot,pos1e,pos1e)
	          print(imseq," ",imextn," ",seqnum," ",chid," ",img,>> outfile)
	          } else		 
                     print(imroot," ",imextn," ",img,>> outfile)
              }
           }
        }
     }
  }
}
if (imoption != "nolist" && nok > 0) {
   if (terse)
     fields (outfile,"1",lines="1-",print-)
   else if (chlen != 0) {
     if (imoption == "root") 
        fields (outfile,"1,2,3,4",lines="1-",print-)
     else if (imoption == "full")
        fields (outfile,"1,2,3,4,5",lines="1-",print-)
   } else {
        if (imoption == "root") 
           fields (outfile,"1,2,3",lines="1-",print-)
        else if (imoption == "full")
           fields (outfile,"1,2,3,4",lines="1-",print-)
   }
} else if (imoption != "nolist" && nok == 0) {	# No valid file extensions
   print ("WARNING: no images found with imextn:")
   type (extnlist)
}

okimages = nok 
inimages = sections.nimages

skip:

# Finish up
inlist = ""; elist = ""
delete (infile//","//extnlist//","//outfile, verify-,>& "dev$null")
   
end

#      if (substr(in,strlen(in)-3,strlen(in)) == ".imh" ) {
#         imextn = ".imh"
#         imroot = substr(in,1,strlen(in)-4)
#      } else if  (substr(in,strlen(in)-4,strlen(in)) == ".fits" ) {
#         imextn = ".fits"
#         imroot = substr(in,1,strlen(in)-5)
#      } else if  (substr(in,strlen(in)-3,strlen(in)) == ".fit" ) {
#         imextn = ".fit"
#         imroot = substr(in,1,strlen(in)-4)
#      } else {
#         imextn = ""
#         imroot = in
#      }
