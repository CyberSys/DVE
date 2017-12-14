unit dveChunk;


interface


uses
// Project
  dveOpenGLHandler,

// External
  Neslib.FastMath;

type


{$REGION 'Directions'}
  // 27 main directions
  // Imagine 3x3x cube with OpenGL righthanded coordinates. X+ Right, Y+ Up, Z+ Behind you.
  // Center of the grid is our reference point d13
  // Looping X,Y,Z from - to + you number the 27 cubes like this:
  // x- y- z- left  bottom  away from you corner is   d0
  // x+ y- z- right bottom  away from you corner is   d2
  // x- y+ z- left  top     away from you corner is   d6
  // x+ y+ z- right top     away from you corner is   d8
  // x- y- z+ left  bottom  close to you corner is    d18
  // x+ y- z+ left  bottom  close to you corner is    d20
  // x- y+ z+ left  top     close to you corner is    d24
  // x+ y+ z+ left  top     close to you corner is    d26
  //            Y=0   Y=0   Y=0   Y=1   Y=1   Y=1   Y=2   Y=2   Y=2
  //            X=0   X=1   X=2   X=0   X=1   X=2   X=0   X=1   X=2
  TDirection = (d0,   d1,   d2,   d3,   d4,   d5,   d6,   d7,   d8,   // Z=0
                d9,   d10,  d11,  d12,  d13,  d14,  d15,  d16,  d17,  // Z=1
                d18,  d19,  d20,  d21,  d22,  d23,  d24,  d25,  d26); // Z=2
{$ENDREGION}


{$REGION 'TBlock'}
TBlock = record
  Solid: Boolean;
  ScanData: Byte;   // This determines which faces need attention
                    // bit  direction   axis
                    // 0 =  d14         x+
                    // 1 =  d16         y+
                    // 2 =  d22         z+
                    // 3 =  d12         x-
                    // 4 =  d10         y-
                    // 5 =  d4          z-
                    // 6 =
                    // 7 =
                    // This structure is currently not used, but may be faster than looking into the mapdata to find if
                    // Neighbours exist.
                    // This would be set on chunk creation (not on load)
                    // and on TBlock state change, for it's neighbouring chunks
end;
{$ENDREGION}


{$REGION 'TChunk'}
{ Chunk is a 1D array of TBlock representing a cube of side length aSizeEdge.
  One extra layer of data is stored on each side of the chunk, so the actual length
  is (aSizeEdge+2)^3
}
TChunk = class
  private
    aID: String;                                                      // Sring ID for location
    aXWorld: Int16;                                                   // World coordinates of chunk
    aYWorld: Int16;                                                   // World coordinates of chunk
    aZWorld: Int16;                                                   // World coordinates of chunk
    aSizeEdge: Cardinal;                                              // Chunk side length
    aSizeEdge2: Cardinal;                                             // Chunk side length with hidden data. One row/column on each side of cube
    aSizeArray2: Cardinal;                                            // Chunk array length
    aUpdateVertices: Boolean;                                         // Needs an update
    aInFrustrum: Boolean;                                             // Chunk is in Frustrum

    function GetPosWorld: TVector3;                                   // Get world position in Chunk-count
    procedure OccupyChunkData;                                        // Fill MapData array
    function GetUpdateVertices: Boolean;                              // Getter
    procedure SetUpdateVertices(const Value: Boolean);                // Setter

  public
//    fSeedStr: String;                                                 // Chunk ID string
    aSkipVertexArray: Boolean;

    MapData: array of TBlock;

    aVertexArray: TVertexArray;                                       // Vertex data for this chunk

    property IDString: String read aID;                               // ID String to hash
    property XWorld: Int16 read aXWorld;                              // Chunk world coordinates
    property YWorld: Int16 read aYWorld;                              // Chunk world coordinates
    property ZWorld: Int16 read aZWorld;                              // Chunk world coordinates
    property PosWorld: TVector3 read GetPosWorld;                     //
    property CreateVertices: Boolean read GetUpdateVertices write SetUpdateVertices;  //
    property SizeEdge: Cardinal read aSizeEdge;                       //
    property SizeArray: Cardinal read aSizeArray2;                    //
    property InFrustrum: boolean read aInFrustrum write aInFrustrum;  //
    property SkipVertexArray: Boolean read aSkipVertexArray write aSkipVertexArray;

    constructor Create(const aSize: Cardinal; const Xworld, Yworld, Zworld: Int16);   //
    destructor Destroy; override;                                     //
    function IndexToBlockLocalCoords(const I: Integer): TVector3;     // Internal coordinates of a block
    function IndexToBlockWorldCoords(const I: Integer): TVector3;     // World coordinates of a block
    function GetBlock(const aIndex: Integer; const aDir: TDirection): TBlock; //
    function AmbientOcclusion2(const aIndex: Cardinal; const aD1, aD2, aD3: TDirection): Single;  //

