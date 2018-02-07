unit UnitMain;

interface

uses
  // Project
  dveChunk,
  dveChunkManager,
  dveChunkManagerFile,
  dveOpenGLHandler,
  dglOpenGL,

  // External
  Neslib.FastMath,

  // System
  Generics.Collections,
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Grids;

type
  TFormTest = class(TForm)
    PanelLeftSide: TPanel;
    Splitter1: TSplitter;
    PanelDrawSurface: TPanel;
    GroupBox1: TGroupBox;
    PageControl1: TPageControl;
    TabSheetWorld: TTabSheet;
    TabSheetLog: TTabSheet;
    ButtonClearLog: TButton;
    CheckBoxRender: TCheckBox;
    Memo1: TMemo;
    ButtonChunkManager: TButton;
    ButtonListListVicinity: TButton;
    CheckBoxDebug: TCheckBox;
    ButtonCreateBenchmark: TButton;
    ButtonOffsetbuilder: TButton;
    procedure ButtonClearLogClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ButtonFragCompileClick(Sender: TObject);
    procedure PanelDrawSurfaceResize(Sender: TObject);
    procedure PanelDrawSurfaceMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PanelDrawSurfaceMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PanelDrawSurfaceMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ButtonChunkManagerClick(Sender: TObject);
    procedure ButtonListListVicinityClick(Sender: TObject);
    procedure ButtonToggleMemoClick(Sender: TObject);
    procedure ButtonCreateBenchmarkClick(Sender: TObject);
    procedure ButtonOffsetbuilderClick(Sender: TObject);
  private
    { Private declarations }
  public


    FullScreen: Boolean;
    OGLH: TOpenGLHandler;


    procedure SetFullScreen;
    procedure Log(const aString: String);
    procedure IdleHandler2(Sender : TObject; var Done : Boolean);
    procedure Setup2;
    procedure SetupVertex2;


  end;

var
  FormTest: TFormTest;
  FPSLast: Single;
  FPSSum: Single;
  Blink: Integer = 0;
  OldBlink: Integer = -1;
  CM: TChunkManager;
  CMF: TChunkManagerFile;
  LastFrameTime: double;
  CM_Counter: Cardinal = 0;
  RandSeed: Integer = 1;

  tmp: Integer = 0;

implementation

uses
  // Temp
//  dveSimplexNoise1234,

  // Project
  dveWorld,
  dveSimplexNoise1234,

  // External

  // System
  Math,
  StrUtils,
  System.Diagnostics;


{$R *.dfm}






procedure TFormTest.ButtonCreateBenchmarkClick(Sender: TObject);
const
  Step=10;
  ChunkSize=16;
var
//  q: Double;
  x,y,z,i: Integer;
  SID: String;
  C: TChunk;
  SW, SW2: TStopWatch;
  At: TArray<Single>;
  It: TArray<GLUInt>;
  maxi: integer;
//  Done: Boolean;
  S: String;

begin
  Memo1.Lines.Clear;
  Memo1.Lines.Add('Benchmarks');
  I := (Step*2+1)*(Step*2+1)*(Step*2+1);

  Memo1.Lines.Add('');
  Memo1.Lines.Add('           Chunks cubed : ' + Integer(Step*2+1).ToString);
  Memo1.Lines.Add('            Chunk count : ' + I.ToString);
  Memo1.Lines.Add('     Chunk blocks cubed : ' + ChunkSize.ToString);
  Memo1.Lines.Add('  Blocks array(+2) size : ' + ((ChunkSize+2)*(ChunkSize+2)*(ChunkSize+2)).ToString);

  SW.Create;
  SW.Reset;
  SW.Start;

  // Change seed
  inc(RandSeed);
