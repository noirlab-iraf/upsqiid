# ZADJ: 14OCT98 KMM expects IRAF 2.11Export or later
# ZADJ: - interactive intensity readjust of nircombine-based
#   image databases
#

procedure zadj (infofile,image_nums)

file   infofile     {prompt=".src file produced by NIRCOMBINE"}

string image_nums    {prompt="Selected image numbers|offsetadj"}
string include_frame {"all", prompt="Selected image numbers to include"}
file   outfile      {"", prompt="Output information file name"}

bool   interactive  {no, prompt="Interactive mode ?"}
bool   verbose      {yes, prompt="Verbose output?"}
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
          im_offsets,im_zero,pre_zero,com000,nimlist,combinfo
   int    nex
   string gimextn, imextn, imroot
   struct line = ""

#   matchname   = stack_name
   info        = infofile
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
      
   uniq        = mktemp ("_Trcb")
   task        = uniq // ".tsk"
   newinfo     = uniq // ".new"
   oldinfo     = uniq // ".old"
   dbinfo      = mktemp("tmp$icb")
   doinfo      = mktemp("tmp$icb")
   matinfo     = mktemp("tmp$icb")
   com000      = mktemp("tmp$icb")
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
 
   if (! access(info)) { 		# Exit if can't find info
      print ("Cannot access info_file: ",info)
      goto err
   }

# Transfer appropriate information from reference to output file
   match ("^\#DBR",info,meta+,stop-,print-, > dbinfo)
   match ("^COM",info,meta+,stop-,print-) |
     match ("COM_000",,meta-,stop+,print-, > matinfo)
   match ("^COM_000",matinfo,meta+,stop-,print-, >> com000)   
   match ("^COM",info,meta+,stop+,print-, >> oldinfo)
   

# establish ID of output image name and infofile
  if (outfile == "" || outfile == " " || outfile == "default") {
      pos1e = strlen(info)
      pos1b = stridx("_",info) + 1
      out = substr(info,pos1b,pos1e) + 1
      while (access(out)) {
         out = out + 1
      }
   } else
      out = outfile

   if (out != "STDOUT" && access(out)) {
      print("WARNING: Will overwrite output_file ",out,"!")
      if (!answer) goto err
   }

   imagenums   = image_nums

   time() | scan(line)
# Log parameters
   print("#DBR ",line," ZADJ:",>> dbinfo)
   print("#DBR    info_file       ",info,>> dbinfo)
   print("#DBR    image_nums      ",imagenums,>> dbinfo)
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

# generate im_offsets
   translit (matinfo, "_", " ") |
   fields ("","2,12",lines="1-",quit+,print-,>> im_offsets)
      
   type(im_offsets)
   goto err
# strip off archival info
   fields (matinfo,"6-8",lines="1-",quit+,print-,>> oldinfo)

goto p0
   slenmax = 0; list1 = matinfo
# Loop through frames: fixpix|setpix|geotran|imshift|zoffset
   while (fscan(list1,imname,src,nxlosrc,nxhisrc,nylosrc,nyhisrc,
      nxmat0,nymat0,fxs,fys,soffset) != EOF) {
      pos1b = stridx("_",imname)+1
      if (pos1b < 2) {
         print("Image path position (COM_pos) missing at ",imname)
         goto err
      } else
         nim = int(substr(imname,pos1b,strlen(imname)))

      if (nim == 0 ) {	 			# SKIP COM_000 REF IMAGE
         print("#NOTE: skipping COM_000 ",src)
         next
      }

      if (soffset == "INDEF") soffset = "0.0"
      zoff = real (soffset)
      slenmax = max(slenmax,strlen(src))
   }
p0:

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

# extract per_image info from IMCOMBINE log
   match ("_",comblog,meta-,stop-,print-) |
      match ("ncombine",,meta-,stop+,print-,>> combinfo) 
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

   delete (newinfo//","//oldinfo//","//tmp1//","//tmp2,ver-,>& "dev$null")
   delete (doinfo//","//com000,ver-,>& "dev$null")
   delete (nimlist//","//comblog//","//combinfo//","//task,ver-,>& "dev$null")
   delete (procfile//","//misc//","//dbinfo//","//matinfo,ver-,>& "dev$null")
   delete (pre_zero//","//im_offsets//","//im_zero,ver-,>& "dev$null")
   
end
