# GROUP: 07JUN99 KMM expects IRAF 2.11Export or later
# MOVPROC: 03MAR99 KMM remove blankimage option; will always compute skyframe
# PATPROC: -- pattern process raw image data generated from the following
#             protocols (+ = on|object; - = off|sky):
#                  all_on:  + + + + +   order=1
#                    pair:  +- +- +-    order=2
#                   triad:  +-+ +-+     order=3
#                    quad:  +--+ +--+   order=4
#                alt-quad:  -++- -++-   order=5
#               alt-triad:  -++ -++     order=6
# GROUP: 07JUN99 KMM explore data groupings for MOVPROC and PATPROC

procedure group (image_root, begin_pic, end_pic)

#string input      {prompt="Input raw images"}
string image_root {prompt="Image root filename (e.g. test_)?"}
int    begin_pic  {prompt="Ordinal number of first image to be processed?"}
int    end_pic    {prompt="Ordinal number of last  image to be processed?"}
string seq_id     {".000",
                      prompt='Sequential imager id template? (eg, ".00"|"000")'}
string im_extn    {"", prompt="image extension (excluding .)"}
		      
   # Model: image_name == imroot//seq_id//"."//imextn
   #      where seq_id == seq_mark//seq_number
   
int    order      {6, min=1, max=6,
                   prompt="Pattern # 1:++ 2:+- 3:+-+ 4:+--+ 5:-++- 6:-++ ?"}
int    multiple   {5, prompt="# of frames at each +/- pattern state?"}
bool   list_only  {no, prompt="Output only target and sky lists"}
bool   verbose    {yes,prompt="Verbose output?"}
file   logfile    {"STDOUT",prompt="logfile name"}
int    include    {5, prompt="Number of included images in blankimage subset"}
int    improc     {5, prompt="Number of images to process in group"}
int    imskip     {10,prompt="Number of images to skip between process"}
int    first_proc {1, prompt="List number of first image to be processed"}
int    last_proc  {1000, prompt="List number of last image to be processed"}
   
struct  *inlist,*outlist,*imglist,*l_list

begin

   int    nin, irootlen, orootlen, stat, pos1b, pos1e, pos2b, pos2e,
          img_num, first_in, last_in, ilist, gnum, nbegin, nend, ntarget, nsky
   string in,in1,in2,out,iroot,oroot,uniq,img,sname,sout,sbuff,sjunk,
          smean, smedian, smode, front, srcsub, seqid 
   file   skyimg,  nflat, infile, outfile, im1, im2, im3, tmp1, tmp2, tmp3,
          l_log, task, onfile, offfile, opfile
   bool   found
   bool   debug=no
   int    nex
   string gimextn, imextn, imname, imroot

   struct line = ""

# Assign positional parameters to local variables

#   in          = input
   imroot = image_root
   nbegin = begin_pic
   nend   = end_pic
   seqid  = seq_id
   if (im_extn != "" && im_extn != " ") {
     if (substr(im_extn,1,1) != ".")
        imextn = "."//im_extn
     else
        imextn = im_extn
   } else
     imextn = im_extn
     
   uniq        = mktemp ("_Tabp")
   infile      = mktemp ("tmp$abn")
   outfile     = mktemp ("tmp$abn")
   onfile      = mktemp ("tmp$abn")
   opfile      = mktemp ("tmp$abn")
   offfile     = mktemp ("tmp$abn")
   tmp1        = mktemp ("tmp$abn")
   tmp2        = mktemp ("tmp$abn")
   tmp3        = mktemp ("tmp$abn")
   l_log       = mktemp ("tmp$abn")

#   inlist = in
#   for (nin = 0; fscan (inlist,img) !=EOF; nin += 1) {
#      print(img,>> infile)
#      print("out_"//img,>> outfile)
#   }
   for (nin = nbegin; nin <= nend; nin +=1) {
      oroot = seqid + nin
      img = imroot//oroot//imextn
      print(img,>> infile)
      print("out_"//img,>> outfile)
   }
   count(infile) | scan(nin)
# Generate list of on frames
   statelist ("@"//infile, order=order, state= "on", multiple=multiple,
      format="group",>> onfile)
   count (onfile) | scan(ntarget)       
   print("Target frames: ",ntarget,>> logfile)
  
   type(onfile,>> logfile)
# Generate list of off frames      
   statelist ("@"//infile, order=order, state= "off", multiple=multiple,
      format="group",>> offfile)
      
   count (offfile) | scan (nsky)	 
   print("Sky frames: ",nsky, >> logfile)   
   type(offfile,>> logfile)	 
   if (list_only) goto skip
	       
   inlist = ""
         
   print(nin,include,improc,imskip, >> logfile)

# Loop through data
   img_num = 0
   gnum    = 0
   l_list = ""; delete (tmp1, verify-,>& "dev$null")
   inlist = infile; outlist = outfile
   copy (infile, tmp2)
   while ((fscan (inlist,sname) != EOF) && (fscan(outlist,sout) != EOF)) {

      img_num += 1
      if (img_num < first_proc) next  # skip until appropriate list number
      if (img_num > last_proc  || img_num > nin) break # terminate
      if (((img_num - first_proc) % (improc+imskip)) == 0)
         gnum +=1
if(debug) {##DEBUG
   print(img_num, gnum, ((img_num - first_proc) % improc),
         (first_proc + gnum*improc-1),
         (first_proc + gnum*(improc+imskip)-1),
         (first_proc + (gnum-1)*improc-1),
         (first_proc + (gnum-1)*(improc+imskip)),
         (first_proc + gnum*(improc)+(gnum-1)*imskip-1))
}##DEBUG
      if ((img_num > (first_proc + gnum*improc + (gnum-1)*imskip - 1))) {
          next  # skip until appropriate list number
      }


      if (verbose) print ("# list_number: ",img_num,sname, >> logfile) 
# Subtract the blank image from the raw data images.

      first_in = img_num - int((include/2))
      last_in  = int((include + 1)/2) + img_num
      if (first_in < 1) {
         last_in += (1 - first_in)
         first_in = 1
      } else if (last_in > nin) {
         first_in -= (last_in - nin)
         last_in = nin
      }
      print ("# compute sky from:  ",img_num,first_in,last_in, >> logfile)
      imglist = tmp2
      for (ilist = 1; fscan(imglist,img) != EOF; ilist += 1) {
         if (ilist > last_in) break
         if ((ilist >= first_in) && (ilist != img_num)) {
            print(img,>> tmp3)
         }
      }
      type (tmp3, >> logfile)
      imglist = ""; delete (tmp3, verify-,>& "dev$null")
   }
   
   skip:

   # Finish up
      inlist = ""; outlist = ""; imglist = ""; l_list = ""
      imdelete (onfile//","//offfile//","//opfile,verify-,>& "dev$null")
      delete (tmp1//","//tmp2//","//tmp3//","//l_log, verify-,>& "dev$null")
      delete (infile//","//outfile, verify-,>& "dev$null")
   
end
