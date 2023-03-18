# IMQUADFIT  --  perform a pixel by pixel, polynomial least squares fit
#            to a set of images.
#
# This is a modified version of imlinfit.cl
#
#
#	The function is:  y = a + b*x + c*x**2
#       
#
#       UPPERCASE are coadded images, lowercase are scalars.

procedure poly  (images, coefa, coefb, coefc)

string	images		{prompt="Images to fit"}
string	coefa   	{prompt="Output coefficient a image"}
string	coefb		{prompt="Output coefficient b image"}
string  coefc           {prompt="Output coefficient c image"}

string	keyword	= "  " 	{prompt="Keyword for x values"}

struct	*ilist
struct	*xlist

begin
	string	img, coa, cob, coc, sumy, sumxy, sumx2y
        string  sumx, sumx2, sumx3, sumx4
	string	ifile, xfile, x2file, x3file, tfile, tmp1, tmp2 
        string  tmp3, tmp4, tmp5, tmp6, tmp7, tmp8, tmp9
        string  tmp10, tmp11, tmp12, tmp13, tmp14, x4file
	real	x, delta1, delta2, delta3, delta

	real	sumpx  = 0.0
	real	sumpx2 = 0.0
        real    sumpx3 = 0.0
        real    sumpx4 = 0.0
	int	nimg  = 0

	# Make names for temporary images
	sumy	= mktemp ("tmp$imf")
	sumxy	= mktemp ("tmp$imf")
        sumx2y  = mktemp ("tmp$imf")
        sumx    = mktemp ("tmp$imf")
        sumx2   = mktemp ("tmp$imf")
        sumx3   = mktemp ("tmp$imf")
        sumx4   = mktemp ("tmp$imf")
	tmp1	= mktemp ("tmp$imf")
	tmp2	= mktemp ("tmp$imf")
	tmp3	= mktemp ("tmp$imf")
	tmp4	= mktemp ("tmp$imf")
        tmp5	= mktemp ("tmp$imf")
	tmp6	= mktemp ("tmp$imf")
	tmp7	= mktemp ("tmp$imf")
	tmp8	= mktemp ("tmp$imf")
	tmp9	= mktemp ("tmp$imf")
	tmp10	= mktemp ("tmp$imf")
	tmp11	= mktemp ("tmp$imf")
	tmp12	= mktemp ("tmp$imf")
        tmp13	= mktemp ("tmp$imf")
	tmp14	= mktemp ("tmp$imf")
	

	# Make names for temporary files
	ifile	= mktemp ("tmp$imf")
	tfile	= mktemp ("tmp$imf")
	xfile	= mktemp ("tmp$imf")
        x2file  = mktemp ("tmp$imf")
        x3file  = mktemp ("tmp$imf")
        x4file  = mktemp ("tmp$imf")

	# Prompt for the images and expand the template
	sections (images, option="fullname", > ifile)

	# Prompt for the other query parameters
	coa	= coefa
        cob     = coefb
        coc     = coefc

	# Open the
	ilist = ifile; xlist = xfile
	while (fscan (ilist, img) != EOF) {
	    # Temporary images, 1 per input image
	    print (mktemp ("tmp$imf"), >> tfile)
	    hselect (img, keyword, yes, >> xfile)
	    if (fscan (xlist, x) != 1)
		error (1, "Keyword `" // keyword // "' not found in " // img)
            print (x*x, >> x2file)
            print (x**3, >> x3file)
            print (x**4, >> x4file)
 	    sumpx  += x
	    sumpx2 += x*x
            sumpx3 += x*x*x
            sumpx4 += x*x*x*x
	    nimg  += 1
        } 
	ilist = ""; xlist = ""

	delta1 = sumpx2*(sumpx*sumpx3 - sumpx2*sumpx2) 
        delta2 = sumpx3*(nimg*sumpx3 - sumpx2*sumpx) 
        delta3 = sumpx4*(nimg*sumpx2 - sumpx*sumpx)
        delta  = delta1 - delta2 + delta3

	# Calculate SUMY
	imsum ("@" // ifile, sumy, option="sum", pixtype="real",
            calctype="real")
	
	# Calculate SUMXY
	imarith ("@" // ifile, "*", "@" // xfile, "@" // tfile,
	    pixtype="real", calctype="real", verbose-, noact-)
	imsum ("@" // tfile, sumxy, option="sum", pixtype="real",
           calctype="real")
        imdelete ("@" // tfile, ver-, >& "dev$null")

        # Calculate SUMX2Y
        imarith ("@" // ifile, "*", "@" // x2file, "@" // tfile,
            pixtype="real", calctype="real", verbose-, noact-)
        imsum ("@" // tfile, sumx2y, option="sum", pixtype="real",
           calctype="real")
        imdelete ("@" // tfile, ver-, >& "dev$null")

        # Calculate SUMX
        imarith ("@" // ifile, "/", "@" // ifile, "@" // tfile,
            pixtype="real", calctype="real", verbose-, noact-)
        imarith ("@" // tfile, "*", "@" // xfile, "@" // tfile,
            pixtype="real", calctype="real", verbose-, noact-)
        imsum ("@" // tfile, sumx, option="sum", pixtype="real",
           calctype="real")
        imdelete ("@" // tfile, ver-, >& "dev$null")

        # Calculate SUMX2
        imarith ("@" // ifile, "/", "@" // ifile, "@" // tfile,
            pixtype="real", calctype="real", verbose-, noact-)
        imarith ("@" // tfile, "*", "@" // x2file, "@" // tfile,
            pixtype="real", calctype="real", verbose-, noact-)
        imsum ("@" // tfile, sumx2, option="sum", pixtype="real",
           calctype="real")
        imdelete ("@" // tfile, ver-, >& "dev$null")

        # Calculate SUMX3
        imarith ("@" // ifile, "/", "@" // ifile, "@" // tfile,
            pixtype="real", calctype="real", verbose-, noact-)
        imarith ("@" // tfile, "*", "@" // x3file, "@" // tfile,
            pixtype="real", calctype="real", verbose-, noact-)
        imsum ("@" // tfile, sumx3, option="sum", pixtype="real",
           calctype="real")
        imdelete ("@" // tfile, ver-, >& "dev$null"

        # Calculate SUMX4
        imarith ("@" // ifile, "/", "@" // ifile, "@" // tfile,
            pixtype="real", calctype="real", verbose-, noact-)
        imarith ("@" // tfile, "*", "@" // x4file, "@" // tfile,
            pixtype="real", calctype="real", verbose-, noact-)
        imsum ("@" // tfile, sumx4, option="sum", pixtype="real",
           calctype="real")
        imdelete ("@" // tfile, ver-, >& "dev$null"

          

	# Calculate coefa
	imarith (sumx, "*", sumx3, tmp1, pix="r", calc="r", verb-, noact-)
	imarith (sumx2, "*", sumx2, tmp2, pix="r", calc="r", verb-, noact-)
	imarith (tmp1, "-", tmp2, tmp3, pix="r", calc="r", verb-, noact-)
       	imarith (tmp3, "*", sumx2y, tmp4, pix="r", calc="r", verb-, noact-)
    	imarith (sumy, "*", sumx3, tmp5, pix="r", calc="r", verb-, noact-)
        imarith (sumx2, "*", sumxy, tmp6, pix="r", calc="r", verb-, noact-)
        imarith (tmp5, "-", tmp6, tmp7, pix="r", calc="r", verb-, noact-)
        imarith (sumx3, "*", tmp7, tmp8, pix="r", calc="r", verb-, noact-)
        imarith (sumy, "*", sumx2, tmp9, pix="r", calc="r", verb-, noact-)
	imarith (sumx, "*", sumxy, tmp10, pix="r", calc="r", verb-, noact-)
	imarith (tmp9, "-", tmp10, tmp11, pix="r", calc="r", verb-, noact-)
	imarith (tmp11, "*", sumx4, tmp12, pix="r", calc="r", verb-, noact-)
        imarith (tmp4, "-", tmp8, tmp13, pix="r", calc="r", verb-, noact-)
        imarith (tmp13, "+", tmp12, tmp14, pix="r", calc="r", verb-, noact-)
        imarith (tmp14, "/", delta, coa, pix="r", calc="r", verb-, noact-)
        imdelete (tmp1//","//tmp2//","//tmp3//","//tmp4, >& "dev$null")
        imdelete (tmp5//","//tmp6//","//tmp7//","//tmp8, ver-, >& "dev$null")
        imdelete (tmp9//","//tmp10//","//tmp11, ver-, >& "dev$null")
        imdelete (tmp12//","//tmp13//","//tmp14, ver-, >& "dev$null")

	# Calculate coefb
        imarith (sumy, "*", sumx3, tmp1, pix="r", calc="r", verb-, noact-)
	imarith (sumx2, "*", sumxy, tmp2, pix="r", calc="r", verb-, noact-)
	imarith (tmp1, "-", tmp2, tmp3, pix="r", calc="r", verb-, noact-)
       	imarith (tmp3, "*", sumx2, tmp4, pix="r", calc="r", verb-, noact-)
    	imarith (nimg, "*", sumx3, tmp5, pix="r", calc="r", verb-, noact-)
        imarith (sumx, "*", sumx2, tmp6, pix="r", calc="r", verb-, noact-)
        imarith (tmp5, "-", tmp6, tmp7, pix="r", calc="r", verb-, noact-)
        imarith (sumx2y, "*", tmp7, tmp8, pix="r", calc="r", verb-, noact-)
        imarith (nimg, "*", sumxy, tmp9, pix="r", calc="r", verb-, noact-)
	imarith (sumy, "*", sumx, tmp10, pix="r", calc="r", verb-, noact-)
	imarith (tmp9, "-", tmp10, tmp11, pix="r", calc="r", verb-, noact-)
	imarith (tmp11, "*", sumx4, tmp12, pix="r", calc="r", verb-, noact-)
        imarith (tmp4, "-", tmp8, tmp13, pix="r", calc="r", verb-, noact-)
        imarith (tmp13, "+", tmp12, tmp14, pix="r", calc="r", verb-, noact-)
        imarith (tmp14, "/", delta, cob, pix="r", calc="r", verb-, noact-)
        imdelete (tmp1//","//tmp2//","//tmp3//","//tmp4, ver-, >& "dev$null")
        imdelete (tmp5//","//tmp6//","//tmp7//","//tmp8, ver-, >& "dev$null")
        imdelete (tmp9//","//tmp10//","//tmp11, ver-, >& "dev$null")
        imdelete (tmp12//","//tmp13//","//tmp14, ver-, >& "dev$null")

        # Calculate coefc
        imarith (sumx, "*", sumxy, tmp1, pix="r", calc="r", verb-, noact-)
	imarith (sumy, "*", sumx2, tmp2, pix="r", calc="r", verb-, noact-)
	imarith (tmp1, "-", tmp2, tmp3, pix="r", calc="r", verb-, noact-)
       	imarith (tmp3, "*", sumx2, tmp4, pix="r", calc="r", verb-, noact-)
    	imarith (nimg, "*", sumxy, tmp5, pix="r", calc="r", verb-, noact-)
        imarith (sumy, "*", sumx, tmp6, pix="r", calc="r", verb-, noact-)
        imarith (tmp5, "-", tmp6, tmp7, pix="r", calc="r", verb-, noact-)
        imarith (sumx3, "*", tmp7, tmp8, pix="r", calc="r", verb-, noact-)
        imarith (nimg, "*", sumx2, tmp9, pix="r", calc="r", verb-, noact-)
	imarith (sumx, "*", sumx, tmp10, pix="r", calc="r", verb-, noact-)
	imarith (tmp9, "-", tmp10, tmp11, pix="r", calc="r", verb-, noact-)
	imarith (tmp11, "*", sumx2y, tmp12, pix="r", calc="r", verb-, noact-)
        imarith (tmp4, "-", tmp8, tmp13, pix="r", calc="r", verb-, noact-)
        imarith (tmp13, "+", tmp12, tmp14, pix="r", calc="r", verb-, noact-)
        imarith (tmp14, "/", delta, coc, pix="r", calc="r", verb-, noact-)
        imdelete (tmp1//","//tmp2//","//tmp3//","//tmp4, ver-, >& "dev$null")
        imdelete (tmp5//","//tmp6//","//tmp7//","//tmp8, ver-, >& "dev$null")
        imdelete (tmp9//","//tmp10//","//tmp11, ver-, >& "dev$null")
        imdelete (tmp12//","//tmp13//","//tmp14, ver-, >& "dev$null")

	# Clean up
	imdelete (sumy//","//sumxy//","//sumx2y//","//sumx//","//sumx2//
                 ","//sumx3//","//sumx4, ver-, >& "dev$null")
	delete (ifile//","//tfile//","//xfile//","//x2file//
                 ","//x3file,  ver-,  >& "dev$null")
end
