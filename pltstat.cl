# PLTSTAT: 27APR99 KMM expects IRAF 2.11Export or later
# PLTSTAT: - produce graph of statistic within image subsection of a list
# PLTSTAT: 10AUG98 KMM

procedure pltstat (input)

string input      {prompt="List of input image tiles"}
string disp_stat  {"rmedian",enum="mean|median|mode|rmedian",
                    prompt="Statistic displayed: |mean|median|mode|rmedian|"}
string statsec    {"[300:700,400:600]",
                    prompt="Image section for calculating statistics"}
string seq_id     {"none",
                     prompt='Sequential imager id template? (eg, ".00"|"000")'}		     		     
# Model: image_name == imroot//seq_id//"."//imextn
#      where seq_id == seq_mark//seq_number
real   lthreshold {INDEF,prompt="Lower threshold for exclusion in statistics"}
real   hthreshold {INDEF,prompt="Upper threshold for exclusion in statistics"}

string qexposure  { "INT_S", prompt="Exposure time image header keyword"}		     
string qutime     { "UT", prompt="UT time image header keyword"}
string qdate      { "UTDATE", prompt="UT Date image header keyword"}
string qremark    { "REMARK", prompt="Remark image header keyword"}
string qtemp0     { "AMBIENT",prompt="Ambient temperature image header keyword"}
string qtemp1     { "TB.FRNT",prompt="Front temperature image header keyword"}
string qtemp2     { "TB.REAR",prompt="Rear temperature image header keyword"}

bool   plot_temp   {no, prompt="Overplot temperature?"}
real   tmin        {200.0,prompt="Minimum temperature?"}
real   tmax        {290.0,prompt="Maximum temperature?"}
		     

bool   verbose    {yes, prompt="Print messages about progress of the task?"}
file   logfile    {"STDOUT", prompt="Log file name"}

struct	*list1,*list2,*l_list
 
begin

file    tmp1, tmp2, secfile, info, infile
int     i, nin, stat, pos1b, pos1e, nim, maxnim, nseq, nout
real    rmean, rmedian, rmode, z0, itime, rstat, tamb, tfront, trear
string  in, in1, img, med_sec, sjunk, sname, seqnum, gxlabel, gylabel, gtitle
int     nex
string  gimextn, imextn, imname, imroot
       
# get IRAF global image extension
show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
nex     = strlen(gimextn)

tmp1      = mktemp ("tmp$sqm")
tmp2      = mktemp ("tmp$sqm")
secfile   = mktemp ("tmp$sqm")
infile    = mktemp ("tmp$sqm")
info      = mktemp ("tmp$sqm")

# Get positional parameters
in       = input

# check whether input stuff exists
print (in) | translit ("", "@", "  ") | scan(in1)
if ((stridx("@",in) == 1) && (! access(in1))) {      # check input @file
      print ("Input file ",in," does not exist!")
      goto skip
}

# Expand input file name list
#   option="root" truncates lines beyond imextn including section info
sections (in, option="root",> infile)
if (sections.nimages == 0) {                 # check input images
   print ("Input images in file ",in, " do not exist!")
   goto skip
}

# log parameters   
time() | scan(line)
print("#DB  ",line," ABUSTAT:",>> info)
print("#DB     stat_section    ",statsec, >> info)
print("#Plot ",disp_stat," statistics for data within ", lthreshold, " to ",
   hthreshold," in section ",statsec, >> info)   
imstatistics ("", fields="image,npix,mean,midpt,mode,stddev,min,max",
   lower=lthreshold,upper=hthreshold,binwidth=0.001,format+,>> info)
   
if (verbose && logfile != "STDOUT")
   type (info, >> logfile)
else if (verbose)
   type (info)
   
list1 = infile
for (nin = 0; fscan (list1,img) !=EOF; nin += 1) {
    i = strlen(img)
    if (substr(img,i-nex,i) == "."//gimextn)      # Strip off imextn
       img = substr(img,1,i-nex-1)
    print (img//statsec,>> secfile)
    imgets(img, qexposure) ; z0 = real(imgets.value)
    itime   = 0.001*nint(1000.0*z0)
    imgets(img, qtemp0)    ; z0 = real(imgets.value)
    tamb    = 0.01*nint(100.0*z0)
    imgets(img, qtemp1)    ; z0 = real(imgets.value)
    tfront  = 0.01*nint(100.0*z0)
    imgets(img, qtemp2)    ; z0 = real(imgets.value)
    trear   = 0.01*nint(100.0*z0)
    print (itime,tamb,tfront,trear,>> tmp2)
} 
nout = nin
   
imstatistics ("@"//secfile,
   fields="image,npix,mean,midpt,mode,stddev,min,max",
   lower=lthreshold,upper=hthreshold,binwidth=0.001,format-,>> tmp1)

nim = 0
delete (info, verify-, >& "dev$null")
list1 = tmp1
list2 = tmp2
while (fscan(list1,sname,nin,rmean,rmedian,rmode) != EOF && 
       fscan(list2,itime,tamb,tfront,trear) != EOF) {
   nim += 1 
   if (seq_id == "none")
      nseq = nim
   else {
      imparse(sname,imoption="root",seq_id=seq_id) | scan (img,imextn,seqnum)
      nseq = int(seqnum)
   }
   if (nim == 1)
       gxlabel = sname
   rstat = rmedian/itime
   print(nseq,rstat,rmean,rmedian,rmode,itime,tamb,tfront,trear,>> info)      

}
      
if (verbose && logfile != "STDOUT") {
   type (tmp1, >> logfile)
   type (info)
} else if (verbose){
   type (tmp1)
   type (info)
} else
   type (info)

delete (tmp1, verify-, >& "dev$null")
if (disp_stat == "rmedian")         
   fields (info,"1,2",lines="1-",print-,>> tmp1)
else if (disp_stat == "mean")         
   fields (info,"1,3",lines="1-",print-,>> tmp1)
else if (disp_stat == "median")
   fields (info,"1,4",lines="1-",print-,>> tmp1)
else
   fields (info,"1,5",lines="1-",print-,>> tmp1)
           
gylabel = disp_stat
gtitle = "ABU IMAGE STATISTICS"         
graph (tmp1, axis=1, transpose-, point+, marker="plus", szmarker=0.01,
          logx-, logy-, box+, ticklabels+, lintran-, append-, round+, fill+,
	  overplot-,xlabel=gxlabel,ylabel=gylabel, title=gtitle)

if (plot_temp) {
   fields(info,"1,7") |
      graph(STDIN, point-,logx-,logy-,box+,ticklabels+,lintran-,append-,
            overplot+,wy1=tmin,wy2=tmax,xlabel="",ylabel="",title="")
   fields(info,"1,8") |
      graph(STDIN, point-,logx-,logy-,box+,ticklabels+,lintran-,append-,
            overplot+,wy1=tmin,wy2=tmax,xlabel="",ylabel="",title="")
   fields(info,"1,9") |
      graph(STDIN, point-,logx-,logy-,box+,ticklabels+,lintran-,append-,
            overplot+,wy1=tmin,wy2=tmax,xlabel="",ylabel="",title="")
}
	     
skip:

list1 = ""; list2 = ""; l_list = ""
delete (tmp1//","//tmp2, verify-, >& "dev$null")
delete (secfile//","//info//","//infile, verify-, >& "dev$null")

end