//    RandSeed:=0;

  dveSimplexNoise1234.CreateSeed();

  // Make sure we do not try to render anything
  Application.OnIdle := nil;

  // Clean up
  if assigned(OGLH) then FreeAndNil(OGLH);
  if assigned(CMF) then FreeAndNil(CMF);
  DeleteFile (ExtractFilePath(Application.ExeName)+'\Save\ChunkIndices.bin');
  DeleteFile (ExtractFilePath(Application.ExeName)+'\Save\ChunkData.bin');

  // Initialize OGLH
  OGLH := TOpenGLHandler.Create;
  OGLH.SetUpRenderingContext(PanelDrawSurface);
  OGLH.ShaderVoxel          := TShader.Create('Resources\Shaders\18AO.vert', 'Resources\Shaders\18AO.frag');
  OGLH.UniformModel         := OGLH.ShaderVoxel.GetUniformLocation('Model');
  OGLH.UniformView          := OGLH.ShaderVoxel.GetUniformLocation('View');
  OGLH.UniformProjection    := OGLH.ShaderVoxel.GetUniformLocation('Projection');
  OGLH.UniformTextureArray0 := OGLH.ShaderVoxel.GetUniformLocation('TextureArray0');
  S := 'Resources\Textures\Blocks\grass.png'+#13+
       'Resources\Textures\Blocks\grass_side.png'+#13+
       'Resources\Textures\Blocks\dirt.png'+#13+
       'Resources\Textures\Blocks\farmland_dry.png'+#13+
       'Resources\Textures\Blocks\brick.png';
  OGLH.LoadTextureArray(OGLH.TextureArray0, S);
  OGLH.Camera.Position := Vector3(0,0,0);

  // Create chunk manager
  CMF := TChunkManagerFile.Create(ChunkSize);
  CMF.DistanceView := 0;
  CMF.DistanceLoad := Step+1;
  CMF.WorldSeed    := 'Jaajaa';
  CMF.OpenGLStuff;

  SW.Stop;
  Memo1.Lines.Add('');
  Memo1.Lines.Add('  Initialization etc: ' + SW.ElapsedMilliseconds.ToString + ' ms');


  SW.Reset;
  SW.Start;

    // Loop chunks and add to be created
    for X := -Step to Step do
      for Y := -Step to Step do
        for Z := -Step to Step do
          begin
            SID := ChunkID(X,Y,Z);
            CMF.ListLoad.Add(SID, nil);
          end;

  SW.Stop;
  I := (Step*2+1)*(Step*2+1)*(Step*2+1);
  Memo1.Lines.Add('');
  Memo1.Lines.Add('  Occupy ListLoad: ' + SW.ElapsedMilliseconds.ToString + ' ms');
  Memo1.Lines.Add('    Per item: ' + Double(SW.ElapsedMilliseconds/I).ToString + ' ms');


  // Create chunks
  Memo1.Lines.Add('');
  Memo1.Lines.Add('  Creating chunks, please wait');
  SW.Reset;
  SW.Start;
    I := CMF.ListLoad.Count;
    CMF.ListLoadChunksProcess(I+10);
  SW.Stop;
  Memo1.Lines.Add('  Create chunks one at a time: ' + SW.ElapsedMilliseconds.ToString + ' ms');
  Memo1.Lines.Add('    Chunks processed: ' + I.ToString);
  Memo1.Lines.Add('    Per item: ' + Double(SW.ElapsedMilliseconds/I).ToString + ' ms');
  Memo1.Lines.Add('    Chunks with solids created: ' + CMF.ListLoaded.Count.ToString);
  Memo1.Lines.Add('    Per created: ' + Double(SW.ElapsedMilliseconds/CMF.ListLoaded.Count).ToString + ' ms');

  // Save one at a time, Super slow
