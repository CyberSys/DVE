program DVE;

uses
  Vcl.Forms,
  Neslib.Stb.Common in 'External\Neslib-Stb\Neslib.Stb.Common.pas',
  Neslib.Stb.Image in 'External\Neslib-Stb\Neslib.Stb.Image.pas',
  Neslib.Stb.TrueType in 'External\Neslib-Stb\Neslib.Stb.TrueType.pas',
  dglOpenGL in 'External\dglOpenGL\dglOpenGL.pas',
  UnitMain in 'UnitMain.pas' {FormTest},
  dveOpenGLHandler in 'Source\dveOpenGLHandler.pas',
  dveChunk in 'Source\dveChunk.pas',
  dveChunkManager in 'Source\dveChunkManager.pas',
  dveSimplexNoise1234 in 'source\dveSimplexNoise1234.pas',
  Neslib.Stb.RectPack in 'External\Neslib-Stb\Neslib.Stb.RectPack.pas',
  Neslib.FastMath in 'External\FastMath\Neslib.FastMath.pas',
  dveChunkManagerFile in 'source\dveChunkManagerFile.pas',
  dveComponentStreamer in 'source\dveComponentStreamer.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := true;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormTest, FormTest);
  Application.Run;
end.

