# PLTNAAC: 09JUL98 KMM
# PLTNAAC:  plot histrograms by quadrant/channel
# PLTNAAC: 25NOV97 KMM
# PLTNAAC: 04MAR98 KMM
# PLTNAAC: 09JUL98 KMM

procedure pltnaac (input,type)

string input      {prompt="Input sigma image"}
string type       {prompt="Type of plot: quad|ch|all",
                      enum="|quad|ch|all|"}

real   z1         {0,prompt="Low threshold for histogram"}
real   z2         {4,prompt="High threshold for histogram"}
int    nbins      {50,prompt="Number ofbins in  histogram"}
bool   stats      {yes,prompt="Output statistics"}
bool   plotit     {yes,prompt="Produce graphical plots"}
bool   raw        {yes,prompt="Raw data (else descrambled)?"}


struct  *list1

begin

   int    nin, irootlen, orootlen, stat, pos1b, pos1e, pos2b, pos2e,
          ncols, nrows, nfirstx, nfirsty, i, iq
   real   xmedian, ymedian, zmedian, x0, y0, z0, 
          xmin, xmax, ymin, ymax, zmin, zmax, rmedian, rmin, rmax, rtest
   string in,in1,in2,out,iroot,uniq,img,sname,sout,sjunk,stype,itype,xlabel
   file   infile, tmp1, tmp2, tmp3, grout

   struct line = ""

# Assign positional parameters to local variables
   in      = input
   stype   = type
   if (stats)
      sout = "STDOUT"
   else
      sout = ""

   infile      = mktemp ("tmp$stl")
   tmp1        = mktemp ("tmp$stl")
   grout       = mktemp ("tmp$stl")

# check whether input stuff exists

   print (in) | translit ("", "@:", "  ") | scan(in1,in2)
   if ((stridx("@",in) == 1) && (! access(in1))) {	# check input @file
      print ("Input file ",in1," does not exist!")
      goto skip
   }