end;
{$ENDREGION}



// Utility functions
function CoordsToIndex(const iX,iY,iZ: Integer; const aLength: Integer): Integer;

function ChunkID(const aX, aY, aZ: Single):String;



implementation



uses
// Project
  dveUnitSimplexNoise1234,

// External

// system
  Vcl.Dialogs,
  Math,
  SysUtils;



// Get Index from coords
function CoordsToIndex(const iX,iY,iZ: Integer; const aLength: Integer): Integer;
begin
  // If we are outside the current block return -1
//  if (iX >= 0) and (iY >= 0) and (iZ >= 0) and (iX<aLength) and (iY<aLength) and (iZ<aLength) then
    Result :=
      iX +
      iY*aLength +
      iZ*aLength*aLength;
end;

// ID for Chunk
function ChunkID(const aX, aY, aZ: Single):String;
begin
  Result := Format('%d.%d.%d', [NesLib.FastMath.floor(aX), NesLib.FastMath.floor(aY), NesLib.FastMath.floor(aZ)]);
end;



{$REGION 'Chunk'}


constructor TChunk.Create(const aSize: Cardinal; const Xworld: Int16; const Yworld: Int16; const Zworld: Int16);
var
  C: Cardinal;
begin
  aID := Format('%d.%d.%d', [Xworld,Yworld,Zworld]);
  aXWorld := Xworld;
  aYWorld := Yworld;
  aZWorld := Zworld;

  aSizeEdge     := aSize;                             // Chunk edge
  aSizeEdge2    := aSize+2;                           // Chunk edge with extra data. 2 rows, columns one on each side of cube
  aSizeArray2   := aSizeEdge2*aSizeEdge2*aSizeEdge2;  // Total array length
  SetLength(MapData, aSizeArray2);                    // Set block array SizeSide

  OccupyChunkData;
end;


destructor TChunk.Destroy;
begin
  if assigned(aVertexArray) then aVertexArray.Free;

  inherited Destroy;
end;


function TChunk.IndexToBlockLocalCoords(const I: Integer): TVector3;
begin

  // Local coordinates from total array size and real edge length
  Result.X := I mod aSizeEdge2;
  Result.Y := (I div aSizeEdge2) mod aSizeEdge2;
  Result.Z := (I div aSizeEdge2) div aSizeEdge2;

end;


function TChunk.IndexToBlockWorldCoords(const I: Integer): TVector3;
begin

  // Local coords of chunk
  Result := IndexToBlockLocalCoords(I);

  //          Must be offset by -1 to correspond to real world coords because of extra data row
  //                       Chunk world coordinate to block coordinate
  Result.X := Result.X-1 + aXWorld*aSizeEdge;
  Result.Y := Result.Y-1 + aYWorld*aSizeEdge;
  Result.Z := Result.Z-1 + aZWorld*aSizeEdge;

end;


