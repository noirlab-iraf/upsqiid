# NOTCHLIST.CL 30SEP92
# NOTCHLIST.CL make list on either side, but not including entry in list
#	useful for generating running statistics

procedure notchlist (full_list,first_in,last_in,exclude_num)

string	full_list    {prompt="Sequential list of candidate images"}
int	first_in     {prompt="Number of first image to include in output list"}
int	last_in      {prompt="Number of last image to include in output list"}
int	exclude_num  {prompt="Number of image to excude from output list"}

struct	*imglist

begin

   string fullist,img
   int	  ilist,firstin,lastin,exclude

# Get query parameters

   fullist = full_list
   firstin = first_in
   lastin  = last_in
   exclude  = exclude_num

   imglist = fullist
   for (ilist = 1; fscan(imglist,img) != EOF; ilist += 1) {
      if (ilist > lastin) bye
      if ((ilist >= firstin) && (ilist != exclude))
	  files(img)
   }
			    
end
