// Translated and modified from C++ file that was under MIT license
// Therefore this file is as well under the MIT as well https://opensource.org/licenses/MIT

unit dveSimplexNoise1234;


interface


{$REGION 'Constants'}
const

// A lookup table to traverse the simplex around a given point in 4D.
// Details can be found where this table is used, in the 4D noise method.
simplex: array [0..63, 0..3] of byte = (
    (0,1,2,3),(0,1,3,2),(0,0,0,0),(0,2,3,1),(0,0,0,0),(0,0,0,0),(0,0,0,0),(1,2,3,0),
    (0,2,1,3),(0,0,0,0),(0,3,1,2),(0,3,2,1),(0,0,0,0),(0,0,0,0),(0,0,0,0),(1,3,2,0),
    (0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),
    (1,2,0,3),(0,0,0,0),(1,3,0,2),(0,0,0,0),(0,0,0,0),(0,0,0,0),(2,3,0,1),(2,3,1,0),
    (1,0,2,3),(1,0,3,2),(0,0,0,0),(0,0,0,0),(0,0,0,0),(2,0,3,1),(0,0,0,0),(2,1,3,0),
    (0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0),
    (2,0,1,3),(0,0,0,0),(0,0,0,0),(0,0,0,0),(3,0,1,2),(3,0,2,1),(0,0,0,0),(3,1,2,0),
    (2,1,0,3),(0,0,0,0),(0,0,0,0),(0,0,0,0),(3,1,0,2),(0,0,0,0),(3,2,0,1),(3,2,1,0)
    );


{$ENDREGION}


{$REGION 'Helpers'}

// Helper functions to compute gradients-dot-residualvectors (1D to 4D)
// Note that these generate gradients of more than unit length. To make
// a close match with the value range of classic Perlin noise, the final
// noise values need to be rescaled to fit nicely within [-1,1].
// (The simplex noise functions as such also have different scaling.)

function Grad1(hash: integer; x: Single): Single;
function Grad2(hash: integer; x, y: Single): Single;
function Grad3(hash: integer; x,y,z: Single): Single;
function Grad4(hash: integer; x,y,z,t: Single): Single;

function SNoise1D(x: Single): Single;
function SNoise2D(x,y: Single): Single;
function SNoise3D(x,y,z: Single): Single;
function SNoise4D(x,y,z,w: Single): Single;

{$ENDREGION}


var
  // Permutation table. Holds random order of one of each of numbers 0-255,
  // Repeated twice to avoid wrapping the index at 255 for each lookup.
  Perm: array [0..511] of byte;


implementation


uses
  Math;


procedure CreateSeed;
var
  I: Integer;
  tempI, tempV: Integer;
begin
  // Initialize 0-255 to values 0-255
  for I := 0 to 255 do
    Perm[I] := I;

  // Randomize content
  for I := 255 downto 1 do
    begin
      tempI := Random(I);     // Remember a random index
      tempV := Perm[tempI];   // Remember a value at the random index

      Perm[tempI] := Perm[I]; // Overwrite at random index with value from current index
      Perm[I]     := tempV;   // Current index value is the values from random index
    end;

  // Repeat and occupy second half of array
  for I := 0 to 255 do
    Perm[I+256] := Perm[I];

end;


function Grad1(hash: Integer; x: Single): Single;
var
  h: integer;
  grad: single;
begin
    h := (hash and 15);
    grad := 1.0 + (h and 7);                // Gradient value 1.0, 2.0, ..., 8.0
    if (h and 8) = h then grad := -grad;    // Set a random sign for the gradient
    result := grad*x;                       // Multiply the gradient with the distance
end;


function Grad2(hash: Integer; x, y: Single): Single;
var
  h: integer;
  u,v,r: single;
begin
  h := (hash and 7);                        // int h = hash & 7;        // Convert low 3 bits of hash code
  if h<4 then u:=x else u:=y;               // float u = h<4 ? x : y;   // into 8 simple gradient directions,
  if h<4 then v:=y else v:=x;               // float v = h<4 ? y : x;   // and compute the dot product with (x,y).

  if (h and 1) = 1 then                     // return ((h&1)? -u : u) + ((h&2)? -2.0f*v : 2.0f*v);
    r := -u else r := u;
  if (h and 2) = 2 then
    r := r+(-2.0*v) else r := r+(2.0*v);

  result := r;
