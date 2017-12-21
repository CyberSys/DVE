unit UnitMain;

interface

uses
  dveChunk,
  dveChunkManagerFile,
  Generics.Collections,
  dveOpenGLHandler,
  dglOpenGL,
  Neslib.FastMath,
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Grids;

type
  TFormTest = class(TForm)
    Panel2: TPanel;
    Splitter1: TSplitter;
    Panel1: TPanel;
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
    procedure ButtonClearLogClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ButtonFragCompileClick(Sender: TObject);
    procedure Panel1Resize(Sender: TObject);
    procedure Panel1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure Panel1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Panel1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ButtonChunkManagerClick(Sender: TObject);
    procedure ButtonListListVicinityClick(Sender: TObject);
    procedure ButtonToggleMemoClick(Sender: TObject);
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
  CM: TChunkManagerFile;
  LastFrameTime: double;
  CM_Counter: Cardinal = 0;



implementation

uses
  // Temp
//  dveSimplexNoise1234,

  // Project
  dveWorld,

  // External

  // System
  StrUtils,
  System.Diagnostics;

{$R *.dfm}









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
  CM.Free;
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



procedure TFormTest.Panel1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if assigned(OGLH) then
    OGLH.Camera.ProcessMouseDown(X, Y);
end;


procedure TFormTest.Panel1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
if assigned(OGLH) then
  begin
    OGLH.Camera.ProcessMouseMove(X, Y);

  end;

end;


procedure TFormTest.Panel1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if assigned(OGLH) then
    OGLH.Camera.ProcessMouseUp;
end;


procedure TFormTest.Panel1Resize(Sender: TObject);
begin
//  ShowMessage(Sender.ToString);

// Define the viewport dimensions
  if assigned(OGLH) then
    glViewport(0, 0, Panel1.Width, Panel1.Height);
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
  a: boolean;
  S: String;
  I: Integer;
begin
  if assigned(OGLH) then OGLH.Free;

  // Initialize OGLH
    OGLH := TOpenGLHandler.Create;
    OGLH.SetUpRenderingContext(Panel1);
    glInfoToDisk;

  // Create chunk list
    CM := TChunkManagerFile.Create;
    CM.DistanceView := 0;
    CM.DistanceLoad := 8;
    CM.WorldSeed    := 'Jaajaa';
    CM.SizeEdge     := 16;        // Default 11;
    CM.MakeOutliers;

  // Camera location
//  CM.UpdateListVicinity(OGLH.Camera);           // To list initial chunks

  // Create voxel related shaders and link the uniforms
  OGLH.ShaderVoxel    := TShader.Create('Resources\Shaders\18AO.vert', 'Resources\Shaders\18AO.frag');
  OGLH.UniformModel   := OGLH.ShaderVoxel.GetUniformLocation('Model');
  OGLH.UniformView    := OGLH.ShaderVoxel.GetUniformLocation('View');
  OGLH.UniformProjection := OGLH.ShaderVoxel.GetUniformLocation('Projection');

  // Create the array uniform for voxel textures
  OGLH.UniformTextureArray0 := OGLH.ShaderVoxel.GetUniformLocation('TextureArray0');
  S :=  'Resources\Textures\Blocks\grass.png'+#13+
        'Resources\Textures\Blocks\grass_side.png'+#13+
        'Resources\Textures\Blocks\dirt.png'+#13+
        'Resources\Textures\Blocks\farmland_dry.png'+#13+
        'Resources\Textures\Blocks\brick.png';
  OGLH.LoadTextureArray(OGLH.TextureArray0, S);

  // Create vertex data related things
//  SetupVertex2;

  OGLH.Camera.Position := Vector3(0,0,0);
  CM.UpdateChunkFrustrums(OGLH.Camera);
//  CM.UpdateChunkFrustrums(Plane);

  for I := 0 to 100 do
    IdleHandler2(nil, a);

  OGLH.Camera.Position := Vector3(0,0,0);
//  CM.UpdateChunkFrustrums(OGLH.Camera);

//  for I := 0 to 100 do
//    IdleHandler2(nil, a);

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
  Blink := 0;
  OldBlink := -1;

end.

