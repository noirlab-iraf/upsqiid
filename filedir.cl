# FILEDIR: 15JUL00 KMM
# Routine to parse a file name into its directory and its filename

procedure filedir(filename)

string	filename 	{prompt="File name"}
bool    nosection       {yes,prompt="Remove image section"}
string	root		{"",prompt="Returned filename root"}
string	dir   	        {"",prompt="Returned filename directory"}

begin

string	fname		# Equals filename
string	revname		# Reversed version of input string
string  sjunk
int 	ilen,ipos,ic	# String position markers
int	ii		# Counter

# Get query parameter.

fname = filename

# Reverse filename string character by character --> revname.

ilen = strlen(fname)
revname = ""
for (ic=ilen; ic>=1; ic-=1) {
   revname = revname // substr(fname,ic,ic)
}

# Look for the first period in the reversed name.

ipos = stridx("/$",revname)

# If / or $  exists, break filename into directory and root.  Otherwise,
# return null values for the directory, and the whole file name for the root.

if (ipos != 0) {
   root   = substr(fname,ilen-ipos+2,ilen)
   dir    = substr(fname,1,ilen-ipos+1)
} else {
   root   = fname
   dir    =  ""
}
if (nosection) {
   print (root) | translit ("", "[:]", " ") | scan (sjunk)
   root = sjunk
}
##DEBUG:   print ( filename," ",dir," ",root)

end
