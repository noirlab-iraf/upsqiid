procedure grid (input,ra0,dec0)

string input {prompt="List of positions"}
real   ra0   {prompt="Initial RA"}
real   dec0  {prompt="Initial DEC"}

struct *inlist

begin

real   ra,dec,ra00,dec00,x,y,cosd
string in, name

in = input
ra00 = ra0
dec00 = dec0
cosd = cos(dec00/57.2957795)
print (cosd)

inlist = in
while (fscan(inlist,name,ra,dec) != EOF) {

   x = -(ra - ra00)*3600.0*15*cosd
   y = (dec - dec00)*3600.0

   printf ("%15s %8.2f %8.2f \n",name,x,y)

}

end
