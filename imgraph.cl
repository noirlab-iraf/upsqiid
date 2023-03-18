# IMGRAPH: 20JUN98 KMM expects IRAF 2.11Export or later
# IMGRAPH - produce  scatterplot of pixels in two images
# IMGRAPH: 26NOV911 KMM
# IMGRAPH: 20JUN98 KMM add global image extension
#                   replace access with imaccess where appropriate

procedure imgraph (x_image,y_image)

string x_image    {prompt="X image?"}
string y_image    {prompt="Y image?"}
string section    {"",prompt="Image subsection [xmin:xmax,ymin:ymax]"}
int    npad       {10,prompt="Number of pixels included +/- central pixel"}
bool   displayit  {no, prompt="Do you want to display X image?"}
bool   zscale     {yes, prompt="DISPLAY using zscale?"}
real   z1         {0.0, prompt="minimum greylevel to be displayed"}
real   z2         {1000.0, prompt="maximum greylevel to be displayed"}
bool   graphit    {yes, prompt="Graph results?"}
string out        {"STDOUT", prompt="Print out XY list?"}
bool   autoscale  {yes, prompt="Autosclae axes?"}
real   wx1        {0.,prompt="left  world x-coord if not autoscaling"}
real   wx2        {0.,prompt="right world x-coord if not autoscaling"}
real   wy1        {0.,prompt="lower world y-coord if not autoscaling"}
real   wy2        {0.,prompt="upper world y-coord if not autoscaling"}
bool   pointmode  { no,prompt="plot points instead of lines?"}
string marker     {"box",prompt="point marker character?"}
real   szmarker   {0.005,prompt="marker size (0 for list input)"}
bool   logx       {no,prompt="log scale x-axis"}
bool   logy       {no,prompt="log scale y-axis"}
string xlabel     {"",prompt="x-axis label"}
string ylabel     {"",prompt="y-axis label"}
int    majrx      {5,prompt="number of major divisions along x grid"}
int    minrx      {5,prompt="number of minor divisions along x grid"}
int    majry      {5,prompt="number of major divisions along y grid"}
int    minry      {5,prompt="number of minor divisions along y grid"}
bool   append     {no,prompt="append to existing plot?"}
bool   round      {no,prompt="round axes to nice values?"}
bool   fill       {no,prompt="fill viewport vs enforce unity aspect ratio?"}

struct  *list1,*list2,*list3,*l_list
imcur   *starco

begin
   file    cofile, tmp0, tmp1, tmp2
   int     i, nin,stat,pos1b,pos1e,nim, ncols,nrows,
           nxref,nyref,nxlosrc,nxhisrc,nylosrc,nyhisrc,wcs
   real    xin,yin,xref,yref
   string  ximage, yimage, sjunk,src,srcsub,sname,key,uniq,imtitle
   bool    getcoords
   int    nex
   string gimextn, imextn, imname, imroot  
   struct command = ""
   struct line = ""
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
   
   uniq     = mktemp ("_Txyp")
   ximage   = x_image
   if (substr(ximage,i-nex,i) == "."//gimextn)	# Strip off imextn
      ximage = substr(ximage,1,i-nex-1)  
   yimage   = y_image
   if (substr(yimage,i-nex,i) == "."//gimextn)	# Strip off imextn
      yimage = substr(yimage,1,i-nex-1)

   tmp0     = mktemp ("tmp$xyp")
   tmp1     = mktemp ("tmp$xyp")
   tmp2     = mktemp ("tmp$xyp")
   cofile   = mktemp ("tmp$xyp")

   if (displayit) {
      if (zscale) { 	# DISPLAY using zscale+
         print ("display "//ximage//" 1 zscale+ fi-" ) | cl
      } else {
         print ("display "//ximage//" 1 z1="//z1//" z2="//z2//" fi-" ) | cl
      }
      frame (1)
   }
   print ("Mark center:")
   print ("Allowed keystrokes: |f(find)|spacebar(find&use)|q(quit)|")
   while (fscan(starco,xin,yin,wcs,command) != EOF) {
      if (substr(command,1,1) == "\\")
         key = substr(command,2,4)
      else
         key = substr(command,1,1)
      if (key == "f")
         print ("Star_coordinates= ",xin,yin)
      else if (key == "040") {			# 040 == spacebar
         print (xin,yin,>> tmp0)
         break
      } else if (key == "q") {
         break
      } else {
         print("Unknown keystroke: ",key," allowed = |f|spacebar|q|")
         beep
      }
   }
   list1 = tmp0
   stat = fscan(list1,xref,yref)	# skip reference image
   nxref = nint(xref); nyref = nint(yref)
   nxlosrc = nxref - npad; nxhisrc = nxref + npad
   nylosrc = nyref - npad; nyhisrc = nyref + npad
   srcsub ="["//nxlosrc//":"//nxhisrc//","//nylosrc//":"//nyhisrc //"]"
   imtitle = ximage//srcsub//yimage
   listpixels (ximage//srcsub,verbose-,>> tmp1)
   listpixels (yimage//srcsub,verbose-,>> tmp2)
   join (tmp1, tmp2, out="STDOUT",max=72,delim=" ",short+,verb+) |
      fields("STDIN","3,6,1-2",lines="1-",quit-,print-,>> cofile)
   if (graphit) {
      if (autoscale)
         graph (cofile,wx1=0,wx2=0,wy1=0,wy2=0,axis=1,transpose-,point+,
            marker=marker,logx=logx,logy=logy,box+,tick+,xlabel=xlabel,
            ylabel=ylabel,title=imtitle,lintran-,vx1=0.,vx2=0.,vy1=0.,vy2=0.,
            majrx=majrx,minrx=minrx,majry=majry,minry=minry,append=append,
            device="stdgraph",round-,fill=fill)
      else
         graph (cofile,wx1=wx1,wx2=wx2,wy1=wy1,wy2=wy2,axis=1,transpose-,point+,
            marker=marker,logx=logx,logy=logy,box+,tick+,xlabel=xlabel,
            ylabel=ylabel,title=imtitle,lintran-,vx1=0.,vx2=0.,vy1=0.,vy2=0.,
            majrx=majrx,minrx=minrx,majry=majry,minry=minry,append=append,
            device="stdgraph",round=round,fill=fill)
   } else if (out != "null" && out != " " && out != "")
      type (cofile)

skip:		 # Clean up

   delete(tmp0//","//tmp1//","//tmp2//","//cofile,ver-,>& "dev$null")

end
