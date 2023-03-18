# USQPROOF: 21JAN00 KMM expects IRAF 2.11export or later
# USQPROOF: - produce proof sheet by tiling subsections of an image list
# ABUPROOF: 07AUG98 KMM
# USQPROOF: 21JAN00 KMM modify for UPSQIID including channel offset syntax

procedure usqproof (input, output, nxsub, nysub)

string  input        {prompt="List of input image tiles"}
string  output       {prompt="Output tiled image"}
int     nxsub        {prompt="Number of input tiles in X column direction)"}
int     nysub        {prompt="Number of input tiles in Y line direction"}

string  trim_section  {"[*,*]",
                       prompt='Input tile section "[*,*]" means all'}
string	missing_input {"", prompt="List of missing image tiles"}
string	start_tile    {"ll",
                        prompt="Position in output image of first input tile"}
bool    row_order    {yes, prompt="Insert input tiles in row order?"}
bool	raster_order {no,  prompt="Insert input tiles in raster scan order?"}
string  median_section {"[*,*]",
                       prompt="Input tile section used to compute median"}
bool    subtract     {no,
                      prompt="Subtract the median pixel value from each input?"}
real	oval	     {0., prompt="Value of undefined output image pixels"}
int     nimcols      {INDEF,prompt="The number of columns in the output image"}
int     nimrows      {INDEF,prompt="The number of rows in the output image"}
int     ncoverlap    {-1,
                prompt="Number of columns of overlap between adjacent tiles?"}
int     nloverlap    {-1,
                prompt="Number of lines of overlap between adjacent tiles?"}
string  opixtype     {"r",prompt="Output image pixel type?"}
bool    verbose      {yes, prompt="Print messages about progress of the task?"}
file    logfile      {"STDOUT", prompt="Log file name"}

#bool    save_dbmos   {no, prompt="Save the IRMOSAIC database file?"}
#file    infofile     {"", prompt="Output information file name"}

struct	*list1,*l_list
 
begin

file    tmp1, info, dbinfo, rootfile
int     nx, ny, i, nin, stat, pos1b, pos1e, nim, maxnim, nmissing,
        ncols, nrows, ncolsout, nrowsout ,nxoverlap, nyoverlap, nsubrasters,
        nxlotrim,nxhitrim,nylotrim,nyhitrim
string  in, in1, mosout, img, med_sec, sjunk, sname, nulls, addmiss,
        mos_name,mos_section,mos_corner,mos_order,mos_oval  
int     nex
string  gimextn, imextn, imname, imroot
       
# get IRAF global image extension
show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
nex     = strlen(gimextn)

tmp1      = mktemp ("tmp$sqm")
info      = mktemp ("tmp$sqm")
rootfile  = mktemp ("tmp$sqm")

# Get positional parameters
in       = input
mosout   = output
nx       = nxsub
ny       = nysub

# check whether input stuff exists
print (in) | translit ("", "@:", "  ") | scan(in1,in2)
if ((stridx("@",in) == 1) && (! access(in1))) {      # check input @file
      print ("Input file ",in," does not exist!")
      goto skip
}
sqsections (in,option="nolist")
if (sqsections.nimages == 0) {                 # check input images
   print ("Input images in file ",in, " do not exist!")
   goto skip
}
sqsections (in, option="root") | match ("\#",meta+,stop+,print-,> rootfile)
count (rootfile) | scan (nin)

maxnim = nx*ny
if (imaccess(mosout)) { # check output collision
   print ("Output image ",mosout, " already exists!")
   goto skip
}

# verify proper accounting: number of images = missing + supplied 	
if (missing_input == " " || missing_input == "") {
   nulls = ""		# trap space
   nmissing = 0
} else {
   nulls = missing_input
   expandnim (nulls,ref_nim=-1,max_nim=maxnim) | count | scan (nmissing)
}
if ((nmissing + nin) != maxnim) {
   print ("Improper # of images - need ",maxnim,
      ";  input ",nin,"; declared missing ",nmissing)
   addmiss = (nin+nmissing+1)//"-"//maxnim
   addmiss = nulls//","//addmiss
   print ("Suggest missing_input: ",nulls," be amended to ",addmiss)
   goto skip
}   
if (subtract) 	# Pass median_section to irmosaic
   med_sec = median_section
else
   med_sec = ""
   
# log parameters   
time() | scan(line)
print("#DB  ",line," USQPROOF:",>> info)
print("#DB     mosaic          ",mosout,>> info)
print("#DB     nxsub           ",nx,>> info)
print("#DB     nysub           ",ny,>> info)
print("#DB     trimsection     ",trim_section,>> info)
print("#DB     missing_input   ",nulls,>> info)
print("#DB     start_tile      ",start_tile,>> info)
print("#DB     row_order       ",row_order,>> info)
print("#DB     raster_order    ",raster_order,>> info)
print("#DB     median_section  ",med_sec, >> info)
print("#DB     median_subtract ",subtract,>> info)

if (verbose && logfile != "STDOUT")
   type (info)
else 
   type (info, >> logfile)
    	  
imtile("@//rootfile, mosout, nx, ny, trim_section=trim_section, 
   missing_input=nulls, start_tile=start_tile,            
   row_order=row_order, raster_order=raster_order,             
   median_section=med_sec, subtract=subtract,
   ncols=nimcols, nlines=nimrows, ncoverlap=ncoverlap,nloverlap=nloverlap,             
   opixtype=opixtype,ovalue=oval,verbose=verbose, >> logfile)

skip:

list1 = ""; l_list = ""
delete (tmp1//","//info//","//rootfile, verify-, >& "dev$null")

end
