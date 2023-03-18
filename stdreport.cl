# STDREPORT: 26APR99 KMM
# STDREPORT  report image info to a file

procedure stdreport (input)

string input       {prompt="Input processed image name"}

string mag_postfix {"mag", prompt="QPHOT output file postfix"}
bool   mktable     {no, prompt="Make database table?"}
bool   plotrad     {no, prompt="Plot radial profile?"}
bool   fancyout    {no, prompt="Fancy printout with |s to delineate?"}
string img_dir     {"", prompt="Image directory"}

bool   dofit       {yes, prompt="Run image profile fit on standards"}
bool   dophot      {yes, prompt="Run QPHOT on standards"}
real   qcbox       { 5., prompt="Centering box width in pixels"}
real   qannulus    { 10., prompt="Inner radius of sky annulus in pixels"}
real   qdannulus   { 3., prompt="Width of the sky annulus in pixels"}
string qapertures  { "5,6,7,8,9,10", prompt="List of photometry apertures"}
real   qzmag       { 25., prompt="Zero point of magnitude scale"}
string qexposure   { "INT_S", prompt="Exposure time image header keyword"}
string qairmass    { "AIRMAS", prompt="Airmass image header key word"}
string qfilter     { "FILTER", prompt="Filter image header keyword"}
string filter      { "", prompt="Filter name?"}
string qstarid     { "STAR_ID", prompt="Star ID image header keyword"}
string starid      { "", prompt="Star ID?"}

string qutime      { "UT", prompt="UT time image header keyword"}
string qdate       { "UTDATE", prompt="UT Date image header keyword"}
string qremark     { "REMARK", prompt="Remark image header keyword"}
string qtemp0      { "AMBIENT",prompt="Ambient temperature image header keyword"}
string qtemp1      { "TB.FRNT",prompt="Front temperature image header keyword"}
string qtemp2      { "TB.REAR",prompt="Rear temperature image header keyword"}
string qrawstat    { "RAW_MIDP", prompt="Raw statistic image header keyword"}
string qprocstat   { "PRO_MIDP", prompt="Proc statistic image header keyword"}
string qxcen       { "XCENTER", prompt="Xcenter image header keyword"}
string qycen       { "YCENTER", prompt="Ycenter image header keyword"}

string statsec     {"[50:200,50:200]",
                     prompt="Image section for calculating statistics"}
string norm_stat   {"midpt",enum="none|mean|median|midpt|mode",
                       prompt="statistic: |none|mean|median|midpt|mode"}
real   lthreshold  {INDEF, prompt="Lower threshold for exclusion in statistics"}
real   hthreshold  {INDEF, prompt="Upper threshold for exclusion in statistics"}

bool   verbose     {yes,prompt="Verbose output?"}
file   logfile     {"STDOUT",prompt="logfile name"}

struct  *inlist, *l_list

begin

   int    i, n, nin, nim, irootlen, stat, pos1b, pos1e, pos2b, pos2e,
          nobj, nsky, nok, int_ms, hh, mm, slenmax, npeak, nex
   string in,in1,in2,out,iroot,oroot,uniq,img,sname,sout,sjunk,
          sexpr,sdata,sroot,sstat,sstarid,
          aqmode,aqdate,aqname,sformat,aqut,header,photid,sfilt
   real   x0, y0, z0, airmass, zmin, zmax, zmedian, zmean, rstat, nrstat, 
          zmag,rmag,flux,rsky,zsky,rmom,ellip,pa,gpeak,fwhm,r1,r2,r3,
	  temp,m5,m6,m7,m8,m9,m10,xcen,ycen,itime,tamb,tfront,trear,
	  beta,fwhm_e,fwhm_m,fwhm_d
	  	   
   bool   out_terse
   file   infile, imlist, tmp1, tmp2, photfile, cofile
   string gimextn, imextn, imname, imroot
   
# Assign positional parameters to local variables
   in          = input

   infile      = mktemp ("tmp$irp")
   tmp1        = mktemp ("tmp$irp")
   tmp2        = mktemp ("tmp$irp")
   photfile    = mktemp ("tmp$irp")
   cofile      = mktemp ("tmp$irp")

# check whether input stuff exists
   print (in) | translit ("", "@", "  ") | scan(in1)

   if ((stridx("@",in) == 1) && (! access(in1))) {	# check input @file
      print ("Input file ",in1," does not exist!")
      goto skip
   }

# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
     
# Expand input file name list
#   option="root" truncates lines beyond ".imh" including section info
   sections (in, option="root",> infile)
   if (sections.nimages == 0) {			# check input images
      print ("Input images in file ",in1, " do not exist!")
      goto skip
   }

   count(infile) | scan (pos1b)
   nin = pos1b

# send newline if appending to existing logfile
   if (!mktable) {
      if (access(logfile)) {
         if (logfile == "STDOUT")
            print("\n")
         else
            print("\n",>> logfile)
      }
   }
   
