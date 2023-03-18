# RECOMBINE: 14JUL00 KMM expects IRAF 2.11Export or later
# RECOMBINE: - interactive intensity readjust and imcombine of nircombine-based
#   image stacks;  derived from NIRCOMBINE: 08APR94 KMM
#            22JUL94 KMM
#            28JUL94 KMM utilize printf for formatted output (instead of AWK)
#            08AUG94 KMM fix printf format problems
#            06MAY96 KMM include nkeep
#                        modify version check coding
# RECOMBINE: 22JUN98 KMM add global image extension
#                        replace access with imaccess where appropriate
#            30APR99 KMM add option to recreate without zero-adust
#            14JUL00 KMM minor fixes to error checking and reparse IMCOMBINE
#                        output

procedure recombine (stack_name,infofile,image_nums)

string stack_name   {prompt="name of input image stack from NIRCOMBINE"}
file   infofile     {prompt=".src file produced by NIRCOMBINE"}

string image_nums    {prompt="Selected image numbers|offsetadj"}
string include_frame {"all", prompt="Selected image numbers to include"}
#bool   stack_out    {"", prompt="Output image stack"}
string out_name     {"", prompt="Output composite image name"}
file   outfile      {"", prompt="Output information file name"}
string comb_opt     {"median", enum="average|median",
                       prompt="Type of combine operation: |average|median|"}
string reject_opt   {"none", prompt="Type of pixel rejection operation",
                    enum="none|minmax|ccdclip|crreject|sigclip|avsigclip|pclip"}
real   lthreshold   {-200.,prompt="Rejection floor for imcombine"}
real   hthreshold   {65000.,prompt="Rejection ceiling for imcombine"}
real   blank        {-1000.,prompt="Value if there are no pixels"}

bool   interactive  {no, prompt="Interactive mode ?"}
bool   apply_zero   {no,prompt="Apply zeropoint to images prior to imcombine?"}
bool   invert_zero  {no,
                     prompt="Invert database zeropoints prior to application?"}
# prior to IRAF 2.10 one must invert to database zeropoints when using imcombine
#bool   make_stack   {no,prompt="Imstack images prior to imcombine?"}
#bool   save_images  {no,prompt="Save images which were IMCOMBINED via imstack?"}
bool   verbose      {yes, prompt="Verbose output?"}

string weight       {"none",prompt="Image weights"}
bool   mclip        {no, prompt="Use median, not mean, in clip algorithms"}
real   pclip        {-0.5, prompt="pclip: Percentile clipping parameter"}
int    nlow         {1, prompt="minmax: Number of low pixels to reject"}
int    nhigh        {1, prompt="minmax: Number of high pixels to reject"}
int    nkeep        {0, 
                      prompt="Minimum to keep (pos) or maximum to reject (neg)"}

real   lsigma       {3., prompt="Lower sigma clipping factor"}
real   hsigma       {3., prompt="Upper sigma clipping factor"}
real   sigscale     {0.1,
                     prompt="Tolerance for sigma clipping scaling correction"}
int    grow         {0, prompt="Radius (pixels) for 1D neighbor rejection"}
string expname      {"", prompt="Image header exposure time keyword"}
string rdnoise      {"0.", prompt="ccdclip: CCD readout noise (electrons)"}
string gain         {"1.", prompt="ccdclip: CCD gain (electrons/DN)"}
bool   answer       {yes, prompt="Do you want to continue?", mode="q"}

struct  *list1, *list2