end;


function Grad3(hash: Integer; x,y,z: Single): Single;
var
  h: integer;
  u,v,r: single;
begin
  h := (hash and 15);                 //    int h = hash & 15;     // Convert low 4 bits of hash code into 12 simple
  if (h<8) then u:=x else u:=y;       //    float u = h<8 ? x : y; // gradient directions, and compute dot product.
  if (h<4) then v:=y else if          //    float v = h<4 ? y : h==12||h==14 ? x : z; // Fix repeats at h = 12 to 15
    (h=12) or (H=14) then v:=x else V:=z;

  if (h and 1) = 1 then               //    return ((h&1)? -u : u) + ((h&2)? -v : v);
    r := -u else r := u;
  if (h and 2) = 2 then
    r := r-v else r := r+v;

  result := r;
end;


function Grad4(hash: Integer; x,y,z,t: Single): Single;
var
  h: integer;
  u,v,w,r: single;
begin
  h := (hash and 31);                 //  int h = hash & 31;      // Convert low 5 bits of hash code into 32 simple
  if (h<24) then u:=x else u:=y;      //  float u = h<24 ? x : y; // gradient directions, and compute dot product.
  if (h<16) then v:=y else v:=x;      //  float v = h<16 ? y : z;
  if (h<8) then w:=z else w:=t;       //  float w = h<8 ? z : t;

  if (h and 1)=1 then                 //  return ((h&1)? -u : u) + ((h&2)? -v : v) + ((h&4)? -w : w);
    r := -u else r:= u;
  if (h and 2)=2 then
    r:=r-v else r:=r+v;
  if (h and 4)=4 then
    r:=r-w else r:=r+w;

  result := r;
end;

function SNoise1D(x: Single): Single;
var
  i0, i1: integer;
  x0, x1: single;
  n0, n1: single;
  t0, t1: single;
begin
  i0 := floor(x);                             // int i0 = FASTFLOOR(x);
  i1 := i0+1;                                 // int i1 = i0 + 1;
  x0 := x-i0;                                 // float x0 = x - i0;
  x1 := x0-1.0;                               // float x1 = x0 - 1.0f;
  t0 := 1.0 - x0*x0;                          // float t0 = 1.0f - x0*x0;
                                              // if(t0 < 0.0f) t0 = 0.0f; // this never happens for the 1D case
  t0 := t0*t0;                                // t0 *= t0;
  n0 := t0*t0* grad1(perm[i0 and $FF], x0);   // n0 = t0 * t0 * grad1(perm[i0 & 0xff], x0);
  t1 := 1.0 - x1*x1;                          // float t1 = 1.0f - x1*x1;
                                              // if(t1 < 0.0f) t1 = 0.0f; // this never happens for the 1D case
  t1 := t1*t1;                                // t1 *= t1;
  n1 := t1*t1* grad1(perm[i1 and $FF], x1);   // n1 = t1 * t1 * grad1(perm[i1 & 0xff], x1);

  result := 0.58057117763672979354 * (n0+n1);

end;


function SNoise2D(x, y: Single): Single;
const
  F2 = 0.3660254037844386;      // F2 = 0.5*(sqrt(3.0)-1.0)
  G2 = 0.2113248654051871;      // G2 = (3.0-Math.sqrt(3.0))/6.0
var
  n0, n1, n2: single;           // float n0, n1, n2; // Noise contributions from the three corners
  s, xs, ys: single;
  i, j, ii, jj: integer;
  XX0, YY0, x0, y0: single;     // Capital X0 and Y0 XX0 and YY0 in pascal
  t, x1, y1, x2, y2, t0, t1, t2: single;
  i1, j1: integer;              //  int i1, j1; // Offsets for second (middle) corner of simplex in (i,j) coords
