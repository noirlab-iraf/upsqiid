# RECHANNEL: 14JAN00 KMM
# RECHANNEL: produces list of images for given channel from image list

procedure rechannel (image, channel)

string image       {prompt="Image list"}
string channel     {prompt="Image color: |j|h|k|l|", enum="|j|h|k|l|"}

# Model: image_name == imroot//seq_mark//seq_number//channel_id//"."//imextn
#      where seq_id     == seq_mark//seq_number//channel_id      		    
#            seq_mark   == ""|"."|"_"
#            seq_number == "00|000|0000"  (number of "0"s is number of digits)
#            channel_id == ""|"j"|"h"|"k"|"l"  (SQIID)
#            imextn     == "imh|fits|fit"
 
string section     {"",prompt="Image subsection [xmin:xmax,ymin:ymax]"}

struct *inlist

begin

int    nim,i,max,off,nex
string in,ch_id,imname,imroot,gimextn,imextn,im_ch,imseq
file   tmp1

tmp1 = mktemp("tmp$col")

# Assign positional parameters to local variables
in      = image
ch_id   = channel

# get IRAF global image extension
show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
nex     = strlen(gimextn)

# expand and parse file template for image root and extension
imparse(in,imoption="root",terse-,sqiid+,> tmp1)
inlist = tmp1
while (fscan(inlist,imroot,imextn,imseq,im_ch) != EOF) {
     print (imroot//imseq//ch_id//"."//imextn//section)
}

skip:

inlist = ""      
delete (tmp1, verify-,>& "dev$null")

end
