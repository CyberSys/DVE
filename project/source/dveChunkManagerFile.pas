unit dveChunkManagerFile;

// Include file operations for load and save
// Separate for modularity

interface

uses
  // Project
  dveChunk,
  dveChunkManager,

  // External
  SynBigTable,
  Neslib.FastMath
  ;

type

TChunkManagerFile = class(TChunkManager)
  protected
    Storage: TSynBigTableString;

  public
    constructor Create; dynamic;
    destructor Destroy; override;

    function ChunkLoadCreate(aID: String): TChunk; override;  // Load or create chunk. Always returns one, use responsibly
                                                              // Immediately close by chunks

end;

implementation

constructor TChunkManagerFile.Create;
begin
  inherited Create;

  Storage := TSynBigTableString.Create('Mapdata.bin');
end;

destructor TChunkManagerFile.Destroy;
begin
  Storage.Free;

  Inherited Destroy;
end;


function TChunkManagerFile.ChunkLoadCreate(aID: string): TChunk;
var
  C: TVector3;
begin
  // Check from loaded chunks
  if ListLoaded.TryGetValue(aID, Result) then exit;

  // Check from disk
  // Yeah it wasn't on the disk now go away!

  // Create it from thin air
  C := CoordsFromID(aID);
  Result := TChunk.Create(aSizeEdge, round(C.X), round(C.Y), round(C.Z));
end;



end.