# send newline if appending to existing logfile
   if (access(logfile)) print("\n",>> logfile)
        
   if (norm_stat != "median")
      sstat = norm_stat
   else
      sstat = "midpt"
 
# print(sstarid,aqname,aqdate,aqut,itime,airmass,sfilt,tamb,nrstat,
#       m5,m6,m7,m8,m9,m10,xcen,ycen,rstat,rsky,gpeak,fwhm_e,ellip,pa,
#       tamb,tfront,trear)
   
   if (!fancyout) {
      header = "# OBJECT  IMAGE            DATE        TIME  "
      header = header//"  T(sec)   Z    FILT Tamb   RATE   "
      header = header//" mag5    mag6    mag7    mag8    mag9    mag10 "
      header = header//"  Xcen    Ycen  "
      header = header//"  TOTAL   FITSKY  PEAK    FWHM  ELL   PA"
      sformat = "%-9s "//'%'//-16//"s"//
         " %-8s %05s  %8.3f %5.3f %-4s %5.1f %7.1f"//
         " %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.2f %7.2f"//
         " %7.1f %7.1f %7.1f %5.2f %5.2f %5.2f %5.1f %5.1f %5.1f\n" 
   } else {  
      header = "# OBJECT  IMAGE            | DATE        TIME  "
      header = header//"|  T(sec)   Z    FILT Tamb   RATE   "
      header = header//"|  mag5    mag6    mag7    mag8    mag9    mag10  "
      header = header//"|  Xcen    Ycen   "
      header = header//"|  TOTAL   FITSKY  PEAK    FWHM  ELL   PA"
      sformat = "%-9s "//'%'//-16//"s"//
         " | %-8s %05s | %8.3f %5.3f %-4s %5.1f %7.1f"//
         " | %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f | %7.2f %7.2f"//
         " | %7.1f %7.1f %7.1f %5.2f %5.2f %5.2f\n" 
   }
   if (logfile == "STDOUT" || logfile == "" || logfile == " ") {
      print(header)
   } else {
      print(header,>> logfile)
   }

