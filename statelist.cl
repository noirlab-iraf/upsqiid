# STATELIST: 04AUG98 KMM expects IRAF 2.11Export or later
# STATELIST: 02JAN95 KMM generate lists of on or off frames for input images
#    generated from the following protocols
#        all_on:  + + + + +   order=1
#          pair:  +- +- +-    order=2
#         triad:  +-+ +-+     order=3
#          quad:  +--+ +--+   order=4
#      alt-quad:  -++- -++-   order=5
#     alt-triad:  -++ -++     order=6
# STATELIST: 18FEB95 KMM Shorten rowlength of final table so longer pathnames
#                        will work (was overflowing linelength allowed for
#                        "fields"/"type".
#                        Lines with ## contain an alternative, more aggressive,
#                        solution which holds down the row lengths within the
#                        intermediate tables.
# STATELIST: 28JUL98 KMM add global image extension
#                        eliminate STSDAS table package dependency
# STATELIST: 03AUG98 KMM add alternative quad processing -++- and
#                            alternative triad processing -++
#                        enable multiple images per state, e.g.:
#                                 multiple=2 alt_triad
#                                   --++++ --++++ --++++
# STATELIST: 04AUG98 KMM add new variable output "format"
#                          when state = "obj|on|off|sky"
#                            if format = 1name   on|off
#                            if format = group   on|off, group#
#                            else                on|off, group#, list#
#                          when state = "op"
#                            if format = 1name   on, nearest off
#                            if format = 2name   on, nearest 2 offs
#                            if format = group   on, nearest 2 offs, group#
#                            else              on, nearest 2 offs, group#, list#

procedure statelist (input)

string input      {prompt="Input raw images"}
int    order      {2, min=1, max=6,
               prompt="Pattern # 1:++ 2:+- 3:+-+ 4:+--+ 5:-++- 6:-++ ?"}
int    multiple   {1, prompt="Number of frames at each pattern state?"} 
string state      {"on",prompt="Image state selected: on|obj|off|op|sky",
                        enum="on|obj|off|op|sky"}
string format     {"full",prompt="Output format: 1name|2name|group|full ?",
                   enum="1name|2name|group|full"}

struct  *inlist,*onlist,*offlist

begin

   int    nin, stat, pos1b, pos1e, pos2b, pos2e,
          nex, nim, non, ntot, noff, noff0, noff1, noff2,
          num, ngp, ngp0, ngp1, ngp2
   real   rnorm, rmean, rmedian, rmode, objdiffstat, objonstat, objoffstat,
          skyonstat, skyoffstat, skydiffstat
   string in,in1,in2,out,iroot,oroot,uniq,img,sname,sout,sjunk
   file   infile, outfile, onfile, offfile, opfile, tmp1
   string gimextn, imextn, imname, imroot
   string on, off, off0, off1, off2

   struct line = ""

# Assign positional parameters to local variables
   in          = input
   num         = multiple
   
# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)
   
   infile      = mktemp ("tmp$stl")
   outfile     = mktemp ("tmp$stl")
   onfile      = mktemp ("tmp$stl")
   offfile     = mktemp ("tmp$stl")
   tmp1        = mktemp ("tmp$stl")

# check whether input stuff exists
   print (in) | translit ("", "@:", "  ") | scan(in1,in2)

   if ((stridx("@",in) == 1) && (! access(in1))) {	# check input @file
      print ("Input file ",in1," does not exist!")
      goto skip
   }
   sections (in,option="nolist")
   if (sections.nimages == 0) {			# check input images
      print ("Input images in file ",in, " do not exist!")
      goto skip
   }

# Expand input file name list
#   option="root" truncates lines beyond ".imh" including section info
   sections (in,option="root",> tmp1)

