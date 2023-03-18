# MKFRAMELIST: 21JUN94 KMM
# MKFRAMELIST expand range of numbers to a list of unique image numbers

procedure mkframelist (image_nums)

string image_nums   {prompt="Selected image numbers|ref_id"}
string nimrange    {prompt="Range of image numbers"}
int    max_nim     {102,prompt="Maximum image number"}
bool   comid       {no,prompt="Output lines as COM_000 + image_number"}
struct  *list1, *list2
struct line = ""

begin

int    ncomp,lo,hi,i
string key,imagenums,sjunk,image_nims
file   tmp1,tmp2,nimlist,procfile

     imagenums   = image_nums 
     ncomp       = max_nim
     tmp1        = mktemp ("tmp$mkf")
     tmp2        = mktemp ("tmp$mkf")
     nimlist     = mktemp ("tmp$mkf")
     procfile    = mktemp ("tmp$mkf")

     # Expand the range of mosaic images
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

  # establish which images are needed
     list1 = procfile
     while (fscan(list1,line) != EOF) {
  # Expand the range of images, including any ref_id
        print (line) | translit ("", "|", ",",del-,coll-) | scan(image_nims)
        if (image_nims == "all" || image_nims == "*")
           image_nims = "1-"//ncomp
        print (image_nims, ",") | translit ("", "^-,0-9", del+) |
           translit ("", "-", "!", del-) | tokens (new-) |
           translit ("", "\n,", " \n", del-, > tmp1)
        list2 = tmp1
        while (fscan (list2, lo, key, hi, sjunk) != EOF) {
           if (nscan() == 0)
              next
           else if (nscan() == 1 && lo >= 1) {
              if (comid) {
                 sjunk = "COM_000" + lo
                 print (sjunk, >> tmp2)
              } else
                 print (lo, >> tmp2)
           } else if (nscan() == 3) {
              lo = min (max (lo, 1), ncomp); hi = min (max (hi, 1), ncomp)
              for (i = lo; i <= hi; i += 1) {
                 if (comid) {
                    sjunk = "COM_000" + i
                    print (sjunk, >> tmp2)
                 } else
                   print (i, >> tmp2)
              }
           }
        }
        delete (tmp1, ver-, >& "dev$null")
     }
     sort (tmp2, col=0, ign+, num+, rev-) | unique (>> nimlist)
     type (nimlist)

err:

     list1 = ""
     delete (tmp1//","//tmp2//","//nimlist//","//procfile, ver-, >& "dev$null")

end