//    SW.Reset;
//    SW.Start;
//      I:= CMF.ListLoaded.Values.Count;
//      for C in CMF.ListLoaded.Values do
//        begin
//          CMF.ChunkSave(C);
//        end;
//    SW.Stop;
//    Memo1.Lines.Add('');
//    Memo1.Lines.Add('  Save chunks disk individually: ' + SW.ElapsedMilliseconds.ToString + ' ms');
//    Memo1.Lines.Add('    Per item: ' + Double(SW.ElapsedMilliseconds/I).ToString + ' ms');


  // Bulk save
    DeleteFile (ExtractFilePath(Application.ExeName)+'\Save\ChunkIndices.bin');
    DeleteFile (ExtractFilePath(Application.ExeName)+'\Save\ChunkData.bin');
    CMF.ChunkIndicesLoad;  // This clear saved list if there is no file
    CMF.CreateFiles;

    SW.Reset;
    SW.Start;
      I:= CMF.ListLoaded.Values.Count;
      CMF.ChunkListSave(CMF.ListLoaded);
    SW.Stop;
    Memo1.Lines.Add('');
    Memo1.Lines.Add('  Save chunks disk bulk: ' + SW.ElapsedMilliseconds.ToString + ' ms');
    Memo1.Lines.Add('    Items: ' + I.ToString);
    Memo1.Lines.Add('    Per item: ' + Double(SW.ElapsedMilliseconds/I).ToString + ' ms');


  // File locations save
    SW.Reset;
    SW.Start;
      CMF.ChunkIndicesSave;
    SW.Stop;
    Memo1.Lines.Add('');
    Memo1.Lines.Add('  Save chunks file locations: ' + SW.ElapsedMilliseconds.ToString + ' ms');


  // Create vertices & indices
    maxi := 0;
    SW.Reset;
    SW.Start;
      I:= CMF.ListLoaded.Values.Count;
      for C in CMF.ListLoaded.Values do
        begin
          SW2.Create;
          SW2.Reset;
          SW2.Start;
          CMF.ChunkVertices(C, At, It);
          C.aVertexArray := TVertexArray.Create(
                                    CMF.VertexLayoutForVoxel,
                                    At,
                                    SizeOf(Single)*Length(At),
                                    It[0],
                                    Length(It)
                                 );
          SW2.Stop;
          maxi := max(SW2.Elapsedmilliseconds, maxi);

        end;
    SW.Stop;
    Memo1.Lines.Add('');
    Memo1.Lines.Add('  Create vertices, Indices: ' + SW.ElapsedMilliseconds.ToString + ' ms');
    Memo1.Lines.Add('    Items: ' + I.ToString);
    Memo1.Lines.Add('    Per item: ' + Double(SW.ElapsedMilliseconds/I).ToString + ' ms');
    Memo1.Lines.Add('    Slowest item: ' + maxi.ToString + ' ms');

  // Render
    SW.Reset;
    SW.Start;
      I:= CMF.ListLoaded.Values.Count;
      OGLH.Render1;
      for C in CMF.ListLoaded.Values do
        begin
          if (assigned(C.aVertexArray)) then C.aVertexArray.Render;
        end;
      OGLH.SwapBuffer;
    SW.Stop;
    Memo1.Lines.Add('');
    Memo1.Lines.Add('  Render (all loaded): ' + SW.ElapsedMilliseconds.ToString + ' ms');
    Memo1.Lines.Add('    Items: ' + I.ToString);
    Memo1.Lines.Add('    Per item: ' + Double(SW.ElapsedMilliseconds/I).ToString + ' ms');

  // Render
    SW.Reset;
    SW.Start;
      I:= CMF.ListLoaded.Values.Count;
      OGLH.Render1;
      for C in CMF.ListLoaded.Values do
        begin
          if (assigned(C.aVertexArray)) then C.aVertexArray.Render;
        end;
      OGLH.SwapBuffer;
    SW.Stop;
    Memo1.Lines.Add('');
    Memo1.Lines.Add('  Render (all loaded): ' + SW.ElapsedMilliseconds.ToString + ' ms');
    Memo1.Lines.Add('    Items: ' + I.ToString);
    Memo1.Lines.Add('    Per item: ' + Double(SW.ElapsedMilliseconds/I).ToString + ' ms');

  // Update Frustrum
    SW.Reset;
    SW.Start;
      CMF.UpdateChunkFrustrums(OGLH.Camera);
    SW.Stop;
    Memo1.Lines.Add('');
    Memo1.Lines.Add('  Updated frustrum: ' + SW.ElapsedMilliseconds.ToString + ' ms');

  // Render frustrum only
    SW.Reset;
    SW.Start;
      I:=0;
      OGLH.Render1;
      for C in CMF.ListLoaded.Values do
        begin
          if C.InFrustrum and (assigned(C.aVertexArray)) then
            begin
             C.aVertexArray.Render;
             Inc(I);
            end;
        end;
      OGLH.SwapBuffer;
    SW.Stop;
    Memo1.Lines.Add('');
    Memo1.Lines.Add('  Render (in frustrum): ' + SW.ElapsedMilliseconds.ToString + ' ms');
    Memo1.Lines.Add('    Items: ' + I.ToString);
    Memo1.Lines.Add('    Per item: ' + Double(SW.ElapsedMilliseconds/I).ToString + ' ms');


  // Start engine tick