# Loop through data
   inlist = infile

   slenmax = 0
   while ((fscan (inlist,sdata) != EOF)) {
      m5 = 0; m6 = 0; m7 = 0; m8 = 0; m9=0; m10=0
      txdump(sdata,fields="IMA,XCEN,YCEN,ITIME,XAIR,MAG",expr+,header-,param-,
         >> tmp2) 
      l_list = tmp2 
      stat = fscan(l_list,sname,xcen,ycen,itime,z0,m5,m6,m7,m8,m9,m10) 

#   textfiles = "*.mag.2"       Input apphot/daophot text database(s)
#       fields = "IMA,XCEN,YCEN,ITIME,XAIR,MAG" Fields to be extracted
#         expr = "yes"           Boolean expression for record selection
#     (headers = no)             Print the field headers ?
#  (parameters = no)            Print the parameters if headers is yes ?
      
      aqname = sname
      photid = img_dir//sname
      imgets(photid, qdate)      ; aqdate = imgets.value
      imgets(photid, qutime)     ; aqut   = imgets.value
      print (aqut) | translit ("", ":", " ") | scan(in1,in2)
      aqut = in1//":"//in2

      sfilt = "   "
      if (qfilter != "" && qfilter != " ") {
         imgets(photid, qfilter)
	 sfilt = imgets.value
      } else
        sfilt = filter
	
      sstarid = "       "
      if (qstarid != "" && qstarid != " ") {
         imgets(photid, qstarid)
	 sstarid = imgets.value
      } else
        sstarid = starid
	
      imgets(photid, qairmass)  ; airmass = real(imgets.value)
      airmass = 0.001*real(nint(1000.0*airmass))

      imgets(photid, qexposure) ; z0 = real(imgets.value)
      itime   = 0.001*nint(1000.0*z0)
      
      imgets(photid, qtemp0)    ; z0 = real(imgets.value)
      tamb    = 0.1*nint(10.0*z0)
      imgets(photid, qtemp1)    ; z0 = real(imgets.value)
      tfront  = 0.1*nint(10.0*z0)
      imgets(photid, qtemp2)    ; z0 = real(imgets.value)
      trear   = 0.1*nint(10.0*z0)
            
      imgets(photid, qxcen) ; xcen = real(imgets.value)
      imgets(photid, qycen) ; ycen = real(imgets.value)
      print (xcen, ycen, >> cofile)
            
      imgets(photid, qrawstat ; rstat = real(imgets.value) 
      nrstat = rstat/itime
      
#      if (!mktable) {
#        print("# IMEXAM for ",sname," for SAA peak ",xcen//":"//ycen,
#            " airmass= ",airmass, " Tsec = ",itime)
#      }
         
      rmag = 0.0;   zmag   = 0.0; flux   = 0.0; rsky = 0.0; gpeak = 0.0
      ellip  = 0.0; pa     = 0.0; beta   = 0.0
      fwhm_e = 0.0; fwhm_m = 0.0; fwhm_d = 0.0
            
      if (dofit) {
      
         imexamine(photid,use-,imagecur=cofile,def="a",>> tmp1)
	 
#   COL    LINE   COORDINATES
#     R    MAG    FLUX     SKY    PEAK    E   PA BETA ENCLOSED   MOFFAT DIRECT
# 520.59  440.82 520.59 440.82
# 15.66 -14.39 569565.  -944.1  12913. 0.22  -87 1.82     5.11     4.97   5.22	
 
         type (tmp1) | fields ("STDIN","1-11",lines="4") |
           scan (rmag,zmag,flux,rsky,gpeak,ellip,pa,beta,fwhm_e,fwhm_m,fwhm_d)

      }
      
      printf(sformat,sstarid,aqname,aqdate,aqut,itime,airmass,
	 sfilt,tamb,nrstat,m5,m6,m7,m8,m9,m10,xcen,ycen,rstat,	    
	 rsky,gpeak,fwhm_e,ellip,pa,tamb,tfront,trear)
	    
#      if (mktable) {
#	 
#         if (logfile == "STDOUT") {
#            printf(sformat,sstarid,aqname,aqdate,aqut,itime,airmass,
#	    sfilt,tamb,nrstat,m5,m6,m7,m8,m9,m10,xcen,ycen,rstat,	    
#	    rsky,gpeak,fwhm_e,ellip,pa)
#         } else {
#         }
#     } else {
#         type (tmp1,>> logfile)
#         if (plotrad) {
#            imexamine(photid,use-,imagecur=cofile,def="r",ncst=nsize1,
#               nlst=nsize1)
#         }
#         if (qphot) {
#            print("# QPHOT photometry for ",sname," for apertures : ",apertures)
#            qphot(photid,cbox,annulus,dannulus,apertures,coords=cofile,zmag=0,
#               output=photfile,inter-,radplot-,verb+,icommands="",gcommands="")
#      sstat= "RAPERT,MAG,MERR,MSKY"
#      txdump(photfile,sstat,yes,header-,param-,>> logfile)
#         }
#         if (logfile == "STDOUT")
#            print("\n")
#         else
#            print("\n",>> logfile)
#     }
      l_list = ""
      delete (tmp1//","//tmp2//","//photfile//","//cofile,ver-,>& "dev$null")
   }

   skip:

   # Finish up
      inlist = ""; l_list = ""
      delete (infile//","//photfile//","//cofile,ver-,>& "dev$null")
      delete (tmp1//","//tmp2,ver-,>& "dev$null")
end
   
# txdump
#   textfiles = "*.mag.2"       Input apphot/daophot text database(s)
#       fields = "IMA,XCEN,YCEN,ITIME,XAIR,MAG" Fields to be extracted
#         expr = "yes"           Boolean expression for record selection
#     (headers = no)             Print the field headers ?
#  (parameters = no)            Print the parameters if headers is yes ?
#                    Image Reduction and Analysis Facility
#PACKAGE = tv
#   TASK = rimexam
#
#(banner =                  yes) Standard banner
#(title  =                     ) Title
#(xlabel =               Radius) X-axis label
#(ylabel =          Pixel Value) Y-axis label
#(fitplot=                  yes) Overplot gaussian fit?
#(center =                  yes) Center object in aperture? 
#(backgro=                  yes) Fit and subtract background?
#(radius =                 12.5) Object radius
#(buffer =                  2.5) Background buffer width
#(width  =                   5.) Background width
#(xorder =                    0) Background x order
#(yorder =                    0) Background y order
#(magzero=                   0.) Magnitude zero point
#(rplot  =                  15.) Plotting radius
# INSTRUME= 'ABU               '  /
# OBJECT  = 'Abu/SPIREX (South Pole)                                             '
# COADDS  =                    1  /  No. internal coadds
# INT_S   =            20.000000  /  Exposure time
# EXPTIME =            20.000000  /  Exp.time (usual)
# MODE    = 'stare4            '  /
# LNRS    =                    1  /  Low noise reads
# NDAVG   =                    1  /  AtoD averages
# UCODE   = 'ASPP_ABU_1024_01  '  /  Detector microcode
# COMMENT = 'none              '  /
# VAR1    = 'This setup is for 700mv detector bias                              '
# OBSERVAT= 'CARA/South Pole   '  /
# TELESCOP= 'Spirex            '  /
# UT      = '17:22:05          '  /  Universal time
# UTDATE  = '1999-Mar-06       '  /
# DATE    = '07-03-99          '  /
# PLATE_SC=             0.600000  /  Arc sec. per pixel
# RECID   = 'spirex.990307.052205.196                                           '
# LST     =             4.000000  /
# EPOCH   =          2000.000000  /
# AIRMAS  =             1.098000  /
# RA      = '05:45:06.11       '  /
# DEC     = '-65:38:08.0       '  /
# RAOFF   =           942.000000  /
# DECOFF  =         -2229.000000  /
# AZ      =            21.799999  /
# ALT     =            65.599998  /
# REMARK  = 'CROSS, ddor,pah, #1, ON                                            '
# AMBIENT =           228.445007  /
