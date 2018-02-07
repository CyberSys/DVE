// Contains TWorld
unit dveWorld;

interface

uses
  // Own
  dveChunk,

  // External
  Neslib.FastMath,

  // System
  Dialogs,
  SysUtils,
  System.Generics.Collections
  ;

type


TD = TDictionary<String, TChunk>;


{$REGION 'TWorld'}
{ Host class for all static world data

  WorldsSize  }
{$ENDREGION}
TWorld = class

  private
//    fChunkEdgeSize  : Int32;                            // Chunk edge size
//    fWorldSize      : Int64;                            // Maximum


//    procedure SetWorldSize(const Value: Int64);
//    procedure CMFillRecursively(aChunkID: String);

  public
    fChunkEdgeSize  : Int32;                            // Chunk edge size

    { Handles world creation }
    constructor Create; dynamic;

    destructor Destroy; dynamic;

    { World size in Chunks X,Y,Z directions
      The World chunks go into a TDictionary indexed by string }
//    property WorldSize: Int64 read FWorldSize write SetWorldSize;

    { From given start-chunk creates all surronding chunks that may be visible. Purpose: To be able to display initial terrain quickly and leave underground creation for later.
      Each chunk with at least one solid and one non-solid block will recursively try to create all surronding chunks.
        For special case where 'surface' exactly at the edge of two chunks, this will still work, as
        the chunk data array is larger than chunk itself -> Chunk data array is (edge length+2)^3
        effectively holiding one row of data from neighbours on each side.
      If start chunk is in air or under ground, we traverse only up and down, surface will be found eventually?
    }
    procedure CreateSurfaceRecursively(OriginalLoc: TLoc; TestLoc: TLoc; MaxDistance: UInt16; var aTD: TD);


end;

function DistanceLess(A: TLoc; B: TLoc; Distance: Single): boolean;


implementation


function DistanceLess(A: TLoc; B: TLoc; Distance: Single): boolean;
begin

  if
    power(A.X-B.X,2) + power(A.Y-B.Y,2) + power(A.Z-B.Z,2) < power(Distance,2)
  then
    Result := true
  else
    Result := false;

end;


{ TWorld }


constructor TWorld.Create;
begin

end;


destructor TWorld.Destroy;
begin

end;



procedure TWorld.CreateSurfaceRecursively(OriginalLoc: TLoc; TestLoc: TLoc; MaxDistance: UInt16; var aTD: TD);
var
  aChunk: TChunk;
  tmpLoc: TLoc;
begin

  // Check if already exists before creating
  if aTD.ContainsKey(Format('%d.%d.%d', [TestLoc.X,TestLoc.Y,TestLoc.Z])) then exit;

  // Create Chunk
  aChunk := TChunk.Create(fChunkEdgeSize, TestLoc, false);

  // We are an interface chunk that is not in the Dictionary, and not too far
  if  aChunk.Info.AnySolid and                        // Mixed chunk
      aChunk.Info.AnyVoid and                         // Mixed chunk
      DistanceLess(OriginalLoc, TestLoc, MaxDistance) // In Range
  then
    begin
      // Add it to the dictionary
      aTD.AddOrSetValue(aChunk.IDString, aChunk);

      // Try adding the neighbours... 'Follow the surface'
      // X-
        tmpLoc := TestLoc;
        Dec(tmpLoc.X);
        CreateSurfaceRecursively(OriginalLoc, tmpLoc, MaxDistance, aTD);
      // X+
        Inc(tmpLoc.X,2);
        CreateSurfaceRecursively(OriginalLoc, tmpLoc, MaxDistance, aTD);
      // Y-
        tmpLoc := TestLoc;
        Dec(tmpLoc.Y);
        CreateSurfaceRecursively(OriginalLoc, tmpLoc, MaxDistance, aTD);
      // Y+
        Inc(tmpLoc.Y,2);
        CreateSurfaceRecursively(OriginalLoc, tmpLoc, MaxDistance, aTD);
      // Z-
        tmpLoc := TestLoc;
        Dec(tmpLoc.Z);
        CreateSurfaceRecursively(OriginalLoc, tmpLoc, MaxDistance, aTD);
      // Z+
        Inc(tmpLoc.Z,2);
        CreateSurfaceRecursively(OriginalLoc, tmpLoc, MaxDistance, aTD);
    end
  else if
    // We might have original chunk inside earth or up in air. In such case allow up and down to be scanned
    (OriginalLoc.X = TestLoc.X) and                 // X remains same
    (OriginalLoc.Z = TestLoc.Z) and                 // Z remains same
    DistanceLess(OriginalLoc, TestLoc, MaxDistance) // In range
  then
    begin

      // Add it to the dictionary
      aTD.AddOrSetValue(aChunk.IDString, aChunk);

      // Traverse up and down
      // Y-
        tmpLoc := TestLoc;
        Dec(tmpLoc.Y);
        CreateSurfaceRecursively(OriginalLoc, tmpLoc, MaxDistance, aTD);
      // Y+
        Inc(tmpLoc.Y,2);
        CreateSurfaceRecursively(OriginalLoc, tmpLoc, MaxDistance, aTD);

    end
  else
    // Chunk was not useful, release it
    aChunk.Free;

end;


end.