//    Application.OnIdle := IdleHandler2;


  // Clean up
  if assigned(OGLH) then FreeAndNil(OGLH);
  if assigned(CMF) then FreeAndNil(CMF);

end;


procedure TFormTest.ButtonOffsetbuilderClick(Sender: TObject);

const
  aSizeEdge2=18;

var
  aIndex, Result2: Integer;
  d: TDirection;

begin

    aIndex := round(aSizeEdge2*aSizeEdge2*aSizeEdge2/2);
    aIndex := 0;

    Memo1.Lines.Clear;
    Memo1.Lines.Add('Cube size:'+Integer(aSizeEdge2-2).ToString);

    for d := TDirection(0) to TDirection(26) do
      begin
        case d of
          d0:   Result2 := aIndex-(aSizeEdge2*aSizeEdge2)-aSizeEdge2-1;
          d1:   Result2 := aIndex-(aSizeEdge2*aSizeEdge2)-aSizeEdge2;
          d2:   Result2 := aIndex-(aSizeEdge2*aSizeEdge2)-aSizeEdge2+1;
          d3:   Result2 := aIndex-(aSizeEdge2*aSizeEdge2)-1;
          d4:   Result2 := aIndex-(aSizeEdge2*aSizeEdge2);
          d5:   Result2 := aIndex-(aSizeEdge2*aSizeEdge2)+1;
          d6:   Result2 := aIndex-(aSizeEdge2*aSizeEdge2)+aSizeEdge2-1;
          d7:   Result2 := aIndex-(aSizeEdge2*aSizeEdge2)+aSizeEdge2;
          d8:   Result2 := aIndex-(aSizeEdge2*aSizeEdge2)+aSizeEdge2+1;

          d9:   Result2 := aIndex-aSizeEdge2-1;
          d10:  Result2 := aIndex-aSizeEdge2;
          d11:  Result2 := aIndex-aSizeEdge2+1;
          d12:  Result2 := aIndex-1;
          d13:  Result2 := aIndex;
          d14:  Result2 := aIndex+1;
          d15:  Result2 := aIndex+aSizeEdge2-1;
          d16:  Result2 := aIndex+aSizeEdge2;
          d17:  Result2 := aIndex+aSizeEdge2+1;

          d18:  Result2 := aIndex+(aSizeEdge2*aSizeEdge2)-aSizeEdge2-1;
          d19:  Result2 := aIndex+(aSizeEdge2*aSizeEdge2)-aSizeEdge2;
          d20:  Result2 := aIndex+(aSizeEdge2*aSizeEdge2)-aSizeEdge2+1;
          d21:  Result2 := aIndex+(aSizeEdge2*aSizeEdge2)-1;
          d22:  Result2 := aIndex+(aSizeEdge2*aSizeEdge2);
          d23:  Result2 := aIndex+(aSizeEdge2*aSizeEdge2)+1;
          d24:  Result2 := aIndex+(aSizeEdge2*aSizeEdge2)+aSizeEdge2-1;
          d25:  Result2 := aIndex+(aSizeEdge2*aSizeEdge2)+aSizeEdge2;
          d26:  Result2 := aIndex+(aSizeEdge2*aSizeEdge2)+aSizeEdge2+1;
        end;
        Memo1.Lines.Add(Result2.ToString + ',');
      end;




end;


procedure TFormTest.ButtonChunkManagerClick(Sender: TObject);
begin
  Setup2;
end;


procedure TFormTest.ButtonClearLogClick(Sender: TObject);
begin
//  Memo1.Lines.Clear;
end;


procedure TFormTest.ButtonFragCompileClick(Sender: TObject);
begin
  if assigned(OGLH) then
    begin
//      OGLH.CompileFragmentShader(BCEditorFragment.Text, S);
//      MemoFragment.Lines.Add(EditFrag.Text + ' ' + S);
//      OGLH.CompileShaderProgram(S);
//      MemoVertex.Lines.Add(S);
    end;
