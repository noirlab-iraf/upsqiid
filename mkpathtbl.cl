# MKPATHTBL 28SEP90 KMM
## MKPATHTBL convert mosaic path position to grid location relative to ll corner

procedure mkpathtbl (start_pos,end_pos,x_max,y_max,path_order,path_corner)

   int    start_pos   {prompt="first path position"}
   int    end_pos     {prompt="last  path position"}
   int    x_max       {prompt="grid dimension in x (== nxsub)"}
   int    y_max       {prompt="grid dimension in y (== nysub)"}
   string path_order  {enum="row|column",prompt="path order: |row|column|"}
   string path_corner {enum="lr|ll|ur|ul",prompt="start corner: |lr|ll|ur|ul|"} 
   bool   sort_grid   {no, prompt="Sort by grid location"}
   bool   format      {no, prompt="Provide neat tabular output via AWK"}

   struct *list1

   begin

      int    nim,gridx,gridy,nxsub,nysub,ncol,pstart,pend
      string corner,order,uniq,snim,sformat
      file   task,tmp1,tmp2

      uniq        = mktemp ("_Tmpt")
      tmp1        = uniq // ".tm1"
      tmp2        = uniq // ".tm2"
      task        = uniq // ".tsk"

      pstart = start_pos
      pend   = end_pos
      nxsub  = x_max
      nysub  = y_max
      order  = path_order
      corner = path_corner
      
   # converting list order to grid position relative to ll corner
      if (order == "row") {
         if (corner == "ll") {
            for (nim = pstart; nim <= pend; nim +=1) {
               gridx = mod(nim-1,nxsub)+1
               gridy = int((nim-1)/nxsub)+1
               snim = "000" + nim
               print (snim," ",gridx,gridy,>> tmp1)
            }
         } else if (corner == "lr") {
            for (nim = pstart; nim <= pend; nim +=1) {
               gridx = nxsub-mod(nim-1,nxsub)
               gridy = int((nim-1)/nxsub)+1
               snim = "000" + nim
               print (snim," ",gridx,gridy,>> tmp1)
            }
         } else if (corner == "ul") {
            for (nim = pstart; nim <= pend; nim +=1) {
               gridx = mod(nim-1,nxsub)+1
               gridy = nysub-int((nim-1)/nxsub)
               snim = "000" + nim
               print (snim," ",gridx,gridy,>> tmp1)
            }
         } else {
            for (nim = pstart; nim <= pend; nim +=1) {
               gridx = nxsub-mod(nim-1,nxsub)
               gridy = nysub-int((nim-1)/nxsub)
               snim = "000" + nim
               print (snim," ",gridx,gridy,>> tmp1)
            }
         }
      } else {
         if (corner == "ll") {
            for (nim = pstart; nim <= pend; nim +=1) {
               gridx = int((nim-1)/nysub)+1
               gridy = mod(nim-1,nysub)+1
               snim = "000" + nim
               print (snim," ",gridx,gridy,>> tmp1)
            }
         } else if (corner == "lr") {
            for (nim = pstart; nim <= pend; nim +=1) {
               gridx = nxsub-int((nim-1)/nysub)
               gridy = mod(nim-1,nysub)+1
               snim = "000" + nim
               print (snim," ",gridx,gridy,>> tmp1)
            }
         } else if (corner == "ul") {
            for (nim = pstart; nim <= pend; nim +=1) {
               gridx = int((nim-1)/nysub)+1
               gridy = nxsub-mod(nim-1,nysub)
               snim = "000" + nim
               print (snim," ",gridx,gridy,>> tmp1)
            }
         } else {
            for (nim = pstart; nim <= pend; nim +=1) {
               gridx = nxsub-int((nim-1)/nysub)
               gridy = nxsub-mod(nim-1,nysub)
               snim = "000" + nim
               print (snim," ",gridx,gridy,>> tmp1)
            }
         }
      }

      if (sort_grid)
   #  sort column  == "x" ncol = 2
         sort (tmp1,col=2,ignore+,num-,rev-)

      if (format) { # Fancy format
         sformat='%03d %03d %03d\\n'
         list1 = tmp1
         for (i = 0; fscan(list1,nim,gridx,gridy) != EOF;
              i += 1) {
            printf(sformat,nim,gridx,gridy,>>out)
         }
      } else
         type (tmp1)

   # Finish up
      list1 = ""
      delete (uniq//"*", verify=no)

   end

# convert mosaic grid location relative to ll corner to path position
#  if (order == "row") {
#     if (corner == "ll") 
#        nim = nxsub*(ny-1) + nx
#     else if (corner == "lr") 
#        nim = nxsub*ny + 1 - nx
#     else if (corner == "ul")
#        nim = nxsub*(nysub-ny) + nx
#     else
#        nim = nxsub*(nysub+1-ny) + 1 - nx
#  }
#  else {
#     if (corner == "ll")
#        nim = nysub*(nx-1) + ny
#     else if (corner == "lr")
#        nim = nysub*(nxsub-nx) +ny
#     else if (corner == "ul")
#        nim = nysub*nx + 1 - ny
#     else
#        nim = nysub*(nxsub+1-nx) + 1 - ny
#  }