begin

   int    i,stat,nim,maxnim,slen,slenmax,njunk,pos1b,pos1e,ncolsout,nrowsout,
          nxlosrc,nxhisrc,nylosrc,nyhisrc,ncols,nrows,nxmat0,nymat0,max_nim
   real   zoff, xoff, yoff, preoff, imoff, tpreoff, timoff, zimoff, zpreoff
   bool   update
   string uniq,imname,tmpname,matchname,sjunk,soffset,
          src,srcsub,mos,mossub,mat,matsub,ref,refsub,stasub,imagenums,
          sformat,zero,vcheck,optreject,combopt,image_nims,outname
   file   info,out,dbinfo,doinfo,tmp1,tmp2,oldinfo,
          tmpimg,procfile,matinfo,newinfo,task,misc,comblog,
          im_offsets,im_zero,pre_zero,ncomblist,nimlist,combinfo
   int    nex
   string gimextn, imextn, imroot
   struct line = ""

   matchname   = stack_name
   info        = infofile
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
      
   uniq        = mktemp ("_Trcb")
   task        = uniq // ".tsk"
   newinfo     = uniq // ".new"
   oldinfo     = uniq // ".old"
   tmpimg      = uniq // "_tim"
   dbinfo      = mktemp("tmp$icb")
   doinfo      = mktemp("tmp$icb")
   matinfo     = mktemp("tmp$icb")
   ncomblist   = mktemp("tmp$icb")
   nimlist     = mktemp("tmp$icb")
   procfile    = mktemp("tmp$icb")
   tmp1        = mktemp("tmp$icb")
   tmp2        = mktemp("tmp$icb")
   misc        = mktemp("tmp$icb")
   im_offsets  = mktemp("tmp$icb")
   pre_zero    = mktemp("tmp$icb")
   im_zero     = mktemp("tmp$icb")
   comblog     = mktemp("tmp$icb")
   combinfo    = mktemp("tmp$icb")

   optreject  = reject_opt
   combopt = comb_opt
   
   i = strlen(matchname)
   if (! imaccess(matchname)) {
      print("Image stack",matchname," not fpund!")
      goto err
   } else if (substr(matchname,i-nex,i) == "."//gimextn) { # Strip off imextn
      matchname = substr(matchname,1,i-nex-1)
   }  
   if (! access(info)) { 		# Exit if can't find info
      print ("Cannot access info_file: ",info)
      goto err
   }
   imgets (matchname, "i_naxis"); nim = int (imgets.value)
   if (nim != 3) {
      print("Image ",matchname," is not an image stack!")
      goto err
   }

# get image size and number
   imgets (matchname, "i_naxis1"); ncols  = int (imgets.value)
   imgets (matchname, "i_naxis2"); nrows  = int (imgets.value)
   imgets (matchname, "i_naxis3"); maxnim = int (imgets.value)
   refsub = "[1:"//ncols//",1:"//nrows//","

# Transfer appropriate information from reference to output file
   match ("^\#DBR",info,meta+,stop-,print-, > dbinfo)
   match ("^STA",info,meta+,stop-,print-) |
      match ("STA_000",,meta-,stop+,print-, > matinfo)