end;


procedure TFormTest.ButtonListListVicinityClick(Sender: TObject);
begin
  Memo1.Lines.BeginUpdate;

  Memo1.Lines.Clear;
  Memo1.Lines.Add('Chunks');
  Memo1.Lines.Add(' Vicinity     :'+IntToStr(CM.ListVicinity.Count));
  Memo1.Lines.Add(' Load         :'+IntToStr(CM.ListLoad.Count));
  Memo1.Lines.Add(' Loaded       :'+IntToStr(CM.ListLoaded.Count));
  Memo1.Lines.Add(' In frustrum  :'+IntToStr(CM.InFrustrumCount));
  Memo1.Lines.Add(' Unload       :'+IntToStr(CM.ListUnload.Count));

  Memo1.Lines.Add('');
  Memo1.Lines.Add('Camera');
  Memo1.Lines.Add(' Position    :'+OGLH.Camera.Position.AsString);
  Memo1.Lines.Add(' Front       :'+OGLH.Camera.Front.AsString);
  Memo1.Lines.Add(' Right       :'+OGLH.Camera.Right.AsString);
  Memo1.Lines.Add(' Up          :'+OGLH.Camera.Up.AsString);
  Memo1.Lines.Add(' X-zoom      :'+FormatFloat('0.00', OGLH.Camera.ZoomX));
  Memo1.Lines.Add(' Y-zoom      :'+FormatFloat('0.00', OGLH.Camera.ZoomY));

  Memo1.Lines.EndUpdate;
end;


procedure TFormTest.ButtonToggleMemoClick(Sender: TObject);
begin
  Memo1.Visible := not Memo1.Visible;

end;


procedure TFormTest.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if assigned(CM) then CM.Free;
  if assigned(OGLH) then OGLH.Free;

//  if Assigned(Chunk) then Chunk.Free;
end;


procedure TFormTest.FormCreate(Sender: TObject);
begin

  PageControl1.ActivePageIndex := 0;
  FullScreen := false;

end;


procedure TFormTest.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
//  Memo1.Lines.Add(IntToStr(Key));
  if Key = 122 then exit;

  if Key = 112 then   // F1
    begin
      fullScreen := not FullScreen;
      SetFullScreen;
    end
  else if assigned(OGLH) then
    begin
      OGLH.Camera.ProcessKeyDown(Key);
    end;
end;


procedure TFormTest.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 122 then exit;

  if assigned(OGLH) then
    begin
      OGLH.Camera.ProcessKeyUp(Key);
//      Log('Camera: '
//        + FormatFloat('0.0',OGLH.Camera.Position.X) +'/'
//        + FormatFloat('0.0',OGLH.Camera.Position.Y) +'/'
//        + FormatFloat('0.0',OGLH.Camera.Position.Z)
//      );
    end;

end;


procedure TFormTest.SetFullScreen;
begin
  if FullScreen then
    begin
      Memo1.Lines.Add('Full');
      BorderStyle := bsNone;
      WindowState := wsMaximized;
    end
  else
    begin
      Memo1.Lines.Add('Windowed');
      BorderStyle := bsSizeable;
      WindowState := wsNormal;
    end;
end;


procedure TFormTest.Log(const aString: string);
begin
  Memo1.Lines.Add(FormatDateTime('hh:mm:ss:zzz', now)+ '-> ' +aString);
end;


procedure TFormTest.PanelDrawSurfaceMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if assigned(OGLH) then
    OGLH.Camera.ProcessMouseDown(X, Y);
end;


procedure TFormTest.PanelDrawSurfaceMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
if assigned(OGLH) then
  begin
    OGLH.Camera.ProcessMouseMove(X, Y);

  end;

end;


procedure TFormTest.PanelDrawSurfaceMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if assigned(OGLH) then
    OGLH.Camera.ProcessMouseUp;
end;


procedure TFormTest.PanelDrawSurfaceResize(Sender: TObject);
begin
//  ShowMessage(Sender.ToString);

// Define the viewport dimensions
  if assigned(OGLH) then
    glViewport(0, 0, PanelDrawSurface.Width, PanelDrawSurface.Height);
end;


