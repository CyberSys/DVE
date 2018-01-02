unit dveChunkManagerFile;

// Include file operations for load and save
// Separate for modularity

// Indices file sturcture     Data type
//    1) ID in savefile       Int64
//    2) X                    Int64
//    3) Y                    Int64
//    4) Z                    Int64


interface


uses
  // Project
  dveChunk,
  dveChunkManager,

  // External
  Neslib.FastMath,

  // System
  System.Classes,
  Generics.Collections
  ;


type


TChunkManagerFile = class(TChunkManager)
  private
    ChunkIndicesFileName: String;
    ChunkDataFileName: String;
    SavedChunkIndices: TDictionary<String, Int64>;

  protected

  public
    constructor Create(const bSizeEdge: Integer); dynamic;
    destructor Destroy; override;

    procedure ChunkSave(const aChunk: TChunk); override;
    function ChunkLoad(const aID: String; var aChunk: TChunk): Boolean; override;
    procedure ChunkListSave(const aList: TDictionary<String, TChunk>);
    function GetID(const ID: Integer): String;
    procedure CreateFiles;

    procedure ChunkIndicesLoad;                                 // Load chunk locations for file from another file
    procedure ChunkIndicesSave;                                 // Save chunk locations to a file
end;


implementation


uses
  // System
  Dialogs,
  VCL.Forms,    // App path
  SysUtils;


constructor TChunkManagerFile.Create(const bSizeEdge: Integer);
begin
  inherited Create(bSizeEdge);

  // Keep track of chunk save indices
  ChunkIndicesFileName  := ExtractFilePath(Application.ExeName)+'\Save\ChunkIndices.bin';
  ChunkDataFileName     := ExtractFilePath(Application.ExeName)+'\Save\ChunkData.bin';
  // Make folder
  {$IOChecks off}
  MkDir('Save');
  {$IOChecks on}

  SavedChunkIndices     := TDictionary<String, Int64>.Create;

  // Load Indices
  ChunkIndicesLoad;

  // Create files that are needed in case they do not exist
  CreateFiles;
end;


destructor TChunkManagerFile.Destroy;
begin
  ChunkIndicesSave;
  SavedChunkIndices.Free;

  Inherited Destroy;
end;


procedure TChunkManagerFile.CreateFiles;
var
  Stream: TFileStream;
begin
 if not FileExists(ChunkDataFileName) then
  begin
    Stream := TFileStream.Create(ChunkDataFileName, fmCreate);
    Stream.Free;
  end;
end;


procedure TChunkManagerFile.ChunkSave(const aChunk: TChunk);
var
  CID: Int64;
  Stream: TFileStream;
  B : TBinaryWriter;
  I: Integer;
begin
  CID := 0;

  // Fetch the chunk save ID
  SavedChunkIndices.TryGetValue(aChunk.IDString, CID);

  // Or append at the end
  if CID = 0 then
    begin
      CID := SavedChunkIndices.Count;
      SavedChunkIndices.AddOrSetValue(aChunk.IDString, CID);
    end;

  // Save
  Stream := TFileStream.Create(ChunkDataFileName, fmOpenReadWrite);
  B := TBinaryWriter.Create(Stream);

  try
    Stream.Position := SizeOf(TBlock) * Length(aChunk.MapData) * (CID-1) ;

    for I := 0 to Length(aChunk.MapData)-1 do
      begin
        B.Write(aChunk.MapData[I].Solid);
        aChunk.MapData[I].Terrain := 1;
        B.Write(aChunk.MapData[I].Terrain);
        B.Write(aChunk.MapData[I].ScanData);

      end;

    B.Close;
  finally

    B.Free;
    Stream.Free;
  end;

end;


procedure TChunkManagerFile.ChunkListSave(const aList: TDictionary<System.string,dveChunk.TChunk>);
var
  CID: Int64;
  Stream: TFileStream;
  B : TBinaryWriter;
  I: Integer;
  C: TChunk;