# generate lists of on and off fields
   inlist = tmp1  
   for (nin = 1; (fscan(inlist,imname) != EOF); nin +=1) {
       print(imname," ",nin,>> infile)
   }
   delete (tmp1, verify-,>& "dev$null")
   count(infile)  | scan(ntot)
   inlist = infile
   while(fscan(inlist,imname,nin) != EOF) {
      ngp = int((nin+num-1)/num)
      switch (order) {
         case 1: {		# all_on:  + + + + +
            print(imname," ",nin,ngp,>> onfile)
            print(imname," ",nin,ngp,>> offfile)
         }
         case 2: {		# pair:  +- +- +-
            if (ngp % 2 == 1) 
               print(imname," ",nin,ngp,>> onfile)
            else
               print(imname," ",nin,ngp,>> offfile)
         }
         case 3: {		# triad:  +-+ +-+
            if (ngp % 3 != 2) 
               print(imname," ",nin,ngp,>> onfile)
            else
               print(imname," ",nin,ngp,>> offfile)
         }
         case 4: {		# quad:  +--+ +--+
            if (ngp % 4 <= 1) 
               print(imname," ",nin,ngp,>> onfile)
            else
               print(imname," ",nin,ngp,>> offfile)
         }
         case 5: {		# alt-quad:  -++- -++-
            if (ngp % 4 > 1) 
               print(imname," ",nin,ngp,>> onfile)
            else
               print(imname," ",nin,ngp,>> offfile)
         }
         case 6: {		# alt-triad:  -++ -++
            if (ngp % 3 != 1) 
               print(imname," ",nin,ngp,>> onfile)
            else
               print(imname," ",nin,ngp,>> offfile)
         }
      }
   }
   count(onfile)  | scan(non)
   count(offfile)  | scan(noff)
   off1 = ""; off2 = ""
   offlist = offfile
   onlist = onfile
   if (state == "op") {
      for (non = 1; (fscan(onlist,imname,nin) != EOF); non +=1) {
         ngp = int((non+num-1)/num)
         switch (order) {
            case 1: {		# all_on:  + + + + +
               print (imname," ",imname," ",imname," ",nin,ngp,>> outfile)
            }
            case 2: {		# pair:  +- +- +-
              if (non == 1) {
                  stat = fscan(offlist,off1)
                  stat = fscan(offlist,off2)
               } else if (non > 2) {
                  stat = fscan(offlist,off0)
                  if (stat >= 1) {
                     off1 = off2
                     off2 = off0
                  }
               }
               if (stat >= 1) 
                  print(imname," ",off1," ",off2," ",nin,ngp,>> outfile) 
               else
                  print(imname," ",off2," ",off1," ",nin,ngp,>> outfile)
            }
            case 3: {		# triad:  +-+ +-+
               if (non == 1) {
                  stat = fscan(offlist,off1)
                  stat = fscan(offlist,off2)
                  print(imname," ",off1," ",off2," ",nin,ngp,>> outfile)
                  next
               }
               if (non > 3 && non % 2 == 0) {
                  stat = fscan(offlist,off0)
                  if (stat == 1) {
                     off1 = off2
                     off2 = off0
                  }
               }
               if (non % 2 == 0 && stat >= 1)
                  print(imname," ",off1," ",off2," ",nin,ngp,>> outfile)
               else
                  print(imname," ",off2," ",off1," ",nin,ngp,>> outfile)
            }
            case 4: {		# quad:  +--+ +--+
               if (non == 1) {
                  stat = fscan(offlist,off2)
                  stat = fscan(offlist,off1)
               } else if (non == 2) {
                  stat = fscan(offlist,off2)
               } if (non > 2 && non % 2 == 0) {
                  stat = fscan(offlist,off0)
                  if (stat >= 1) {
                     off1 = off0
                     stat = fscan(offlist,off0)
                     if (stat >= 1) {
                        off2 = off0
                     }
                  }
               }
               if (non % 2 == 0 || stat != 1)
                  print(imname," ",off1," ",off2," ",nin,ngp,>> outfile)
               else
                  print(imname," ",off2," ",off1," ",nin,ngp,>> outfile)
            }
            case 5: {		# alt-quad:  -++- -++-
               if (non == 1) {
                  stat = fscan(offlist,off2)
                  stat = fscan(offlist,off1)
               } else if (non == 2) {
                  stat = fscan(offlist,off2)
               } if (non > 2 && non % 2 == 0) {
                  stat = fscan(offlist,off0)
                  if (stat >= 1) {
                     off1 = off0
                     stat = fscan(offlist,off0)
                     if (stat >= 1) {
                        off2 = off0
                     }
                  }
               }
               if (non % 2 == 0 || stat < 1)
                  print(imname," ",off1," ",off2," ",nin,ngp,>> outfile)
               else
                  print(imname," ",off2," ",off1," ",nin,ngp,>> outfile)
            }
            case 6: {		# alt-triad:  -++ -++
               if (non == 1) {
                  stat = fscan(offlist,off1)
                  stat = fscan(offlist,off2)
                  print(imname," ",off1," ",off2," ",nin,ngp,>> outfile)
                  next
               }
               if (non > 2 && non % 2 == 0) {
                  stat = fscan(offlist,off0)
                  if (stat >= 1) {
                     off1 = off2
                     off2 = off0
                  }
               }
               if (non % 2 == 0 && stat == 0)
                  print(imname," ",off1," ",off2," ",nin,ngp,>> outfile)
               else
                  print(imname," ",off2," ",off1," ",nin,ngp,>> outfile)
            }
         }
      }
      if (format == "1name" )
         fields(outfile,"1,2",lines="1-",print-)
      else if (format == "2name")
         fields(outfile,"1,2,3",lines="1-",print-)
      else if (format == "group")
         fields(outfile,"1,2,3,5",lines="1-",print-)
      else
         fields(outfile,"1,2,3,5,4",lines="1-",print-)
   } else if (state == "off" || state == "sky") {
      if (format == "1name")
         fields (offfile,"1",lines="1-",print-)
      else if (format == "group")
         fields (offfile,"1,3",lines="1-",print-)
      else
         fields (offfile,"1,3,2",lines="1-",print-)
   } else {
      if (format == "1name")
         fields (onfile,"1",lines="1-",print-)
      else if (format == "group")
         fields (onfile,"1,3",lines="1-",print-)
      else
         fields (onfile,"1,3,2",lines="1-",print-)
   }

   skip:

# Finish up
   onlist = ""; offlist = ""; inlist = ""
   delete (onfile//","//offfile//","//infile//","//tmp1, verify-,>& "dev$null")
   
end
