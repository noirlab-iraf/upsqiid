# IMCLIP: 22JUN98 KMM expects IRAF 2.11Export or later
# IMCLIP -- Replace values outside a range.
# IMCLIP: 22JUN98 KMM add global image extension

procedure imclip (input, output, revalue)

string  input      {prompt="Input images"}
string  output     {prompt="Clipped output images"}
real    revalue    {prompt="Replacement value"}

string  section    {"[]",prompt="Image section for replacement"}
real    lowerlim   {INDEF,prompt="Lower limit for in/exclusion"}
real    upperlim   {INDEF,prompt="Upper limit for in/exclusion"}
bool    outside    {yes,prompt="Revalue pixels outside/inside range"}
bool	verbose    {yes,prompt="Verbose output?"}

struct  *inlist
struct  *outlist

begin

# Assign positional parameters to local variables
   int    npos
   real   revalu
   string in, out, uniq, sname
   file   infile, outfile 
   int    nex
   string gimextn, imname, imextn, imroot


# Assign positional parameters to local variables
   in          = input
   out         = output
   revalu      = revalue
   uniq        = mktemp ("_Timc")
   infile      = uniq // "_inf"
   outfile     = uniq // "_out"

# get IRAF global image extension
   show("imtype") | translit ("",","," ",delete-) | scan (gimextn)
   nex     = strlen(gimextn)

# Generate temporary data list for dark subtracted frames
   sections (in,  option="root", >> infile)
   sections (out, option="root", >> outfile)
   imcopy (in, out, verbose=no)
   outlist  = outfile
   while (fscan (outlist, sname) != EOF) {
#   # Strip off ".imh"
#         npos  = strlen(sname)
#         if (substr(sname,npos-3,npos) == ".imh")
#            sname = substr(sname,1,npos-4)
         sname = sname // section
      if (outside) {
         if (lowerlim != INDEF)
            imreplace(sname,revalu,imaginary=0.0,lower=INDEF,upper=lowerlim)
         if (upperlim != INDEF)
            imreplace(sname,revalu,imaginary=0.0,lower=upperlim,upper=INDEF)
      } else {
         imreplace(sname,revalue,imaginary=0.0,lower=lowerlim,upper=upperlim)
      }
   }
# Finish up
   delete   (uniq//"*", verify=no)

end