begin
  // Skew the input space to determine which simplex cell we're in
  s := (x+y)*F2;                //  float s = (x+y)*F2; // Hairy factor for 2D
  xs := x+s;                    //  float xs = x + s;
  ys := y+s;                    //  float ys = y + s;
  i := floor(xs);               //  int i = FASTFLOOR(xs);
  j := floor(ys);               //  int j = FASTFLOOR(ys);
  t := (i+j)*G2;                //  float t = (float)(i+j)*G2;
  XX0 := i-t;                   //  float X0 = i-t; // Unskew the cell origin back to (x,y) space
  YY0 := j-t;                   //  float Y0 = j-t;
  x0 := x-XX0;                  //  float x0 = x-X0; // The x,y distances from the cell origin
  y0 := y-YY0;                  //  float y0 = y-Y0;

  // For the 2D case, the simplex shape is an equilateral triangle.
  // Determine which simplex we are in.
  if x0>y0 then begin
    i1 := 1; j1 := 0; end else begin    //  if(x0>y0) {i1=1; j1=0;} // lower triangle, XY order: (0,0)->(1,0)->(1,1)
    i1 := 0; j1 := 1;                   //  else {i1=0; j1=1;}      // upper triangle, YX order: (0,0)->(0,1)->(1,1)
  end;

  // A step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and
  // a step of (0,1) in (i,j) means a step of (-c,1-c) in (x,y), where
  // c = (3-sqrt(3))/6

  x1 := x0-i1+G2;           //  float x1 = x0 - i1 + G2; // Offsets for middle corner in (x,y) unskewed coords
  y1 := y0-j1+G2;           //  float y1 = y0 - j1 + G2;
  x2 := x0-1.0+(2.0*G2);    //  float x2 = x0 - 1.0f + 2.0f * G2; // Offsets for last corner in (x,y) unskewed coords
  y2 := y0-1.0+(2.0*G2);    //  float y2 = y0 - 1.0f + 2.0f * G2;

  // Wrap the integer indices at 256, to avoid indexing perm[] out of bounds
  ii := (i and $FF);        //  int ii = i & 0xff;
  jj := (j and $FF);        //  int jj = j & 0xff;

  // Calculate the contribution from the three corners
  t0 := 0.5 - (x0*x0)-(y0*y0);  //  float t0 = 0.5f - x0*x0-y0*y0;
  if (t0< 0.0) then n0 := 0.0   //  if(t0 < 0.0f) n0 = 0.0f;
  else begin                    //  else {
    t0 := t0*t0;                //    t0 *= t0;
    n0 := t0*t0*grad2(perm[ii+perm[jj]], x0, y0);  //    n0 = t0 * t0 * grad2(perm[ii+perm[jj]], x0, y0);
  end;                          //  }

  t1 := 0.5 - (x1*x1)-(y1*y1);  //  float t1 = 0.5f - x1*x1-y1*y1;
  if (t1 < 0.0) then n1 := 0.0  //  if(t1 < 0.0f) n1 = 0.0f;
  else begin                    //  else {
    t1 := t1*t1;                //    t1 *= t1;
    n1 := t1*t1*grad2(perm[ii+i1+perm[jj+j1]], x1, y1); //    n1 = t1 * t1 * grad2(perm[ii+i1+perm[jj+j1]], x1, y1);
  end;                          //  }

  t2 := 0.5 - (x2*x2)-(y2*y2);  //  float t2 = 0.5f - x2*x2-y2*y2;
  if (t2 < 0.0) then n2 := 0.0  //  if(t2 < 0.0f) n2 = 0.0f;
  else begin                    //  else {
    t2 := t2*t2;//    t2 *= t2;
    n2 := t2*t2*grad2(perm[ii+1+perm[jj+1]], x2, y2); //    n2 = t2 * t2 * grad2(perm[ii+1+perm[jj+1]], x2, y2);
  end;                          //  }

  // Add contributions from each corner to get the final noise value.
  // The result is scaled to return values in the interval [-1,1].
  result := 45.264 * (n0+n1+n2);  //  return 40.0f * (n0 + n1 + n2); // TODO: The scale factor is preliminary!
end;


function SNoise3D(x, y, z: Single): Single;
const
  // Simple skewing factors for the 3D case
  F3 = 0.333333333;       //#define F3 0.333333333
  G3 = 0.166666667;       //#define G3 0.166666667
