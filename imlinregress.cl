# IMLINREGRESS: 17JUL98 KMM
# IMLINFIT  --  perform a pixel by pixel, linear least squares fit
#            to a set of images.

#	The function is:  y = a + b*x
#
#	The coeffs are:	  a = (SUMY * sumx2 - sumx * SUMXY) / delta
#			  b = (nimg * SUMXY - sumx * SUMY)  / delta
#	where:	      delta = (nimg * sumx2 - sumx * sumx)
#
#       UPPERCASE are coadded images, lowercase are scalars.

procedure imlinregress (yimages, ximages, intercept, slope)

string	yimages		{prompt="Y Images (list) to fit"}
string	ximages		{prompt="X Images (list) to fit"}
string	intercept	{prompt="Output intercept image"}
string	slope		{prompt="Output slope image"}

string	keyword	= ""	{prompt="Keyword for x values"}

struct	*ixlist, *iylist

begin
	string	img, slp, intcpt, sumy, sumxy, sumx, sumxx, delta
	string	ifile, xfile, tfile, ixfile, iyfile, tmp1, tmp2

	int	nimg  = 0

	# Make names for temporary images
	sumx	= mktemp ("_imf")
	sumy	= mktemp ("_imf")
	sumxx	= mktemp ("_imf")
	sumxy	= mktemp ("_imf")
	delta	= mktemp ("_imf")
#	tmp1	= mktemp ("_imf")
#	tmp2	= mktemp ("_imf")

	# Make names for temporary files
	ixfile	= mktemp ("_imf")
	iyfile	= mktemp ("_imf")
	tfile	= mktemp ("_imf")

	# Prompt for the images and expand the template
	sections (ximages, option="fullname", > ixfile)
	sections (yimages, option="fullname", > iyfile)

	# Prompt for the other query parameters
	intcpt	= intercept
	slp	= slope

	# Open the
	iylist = iyfile; ixlist = ixfile
	while (fscan (iylist, img) != EOF) {
	    # Temporary images, 1 per input image
	    print (mktemp ("_imf"), >> tfile)
	    nimg  += 1
	}
	iylist = ""; ixlist = ""


	# Calculate SUMX
	imsum ("@" // ixfile, sumx, option="sum", pix="r", calc="r", verb-)
	# Calculate SUMY
	imsum ("@" // iyfile, sumy, option="sum", pix="r", calc="r", verb-)
	# Calculate SUMXY
	imarith ("@" // iyfile, "*", "@" // ixfile, "@" // tfile,
	    pixtype="real", calctype="real", verbose-, noact-)
	imsum ("@" // tfile, sumxy, option="sum", pix="r", calc="r", verb-)
	imdelete ("@" // tfile, ver-, >& "dev$null")
	# Calculate SUMXX
	imarith ("@" // ixfile, "*", "@" // ixfile, "@" // tfile,
	    pixtype="real", calctype="real", verbose-, noact-)
	imsum ("@" // tfile, sumxx, option="sum", pix="r", calc="r", verb-)
	imdelete ("@" // tfile, ver-, >& "dev$null")

	# Calculate delta = nimg * sumxx - sumx * sumx
        imexpr ("a*b-c**2",delta,nimg,sumxx,sumx)
	imdelete ("@" // tfile, ver-, >& "dev$null")

	# Calculate the intercept
#	The coeffs are:	  a = (SUMY * sumx2 - sumx * SUMXY) / delta
#	where:	      delta = (nimg * sumx2 - sumx * sumx)

        imexpr ("(a*b-c*d)/e",intcpt,sumy,sumxx,sumx,sumxy,delta)
#	imarith (sumy, "*", sumxx, tmp1, pix="r", calc="r", verb-, noact-)
#	imarith (sumxy, "*", sumx, tmp2, pix="r", calc="r", verb-, noact-)
#	imarith (tmp1, "-", tmp2, intcpt, pix="r", calc="r", verb-, noact-)
#	imarith (intcpt, "/", delta, intcpt, pix="r", calc="r", verb-, noact-)
#	imdelete (tmp1//","//tmp2, ver-, >& "dev$null")

	# Calculate the slope
#			  b = (nimg * SUMXY - sumx * SUMY)  / delta
#	where:	      delta = (nimg * sumx2 - sumx * sumx)

        imexpr ("(a*b-c*d)/e",slp,nimg,sumxy,sumx,sumy,delta)
#	imarith (sumxy, "*", nimg, tmp1, pix="r", calc="r", verb-, noact-)
#	imarith (sumy, "*", sumx, tmp2, pix="r", calc="r", verb-, noact-)
#	imarith (tmp1, "-", tmp2, slp, pix="r", calc="r", verb-, noact-)
#	imarith (slp, "/", delta, slp, pix="r", calc="r", verb-, noact-)
#	imdelete (tmp1//","//tmp2, ver-, >& "dev$null")

	# Clean up
	iylist = ""; ixlist = ""
	imdelete (sumy//","//sumxy//","//sumxx//","//sumx, ver-, >& "dev$null")
	delete (ixfile//","//tfile//","//iyfile, ver-, >& "dev$null")

end