begin
  // Prepare file
  Stream := TFileStream.Create(ChunkDataFileName, fmOpenReadWrite);
  B := TBinaryWriter.Create(Stream);

  // Loop whole list
  for C in aList.Values do
    begin

      CID := 0;
      // See if the chunk is already saved
      SavedChunkIndices.TryGetValue(C.IDString, CID);

      // Or append at the end
      if CID = 0 then
        begin
          CID := SavedChunkIndices.Count;
          SavedChunkIndices.AddOrSetValue(C.IDString, CID);
        end;

      // Save data
      try
        Stream.Position := SizeOf(TBlock) * Length(C.MapData) * (CID-1) ;

        Stream.WriteBuffer(C.MapData[0], SizeOf(TBlock)*Length(C.MapData) );

//        for I := 0 to Length(C.MapData)-1 do
//          begin
//            B.Write(C.MapData[I].Solid);
//            C.MapData[I].Terrain := 1;
//            B.Write(C.MapData[I].Terrain);
//            B.Write(C.MapData[I].ScanData);
//          end;

      finally

      end;

    end;

    B.Close;
    B.Free;
    Stream.Free;

end;


function TChunkManagerFile.ChunkLoad(const aID: String; var aChunk: TChunk): Boolean;
var
  CID: Int64;
  C: TVector3;
  I: Integer;

  Stream: TFileStream;
  B: TBinaryReader;
begin
  if SavedChunkIndices.TryGetValue(aID, CID) then
    begin
      C := CoordsFromID(aID);
      aChunk := TChunk.Create(aSizeEdge, round(C.X), round(C.Y), round(C.Z), true);
      aChunk.CreateVertices := true;

      Stream := TFileStream.Create(ChunkDataFileName, fmOpenRead);
      B := TBinaryReader.Create(Stream);

      try
        Stream.Position := SizeOf(TBlock) * Length(aChunk.MapData) * (CID-1);

        for I := 0 to Length(aChunk.MapData)-1 do
          begin
            aChunk.MapData[I].Solid     := B.ReadBoolean;
            aChunk.MapData[I].Terrain   := B.ReadByte;
            aChunk.MapData[I].ScanData  := B.ReadByte;
          end;

      finally
        B.Free;
        Stream.Free;
      end;

      Result := true;
    end
  else
    Result := false;
end;


procedure TChunkManagerFile.ChunkIndicesLoad;
var
  Stream: TFileStream;
  BR : TBinaryReader;
  ID, X,Y,Z: Int64;
  I: Integer;
begin
  // No file, cannot load anything
  if not FileExists(ChunkIndicesFileName) then
    begin
      SavedChunkIndices.Clear;
      exit;
    end;

  // Clear indices list
  SavedChunkIndices.Clear;
  Stream := TFileStream.Create(ChunkIndicesFileName, fmOpenRead);
  BR := TBinaryReader.Create(Stream);

  // Occupy indices list
  I := 0;
  try
    while Stream.Position < Stream.Size do
      begin
        ID := BR.ReadInt64;
        X := BR.ReadInt64;
        Y := BR.ReadInt64;
        Z := BR.ReadInt64;

        SavedChunkIndices.AddOrSetValue(ChunkID(X,Y,Z), ID);
        Inc(I);
      end;

  finally
    BR.Free;
    Stream.Free;
  end;

//  ShowMessage(I.ToString + ' Chunks in load list');

end;


procedure TChunkManagerFile.ChunkIndicesSave;
var
  Stream: TFileStream;
  B : TBinaryWriter;
  Loc: TVector3;
  Item: TPair<string, Int64>;
begin

  Stream := TFileStream.Create(ChunkIndicesFileName, fmOpenWrite or fmCreate);
  Stream.Position := 0;
  B := TBinaryWriter.Create(Stream);

  try
    for Item in SavedChunkIndices do
      begin
        B.Write(Item.Value);
        Loc := CoordsFromID(Item.Key);
        B.Write(Int64(Round(Loc.X)));
        B.Write(Int64(Round(Loc.Y)));
        B.Write(Int64(Round(Loc.Z)));
      end;

    B.Close;
  finally

    B.Free;
    Stream.Free;
  end;

end;


function TChunkManagerFile.GetID(const ID: Integer): String;
var
  I: Integer;
  S: String;
begin
  S := 'Undefined';
  I := 0;
  for S in SavedChunkIndices.Keys do
    begin
      if I = ID then break;
      Inc(I);
    end;

  Result := S;

end;


end.