var
  n0, n1, n2, n3: single;     // float n0, n1, n2, n3; // Noise contributions from the four corners
  s, xs, ys, zs: single;
  i, j, k: integer;
  t, XX0, YY0, ZZ0, x0, y0, z0: single;
  i1, j1, k1: integer;          //    int i1, j1, k1; // Offsets for second corner of simplex in (i,j,k) coords
  i2, j2, k2: integer;          //    int i2, j2, k2; // Offsets for third corner of simplex in (i,j,k) coords
  x1, x2, x3, y1, y2, y3, z1, z2, z3: single;
  ii, jj, kk: integer;
  t0, t1, t2, t3: single;
begin
  // Skew the input space to determine which simplex cell we're in
  s := (x+y+z)*F3;            //    float s = (x+y+z)*F3; // Very nice and simple skew factor for 3D
  xs := x+s;                  //    float xs = x+s;
  ys := y+s;                  //    float ys = y+s;
  zs := z+s;                  //    float zs = z+s;
  i := floor(xs);             //    int i = FASTFLOOR(xs);
  j := floor(ys);             //    int j = FASTFLOOR(ys);
  k := floor(zs);             //    int k = FASTFLOOR(zs);

  t := (i+j+k)*G3;            //    float t = (float)(i+j+k)*G3;
  XX0 := i-t;                 //    float X0 = i-t; // Unskew the cell origin back to (x,y,z) space
  YY0 := j-t;                 //    float Y0 = j-t;
  ZZ0 := k-t;                 //    float Z0 = k-t;
  x0 := x-XX0;                //    float x0 = x-X0; // The x,y,z distances from the cell origin
  y0 := y-YY0;                //    float y0 = y-Y0;
  z0 := z-ZZ0;                //    float z0 = z-Z0;

  if (x0 >= y0) then
    begin
      if (y0 >= z0) then
        begin
          i1:=1;
          j1:=0;
          k1:=0;
          i2:=1;
          j2:=1;
          k2:=0;
        end
      else if (x0 >= z0) then
        begin
          i1:=1;
          j1:=0;
          k1:=0;
          i2:=1;
          j2:=0;
          k2:=1;
        end // X Z Y order
      else
        begin
          i1:=0;
          j1:=0;
          k1:=1;
          i2:=1;
          j2:=0;
          k2:=1;
        end // Z X Y order
    end
  else
    begin
      if (y0 < z0) then
        begin
          i1:=0;
          j1:=0;
          k1:=1;
          i2:=0;
          j2:=1;
          k2:=1;
        end // Z Y X order
      else if (x0 < z0) then
        begin
          i1:=0;
          j1:=1;
          k1:=0;
          i2:=0;
          j2:=1;
          k2:=1;
        end // Y Z X order
      else
        begin
          i1:=0;
          j1:=1;
          k1:=0;
          i2:=1;
          j2:=1;
          k2:=0;
        end // Y X Z order
    end;

  x1 := x0-i1+G3;         // Offsets for second corner in (x,y,z) coords
  y1 := y0-j1+G3;         //    float y1 = y0 - j1 + G3;
  z1 := z0-k1+G3;         //    float z1 = z0 - k1 + G3;
  x2 := x0-i2+(2.0*G3);   //    float x2 = x0 - i2 + 2.0f*G3;   // Offsets for third corner in (x,y,z) coords
  y2 := y0-j2+(2.0*G3);   //    float y2 = y0 - j2 + 2.0f*G3;
  z2 := z0-k2+(2.0*G3);   //    float z2 = z0 - k2 + 2.0f*G3;
  x3 := x0-1.0+(3.0*G3);  //    float x3 = x0 - 1.0f + 3.0f*G3; // Offsets for last corner in (x,y,z) coords
  y3 := y0-1.0+(3.0*G3);  //    float y3 = y0 - 1.0f + 3.0f*G3;
  z3 := z0-1.0+(3.0*G3);  //    float z3 = z0 - 1.0f + 3.0f*G3;

  // Wrap the integer indices at 256, to avoid indexing perm[] out of bounds
  ii := (i and $FF);  //    int ii = i & 0xff;
  jj := (j and $FF);  //    int jj = j & 0xff;
  kk := (k and $FF);  //    int kk = k & 0xff;

  // Calculate the contribution from the four corners
  t0 := 0.6-(x0*x0)-(y0*y0)-(z0*z0);  //    float t0 = 0.6f - x0*x0 - y0*y0 - z0*z0;
  if (t0<0.0) then n0 := 0.0          //    if(t0 < 0.0f) n0 = 0.0f;
    else begin
      t0 := t0*t0;                    //    t0 *= t0;
                                      //    n0 = t0 * t0 * grad3(perm[ii+perm[jj+perm[kk]]], x0, y0, z0);
      n0 := t0*t0*grad3(perm[ii+perm[jj+perm[kk]]], x0, y0, z0);
    end;

  t1 := 0.6-(x1*x1)-(y1*y1)-(z1*z1);  //    float t1 = 0.6f - x1*x1 - y1*y1 - z1*z1;
  if (t1<0.0) then n1 := 0.0          //    if(t1 < 0.0f) n1 = 0.0f;
    else begin
      t1 := t1*t1;                    //    t1 *= t1;
                                      //    n1 = t1 * t1 * grad3(perm[ii+i1+perm[jj+j1+perm[kk+k1]]], x1, y1, z1);
      n1 := t1*t1*grad3(perm[ii+i1+perm[jj+j1+perm[kk+k1]]], x1, y1, z1);
    end;

  t2 := 0.6-(x2*x2)-(y2*y2)-(z2*z2);  //    float t2 = 0.6f - x2*x2 - y2*y2 - z2*z2;
  if (t2<0.0) then n2 := 0.0          //    if(t2 < 0.0f) n2 = 0.0f;
    else begin
      t2 := t2*t2;                    //    t2 *= t2;
                                      //    n2 = t2 * t2 * grad3(perm[ii+i2+perm[jj+j2+perm[kk+k2]]], x2, y2, z2);
      n2 := t2*t2*grad3(perm[ii+i2+perm[jj+j2+perm[kk+k2]]], x2, y2, z2);
    end;

  t3 := 0.6-(x3*x3)-(y3*y3)-(z3*z3);  //    float t3 = 0.6f - x3*x3 - y3*y3 - z3*z3;
  if (t3<0.0) then n3:= 0.0           //    if(t3<0.0f) n3 = 0.0f;
    else begin
      t3 := t3*t3;                    //    t3 *= t3;
                                      //    n3 = t3 * t3 * grad3(perm[ii+1+perm[jj+1+perm[kk+1]]], x3, y3, z3);
      n3 := t3*t3*grad3(perm[ii+1+perm[jj+1+perm[kk+1]]], x3, y3, z3);
    end;

  // Add contributions from each corner to get the final noise value.
  // The result is scaled to stay just inside [-1,1]
  result := 32.698 * (n0+n1+n2+n3);