procedure TFormTest.IdleHandler2(Sender: TObject; var Done: Boolean);
var
  C: TChunk;

  S1: TStopWatch;
begin
  Done := false;

  if not CheckBoxRender.Checked then begin
    Done := true;
    exit;
  end;

  // Not initialized, go away
    if (not assigned(OGLH)) and (not CheckBoxRender.Checked) then exit;
    if (not assigned(CM)) then exit;

  // Set debug
    CM.Debug := CheckBoxDebug.Checked;

  // Load chunks if above 60 FPS
    while (OGLH.SW.ElapsedMilliseconds < 12) do
      begin
        CM.ListLoadChunksProcess(3);
        CM.ListUnloadProcess(3);
      end;

  // Update Camera position and angle
    OGLH.Camera.HandleInput(OGLH.SW.ElapsedMilliseconds);

  // Which chunks in Frustrum
    CM.UpdateChunkFrustrums(OGLH.Camera);

  // Update load and unload lists based on location
    CM.ManageLists(OGLH.Camera);

  // Loop all in loaded list to create VAO if needed
    CM.UpdateVertices(CM.ListLoaded);

  // Start rendering
    OGLH.Render1;

  // Loop all in loaded list AGAIN?! and render all chunks
    S1 := TStopWatch.Create;
    S1.Start;
    for C in CM.ListLoaded.Values do
      begin
//        if C.CreateVertices then
//          begin
//            CM.ChunkVertices(C, At, It);
//            C.VertexArray := TVertexArray.Create(
//                                CM.VertexLayoutForVoxel,
//                                At,
//                                SizeOf(Single)*Length(At),
//                                It[0],
//                                Length(It)
//                             );
//            C.CreateVertices := false;
//          end;

        if C.InFrustrum and (assigned(C.aVertexArray)) then C.aVertexArray.Render;
        if S1.ElapsedMilliseconds > 15 then break;
      end;

  // Show debug if asked for
    if CheckBoxDebug.Checked then
      Memo1.Text := Memo1.Text + CM.Feedback.Text;

  // Clear debug
    CM.Feedback.Clear;

  // Show rendered stuff
    OGLH.SwapBuffer;

  // Show FPS
    FormTest.Caption := 'FPS: ' + FormatFloat('0', OGLH.FPS);

end;


// Prepare OpenGL
procedure TFormTest.Setup2;
var
//  a: boolean;
  S: String;
//  I: Integer;
  W: TWorld;
  Loc: TLoc;
  C: TChunk;
  SW: TStopWatch;
begin
  if assigned(OGLH) then OGLH.Free;
  if assigned(CM) then CM.Free;
  W := TWorld.Create;

  // Initialize OGLH
    OGLH := TOpenGLHandler.Create;
    OGLH.SetUpRenderingContext(PanelDrawSurface);
    glInfoToDisk;

  // Create chunk list
//    CM := TChunkManagerFile.Create(16);
    CM := TChunkManager.Create(16);
    CM.OpenGLStuff;
    W.fChunkEdgeSize := 16;

    CM.DistanceView := 0;
    CM.DistanceLoad := 20;
    CM.WorldSeed    := 'Jaajaa';
    Loc.X := 0;
    Loc.Y := 10;
    Loc.Z := 0;
    SW.Create;
    SW.Reset;
    SW.Start;
    W.CreateSurfaceRecursively(Loc, Loc, CM.DistanceLoad, CM.ListLoaded);
    Memo1.Lines.Add('Create chunks: '+ SW.ElapsedMilliseconds.ToString + ' ms');
    W.Free;

  // Camera location
