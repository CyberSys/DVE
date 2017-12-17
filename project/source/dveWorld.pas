// TBlock
// TChunk
// TCluster

unit dveWorld;

interface

uses
  // Project
  dveSimplexNoise1234;

  // External

type

TWorld = class
  private
    aChunkSize: Cardinal;
    aClusterSize: Cardinal;

  public
    aData: array of word;

    constructor Create(const ChunkSize, ClusterSize: Cardinal);
    destructor Destroy; override;
    procedure CreateData;



  end;

implementation

uses
  //System
  System.SysUtils,
  Dialogs;


constructor TWorld.Create(const ChunkSize, ClusterSize: Cardinal);
begin
  Inherited Create;

  aChunkSize := ChunkSize;
  aClusterSize := ClusterSize;
end;


destructor TWorld.Destroy;
begin
  //

  Inherited Destroy;
end;


procedure TWorld.CreateData;
var
  X, Y, Z: Cardinal;
  n: Cardinal;
begin
  n := aChunkSize*aClusterSize;
  SetLength(aData, n*n*n);

  for Z := 0 to n-1 do
    for Y := 0 to n-1 do
      for X := 0 to n-1 do
        begin
          aData[X + Y*n + Z*n*n] := word(snoise2(X/100, Z/100) < (Y-n/2));
        end;

end;

end.