end;


function SNoise4D(x,y,z,w: Single): Single;
const
  F4 = 0.309016994;
  G4 = 0.138196601;
var
  n0, n1, n2, n3, n4: single;
  s, xs, ys, zs, ws: single;
  i,j,k,l: integer;
  t, XX0, YY0, ZZ0, WW0: single;
  x0, y0, z0, w0: single;
  c, c1, c2, c3, c4, c5, c6: integer;
  i1,i2,i3: integer;
  j1,j2,j3: integer;
  k1,k2,k3: integer;
  l1,l2,l3: integer;
  x1,x2,x3,x4: single;
  y1,y2,y3,y4: single;
  z1,z2,z3,z4: single;
  w1,w2,w3,w4: single;
  ii,jj,kk,ll: integer;
  t0,t1,t2,t3,t4: single;
begin
  s := (x+y+z+w)*F4;    // Factor for 4D skewing
  xs := x+s;
  ys := y+s;
  zs := z+s;
  ws := w+s;
  i := floor(xs);
  j := floor(ys);
  k := floor(zs);
  l := floor(ws);

  t := (i+j+k+l)*G4;    // Factor for 4D unskewing
  XX0 := i-t;           // Unskew the cell origin back to (x,y,z,w) space
  YY0 := j-t;
  ZZ0 := k-t;
  WW0 := l-t;

  x0 := x-XX0;          // The x,y,z,w distances from the cell origin
  y0 := y-YY0;
  z0 := z-ZZ0;
  w0 := w-WW0;

  if x0>y0 then c1:=32 else c1:=0;
  if x0>z0 then c2:=16 else c2:=0;
  if y0>z0 then c3:=8 else c3:=0;
  if x0>w0 then c4:=4 else c4:=0;
  if y0>w0 then c5:=2 else c5:=0;
  if z0>w0 then c6:=1 else c6:=0;
  c := c1+c2+c3+c4+c5+c6;

  if simplex[c][0] >= 3 then i1 := 1 else i1:=0;
  if simplex[c][1] >= 3 then j1 := 1 else j1:=0;
  if simplex[c][2] >= 3 then k1 := 1 else k1:=0;
  if simplex[c][3] >= 3 then l1 := 1 else l1:=0;

  if simplex[c][0] >= 2 then i2 := 1 else i2:=0;
  if simplex[c][1] >= 2 then j2 := 1 else j2:=0;
  if simplex[c][2] >= 2 then k2 := 1 else k2:=0;
  if simplex[c][3] >= 2 then l2 := 1 else l2:=0;

  if simplex[c][0] >= 1 then i3 := 1 else i3:=0;
  if simplex[c][1] >= 1 then j3 := 1 else j3:=0;
  if simplex[c][2] >= 1 then k3 := 1 else k3:=0;
  if simplex[c][3] >= 1 then l3 := 1 else l3:=0;

  x1 := x0-i1+G4;
  y1 := y0-j1+G4;
  z1 := z0-k1+G4;
  w1 := w0-l1+G4;
  x2 := x0-i2+(2.0*G4);
  y2 := y0-j2+(2.0*G4);
  z2 := z0-k2+(2.0*G4);
  w2 := w0-l2+(2.0*G4);
  x3 := x0-i3+(3.0*G4);
  y3 := y0-j3+(3.0*G4);
  z3 := z0-k3+(3.0*G4);
  w3 := w0-l3+(3.0*G4);
  x4 := x0-1+(4.0*G4);
  y4 := y0-1+(4.0*G4);
  z4 := z0-1+(4.0*G4);
  w4 := w0-1+(4.0*G4);

  // Wrap the integer indices at 256, to avoid indexing perm[] out of bounds
  ii := (i and $FF);      //    int ii = i & 0xff;
  jj := (j and $FF);      //    int jj = j & 0xff;
  kk := (k and $FF);      //    int kk = k & 0xff;
  ll := (l and $FF);      //    int ll = l & 0xff;

  // Calculate the contribution from the five corners
  t0 := 0.6-(x0*x0)-(y0*y0)-(z0*z0)-(w0*w0);
  if t0<0.0 then
    n0:=0.0
  else
    begin
      t0 := t0*t0;
      n0 := t0*t0*grad4(perm[ii+perm[jj+perm[kk+perm[ll]]]], x0, y0, z0, w0);
    end;

  t1 := 0.6-(x1*x1)-(y1*y1)-(z1*z1)-(w1*w1);
  if t1<0.0 then
    n1:=0.0
  else
    begin
      t1 := t1*t1;
      n1 := t1*t1*grad4(perm[ii+i1+perm[jj+j1+perm[kk+k1+perm[ll+l1]]]], x1, y1, z1, w1);
    end;

  t2 := 0.6-(x2*x2)-(y2*y2)-(z2*z2)-(w2*w2);
  if t2<0.0 then
    n2:=0.0
  else
    begin
      t2 := t2*t2;
      n2 := t2*t2*grad4(perm[ii+i2+perm[jj+j2+perm[kk+k2+perm[ll+l2]]]], x2, y2, z2, w2);
    end;

  t3 := 0.6-(x3*x3)-(y3*y3)-(z3*z3)-(w3*w3);
  if t3<0.0 then
    n3:=0.0
  else
    begin
      t3 := t3*t3;
      n3 := t3*t3*grad4(perm[ii+i3+perm[jj+j3+perm[kk+k3+perm[ll+l3]]]], x3, y3, z3, w3);
    end;

  t4 := 0.6-(x4*x4)-(y4*y4)-(z4*z4)-(w4*w4);
  if t4<0.0 then
    n4:=0.0
  else
    begin
      t4 := t4*t4;
      n4 := t4*t4*grad4(perm[ii+1+perm[jj+1+perm[kk+1+perm[ll+1]]]], x4, y4, z4, w4);
    end;

  // Sum up and scale the result to cover the range [-1,1]
  result := 20.7283812229237843377111 *(n0+n1+n2+n3+n4);

end;


Initialization

  CreateSeed;

end.