//  CM.UpdateListVicinity(OGLH.Camera);           // To list initial chunks

  // Create voxel related shaders and link the uniforms
  OGLH.ShaderVoxel        := TShader.Create('Resources\Shaders\18AO.vert', 'Resources\Shaders\18AO.frag');
  OGLH.UniformModel       := OGLH.ShaderVoxel.GetUniformLocation('Model');
  OGLH.UniformView        := OGLH.ShaderVoxel.GetUniformLocation('View');
  OGLH.UniformProjection  := OGLH.ShaderVoxel.GetUniformLocation('Projection');

  // Create the array uniform for voxel textures
  OGLH.UniformTextureArray0 := OGLH.ShaderVoxel.GetUniformLocation('TextureArray0');
  S :=  'Resources\Textures\Blocks\grass.png'+#13+
        'Resources\Textures\Blocks\grass_side.png'+#13+
        'Resources\Textures\Blocks\dirt.png'+#13+
        'Resources\Textures\Blocks\farmland_dry.png'+#13+
        'Resources\Textures\Blocks\brick.png';
  OGLH.LoadTextureArray(OGLH.TextureArray0, S);

  // Prepare camera
  OGLH.Camera.Position := Vector3(Loc.X,Loc.Y,Loc.Z);
  // Update whats in frustrum
//  CM.UpdateChunkFrustrums(OGLH.Camera);

  // Create all vertices
  CM.Debug := true;
  CM.UpdateVertices(CM.ListLoaded, false);
  Memo1.Text := Memo1.Text + CM.Feedback.Text;
//  ShowMessage('Pause');

  // Start rendering
    OGLH.Render1;

    SW.Reset;
    SW.Start;
    for C in CM.ListLoaded.Values do
      if assigned(C.aVertexArray) then C.aVertexArray.Render;
  // Show rendered stuff
    OGLH.SwapBuffer;

    Memo1.Lines.Add('Upload VAOs: '+ SW.ElapsedMilliseconds.ToString + ' ms');


  // Start engine tick
    Application.OnIdle := IdleHandler2;

end;


// Prepare vertex
procedure TFormTest.SetupVertex2;
var
  At: TArray<Single>;
  Bt: TArray<GLUInt>;
  D: Double;
  C: TChunk;
begin
  OldBlink := Blink;
  D := now;

  // Describe the data
  OGLH.VertexLayoutVoxel.Start(OGLH.ShaderVoxel);
  OGLH.VertexLayoutVoxel.Add('position', 3);
  OGLH.VertexLayoutVoxel.Add('TexCoordIn', 3);
  OGLH.VertexLayoutVoxel.Add('lightLevel', 1);

  CM.ManageLists(OGLH.Camera);

  // Loop all chunks
//  for C in CM.ListLoaded.Values do
//    begin
//      C.Vertices2(At,Bt);
//    end;

  CM.UpdateVertices(CM.ListLoaded);

//  memo1.Lines.BeginUpdate;
//  Memo1.Lines.Add('A');
//  for I := 0 to Length(At)-1 do
//    Memo1.Lines.Add(IntToStr(I)+ ' ' + FloatToStr(At[I]));
//  Memo1.Lines.Add('B');
//  for I := 0 to Length(Bt)-1 do
//    Memo1.Lines.Add(IntToStr(I)+ ' ' + FloatToStr(Bt[I]));
//  memo1.Lines.EndUpdate;

  // Add the data
  if assigned(OGLH.VertexArrayVoxel) then OGLH.VertexArrayVoxel.Free;
//  OGLH.VertexArrayVoxel := TVertexArray.Create(OGLH.VertexLayoutVoxel, At, SizeOf(Single)*Length(At), Bt[0], Length(Bt));

  Memo1.Lines.Add('Vertices :' + IntToStr(Length(At)));
  Memo1.Lines.Add('   bytes :' + IntToStr(Length(At)*SizeOf(Single)));
  Memo1.Lines.Add('Indices  :' + IntToStr(Length(Bt)));
  Memo1.Lines.Add('   bytes :' + IntToStr(Length(Bt)*SizeOf(Single)));
  Memo1.Lines.Add('Total    :' + IntToStr(Length(Bt)+Length(At)));
  Memo1.Lines.Add('   bytes :' + IntToStr((Length(Bt)+Length(At)*SizeOf(Single))));
  Memo1.Lines.Add(FormatDateTime('ss:zzz ', now-D));

//  CM.UpdateChunkFrustrums(OGLH.Camera);

  // Call renderer


  OGLH.Render1;
  for C in CM.ListLoaded.Values do
    if C.InFrustrum and assigned(C.aVertexArray) then C.aVertexArray.Render;
  OGLH.SwapBuffer;

end;


Initialization
//  Blink := 0;
//  OldBlink := -1;

end.

