unit dveChunkManager;

interface

uses
  // Own
  dveChunk,
  dveOpenGLHandler,

  // External
  dglOpenGL,
  Neslib.FastMath,

  // System
  Dialogs,
  SysUtils,
  Classes,
  Generics.Collections;

type
  TChunkManager = class
  private
    aSizeEdge: Integer;                                     // Chunk edge size
    aWorldSeed: String;                                     //
    aDistanceView: Integer;                                 // Controls chunk loading to view list, always must be smaller than aDistanceLoad
    aDistanceLoad: Integer;                                 // Controls chunk loading to vicinity list

    aLastVicinityUpdateLocation: TVector3;                  // Location of last Vicinity update

    aOutliers: array of Boolean;                            // Which indices to skip

    procedure Log(const msg: String);                       // Add log entry
    function GetVerticesCount: Cardinal;

  public
    Debug: Boolean;
    Feedback: TStringList;
    ListVicinity: TDictionary<String, TChunk>;              // List of chunks IDs within radius
    ListLoad: TDictionary<String, TChunk>;                  // Chunks to be loaded/created
    ListLoaded: TDictionary<String, TChunk>;                // Chunks to be loaded from disk (Async?)
    ListUnLoad: TDictionary<String, TChunk>;                // Chunks to be unloaded/saved&destroyed (Async?) (From all lists)
    ListVisibility: TDictionary<String, TChunk>;            // Chunks in field of view theorethically viewable

    var InFrustrumCount: Cardinal;
    var ShaderVoxel: TShader;
    var VertexLayoutForVoxel: TVertexLayout;                // Vertex array layout for voxels

    constructor Create;
    Destructor Destroy; Override;

    procedure UpdateOnFrame(const Camera: TCamera);         // Manages lists, run once per frame
    procedure UpdateListVicinity(const Camera: TCamera);    // Run once moved enough
    procedure ListLoadChunksProcess(const Steps: Cardinal); // Process load chunk list
    procedure ListUnloadProcess(const Steps: Cardinal);     // Process unload chunk list one step
    function ChunkLoadCreate(aID: String): TChunk;          // Load or create chunk. Always returns one, use responsibly
                                                            // Immediately close by chunks

    procedure UpdateVertices(const Chunks: TDictionary<String, TChunk>);
    function UpdateChunkFrustrums(const aCamera: TCamera): TMatrix3;        // Updates chunks to know if they are in frustrum

    // Creates Vertices and Indices for a Chunk
    procedure ChunkVertices(aChunk: TChunk; var aVert: TArray<Single>; var aInd: TArray<GLUInt>);

    property VerticesCount: Cardinal read GetVerticesCount;
    property LastVicinityUpdateLocation: TVector3 read aLastVicinityUpdateLocation write aLastVicinityUpdateLocation;


    procedure MakeOutliers;
    function IsOutlier(const aI: Integer): boolean;
//  published
    property SizeEdge: Integer read aSizeEdge write aSizeEdge;
    property WorldSeed: String read aWorldSeed write aWorldSeed;
    property DistanceView: Integer read aDistanceView write aDistanceView;
    property DistanceLoad: Integer read aDistanceLoad write aDistanceLoad;
  end;

function CoordsFromID(aID: String): TVector3;                // Coords from ID

implementation

uses
  System.Diagnostics;