# Get imcombine image size and maximum name length from input file
##print("STA_000 stack_"//matchname," ",out," ",ncolsout,nrowsout,slenmax,> out)
   match ("^STA_000",info,meta+,stop-,print-) | 
      scan (sjunk,sjunk,imname,ncolsout,nrowsout,slenmax) 
   if (nscan() < 5) {
      print("Warning: info missing (ncolsout|nrowsout|slenmax) from infofile!")
      goto err
   } else
      print ("Composite Image size: ["//ncolsout//","//nrowsout//"]")

# establish ID of output image name and infofile
   if (out_name == "" || out_name == " " || out_name == "default") {
      pos1e = strlen(matchname)
      pos1b = stridx("_",matchname) + 1
      outname = substr(matchname,pos1b,pos1e) + 1
      while (imaccess(outname)) {
         outname = outname + 1
      }
   } else
      outname = out_name
   if (imaccess(outname)) {
       print("Image ",outname," already exists!")
       goto err
   }
   if (outfile == "" || outfile == " " || outfile == "default")
      out = outname//".src"
   else
      out = outfile
   if (out != "STDOUT" && access(out)) {
      print("WARNING: Will overwrite output_file ",out,"!")
      if (!answer) goto err
   }

   imagenums   = image_nums

   if (apply_zero) {
      zero = "none"
      print ("Note: zero-points will be applied prior to IMCOMBINE.")
   } else {
      zero = "@"//im_zero 
      print ("Note: zero-points will be applied by IMCOMBINE.")
   }

###### Need to check that lthreshold is safely above mask value
#   if (svalue >= lthreshold) {
#      reject_value = lthreshold - 1.0
#      print ("Resetting reject_value from ",svalue," to ",reject_value)
#   } else
#      reject_value = svalue

   time() | scan(line)
# Log parameters
   print("#DBR ",line," RECOMBINE:",>> dbinfo)
   print("#DBR    stack_input     ",matchname,>> dbinfo)
   print("#DBR    info_file       ",info,>> dbinfo)
   print("#DBR    image_nums      ",imagenums,>> dbinfo)
   print("#DBR    apply_zero      ",apply_zero,>> dbinfo)
   print("#DBR    new_composite   ",outname,>> dbinfo)
   print("#DBR    new_info        ",out    ,>> dbinfo)

# setup nim process file
   if (stridx("@",imagenums) == 1) {			# @-list
      imagenums = substr(imagenums,2,strlen(imagenums))
      if (! access(imagenums)) { 		# Exit if can't find info
         print ("Cannot access image_nums file: ",imagenums)
         goto err
      } else
         copy (imagenums,procfile,verbose-)
   } else {
      print(imagenums,> procfile)
   }

   print("#Process info: ",>> misc); concatenate(procfile,misc,append+)
   if (verbose) {
      print("#Process list: "); type(procfile)
   }

# generate im_offsets, & input im_zero
# format STA_nnn xoff yoff imcombine_applied_zero imstack_applied_zero
#        COM_nnn original_source_image total_applied_zero
   print ("# Absolute",> im_offsets) # Mark offsets as absolute
   fields (matinfo,"2-3",lines="1-9999",quit+,print-,>> im_offsets)
# strip off archival info
   fields (matinfo,"6-8",lines="1-9999",quit+,print-,>> oldinfo)

# work through the list
   list2 = procfile
   while (fscan(list2,line) != EOF) {
# Expand the range of images, splitting off zoff  
      print ("Processing images: ",line)
      print("#DBR    image_nims      ",line,>> dbinfo)
      print (line) | translit ("", "|", " ") | scan(image_nims,soffset)
      if (nscan() < 2) {
         print("Warning: no zoff found!")
      }
      if (soffset == "INDEF") soffset = "0.0"
      zoff = real (soffset)

      expandnim(image_nims,ref_nim=-1,max_nim=512,>> nimlist)

      list1 = nimlist
      while (fscan(list1,nim) != EOF) {
         if (nim > maxnim) {
            print ("NB: requested image#",nim," is outside range and ignored")
            break
         }
         if (apply_zero) {
            tmpname = matchname//refsub//str(nim)//"]"
            imcopy (tmpname,tmpimg,ver-)
            imarith (tmpimg,"+",zoff,tmpimg,pixt="",calct="",hparam="",verbose-)
            imcopy (tmpimg,tmpname,ver-)
            imdelete(tmpimg,verify-,>& "dev$null")
            print (imname," 0.0",zoff,>> doinfo)	# accumulate actions
         }
         imname = "STA_000" + nim
         print (imname," ",zoff," 0.0",>> doinfo)	# accumulate actions
      }
      delete (nimlist, ver-,>& "dev$null")
   }

# accumulate intensity offset data

   list1 = ""; list2 = ""
   list1 = matinfo
   sort (doinfo,col=1,ignore+,numeric-,reverse-,>> tmp1)
   delete (doinfo, ver-, >& "dev$null")
   for (i = 1; (fscan(list1,imname,xoff,yoff,timoff,tpreoff) != EOF); i += 1) {
       match (imname,tmp1,>> tmp2)
       imoff = 0.0; preoff = 0.0
       list2 = tmp2
       while (fscan(list2,sjunk,zimoff,zpreoff) != EOF) {
          imoff   += zimoff
          preoff  += zpreoff
          timoff  += zimoff
          tpreoff += zpreoff
       }
       if (invert_zero)
          print (-timoff,>> im_zero)
       else
          print (timoff,>> im_zero)
       print (preoff,>> pre_zero)
       print (imname," ",xoff,yoff,timoff,tpreoff," ",>> doinfo)
       list2 = ""; delete (tmp2, ver-, >& "dev$null")
   }

# generate updated database
   join(doinfo,oldinfo,out=newinfo,missing="Missing",delim=" ",
            maxchars=161,shortest-,verbose+)

# output information
   delete (out, ver-,>& "dev$null") # delete prior version (we said OK above)
   copy (dbinfo,out,verbose-)
   match ("^COM",info,meta+,stop-,print-, >> out)

   print ("Performing IMCOMBINE: reject= ",optreject," combine= ",
         combopt," output= ", outname)
   print ("#Performing IMCOMBINE: reject= ",optreject," combine= ",
         combopt," output= ", outname,>> out)

   print (matchname, > ncomblist)
   imcombine("@"//ncomblist,tmpimg,plfil="",sigma="",logfil=comblog,
      combine=combopt,reject=optreject,project+,outtype="real",
      offsets=im_offsets,masktype="none",maskvalue=0,blank=blank,
      scale="none",zero=zero,weight=weight,statsec="",
      lthreshold=lthreshold,hthreshold=hthreshold,
      nlow=nlow,nhigh=nhigh,nkeep=nkeep,pclip=pclip,lsigma=lsigma,hsigma=hsigma,
      mclip=mclip,sigscale=sigscale,expname=expname,
      rdnoise=rdnoise,gain=gain,grow=grow)

   if (verbose) type (comblog)

   imgets (tmpimg, "i_naxis1"); ncols = int (imgets.value)
   imgets (tmpimg, "i_naxis2"); nrows = int (imgets.value)
   if (ncols != ncolsout || nrows != nrowsout) {
      mkpattern (outname,output="",pattern="constant",
         v1=blank,v2=0.,title="",pixtype="real",ndim=2,
         ncols=ncolsout,nlines=nrowsout,header=tmpimg)
      nxlosrc = 1; nxhisrc = min(ncols,ncolsout)
      nylosrc = 1; nyhisrc = min(nrows,nrowsout)
      srcsub = "["//nxlosrc//":"//nxhisrc//","//
         nylosrc//":"//nyhisrc//"]"
      print ("# NOTE: Restoring image origin and size: ",
         tmpimg//srcsub," -> ",outname//srcsub,>> out)
      imcopy(tmpimg//srcsub,outname//srcsub,verbose+)
   } else
      imrename(tmpimg,outname,verb-)

# extract per_image info from IMCOMBINE log
   match ("_",comblog,meta-,stop-,print-) |
      match ("=",,meta-,stop+,print-,>> combinfo) 
# Extract number of output categories in IMCOMBINE log to stat
   match ("Images",comblog,meta-,stop-,print-) | count() | scan(i,stat)

# output updated STA_nnn to database for use by RECOMBINE
   print ("STA_000 ",matchname," ",out," ",ncolsout,nrowsout,
      slenmax,>> out)
# Fancy format
   sformat = '%-7s %3d %3d %9.3f %9.3f %-7s %'//slenmax//'s %9.3f\\n'
   list1 = ""; list1 = newinfo
   for (i = 0; fscan(list1,imname,nxlosrc,nxhisrc,xoff,yoff,src,mos,
          zoff) != EOF; i += 1) {
      printf(sformat,imname,src,nxlosrc,nxhisrc,xoff,yoff,src,mos,zoff,>> out)
   }

   concatenate (comblog,out,append+)	 # output IMCOMBINE per_image log
   
# Finish up

err:  list1 = ""; list2 = ""
   imdelete(tmpimg,verify-,>& "dev$null")
   delete (newinfo//","//oldinfo//","//tmp1//","//tmp2,ver-,>& "dev$null")
   delete (doinfo//","//ncomblist,ver-,>& "dev$null")
   delete (nimlist//","//comblog//","//combinfo//","//task,ver-,>& "dev$null")
   delete (procfile//","//misc//","//dbinfo//","//matinfo,ver-,>& "dev$null")
   delete (pre_zero//","//im_offsets//","//im_zero,ver-,>& "dev$null")
   
end