function TChunk.GetBlock(const aIndex: Integer; const aDir: TDirection): TBlock;
begin
  case aDir of
    d0:   Result := MapData[aIndex-(aSizeEdge2*aSizeEdge2)-aSizeEdge2-1];
    d1:   Result := MapData[aIndex-(aSizeEdge2*aSizeEdge2)-aSizeEdge2];
    d2:   Result := MapData[aIndex-(aSizeEdge2*aSizeEdge2)-aSizeEdge2+1];
    d3:   Result := MapData[aIndex-(aSizeEdge2*aSizeEdge2)-1];
    d4:   Result := MapData[aIndex-(aSizeEdge2*aSizeEdge2)];
    d5:   Result := MapData[aIndex-(aSizeEdge2*aSizeEdge2)+1];
    d6:   Result := MapData[aIndex-(aSizeEdge2*aSizeEdge2)+aSizeEdge2-1];
    d7:   Result := MapData[aIndex-(aSizeEdge2*aSizeEdge2)+aSizeEdge2];
    d8:   Result := MapData[aIndex-(aSizeEdge2*aSizeEdge2)+aSizeEdge2+1];

    d9:   Result := MapData[aIndex-aSizeEdge2-1];
    d10:  Result := MapData[aIndex-aSizeEdge2];
    d11:  Result := MapData[aIndex-aSizeEdge2+1];
    d12:  Result := MapData[aIndex-1];
    d13:  Result := MapData[aIndex];
    d14:  Result := MapData[aIndex+1];
    d15:  Result := MapData[aIndex+aSizeEdge2-1];
    d16:  Result := MapData[aIndex+aSizeEdge2];
    d17:  Result := MapData[aIndex+aSizeEdge2+1];

    d18:  Result := MapData[aIndex+(aSizeEdge2*aSizeEdge2)-aSizeEdge2-1];
    d19:  Result := MapData[aIndex+(aSizeEdge2*aSizeEdge2)-aSizeEdge2];
    d20:  Result := MapData[aIndex+(aSizeEdge2*aSizeEdge2)-aSizeEdge2+1];
    d21:  Result := MapData[aIndex+(aSizeEdge2*aSizeEdge2)-1];
    d22:  Result := MapData[aIndex+(aSizeEdge2*aSizeEdge2)];
    d23:  Result := MapData[aIndex+(aSizeEdge2*aSizeEdge2)+1];
    d24:  Result := MapData[aIndex+(aSizeEdge2*aSizeEdge2)+aSizeEdge2-1];
    d25:  Result := MapData[aIndex+(aSizeEdge2*aSizeEdge2)+aSizeEdge2];
    d26:  Result := MapData[aIndex+(aSizeEdge2*aSizeEdge2)+aSizeEdge2+1];
  end;

end;


function TChunk.AmbientOcclusion2(const aIndex: Cardinal; const aD1, aD2, aD3: TDirection): Single;
begin
  Result := 1;

  // Direction aD1 and aD3 are one axis diagonal (edges touching)
  if GetBlock(aIndex, aD1).Solid then Result := Result - 0.4;
  if GetBlock(aIndex, aD3).Solid then Result := Result - 0.4;

  // Direction aD2 is double diagonal            (corner cube)
  // At least one side and corner = half shadow
  if (Result <1) or GetBlock(aIndex, aD2).Solid then Result := 0.6;

end;


// Private


function TChunk.GetPosWorld: TVector3;
begin
  Result.X := aXWorld;
  Result.Y := aYWorld;
  Result.Z := aZWorld;
end;


procedure TChunk.OccupyChunkData;
var
  I: Integer;
  AnySolids: Boolean;
  AnyAir: Boolean;
  C: TVector3;
  N: Single;
begin
  AnySolids := false;
  AnyAir := false;

  for I := 0 to aSizeArray2-1 do
    begin
      MapData[I].Solid := false;

      C := IndexToBlockWorldCoords(I);

//      N := snoise2(C.X, C.Z)*2;

//      Block.Solid = Simplex2(Block.X, Block.Z) < Block.Y/worldheight

//      MapData[I].Solid := ((snoise2(C.Z/74, (C.X+0.123)/31)+1)*0.5) > C.Y/8;
      MapData[I].Solid := snoise2((C.X+1)/100, (C.Z+5)/100)*3 > (C.Y+5);

//      if C.Y < -5 then
//        MapData[I].Solid := true;

//      MapData[I].Solid := random(100)>30;   // 50 Solid
//      MapData[I].Solid := ((X mod 3) = 0) and ((Y mod 3) = 0) and (Z mod 3 = 0);  // Every second coordinate is solid
//      MapData[I].Location := IndexToCoords(I, fSize);

      // We like to know if there is both solid and non-solids in the chunk. If not, no point looping through it again elsewhere
      if MapData[I].Solid = true then
        AnySolids := (AnySolids or true)
      else
        AnyAir := AnyAir or true;

    end;

  CreateVertices := AnySolids and AnyAir;

end;


function TChunk.GetUpdateVertices: Boolean;
begin
  Result := aUpdateVertices;
end;


procedure TChunk.SetUpdateVertices(const Value: Boolean);
begin
  // If we are saying: Set createVertices = true, we will free aVertexArray here
  if (Value = true) and assigned(aVertexArray) then FreeAndNil(aVertexArray);

  aUpdateVertices := Value;
end;


{$ENDREGION}


end.