function CoordsFromID(aID: String): TVector3;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  SL.Delimiter := '.';
  SL.StrictDelimiter := True;
  SL.DelimitedText := aID;

  try
    Result.X := StrToInt(SL[0]);
    Result.Y := StrToInt(SL[1]);
    Result.Z := StrToInt(SL[2]);
  except
    raise Exception.Create('thChunkManager:CoordsForID:Bad input:'''+aID+'''');
  end;

  SL.Free;
end;


constructor TChunkManager.Create;
begin
  inherited Create;
  Debug := false;

  FeedBack := TStringList.Create;
  aSizeEdge := 11;    // Default chunk size

  ListVicinity := TDictionary<String, TChunk>.Create;
//  ListLoadGround := TDictionary<String, TChunk>.Create;
  ListLoad := TDictionary<String, TChunk>.Create;
  ListLoaded := TDictionary<String, TChunk>.Create;
  ListUnLoad := TDictionary<String, TChunk>.Create;
  ListVisibility := TDictionary<String, TChunk>.Create;

  // Create voxel related shaders and link the uniforms
  ShaderVoxel := TShader.Create('Resources\Shaders\18AO.vert', 'Resources\Shaders\18AO.frag');

  VertexLayoutForVoxel.Start(ShaderVoxel);
  VertexLayoutForVoxel.Add('position', 3);
  VertexLayoutForVoxel.Add('TexCoordIn', 3);
  VertexLayoutForVoxel.Add('lightLevel', 1);

  aLastVicinityUpdateLocation := Vector3(0,0,99999999);
end;


destructor TChunkManager.Destroy;
var
  C: TChunk;
begin

  // List vicinity will only hold IDs
  for C in ListVicinity.Values do C.Free;
  for C in ListLoad.Values do C.Free;
  for C in ListLoaded.Values do C.Free;
  for C in ListUnLoad.Values do C.Free;
  for C in ListVisibility.Values do C.Free;

  ListVicinity.Free;
  ListLoad.Free;
  ListLoaded.Free;
  ListUnLoad.Free;
  ListVisibility.Free;

  FeedBack.Clear;
  FeedBack.Free;

  ShaderVoxel.Free;

  Inherited Destroy;
end;


procedure TChunkManager.Log(const msg: string);
begin
  if Debug  then
    Feedback.Add(msg);
end;


function TChunkManager.GetVerticesCount;
var
  C: TChunk;
begin
  Result := 0;

  for C in ListLoaded.Values do
    Result := Result + C.aVertexArray.FVertexCount;


end;


procedure TChunkManager.UpdateListVicinity(const Camera: TCamera);
var
  S: TStopWatch;
  x,y,z: Integer;
begin
  S := TStopWatch.Create;
  S.Start;

  // Remember location of this check
  aLastVicinityUpdateLocation := Camera.Position;

  // Faster to start with all-empty
  ListVicinity.Clear;

  // Loop with precalculated value and add chunk IDs
  for x := -DistanceLoad to DistanceLoad do
    for y := -DistanceLoad to DistanceLoad do
      for z := -DistanceLoad to DistanceLoad do
        begin
          if x*x + y*y + z*z < DistanceLoad*DistanceLoad then
            begin
              ListVicinity.AddOrSetValue(ChunkID(
                round(x+Camera.Position.X/aSizeEdge),
                round(y+Camera.Position.Y/aSizeEdge),
                round(z+Camera.Position.Z/aSizeEdge)
              ), nil);
            end;
        end;

  Log('TChunkManager.UpdateListVicinity ms: ' + S.ElapsedMilliseconds.ToString);
end;


procedure TChunkManager.UpdateOnFrame(const Camera: TCamera);
var
  aID: String;
  C: TChunk;
begin
  // Load chunks
//  ListLoadChunksProcess(20);

  // Unload chunks
//  if ListLoad.Count = 0 then ListUnloadProcess(20);

  // If we have moved >75% of the buffered distance -> Update vicinity list
  // Load distance is in Chunks. Distance squared*chunk size* 0.75
  if Camera.Position.DistanceSquared(aLastVicinityUpdateLocation) > ((aDistanceLoad)*(aDistanceLoad)*aSizeEdge*0.15) then
    begin
      UpdateListVicinity(Camera);

      // Update unload list -> mark for removal chunks in listloaded but not in vicinity
      for aID in ListLoaded.Keys do                     // Loop all chunks in memory
        begin
          if (not ListVicinity.ContainsKey(aID)) then   // There is a chunk in memory not present in vicinity list
            begin
              ListLoaded.TryGetValue(aID, C);           // Fetch the chunk
              ListLoaded.Remove(aID);                   // Remove chunk and id from list
              ListUnLoad.AddOrSetValue(C.IDString, C);  // Transfer chunk for removal
            end;
        end;

      // Update load/create list -> add to load list chunks not in memory but in vicinity
      for aID in ListVicinity.Keys do                   // Loop all vicinity chunk IDs
        begin
          if (not ListLoaded.ContainsKey(aID)) and      // Vicinity chunk ID not found in memory
             (not ListLoad.ContainsKey(aID)) then       // And not in load list
          begin
            ListLoad.Add(aID, nil);                     // Add ID to load chunks list
          end;
        end;
    end;

end;


function TChunkManager.ChunkLoadCreate(aID: string): TChunk;
var
  C: TVector3;
begin
  // Check from loaded chunks
  if ListLoaded.TryGetValue(aID, Result) then exit;

  // Check from disk
  //Yeah it wasn't on the disk now go away!

  // Create it from thin air
  C := CoordsFromID(aID);
  Result := TChunk.Create(aSizeEdge, round(C.X), round(C.Y), round(C.Z));
end;


procedure TChunkManager.ListLoadChunksProcess(const Steps: Cardinal);
var
  I: Integer;
  aID: String;
  C: TChunk;
begin
  if ListLoad.Count = 0 then exit;

  // Loop requested amount of times
  for I := 1 to Steps do
    begin
      aID := '';

      if ListLoad.Count > 0 then                          // If we have entries in the ListLoad
        begin
          for aID in ListLoad.Keys do                     // Get first one of the entries in ListLoad
            break;
        end;

      if aID <> '' then                                   // If we do have Chunk to load
        begin
          ListLoad.Remove(aID);                           // Remove the Chunk ID from ListLoad -> no error if nonexistent

          if not ListLoaded.TrygetValue(aID, C) then      // May already have one in it due multiple load lists
            begin
              C := ChunkLoadCreate(aID);                  // Load Chunk from disk or create it

              if C.CreateVertices then                    // Oddly this made id not help speedthings slower
                ListLoaded.AddOrSetValue (C.IDString, C)  // Add to list of loaded chunks -> no error if nonexistent
              else
                C.Free;                                   // Non drawable chunk so free it
            end;
        end
      else                                                // Break out, nothing to process
        break;
    end;
end;


procedure TChunkManager.ListUnloadProcess(const Steps: Cardinal);
var
  I: Integer;
  aID: String;
  C: TChunk;
begin
  if ListUnLoad.Count = 0 then exit;

  for I := 1 to Steps do
    begin

      aID := '';

      if ListUnLoad.Count > 0 then          // If we have entries in the ListUnLoad
        for aID in ListUnLoad.Keys do       // Get one of them
          break;

      if aID <> '' then                     // If we do have Chunk to unload
        begin
          ListUnLoad.TryGetValue(aID, C);   // Get the Chunk from ListUnLoad
          ListUnLoad.Remove(aID);           // Remove from list

          // Save to disk if changed use buffer+async
          //Add save etc here
          FreeAndNil(C);
//          C.Free;
        end
      else                                  // Break out, nothing to process
        break;
    end;

end;


function TChunkManager.UpdateChunkFrustrums(const aCamera: TCamera):TMatrix3;
var
  S: TStopWatch;
  Ch: TChunk;

  PL1A, PL1B, PL1C: TVector3; // Plane Left,    A, B, C points for definitions
  PRA,  PRB,  PRC:  TVector3; // Plane Right    A, B, C points for definitions
  PBA,  PBB,  PBC:  TVector3; // Plane Bottom   A, B, C points for definitions
  PTA,  PTB,  PTC:  TVector3; // Plane Top      A, B, C points for definitions

  Rad: Single;
  RotL, RotR: TMatrix3;       // Rotate front left and right
  CamL, CamR: TVector3;       // Y-Rotated camera front vectors

  PLM: TMatrix3;             // To get the determianant for plane Left
  PRM: TMatrix3;             // To get the determianant for plane Right
  PBM: TMatrix3;             // To get the determianant for plane Bottom
  PTM: TMatrix3;             // To get the determianant for plane Top

begin

  S := TStopWatch.Create;
  S.Start;

  Rad := -45*0.01745329;
  // Rotation Y matrix Left direction
    RotL.Init(
        cos(Rad),   0,    sin(Rad),
        0,          1,    0,
        -sin(Rad),  0,    cos(Rad)
    );

  // Rotation Y matrix right direction
    RotR.Init(
        cos(-Rad),   0,   sin(-Rad),
        0,           1,   0,
        -sin(-Rad),  0,   cos(-Rad)
    );

  // Forward vector rotated over Y axis
    CamL := aCamera.Front * RotL;
    CamR := aCamera.Front * RotR;

  // Establish the planes: determine 3 points in 3D space to define a plane

  // Left plane
    PL1A :=       aCamera.Position/aSizeEdge;                 //
    PL1A.Offset(  -aCamera.Right*2);                          // Offset to left
    PL1B :=       aCamera.Position/aSizeEdge + CamL;          // Same but offset by Left-rotated front vector
    PL1B.Offset(  -aCamera.Right*2);                          // Offset to left
    PL1C :=       aCamera.Position/aSizeEdge + aCamera.Up;    // As PL1A but offset up, forming third point of triangle
    PL1C.Offset(  -aCamera.Right*2);                          // This too offset to left

  // Right plane
    PRA :=        aCamera.Position/aSizeEdge;
    PRA.Offset(   aCamera.Right*2);
    PRB :=        aCamera.Position/aSizeEdge + CamR;
    PRB.Offset(   aCamera.Right*2);
    PRC :=        aCamera.Position/aSizeEdge + aCamera.Up;
    PRC.Offset(   aCamera.Right*2);

  // Bottom plane
    PBA :=        aCamera.Position/aSizeEdge;
    PBA.Offset(   -aCamera.Up*2);
    PBB :=        aCamera.Position/aSizeEdge + aCamera.Front - (aCamera.Up/(aCamera.ZoomX/aCamera.ZoomY));            // Downward bent front
    PBB.Offset(   -aCamera.Up*2);
    PBC :=        aCamera.Position/aSizeEdge + aCamera.Right;   // Right
    PBC.Offset(   -aCamera.Up*2);                               // All moved downwards


  // Top plane
    PTA :=        aCamera.Position/aSizeEdge;
    PTA.Offset(   aCamera.Up*2);
    PTB :=        aCamera.Position/aSizeEdge + aCamera.Front + (aCamera.Up/(aCamera.ZoomX/aCamera.ZoomY));            // Upward
    PTB.Offset(   aCamera.Up*2);
    PTC :=        aCamera.Position/aSizeEdge + aCamera.Right;   // Right
    PTC.Offset(   aCamera.Up*2);                               // All moved downwards


  InFrustrumCount := 0;
  for Ch in ListLoaded.Values do
    begin
      PLM.Init(PL1B-PL1A, PL1C-PL1A, Ch.PosWorld-PL1A);
      PRM.Init(PRB-PRA, PRC-PRA, Ch.PosWorld-PRA);
      PBM.Init(PBB-PBA, PBC-PBA, Ch.PosWorld-PBA);
      PTM.Init(PTB-PTA, PTC-PTA, Ch.PosWorld-PTA);

      if (PLM.Determinant > 0) and (PRM.Determinant < 0) and (PBM.Determinant < 0) and (PTM.Determinant > 0) then
//      if (PLM.Determinant > 0) and (PRM.Determinant < 0) and (PBM.Determinant < 0)  then
//      if (PLM.Determinant > 0) and (PRM.Determinant < 0) then
//      if (PLM.Determinant > 0)  then
        begin
          Inc(InFrustrumCount,1);
          Ch.InFrustrum := true;
        end
      else
        Ch.InFrustrum := false;
    end;

  Result := RotR;

  Log('TChunkManager.UpdateChunkFrustrums ms: ' + S.ElapsedMilliseconds.ToString);
end;


procedure TChunkManager.UpdateVertices(const Chunks: TDictionary<String, TChunk>);
var
  S3S: String;
  c13: TChunk;     // c13 Chunk to process, cN Neighbour

  At: TArray<Single>;                             // Vertex array data
  It: TArray<GLUInt>;                             // Indices array data

  S1, S2, S3: TStopWatch;

  Created: Cardinal;
  Total: Cardinal;
begin
  S1 := TStopWatch.Create;
  S1.Start;
  S3 := TStopWatch.Create;
  Created := 0;
  Total := 0;
  S3S := '';

  for c13 in Chunks.Values do                                       // Loop all TChunks in given list
    begin
      Inc(Total);

      if
//          (c13.CreateVertices = true) and    // Set false for empty chunks
//          (c13.VertexArray = nil)

        (c13.CreateVertices = true)

      then
        begin
          FreeAndNil(c13.aVertexArray);

          SetLength(At, 0);
          SetLength(It, 0);

          // Make vertex, indices data
          S2 := TStopWatch.Create;
          S2.Start;
          ChunkVertices(c13, At, It);
          S2.Stop;

          // Create TVertexArray
          if Length(At) > 0 then
            begin
              S3.Start;
              c13.aVertexArray := TVertexArray.Create(
                                  VertexLayoutForVoxel,
                                  At,
                                  SizeOf(Single)*Length(At),
                                  It[0],
                                  Length(It)
                               );
              S3.Stop;
              c13.CreateVertices := false;
              Inc(Created,1);
            end;
//          else
//            c13.CreateVertices := false;
        end;
//      if S1.ElapsedMilliseconds > 15 then break;

    end;

  Log('');
  Log('TChunkManager.UpdateVertices      Total looped : ' + Total.ToString);
  Log('TChunkManager.UpdateVertices     Total time ms : ' + S1.ElapsedMilliseconds.ToString);
  Log('TChunkManager.UpdateVertices           Created : ' + Created.ToString);
  Log('TChunkManager.UpdateVertices   Created time ms : ' + S2.ElapsedMilliseconds.ToString);
  if S3.ElapsedMilliseconds > 0 then
  Log('TChunkManager.UpdateVertices   Uploaded VAO ms : ' + S3.ElapsedMilliseconds.ToString);
  Log('');

end;


procedure TChunkManager.ChunkVertices(aChunk: TChunk; var aVert: TArray<System.Single>; var aInd: TArray<GLUInt>);
var
  I, I2: Cardinal;
  cw: TVector3;
  CInitialized: Boolean;

  NextVIndexToUse: Integer;
  NextIIndexToUse: Integer;
  IndexOffset: UInt32;
  Highlight: Double;
//  D: TDirection;
  TextureId: Single;
begin
  NextVIndexToUse := 0;
  NextIIndexToUse := 0;
  IndexOffset     := 0;
  Highlight       := 0;

  //                                  Sides  Indices   XYZ + 2 text coord + 1 for light + 1 Tex ID
  SetLength(aVert, aChunk.SizeArray * 6 *    4 *       7);
  SetLength(aInd,  aChunk.SizeArray * 6 *    6);

  // I2 is counter for how much stuff is stored
  I2 := 0;

  // Build the cube sides
  // Loop all blocks in the chunk
  // I is the chunk coordinate index

  for I := 0 to Length(aOutliers)-1 do
    begin
      // Skip blocks on the edges
//      if aOutliers[I] = true then continue;
      if IsOutlier(I) = true then continue;

      CInitialized := false;

      // Only process solid blocks, or blocks at the negative edge
//      if (aChunk.MapData[I].Solid) or (NegativeEdgeBlock) then
//        begin

          // Calculate these only once
          if not CInitialized then
            begin

                Cw := aChunk.IndexToBlockWorldCoords(I);

//              if aChunk.MapData[I].Highlight then                     // Wow so elegant way to highlight :P
//                Highlight := 1
//              else
                Highlight := 0;

              CInitialized := true;
              TextureId := 0;

            end;


{$REGION '            Negative direction'}
            // Side 4 - Back
            if
               (aChunk.MapData[I].Solid = false) and (aChunk.GetBlock(I, d4).Solid=true)
            then
            begin
              aVert[NextVIndexToUse]    :=  0.5 + Cw.X;                 // Point 4
              aVert[NextVIndexToUse+1]  :=  0.5 + Cw.Y;
              aVert[NextVIndexToUse+2]  := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+3]  :=  1.0;                        // tex x
              aVert[NextVIndexToUse+4]  :=  1.0;                        // tex y
              aVert[NextVIndexToUse+5]  :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+6]  :=  aChunk.AmbientOcclusion2(I, d7, d8, d17)+Highlight;

              aVert[NextVIndexToUse+7]  :=  0.5 + Cw.X;                 // Point 5
              aVert[NextVIndexToUse+8]  := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+9]  := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+10] :=  1;
              aVert[NextVIndexToUse+11] :=  0;
              aVert[NextVIndexToUse+12] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+13] :=  aChunk.AmbientOcclusion2(I, d1, d2, d11)+Highlight;

              aVert[NextVIndexToUse+14] := -0.5 + Cw.X;
              aVert[NextVIndexToUse+15] := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+16] := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+17] :=  0;
              aVert[NextVIndexToUse+18] :=  0;
              aVert[NextVIndexToUse+19] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+20] :=  aChunk.AmbientOcclusion2(I, d1, d0, d9)+Highlight;

              aVert[NextVIndexToUse+21] := -0.5 + Cw.X;
              aVert[NextVIndexToUse+22] :=  0.5 + Cw.Y;
              aVert[NextVIndexToUse+23] := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+24] :=  0;
              aVert[NextVIndexToUse+25] :=  1;
              aVert[NextVIndexToUse+26] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+27] :=  aChunk.AmbientOcclusion2(I, d7, d6, d15)+Highlight;

              aInd[NextIIndexToUse]     :=  0 + I2*4+IndexOffset;       // Top right half
              aInd[NextIIndexToUse+1]   :=  1 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+2]   :=  3 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+3]   :=  1 + I2*4+IndexOffset;       // Bottom left half
              aInd[NextIIndexToUse+4]   :=  2 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+5]   :=  3 + I2*4+IndexOffset;

              Inc(NextVIndexToUse, 28);                                 // Next index to use for vertices
              Inc(NextIIndexToUse, 6);                                  // Next index to use for indices
              inc(I2);                                                  // I2 is counter for 4-vertice groups stored. Starts from 0
            end;

//          d10:                                                        // Side - Bottom
            if
               (aChunk.MapData[I].Solid = false) and (aChunk.GetBlock(I, d10).Solid=true)
            then
            begin
              aVert[NextVIndexToUse]    := -0.5 + Cw.X;                 // x 10
              aVert[NextVIndexToUse+1]  := -0.5 + Cw.Y;                 // y 6
              aVert[NextVIndexToUse+2]  := -0.5 + Cw.Z;                 // z
              aVert[NextVIndexToUse+3]  :=  0;                          // texture x
              aVert[NextVIndexToUse+4]  :=  1;                          // texture y
              aVert[NextVIndexToUse+5]  :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+6]  :=  aChunk.AmbientOcclusion2(I, d12, d3, d4)+Highlight;

              aVert[NextVIndexToUse+7]  :=  0.5 + Cw.X;                 // 5
              aVert[NextVIndexToUse+8]  := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+9]  := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+10] :=  1;
              aVert[NextVIndexToUse+11] :=  1;
              aVert[NextVIndexToUse+12] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+13] :=  aChunk.AmbientOcclusion2(I, d4, d5, d14)+Highlight;

              aVert[NextVIndexToUse+14] :=  0.5 + Cw.X;                 // 1
              aVert[NextVIndexToUse+15] := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+16] :=  0.5 + Cw.Z;
              aVert[NextVIndexToUse+17] :=  1;
              aVert[NextVIndexToUse+18] :=  0;
              aVert[NextVIndexToUse+19] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+20] :=  aChunk.AmbientOcclusion2(I, d22, d23, d14)+Highlight;

              aVert[NextVIndexToUse+21] := -0.5 + Cw.X;                 // 2
              aVert[NextVIndexToUse+22] := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+23] :=  0.5 + Cw.Z;
              aVert[NextVIndexToUse+24] :=  0;
              aVert[NextVIndexToUse+25] :=  0;
              aVert[NextVIndexToUse+26] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+27] :=  aChunk.AmbientOcclusion2(I, d12, d21, d22)+Highlight;

              aInd[NextIIndexToUse]     :=  0 + I2*4+IndexOffset;       // Top right half
              aInd[NextIIndexToUse+1]   :=  1 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+2]   :=  3 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+3]   :=  1 + I2*4+IndexOffset;       // Bottom left half
              aInd[NextIIndexToUse+4]   :=  2 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+5]   :=  3 + I2*4+IndexOffset;

              Inc(NextVIndexToUse, 28);                                 // Next index to use for vertices
              Inc(NextIIndexToUse, 6);                                  // Next index to use for indices
              inc(I2);                                                  // I2 is counter for 4-vertice groups stored. Starts from 0
            end;

//          d12:
            if
              (aChunk.MapData[I].Solid = false) and (aChunk.GetBlock(I, d12).Solid=true)
            then
            begin
              aVert[NextVIndexToUse]    := -0.5 + Cw.X;                 // x 12 LEFT
              aVert[NextVIndexToUse+1]  :=  0.5 + Cw.Y;                 // y
              aVert[NextVIndexToUse+2]  :=  0.5 + Cw.Z;                 // z
              aVert[NextVIndexToUse+3]  :=  0;                          // texture x
              aVert[NextVIndexToUse+4]  :=  0;                          // texture y
              aVert[NextVIndexToUse+5]  :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+6]  :=  aChunk.AmbientOcclusion2(I, d15, d24, d25)+Highlight;

              aVert[NextVIndexToUse+7]  := -0.5 + Cw.X;
              aVert[NextVIndexToUse+8]  :=  0.5 + Cw.Y;
              aVert[NextVIndexToUse+9]  := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+10] :=  1;
              aVert[NextVIndexToUse+11] :=  0;
              aVert[NextVIndexToUse+12] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+13] :=  aChunk.AmbientOcclusion2(I, d14, d6, d7)+Highlight;

              aVert[NextVIndexToUse+14] := -0.5 + Cw.X;
              aVert[NextVIndexToUse+15] := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+16] := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+17] :=  1;
              aVert[NextVIndexToUse+18] :=  1;
              aVert[NextVIndexToUse+19] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+20] :=  aChunk.AmbientOcclusion2(I, d9, d0, d1)+Highlight;

              aVert[NextVIndexToUse+21] := -0.5 + Cw.X;
              aVert[NextVIndexToUse+22] := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+23] :=  0.5 + Cw.Z;
              aVert[NextVIndexToUse+24] :=  0;
              aVert[NextVIndexToUse+25] :=  1;

              aVert[NextVIndexToUse+26] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+27] :=  aChunk.AmbientOcclusion2(I, d9, d18, d19)+Highlight;

              aInd[NextIIndexToUse]     :=  0 + I2*4+IndexOffset;       // Top right half
              aInd[NextIIndexToUse+1]   :=  1 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+2]   :=  3 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+3]   :=  1 + I2*4+IndexOffset;       // Bottom left half
              aInd[NextIIndexToUse+4]   :=  2 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+5]   :=  3 + I2*4+IndexOffset;

              Inc(NextVIndexToUse, 28);                                 // Next index to use for vertices
              Inc(NextIIndexToUse, 6);                                  // Next index to use for indices
              inc(I2);                                                  // I2 is counter for 4-vertice groups stored. Starts from 0
            end;
{$ENDREGION 'Negative'}



{$REGION '            Positive direction'}
//          d14:
            if
              (aChunk.MapData[I].Solid = false) and (aChunk.GetBlock(I, d14).Solid=true)
            then
            begin                                                       // Side 14 Right
              aVert[NextVIndexToUse]    :=  0.5 + Cw.X;                 // x      Right
              aVert[NextVIndexToUse+1]  :=  0.5 + Cw.Y;                 // y
              aVert[NextVIndexToUse+2]  :=  0.5 + Cw.Z;                 // z
              aVert[NextVIndexToUse+3]  :=  0;                          // texture x
              aVert[NextVIndexToUse+4]  :=  0;                          // texture y
              aVert[NextVIndexToUse+5]  :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+6]  :=  aChunk.AmbientOcclusion2(I, d25, d26, d17)+Highlight;

              aVert[NextVIndexToUse+7]  :=  0.5 + Cw.X;
              aVert[NextVIndexToUse+8]  :=  0.5 + Cw.Y;
              aVert[NextVIndexToUse+9]  := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+10] :=  1;
              aVert[NextVIndexToUse+11] :=  0;
              aVert[NextVIndexToUse+12] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+13] :=  aChunk.AmbientOcclusion2(I, d7, d8, d17)+Highlight;

              aVert[NextVIndexToUse+14] :=  0.5 + Cw.X;
              aVert[NextVIndexToUse+15] := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+16] := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+17] :=  1;
              aVert[NextVIndexToUse+18] :=  1;
              aVert[NextVIndexToUse+19] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+20] :=  aChunk.AmbientOcclusion2(I, d1, d2, d11)+Highlight;

              aVert[NextVIndexToUse+21] :=  0.5 + Cw.X;
              aVert[NextVIndexToUse+22] := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+23] :=  0.5 + Cw.Z;
              aVert[NextVIndexToUse+24] :=  0;
              aVert[NextVIndexToUse+25] :=  1;
              aVert[NextVIndexToUse+26] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+27] :=  aChunk.AmbientOcclusion2(I, d19, d20, d11)+Highlight;

              aInd[NextIIndexToUse]     :=  0 + I2*4+IndexOffset;       // Top right half
              aInd[NextIIndexToUse+1]   :=  1 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+2]   :=  3 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+3]   :=  1 + I2*4+IndexOffset;       // Bottom left half
              aInd[NextIIndexToUse+4]   :=  2 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+5]   :=  3 + I2*4+IndexOffset;

              Inc(NextVIndexToUse, 28);                                 // Next index to use for vertices
              Inc(NextIIndexToUse, 6);                                  // Next index to use for indices
              inc(I2);                                                  // I2 is counter for 4-vertice groups stored. Starts from 0
            end;

//          d16:
            if
              (aChunk.MapData[I].Solid = false) and (aChunk.GetBlock(I, d16).Solid=true)
            then
            begin
              aVert[NextVIndexToUse]    :=  -0.5 + Cw.X;                // x TOP 7
              aVert[NextVIndexToUse+1]  :=  0.5 + Cw.Y;                 // y
              aVert[NextVIndexToUse+2]  :=  -0.5 + Cw.Z;                // z
              aVert[NextVIndexToUse+3]  :=  0;                          // texture x
              aVert[NextVIndexToUse+4]  :=  1;                          // texture y
              aVert[NextVIndexToUse+5]  :=  TextureId;                   // tex id
              aVert[NextVIndexToUse+6]  :=  aChunk.AmbientOcclusion2(I, d7, d6, d15)+Highlight;

              aVert[NextVIndexToUse+7]  :=  0.5 + Cw.X;                 // 4
              aVert[NextVIndexToUse+8]  :=  0.5 + Cw.Y;
              aVert[NextVIndexToUse+9]  := -0.5 + Cw.Z;
              aVert[NextVIndexToUse+10] :=  1;
              aVert[NextVIndexToUse+11] :=  1;
              aVert[NextVIndexToUse+12] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+13] :=  aChunk.AmbientOcclusion2(I, d7, d8, d17)+Highlight;

              aVert[NextVIndexToUse+14] :=  0.5 + Cw.X;                 // 0
              aVert[NextVIndexToUse+15] :=  0.5 + Cw.Y;
              aVert[NextVIndexToUse+16] :=  0.5 + Cw.Z;
              aVert[NextVIndexToUse+17] :=  1;
              aVert[NextVIndexToUse+18] :=  0;
              aVert[NextVIndexToUse+19] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+20] :=  aChunk.AmbientOcclusion2(I, d25, d26, d17)+Highlight;

              aVert[NextVIndexToUse+21] := -0.5 + Cw.X;                 // 3
              aVert[NextVIndexToUse+22] :=  0.5 + Cw.Y;
              aVert[NextVIndexToUse+23] :=  0.5 + Cw.Z;
              aVert[NextVIndexToUse+24] :=  0;
              aVert[NextVIndexToUse+25] :=  0;
              aVert[NextVIndexToUse+26] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+27] :=  aChunk.AmbientOcclusion2(I, d15, d24, d25)+Highlight;

              aInd[NextIIndexToUse]     :=  0 + I2*4+IndexOffset;       // Top right half
              aInd[NextIIndexToUse+1]   :=  1 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+2]   :=  3 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+3]   :=  1 + I2*4+IndexOffset;       // Bottom left half
              aInd[NextIIndexToUse+4]   :=  2 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+5]   :=  3 + I2*4+IndexOffset;

              Inc(NextVIndexToUse, 28);                                 // Next index to use for vertices
              Inc(NextIIndexToUse, 6);                                  // Next index to use for indices
              inc(I2);                                                  // I2 is counter for 4-vertice groups stored. Starts from 0
            end;

//                d22:
            if
              (aChunk.MapData[I].Solid = false) and (aChunk.GetBlock(I, d22).Solid=true)
            then
            begin                                                       // Side 22 - Front
              aVert[NextVIndexToUse]    :=  0.5 + Cw.X;                 // 0
              aVert[NextVIndexToUse+1]  :=  0.5 + Cw.Y;                 //
              aVert[NextVIndexToUse+2]  :=  0.5 + Cw.Z;                 //
              aVert[NextVIndexToUse+3]  :=  1.0;                        // texture x
              aVert[NextVIndexToUse+4]  :=  1.0;                        // texture y
              aVert[NextVIndexToUse+5]  :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+6]  :=  aChunk.AmbientOcclusion2(I, d25, d26, d17)+Highlight;

              aVert[NextVIndexToUse+7]  :=  0.5 + Cw.X;                 // 1
              aVert[NextVIndexToUse+8]  := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+9]  :=  0.5 + Cw.Z;
              aVert[NextVIndexToUse+10] :=  1;
              aVert[NextVIndexToUse+11] :=  0;
              aVert[NextVIndexToUse+12] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+13] :=  aChunk.AmbientOcclusion2(I, d19, d20, d11)+Highlight;

              aVert[NextVIndexToUse+14] := -0.5 + Cw.X;                 // 2
              aVert[NextVIndexToUse+15] := -0.5 + Cw.Y;
              aVert[NextVIndexToUse+16] :=  0.5 + Cw.Z;
              aVert[NextVIndexToUse+17] :=  0;
              aVert[NextVIndexToUse+18] :=  0;
              aVert[NextVIndexToUse+19] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+20] :=  aChunk.AmbientOcclusion2(I, d9, d18, d19)+Highlight;

              aVert[NextVIndexToUse+21] := -0.5 + Cw.X;                 // 3
              aVert[NextVIndexToUse+22] :=  0.5 + Cw.Y;                 //
              aVert[NextVIndexToUse+23] :=  0.5 + Cw.Z;
              aVert[NextVIndexToUse+24] :=  0;
              aVert[NextVIndexToUse+25] :=  1;
              aVert[NextVIndexToUse+26] :=  TextureId;                  // tex id
              aVert[NextVIndexToUse+27] :=  aChunk.AmbientOcclusion2(I, d15, d24, d25)+Highlight;

              aInd[NextIIndexToUse]     :=  0 + I2*4+IndexOffset;       // Top right half
              aInd[NextIIndexToUse+1]   :=  1 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+2]   :=  3 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+3]   :=  1 + I2*4+IndexOffset;       // Bottom left half
              aInd[NextIIndexToUse+4]   :=  2 + I2*4+IndexOffset;
              aInd[NextIIndexToUse+5]   :=  3 + I2*4+IndexOffset;

              Inc(NextVIndexToUse, 28);                                 // Next index to use for vertices
              Inc(NextIIndexToUse, 6);                                  // Next index to use for indices
              inc(I2);                                                  // I2 is counter for 4-vertice groups stored. Starts from 0
            end;
{$ENDREGION}


        // End of Process solid or -edge
//        end;

    // End of loop all blocks in Chunk
    end;

  // Truncate to actual SizeSide
  SetLength(aVert, NextVIndexToUse);
  SetLength(aInd, NextIIndexToUse);

//  ShowMessage('CreateV:' + aChunk.CreateVertices.ToString(true) +
//  ' ' + NextVIndexToUse.ToString +
//  ' ' + NextIIndexToUse.ToString
//  );


end;


procedure TChunkManager.MakeOutliers;
var
  I, n: Integer;
begin
  n := aSizeEdge+2;
  SetLength(aOutliers, n*n*n);

  for I := 0 to Length(aOutliers)-1 do
    begin
      if  ((I mod n) = 0) or
          ((I mod n) = (n-1)) or
          (((I div n) mod n) = 0) or
          (((I div n) mod n) = (n-1)) or
          (((I div n) div n) = 0) or
          (((I div n) div n) = (n-1))
      then
        aOutliers[I] := true
      else
        begin
          aOutliers[I] := false;
        end;

    end;
end;


function TChunkManager.IsOutlier(const aI: Integer): boolean;
var
  n: Integer;
begin
  n := aSizeEdge+2;

  if  ((aI mod n) = 0) or
      ((aI mod n) = (n-1)) or
      (((aI div n) mod n) = 0) or
      (((aI div n) mod n) = (n-1)) or
      (((aI div n) div n) = 0) or
      (((aI div n) div n) = (n-1))
  then
    Result := true
  else
    Result := false;

end;



end.