### Note: SAA shift file: ROIR ROIC INTENSITY = y x z
   files (in, sort-, > infile)
   list1 = infile
   while ( fscan(list1,img) != EOF) {
      i = strlen(img)
      if (substr(img,i-3,i) == ".imh") {
         img = substr(img,1,i-4)
         itype = ".imh"
      } else if (substr(img,i-4,i) == ".fits") {
         img = substr(img,1,i-5)
         itype = ".fits"
      } else {
         itype = ""
      }
      iroot = img
      if (plotit) {
#            rtest = max ((rmax+1), 10); nbins = 2 * rmax
#            phist(tmp1,hist_type="cum",append-,logx-,logy-,z1=0,z2=rtest,
#               bin=INDEF,nbins=nbins,xlabel="Data values",ylabel="Counts"
#               title="Max (x,y) peak separation",auto+,round+,fill-,
#               pattern="solid",>>G grout)
         if (stype == "quad" || stype == "all") {
            for (iq = 1; iq <= 4; iq += 1 ) {
               if (raw) {
                   sname = iroot//"["//iq//":2048:4,*]"//itype
               } else {
                   switch (iq) {
                      case 1:
                         sname = iroot//"[1:512,1:512]"//itype
                      case 2:
                         sname = iroot//"[513:1024,1:512]"//itype
                      case 3:
                         sname = iroot//"[1:512,513:1024]"//itype
                      case 4:
                         sname = iroot//"[513:1024,513:1024]"//itype
                   }
               }
               xlabel = "DN rms quad# "//iq
               phist(sname,hist_type="nor",append-,logx-,logy-,z1=z1,z2=z2,
                  bin=INDEF,nbins=nbins,xlabel=xlabel,ylabel="Counts",
                  title=iroot,auto+,round+,fill-,
                  logx-,logy+,pattern="solid",>>G grout)
               if(stats) {
                  imstat(sname,
                    fields="image,npix,mean,midpt,mode,stddev,min,max",
                    lower=INDEF,upper=INDEF,binwidth=0.01,format+)
               }
            }
            gkimosaic (grout,output="",dev="stdgraph",nx=2,ny=2,fill-,rotate-,
               inter-,cursor="")
            delete (grout, verify-,>& "dev$null")
         }
         if (stype == "ch" || stype == "all") {
            for (iq = 1; iq <= 32; iq+= 1 ) {
               if (raw) {
                  sname = iroot//"["//iq//":2048:32,*]"//itype
               } else {
                   switch (iq) {
                      case 1:
                         sname = iroot//"[1:512:8,1:512]"//itype
                      case 2:
                         sname = iroot//"[520:1024:8,1:512]"//itype
                      case 3:
                         sname = iroot//"[1:512:8,513:1024]"//itype
                      case 4:
                         sname = iroot//"[520:1024:8,513:1024]"//itype
                      case 5:
                         sname = iroot//"[2:512:8,1:512]"//itype
                      case 6:
                         sname = iroot//"[519:1024:8,1:512]"//itype
                      case 7:
                         sname = iroot//"[2:512:8,513:1024]"//itype
                      case 8:
                         sname = iroot//"[519:1024:8,513:1024]"//itype
                      case 9:
                         sname = iroot//"[3:512:8,1:512]"//itype
                      case 10:
                         sname = iroot//"[518:1024:8,1:512]"//itype
                      case 11:
                         sname = iroot//"[3:512:8,513:1024]"//itype
                      case 12:
                         sname = iroot//"[518:1024:8,513:1024]"//itype
                      case 13:
                         sname = iroot//"[4:512:8,1:512]"//itype
                      case 14:
                         sname = iroot//"[517:1024:8,1:512]"//itype
                      case 15:
                         sname = iroot//"[4:512:8,513:1024]"//itype
                      case 16:
                         sname = iroot//"[517:1024:8,513:1024]"//itype
                      case 17:
                         sname = iroot//"[5:512:8,1:512]"//itype
                      case 18:
                         sname = iroot//"[516:1024:8,1:512]"//itype
                      case 19:
                         sname = iroot//"[5:512:8,513:1024]"//itype
                      case 20:
                         sname = iroot//"[516:1024:8,513:1024]"//itype
                      case 21:
                         sname = iroot//"[6:512:8,1:512]"//itype
                      case 22:
                         sname = iroot//"[515:1024:8,1:512]"//itype
                      case 23:
                         sname = iroot//"[6:512:8,513:1024]"//itype
                      case 24:
                         sname = iroot//"[515:1024:8,513:1024]"//itype
                      case 25:
                         sname = iroot//"[7:512:8,1:512]"//itype
                      case 26:
                         sname = iroot//"[514:1024:8,1:512]"//itype
                      case 27:
                         sname = iroot//"[7:512:8,513:1024]"//itype
                      case 28:
                         sname = iroot//"[514:1024:8,513:1024]"//itype
                      case 29:
                         sname = iroot//"[8:512:8,1:512]"//itype
                      case 30:
                         sname = iroot//"[513:1024:8,1:512]"//itype
                      case 31:
                         sname = iroot//"[8:512:8,513:1024]"//itype
                      case 32:
                         sname = iroot//"[513:1024:8,513:1024]"//itype
                   }
               }
               xlabel = "DN rms ch# "//iq
               phist(sname,hist_type="nor",append-,logx-,logy-,z1=z1,z2=z2,
                  bin=INDEF,nbins=nbins,xlabel=xlabel,ylabel="Counts",
                  title=iroot,auto+,round+,fill-,
                  logx-,logy+,pattern="solid",>>G grout)
               if(stats) {
                  imstat(sname,
                    fields="image,npix,mean,midpt,mode,stddev,min,max",
                    lower=INDEF,upper=INDEF,binwidth=0.01,format+)
               }
            }
            gkimosaic (grout,output="",dev="stdgraph",nx=8,ny=4,fill-,rotate-,
            inter-,cursor="")
         }
#      if (!plotit)
#         next
      }
   }

   skip:

   # Finish up
   list1 = ""
   delete (infile//","//tmp1, verify-,>& "dev$null")
   delete (grout, verify-,>& "dev$null")
   
end
