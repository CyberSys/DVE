unit dveOpenGLHandler;

interface

uses
  VCL.Controls,
  System.Diagnostics,
  Vcl.StdCtrls,         // Form memo
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  System.Types,         // TRectF
  System.UITypes,
  Winapi.Windows,
  Neslib.FastMath,      //
  Classes,              // StringList for load textures to array
  dglOpenGL;            // version 4.5 @ https://github.com/SaschaWillems/dglOpenGL

type


{$REGION 'TCamera'}
  TCamera = class
  public const
    DEFAULT_YAW         = -90;
    DEFAULT_PITCH       = 0;
    DEFAULT_SPEED       = 0.03;
    DEFAULT_SENSITIVITY = 0.25;
    DEFAULT_ZOOM        = 45;

    DegToRad            = 0.01745329;
  private
    FPosition: TVector3;
    FFront: TVector3;
    FUp: TVector3;
    FRight: TVector3;
    FWorldUp: TVector3;
    FYaw: Single;
    FPitch: Single;
    FMovementSpeed: Single;
    FSensitivity: Single;
    FZoom: Single;

    fViewWidth: Cardinal;
    fViewHeight: Cardinal;
    aZoomX: Single;
    aZoomY: Single;
  private
    { Input }
    FLastX: Single;
    FLastY: Single;
    FScreenEdge: TRectF;
    FLookAround: Boolean;
    FKeyW: Boolean;
    FKeyA: Boolean;
    FKeyS: Boolean;
    FKeyD: Boolean;
    FKeyR: Boolean;
    FKeyF: Boolean;
  protected
    function _GetPosition: TVector3;
    procedure _SetPosition(const AValue: TVector3);
    function _GetFront: TVector3;
    procedure _SetFront(const AValue: TVector3);
    function _GetUp: TVector3;
    procedure _SetUp(const AValue: TVector3);
    function _GetRight: TVector3;
    procedure _SetRight(const AValue: TVector3);
    function _GetWorldUp: TVector3;
    procedure _SetWorldUp(const AValue: TVector3);
    function _GetYaw: Single;
    procedure _SetYaw(const AValue: Single);
    function _GetPitch: Single;
    procedure _SetPitch(const AValue: Single);
    function _GetMovementSpeed: Single;
    procedure _SetMovementSpeed(const AValue: Single);
    function _GetSensitivity: Single;
    procedure _SetSensitivity(const AValue: Single);
    function _GetZoom: Single;
    procedure _SetZoom(const AValue: Single);
    procedure ViewResized(const AWidth, AHeight: Integer);
    procedure ProcessMouseWheel(const AWheelDelta: Integer);
  private
    procedure ProcessMouseMovement(const AXOffset, AYOffset: Single; const AConstrainPitch: Boolean = True);
    procedure UpdateScreenEdge(const AViewWidth, AViewHeight: Single);
    procedure UpdateCameraVectors;
  public
    function GetViewMatrix: TMatrix4;
    property Position: TVector3 read _GetPosition write _SetPosition;
    property Zoom: Single read _GetZoom write _SetZoom;
    property ZoomX: Single read aZoomX;
    property ZoomY: Single read aZoomY;
    property Up: TVector3 read _GetUp;
    property Front: TVector3 read _GetFront;
    property Right: TVector3 read _GetRight;

    procedure ProcessMouseDown(const AX, AY: Single);
    procedure ProcessMouseMove(const AX, AY: Single);
    procedure ProcessMouseUp;

    procedure ProcessKeyDown(const AKey: Integer);
    procedure ProcessKeyUp(const AKey: Integer);
    procedure HandleInput(const ADeltaTimeSec: Single);
    constructor Create(const AViewWidth, AViewHeight: Integer; const APosition, AUp: TVector3; const AYaw: Single = DEFAULT_YAW; const APitch: Single = DEFAULT_PITCH); overload;

  end;
{$ENDREGION}



{$REGION 'TShader'}
  TShader = class
  private
    FProgram: GLuint;
    function _GetHandle: GLuint;
    class function CreateShader(const AShaderPath: String; const AShaderType: GLenum): GLuint;
  public
    property Handle: GLuint read _GetHandle;
    constructor Create(const AVertexShaderPath, AFragmentShaderPath: String);
    destructor Destroy; override;
    function GetUniformLocation(const AName: RawByteString): Integer;
    function GetUniformLocationUnicode(const AName: String): Integer;
    procedure Use;
  end;
{$ENDREGION}



{$REGION 'TVertex'}
  TVertex = record
  public
    Position: TVector3;
    Normal: TVector3;
    TexCoords: TVector2;
  end;

  TTextureKind = (Diffuse, Specular, Normal, Height);
  TTexture = record
  private
    FId: GLuint;
    FKind: TTextureKind;
  public
    procedure Load(const APath: String; const AKind: TTextureKind);
    property Id: GLuint read FId;
    property Kind: TTextureKind read FKind;
  end;
{$ENDREGION}



{$REGION 'TVertex Layout'}
  PVertexLayout = ^TVertexLayout;
  TVertexLayout = packed record
  private const
    MAX_ATTRIBUTES = 8;
  private type
    TAttribute = packed record
      Location: Byte;
      Size: Byte;
      Normalized: GLboolean;
      Offset: Byte;
    end;
  private
    FProgram: GLuint;
    FAttributes: array [0..MAX_ATTRIBUTES - 1] of TAttribute;
    FStride: Byte;
    FAttributeCount: Int8;
  public
    function Start(const AShader: TShader): PVertexLayout;
    function Add(
        const AName: RawByteString; const ACount: Integer;
        const ANormalized: Boolean = False;
        const AOptional: Boolean = False): PVertexLayout;
  end;
{$ENDREGION}



{$REGION 'TVertex Array'}
  TVertexArray = class
  private
    FVertexBuffer: GLuint;                            // VBO
    FIndexBuffer: GLuint;                             // IBO
    FVertexArray: GLuint;                             // VA
    FAttributes: TArray<TVertexLayout.TAttribute>;
    FStride: Integer;
    FIndexCount: Integer;
    FRenderStarted: Boolean;
  public
    FVertexCount: Cardinal;
    Property VertexBuffer: GLUInt read FVertexBuffer;
    Property IndexBuffer: GLUInt read FIndexBuffer;
    Property VertexArray: GLUInt read FVertexArray;
    Property IndexCount: Integer read FIndexCount;

    procedure Render;
    procedure BeginRender;
    procedure EndRender;

    constructor Create( const ALayout: TVertexLayout;
                        const AVertices: array of Single;
                        const ASizeOfVertices: Integer;
                        const AIndices: array of GLUInt;
                        const AIndexCount: Integer);

    destructor Destroy; override;
  end;
{$ENDREGION}



{$REGION 'TOpenGL Handler'}
  TOpenGLHandler = class
    private
      DC: HDC;          // Drawing context handle
      RC: HGLRC;        // OpenGL rendering context

      FPSSum: Double;
      function GetFPS: Cardinal;
    public
      SW: TStopWatch;
      Memo:               TMemo;          // For debug
      Camera:             TCamera;

      ShaderVoxel:        TShader;        // Shaders for voxel drawing
      VertexLayoutVoxel:  TVertexLayout;  // Vertex array layout for voxels
      VertexArrayVoxel:   TVertexArray;   // Vertex array data voxels

      AttributePosition:  GLuInt;         //
      VertexBuffer:       GLuint;
      IndexBuffer:        GLuint;

      UniformModel:       GLUInt;       // From local space to world space
      UniformView:        GLUInt;       // World space to view
      UniformProjection:  GLUInt;       // View space to clip

      Texture0:           GLUint;
      Texture1:           GLUint;
      UniformTexture0:    GLInt;
      UniformTexture1:    GLInt;

      TextureArray0:        GLUint;
      UniformTextureArray0: GLInt;

      Target: TControl;   // Target
      property FPS: Cardinal read GetFPS;

      constructor Create;
      destructor Destroy; override;
      procedure SetUpRenderingContext(const aTarget: TControl);   // Only TPanel for now
      procedure Clear;
      procedure SwapBuffer;
      procedure ErrorCheck(aMessage: String);
      procedure SetUpBuffers;
      procedure LoadTexture(var aID: GLUint; aPath: String);

      // Paths is linebreak separated list of file paths relative to the executable
      procedure LoadTextureArray(var aID: GLUint; Paths: String);
      procedure Render_old;
      procedure Render1;
      procedure GUI;


      // Calculate world space ray from camera location to screen coordinates
      function RayTo(const ScreenX, ScreenY: Cardinal): TVector3;

  end;
{$ENDREGION}


function FileSourceStr(aPath: String): AnsiString;
function IsPowerOfTwo(const AValue: Cardinal): Boolean; inline;
procedure glErrorCheck; {$IFNDEF DEBUG}inline;{$ENDIF}
function glIsExtensionSupported(const AName: RawByteString): Boolean;
procedure glInfoToDisk;

////////////////////////////////////////////////////////////////////
implementation



uses

  // Standard
  Inifiles,
  Math,
  SysUtils,

  // Custom
  Neslib.Stb.Image;


var
  GExtensions: RawByteString = '';



{$REGION 'Helpers'}

{$REGION 'DEBUG'}
{$IFDEF DEBUG}
procedure glErrorCheck;
var
  Error: GLenum;
begin
  Error := GL_NO_ERROR;
  Error := glGetError;
  if (Error <> GL_NO_ERROR) then
    raise Exception.CreateFmt('OpenGL Error: $%.4x', [Error]);
end;
{$ELSE}
procedure glErrorCheck; inline;
begin
  // Nothing
end;
{$ENDIF}
{$ENDREGION}

function FileSourceStr(aPath: String): AnsiString;
var
  SL: TStringList;
begin
  Result := '';
  SL := TStringList.Create;
  try
    SL.LoadFromFile(aPath);
    Result := AnsiString(SL.Text);
  finally
    SL.Free;
  end;

end;

function IsPowerOfTwo(const AValue: Cardinal): Boolean; inline;
begin
  { https://graphics.stanford.edu/~seander/bithacks.html#DetermineIfPowerOf2 }
  Result := ((AValue and (AValue - 1)) = 0);
end;

function glIsExtensionSupported(const AName: RawByteString): Boolean;
begin
  if (GExtensions = '') then
    GExtensions := RawByteString(MarshaledAString(glGetString(GL_EXTENSIONS)));

  Result := (Pos(AName, GExtensions) >= Low(RawByteString));
end;

procedure glInfoToDisk;
var
  Ini: TCustomIniFile;
  Path: String;

  StatusI: GLint;

begin
  // Check if openGL initialized
  if not assigned(glGetIntegerv) then
    begin
      raise Exception.Create('glInfoToDisk: openGL not initialized');
      exit;
    end;

// Make folder
{$IOChecks off}
  MkDir('Debug');
{$IOChecks on}

// Set path
  Path:= ExtractFilePath(Application.ExeName)+'\Debug';

// Check path exists
  if not DirectoryExists(Path) then begin
    raise Exception.Create('glInfoToDisk: cannot create folder');
    exit;
  end;

// Create file
  Ini := TInifile.Create(Path+'\OpenGLinfo.ini');

  try
    // openGL version
    Ini.WriteString('OpenGLInfo', 'GL_VERSION', glGetString(GL_VERSION));

    // Textures available per shader
    StatusI := -1;
    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, @StatusI);
    Ini.WriteInteger('OpenGLInfo', 'GL_MAX_TEXTURE_IMAGE_UNITS (texture units per shader)', StatusI);

    // Total texture units available
    StatusI := -1;
    glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, @StatusI);
    Ini.WriteInteger('OpenGLInfo', 'GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS', StatusI);

    // Max textures size
    StatusI := -1;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, @StatusI);
    Ini.WriteInteger('OpenGLInfo', 'GL_MAX_TEXTURE_SIZE (pixels x pixels)', StatusI);

    // Max texture array depth
    StatusI := -1;
    glGetIntegerv(GL_MAX_ARRAY_TEXTURE_LAYERS, @StatusI);
    Ini.WriteInteger('OpenGLInfo', 'GL_MAX_ARRAY_TEXTURE_LAYERS (maximum texture array depth)', StatusI);

    //
    StatusI := -1;
    glGetIntegerv(GL_MAX_ELEMENTS_VERTICES, @StatusI);
    Ini.WriteInteger('OpenGLInfo', 'GL_MAX_ELEMENTS_VERTICES (dunno what this is)', StatusI);

    //
    StatusI := -1;
    glGetIntegerv(GL_MAX_ELEMENTS_INDICES, @StatusI);
    Ini.WriteInteger('OpenGLInfo', 'GL_MAX_ELEMENTS_INDICES (dunno what this is)', StatusI);




  finally

    Ini.Free;

  end;

end;

{$ENDREGION}



{$REGION 'OpenGLHandler'}

constructor TOpenGLHandler.Create;
begin
  Inherited Create;

  If not InitOpenGL then
    begin
      MessageDlg('Could not initialize OpenGL', mtError, [mbOk], 0);
      Application.Terminate;
    end;

  FPSSum := 0;

  SW := TStopWatch.Create;
  SW.Start;
end;

destructor TOpenGLHandler.Destroy;
begin
  if assigned(VertexArrayVoxel) then VertexArrayVoxel.Free;
  if assigned(ShaderVoxel) then ShaderVoxel.Free;
  if assigned(Camera) then Camera.Free;

  DeactivateRenderingContext; // Deactivates the current context
  wglDeleteContext(RC);

  inherited Destroy;
end;

procedure TOpenGLHandler.SetUpRenderingContext(const aTarget: TControl);
var
  PF: Integer;
const
  PFD:TPIXELFORMATDESCRIPTOR = (
  nSize:sizeof(TPIXELFORMATDESCRIPTOR);	  // size
  nVersion:1;			                        // version
                                          // support double-buffering
  dwFlags:PFD_SUPPORT_OPENGL or PFD_DRAW_TO_WINDOW or PFD_DOUBLEBUFFER;
  iPixelType:PFD_TYPE_RGBA;	              // color type
  cColorBits:24;			                    // preferred color depth
  cRedBits:0;   cRedShift:0;	            // color bits (ignored)
  cGreenBits:0; cGreenShift:0;
  cBlueBits:0;  cBlueShift:0;
  cAlphaBits:0; cAlphaShift:0;            // no alpha buffer
  cAccumBits: 0;
  cAccumRedBits: 0;  		                  // no accumulation buffer,
  cAccumGreenBits: 0;     	              // accum bits (ignored)
  cAccumBlueBits: 0;
  cAccumAlphaBits: 0;
  cDepthBits:32;			                    // depth buffer
  cStencilBits:0;			                    // no stencil buffer
  cAuxBuffers:0;			                    // no auxiliary buffers
  iLayerType:PFD_MAIN_PLANE;  	          // main layer
  bReserved: 0;
  dwLayerMask: 0;
  dwVisibleMask: 0;
  dwDamageMask: 0;                        // no layer, visible, damage masks
  );
begin
  // If one wants to render to a panel, the panel handle is not available yet in the
  // FormCreate event.

  // Get the draw context handle
  if aTarget.ClassType = TPanel then
    DC := GetDc(TPanel(aTarget).Handle);
//  else if aTarget.ClassType = TPaintBox then
//   DC := TPaintBox(aTarget).Canvas.Handle
//  else if aTarget.ClassType = TImage then
//   DC := GetDC(TImage(aTarget).Canvas.Handle);


  // Set up pixel format
  PF := ChoosePixelFormat(DC, @PFD);

  if (PF = 0) then
    begin
      MessageDlg('No suitable pixel format could be found.', mtError, [mbOk], 0);
      exit;
    end;

  if (SetPixelFormat(DC, PF, @pfd) <> TRUE) then
    begin
      MessageDlg('Pixel format could not be applied.', mtError, [mbOk], 0);
      exit;
    end;

  // Create rendering context
  RC := CreateRenderingContext(   DC,                 // DeviceContest
                                  [OpDoubleBuffered], // Options
                                  32,                 // ColorBits
                                  24,                 // Zbits
                                  0,                  // StencilBits
                                  0,                  // AccumBits
                                  0,                  // AuxBuffers
                                  0                   // Layer
                              );

  // The above values were different in all the sources I found, from 16 to 24 bit color depths.
  //  DC -  the device context to which the Rendercontext depends. For example, the context of a form or that of a panel.
  //        Depending on where to draw later on.
  //  Options - are hints such as: opDoubleBuffered. This option specifies that double buffering should be used.
  //  ColorBits - here 32, indicates the color depth. 32 means that 1Bbyte = 8Bit is available for the 4 color
  //        channels (red, green, blue, alpha (transparency)). This means that 256 channels can be used for each channel.
  //        That makes a total of 256^4
  //  Z bits - here 24, indicate how many bits are reserved for the depth buffer. 24Bits means that entries from
  //        0 to 2^24 = 16.7M are possible. The higher the value, the finer / more accurate the depth test.
  //  Stencil bits - required for the stencil test . (Masking screen parts)
  //  AccumBits - indicate how many bits can be stored in the accumulation buffer.
  //  AuxBuffer - specifies how many bits can be stored in the auxiliary buffer.
  //  Layer - specifies the number of layers. For OpenGL, has no use.

  // Activate rendering context
  ActivateRenderingContext(DC, RC);

  // Check whether RC could be generated
  if (RC=0) then
    begin
      MessageDlg('Rendering context could not be created.', mtError, [mbOk], 0);
      Halt(100)
    end;

  // Check whether RC could be activated.
  if (not wglMakeCurrent(DC, RC)) then
    begin
      MessageDlg('Rendering context could not be activated.', mtError, [mbOk], 0);
      Halt(100)
    end;

  // One side, fill
  glPolygonMode(GL_FRONT, GL_FILL);

  // Depth test on
  glEnable(GL_DEPTH_TEST);

  // Clear just to see color change from default
//  Self.Clear;
//  Self.SwapBuffer;

  // Set Target
  Target := aTarget;

  // Camera
  // Why is this done here
  Camera := TCamera.Create(Target.Width, Target.Height, Vector3(0, 0, 0), Vector3(0,1,0));

  ErrorCheck('SetUpRenderingContext');
end;

procedure TOpenGLHandler.Clear;
begin
// Empty color buffer and depth buffer
  glClearColor(0.8, 0.8, 1.0, 1.0);                         // RGBA
  glClear(GL_DEPTH_BUFFER_BIT or GL_COLOR_BUFFER_BIT);
end;

procedure TOpenGLHandler.SwapBuffer;
var
  Difference: Double;
begin
// SwapBuffers ensures that the content of the frame buffer appears on the screen. Without this command, you will not see
// anything from OpenGL. (Interesting article: double buffering)
  SwapBuffers(DC);

// How long since last tick
  Difference := max(1, SW.ElapsedMilliseconds);
  SW := TStopWatch.StartNew;

// Calculate FPS
  FPSSum := (FPSSum*59 + (1000/Difference))/60;


end;

procedure TOpenGLHandler.ErrorCheck(aMessage: String);
var
  Error: GLEnum;
begin
  Error := glGetError;
  if (Error <> GL_NO_ERROR) then
    raise Exception.CreateFmt('OpenGL error: $%.4x on '+aMessage, [Error]);
end;

procedure TOpenGLHandler.SetUpBuffers;
begin
    { Set up vertex data (and buffer(s)) }
  glGenBuffers(1, @VertexBuffer);
  glBindBuffer(GL_ARRAY_BUFFER, VertexBuffer);
//  glBufferData(GL_ARRAY_BUFFER, SizeOf(VERTICES), @A, GL_STATIC_DRAW);
  glBindBuffer(GL_ARRAY_BUFFER, 0);

  glGenBuffers(1, @IndexBuffer);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, IndexBuffer);
//  glBufferData(GL_ELEMENT_ARRAY_BUFFER, SizeOf(INDICES), @B, GL_STATIC_DRAW);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
end;

procedure TOpenGLHandler.LoadTexture(var aID: GLUint; aPath: String);
var
  Width, Height, Components: Integer;
  Image: Pointer;
  SupportsMipmaps: Boolean;
begin

  glGenTextures(1,  @aID);
  // Generate texture names 2.0 - 4.5
  //            Specifies the number of texture names to be generated.
  //                Specifies an array in which the generated texture names are stored.

  glBindTexture(GL_TEXTURE_2D,  aID);
  // Bind a named texture to a texturing target 2.0 - 4.5
  //            Specifies the target to which the texture is bound. Must be one of GL_TEXTURE_1D, GL_TEXTURE_2D, GL_TEXTURE_3D, GL_TEXTURE_1D_ARRAY, GL_TEXTURE_2D_ARRAY, GL_TEXTURE_RECTANGLE, GL_TEXTURE_CUBE_MAP, GL_TEXTURE_CUBE_MAP_ARRAY, GL_TEXTURE_BUFFER, GL_TEXTURE_2D_MULTISAMPLE or GL_TEXTURE_2D_MULTISAMPLE_ARRAY.
  //                            Specifies the name of a texture.

  // Load texture
  Image := stbi_load(PAnsiChar(AnsiString(APath)), Width, Height, Components, 3);
  Assert(Assigned(Image));

  // Set texture data
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, Width, Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);


  // Generate mipmaps if possible. With OpenGL ES, mipmaps are only supported if both dimensions are a power of two.
  SupportsMipmaps := IsPowerOfTwo(Width) and IsPowerOfTwo(Height);
  if (SupportsMipmaps) then
    glGenerateMipmap(GL_TEXTURE_2D);

  // Set texture parameters
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  if (SupportsMipmaps) then
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST)
  else
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

  // Free original image
  stbi_image_free(Image);

  // Unbind
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;
end;

procedure TopenGLHandler.LoadTextureArray(var aID: Cardinal; Paths: String);
const
  mipLevelCount: GLsizei = 1;

var
  thePaths: TStringList;
  I, Width, Height, Components: Integer;
  FilesOK: Boolean;
  Image: Pointer;

begin
  // Check all files exist
  FilesOK := true;
  thePaths := TStringList.Create;
  thePaths.Text := Paths;

  for I := 0 to thePaths.Count-1 do
    begin
      FilesOK := FileExists(thePaths[I]) and FilesOK;
    end;

  // Validate files to be OK next loop also
  if not FilesOK then begin
    raise Exception.Create('LoadTextureArray: file(s) not found in: '+Paths);
    exit;
  end;

  glGenTextures(1,@aID);
  glErrorCheck;
  glActiveTexture(GL_TEXTURE0);                         // Activate texture unit 0
  glErrorCheck;
  glBindTexture(GL_TEXTURE_2D_ARRAY,aID);
  glErrorCheck;

  //Create storage for the texture
  Image := stbi_load(PAnsiChar(AnsiString(thePaths[0])), Width, Height, Components, 3);
  Assert(Assigned(Image));

  glTexStorage3D( GL_TEXTURE_2D_ARRAY,
                  6,                    // Texture levels             log2(max(width, height, depth)+1)
                  GL_RGB8,              // Internal format            GL_SRGB8
                  Width, Height,        // Width, Height
                  thePaths.Count        // Number of layers
                );
  glErrorCheck;

//  glTexParameteri(GL_TEXTURE_2D_ARRAY,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR);
  glErrorCheck;

//  glTexParameteri(GL_TEXTURE_2D_ARRAY,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
//  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER,GL_LINEAR_MIPMAP_LINEAR);
//  glErrorCheck;

//  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
//  glErrorCheck;

//  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
//  glErrorCheck;


  for I := 0 to thePaths.Count-1 do
    begin
      Image := stbi_load(PAnsiChar(AnsiString(thePaths[I])), Width, Height, Components, 3);
      Assert(Assigned(Image));
//    ShowMessage(thePaths[I]);

      glTexSubImage3D(
                  GL_TEXTURE_2D_ARRAY,   // Target
                  0,                     // Mipmap level of the texture to load. Since we rely on OGL to generate the mipmaps, it's 0.
                  0,0,I,                 // xoffset, yoffset, zoffset
                                         // The 5th parameter is the offset in depth of where to store the data passed in.
                                         // In this case it's the layer I.
                  width,height,1,        // width, height, depth
                                         // The eighth parameter is the depth. In the case of arrays, that means the number
                                         // of layers we are passing. It's 1, as we pass a single layer per iteration of the loop
                  GL_RGB,                // format
                  GL_UNSIGNED_BYTE,      // type
                  Image);                // pointer to data

      glErrorCheck;

      // Free original image
      stbi_image_free(Image);
    end;

  glGenerateMipmap(GL_TEXTURE_2D_ARRAY);

  thePaths.Free;

  glErrorCheck;
end;

function TOpenGLHandler.GetFPS;
begin
  Result := round(FPSSum);
end;

procedure TOpenGLHandler.Render_old;
var
  Difference: Cardinal;

// 17 Camera
  Model, View, Projection: TMatrix4;

begin

// Clear and render
  Clear;

  // Shaders activate
  ShaderVoxel.Use;

  glUniform1i(UniformTextureArray0, 0);                 // Specify the value of a uniform variable for the current program object
                                                        // Sampler refers to texture unit 0

  // Coordinates to world coordinates
  Model.InitTranslation(0,0,0);

  // Change coordinates to match camera location
  View := Camera.GetViewMatrix;

  // View angle etc.
  Projection.InitPerspectiveFovRH(Radians(Camera.Zoom), Target.Width/Target.Height, 0.1, 1000);

  // Pass matrices to shader
  glUniformMatrix4fv(UniformModel, 1, GL_FALSE, @Model);
  glUniformMatrix4fv(UniformView, 1, GL_FALSE, @View);
  glUniformMatrix4fv(UniformProjection, 1, GL_FALSE, @Projection);

  // Render the data
  VertexArrayVoxel.Render;

  SwapBuffer;
end;

procedure TOpenGLHandler.Render1;
var
  I: Integer;

// 17 Camera
  Model, View, Projection: TMatrix4;

begin

// Clear and render
  Clear;

  // Shaders activate
  ShaderVoxel.Use;

  glUniform1i(UniformTextureArray0, 0);                 // Specify the value of a uniform variable for the current program object
                                                        // Sampler refers to texture unit 0

  // Coordinates to world coordinates
  Model.InitTranslation(0,0,0);

  // Change coordinates to match camera location
  View := Camera.GetViewMatrix;

  // View angle etc.
  Projection.InitPerspectiveFovRH(Radians(Camera.Zoom), Target.Width/Target.Height, 0.1, 1000);

  // Pass matrices to shader
  glUniformMatrix4fv(UniformModel, 1, GL_FALSE, @Model);
  glUniformMatrix4fv(UniformView, 1, GL_FALSE, @View);
  glUniformMatrix4fv(UniformProjection, 1, GL_FALSE, @Projection);

end;

function TOpenGLHandler.RayTo(const ScreenX, ScreenY: Cardinal): TVector3;
var
  Y_openGL: Double;                           // Y as openGL, + is up
  ViewM, ProjectionM: TMatrix4;               // for inverted matrices
  ray_nds: TVector3;                          // ray normalized device space
  ray_clip: TVector4;                         // ray in clip space
  ray_eye: TVector4;                          // ray in camera space
  ray_wor: TVector4;                          // ray in world space, 4D

// http://antongerdelan.net/opengl/raycasting.html
begin
  // Reverse Y
  Y_openGL := Target.Height-ScreenY;

  // Normallize -1 to +1
  ray_nds.X := (2*ScreenX)/Target.Width-1;
  ray_nds.Y := (2*Y_openGL)/Target.Height-1;
  ray_nds.Z := 1;

  // Go to clip space
  ray_clip.X := ray_nds.X;
  ray_clip.Y := ray_nds.Y;
  ray_clip.Z := -1;
  ray_clip.W := 1;

  // Get and inverse projection
  ProjectionM.InitPerspectiveFovRH(Radians(Camera.Zoom), Target.Width/Target.Height, 0.1, 1000);
  ProjectionM.SetInversed;

  // Undo projection to get into camera space
  ray_eye := ProjectionM*ray_clip;
  ray_eye.Z := -1;
  ray_eye.W := 0;

  // Get and inverse view matrix
  ViewM := Camera.GetViewMatrix;
  ViewM.SetInversed;

  // Undo camera matrix to get to world space
  ray_wor := ray_eye*ViewM;

  // Transfer to 3D vector
  Result.X := ray_wor.X;
  Result.Y := ray_wor.Y;
  Result.Z := ray_wor.Z;

end;

procedure TOpenGLHandler.GUI;
begin
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_CULL_FACE);
  glDisable(GL_TEXTURE_2D);
  glDisable(GL_LIGHTING);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  gluOrtho2D(-100, 100, -100, 100);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glColor3f(1, 1, 1);
  glBegin(GL_QUADS);
      glVertex3f(20.0, 20.0, 0.0);
      glVertex3f(20.0, -20.0, 0.0);
      glVertex3f(-20.0, -20.0, 0.0);
      glVertex3f(-20.0, 20.0, 0.0);
  glEnd();
end;

{$ENDREGION}



{$REGION 'Shader'}

constructor TShader.Create(const AVertexShaderPath, AFragmentShaderPath: String);
var
  Status, LogLength: GLint;
  VertexShader, FragmentShader: GLuint;
  Log: TBytes;
  Msg: String;
begin
  inherited Create;
  FragmentShader := 0;
  VertexShader := CreateShader(AVertexShaderPath, GL_VERTEX_SHADER);
  try
    FragmentShader := CreateShader(AFragmentShaderPath, GL_FRAGMENT_SHADER);
    FProgram := glCreateProgram;

    glAttachShader(FProgram, VertexShader);
    glErrorCheck;

    glAttachShader(FProgram, FragmentShader);
    glErrorCheck;

    glLinkProgram(FProgram);
    glGetProgramiv(FProgram, GL_LINK_STATUS, @Status);

    if (Status <> 1) then
    begin
      glGetProgramiv(FProgram, GL_INFO_LOG_LENGTH, @LogLength);
      if (LogLength > 0) then
      begin
        SetLength(Log, LogLength);
        glGetProgramInfoLog(FProgram, LogLength, @LogLength, @Log[0]);
        Msg := TEncoding.ANSI.GetString(Log);
        raise Exception.Create(Msg);
      end;
    end;
    glErrorCheck;
  finally
    if (FragmentShader <> 0) then
      glDeleteShader(FragmentShader);

    if (VertexShader <> 0) then
      glDeleteShader(VertexShader);
  end;
end;

class function TShader.CreateShader(const AShaderPath: String; const AShaderType: GLenum): GLuint;
var
  Source: RawByteString;
  SourcePtr: MarshaledAString;
  Status, LogLength: GLint;
  Log: TBytes;
  Msg: String;
begin
  Result := glCreateShader(AShaderType);
  Assert(Result <> 0);
  glErrorCheck;

  Source := FileSourceStr(AShaderPath);

  SourcePtr := MarshaledAString(Source);
  glShaderSource(Result, 1, @SourcePtr, nil);
  glErrorCheck;

  glCompileShader(Result);
  glErrorCheck;

  Status := 0;
  glGetShaderiv(Result, GL_COMPILE_STATUS, @Status);
  if (Status <> 1) then
  begin
    glGetShaderiv(Result, GL_INFO_LOG_LENGTH, @LogLength);
    if (LogLength > 0) then
    begin
      SetLength(Log, LogLength);
      glGetShaderInfoLog(Result, LogLength, @LogLength, @Log[0]);
      Msg := TEncoding.ANSI.GetString(Log);
      raise Exception.Create(Msg);
    end;
  end;
end;

destructor TShader.Destroy;
begin
  glUseProgram(0);
  if (FProgram <> 0) then
    glDeleteProgram(FProgram);
  inherited;
end;

function TShader.GetUniformLocation(const AName: RawByteString): Integer;
begin
  Result := glGetUniformLocation(FProgram, MarshaledAString(AName));
  if (Result < 0) then
    raise Exception.CreateFmt('Uniform "%s" not found in shader', [AName]);
end;

function TShader.GetUniformLocationUnicode(const AName: String): Integer;
begin
  Result := GetUniformLocation(RawByteString(AName));
end;

procedure TShader.Use;
begin
  glUseProgram(FProgram);
end;

function TShader._GetHandle: GLuint;
begin
  Result := FProgram;
end;

{$ENDREGION}



{$REGION 'VertexLayout'}


function TVertexLayout.Add(const AName: RawByteString; const ACount: Integer; const ANormalized, AOptional: Boolean): PVertexLayout;
var
  Location, Stride: Integer;
begin
  if (FAttributeCount = MAX_ATTRIBUTES) then
    raise Exception.Create('Too many attributes in vertex layout');

  Stride := FStride + (ACount * SizeOf(Single));
  if (Stride >= 256) then
    raise Exception.Create('Vertex layout too big');

  Location := glGetAttribLocation(FProgram, MarshaledAString(AName));
  if (Location < 0) and (not AOptional) then
    raise Exception.CreateFmt('Attribute "%s" not found in shader', [AName]);

  if (Location >= 0) then
  begin
    Assert(Location <= 255);
    FAttributes[FAttributeCount].Location := Location;
    FAttributes[FAttributeCount].Size := ACount;
    FAttributes[FAttributeCount].Normalized := ANormalized;
    FAttributes[FAttributeCount].Offset := FStride;
    Inc(FAttributeCount);
  end;

  FStride := Stride;

  Result := @Self;
end;

function TVertexLayout.Start(const AShader: TShader): PVertexLayout;
begin
  Assert(Assigned(AShader));
  FillChar(Self, SizeOf(Self), 0);
  FProgram := AShader.Handle;
  Result := @Self;
end;


{$ENDREGION}



{$REGION 'VertexArray'}

constructor TVertexArray.Create ( const ALayout: TVertexLayout;
                                  const AVertices: array of Single;
                                  const ASizeOfVertices: Integer;
                                  const AIndices: array of GLUInt;
                                  const AIndexCount: Integer
                                );
var
  I: Integer;
begin
  inherited Create;
  FIndexCount := AIndexCount;
  FVertexCount := Length(AVertices);

  // Create vertex buffer and index buffer
  glGenBuffers(1, @FVertexBuffer);
  glGenBuffers(1, @FIndexBuffer);

  glGenVertexArrays(1, @FVertexArray);
  glBindVertexArray(FVertexArray);

  glBindBuffer(GL_ARRAY_BUFFER, FVertexBuffer);
  glBufferData(GL_ARRAY_BUFFER, ASizeOfVertices, @AVertices[0], GL_STATIC_DRAW);
  glErrorCheck;

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, FIndexBuffer);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, AIndexCount * SizeOf(GLUInt), @AIndices, GL_STATIC_DRAW);
  glErrorCheck;

  // We can configure the attributes as part of the VAO
  for I := 0 to ALayout.FAttributeCount - 1 do
  begin
    glVertexAttribPointer(
      ALayout.FAttributes[I].Location,
      ALayout.FAttributes[I].Size,
      GL_FLOAT,
      ALayout.FAttributes[I].Normalized,
      ALayout.FStride,
      Pointer(ALayout.FAttributes[I].Offset));
    glEnableVertexAttribArray(ALayout.FAttributes[I].Location);
  end;

  // We can unbind the vertex buffer now since it is registered with the VAO.
  // We cannot unbind the index buffer though.
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);

  glErrorCheck;
end;


destructor TVertexArray.Destroy;
begin
  glDeleteVertexArrays(1, @FVertexArray);
  glDeleteBuffers(1, @FIndexBuffer);
  glDeleteBuffers(1, @FVertexBuffer);
  inherited;
end;


procedure TVertexArray.BeginRender;
var
  I: Integer;
begin
  if (FRenderStarted) then
    Exit;

  glBindVertexArray(FVertexArray);

  FRenderStarted := True;
end;


procedure TVertexArray.EndRender;
var
  I: Integer;
begin
  if (not FRenderStarted) then
    Exit;

  FRenderStarted := False;
  glBindVertexArray(0);
  glErrorCheck;
end;


procedure TVertexArray.Render;
begin
  if (not FRenderStarted) then
    begin
      BeginRender;
      glDrawElements(GL_TRIANGLES, FIndexCount, GL_UNSIGNED_INT, nil);
      EndRender;
    end
  else
    glDrawElements(GL_TRIANGLES, FIndexCount, GL_UNSIGNED_INT, nil);


//  glBindVertexArray(FVertexArray);
//  glDrawElements(GL_TRIANGLES, FIndexCount, GL_UNSIGNED_INT, nil);
//  glBindVertexArray(0);
//  glErrorCheck;

end;




{$ENDREGION}



{$REGION 'Texture'}

procedure TTexture.Load(const APath: String; const AKind: TTextureKind);
var
  Width, Height, Components: Integer;
  Data: TBytes;
  Image: Pointer;
  SupportsMipmaps: Boolean;
begin
  FKind := AKind;

  // Generate OpenGL texture
  glGenTextures(1,  @FId);  // 2.0 - 4.5
  //            Specifies the number of texture names to be generated.
  //                Specifies an array in which the generated texture names are stored.

  glBindTexture(GL_TEXTURE_2D, FId);

  { Load texture }
//  Data := TAssets.Load(APath);
  Assert(Assigned(Data));
  Image := stbi_load_from_memory(Data, Length(Data), Width, Height, Components, 3);
  Assert(Assigned(Image));

  { Set texture data }
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, Width, Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);

  { Generate mipmaps if possible. With OpenGL ES, mipmaps are only supported
    if both dimensions are a power of two. }
  SupportsMipmaps := IsPowerOfTwo(Width) and IsPowerOfTwo(Height);
  if (SupportsMipmaps) then
    glGenerateMipmap(GL_TEXTURE_2D);

  { Set texture parameters }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  if (SupportsMipmaps) then
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR)
  else
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

  { Free original image }
  stbi_image_free(Image);

  { Unbind }
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;
end;

{$ENDREGION}



{$REGION 'Camera'}

constructor TCamera.Create(const AViewWidth, AViewHeight: Integer; const APosition, AUp: TVector3; const AYaw, APitch: Single);
begin
  inherited Create;
  FFront := Vector3(0, 0, -1);
  FMovementSpeed := DEFAULT_SPEED;
  FSensitivity := DEFAULT_SENSITIVITY;
  fViewWidth  := AViewWidth;
  fViewHeight := AViewHeight;
  Zoom := DEFAULT_ZOOM;                         // Use setter to assign zoom ratios
  FPosition := APosition;
  FWorldUp := AUp;
  FYaw := AYaw;
  FPitch := APitch;
  UpdateScreenEdge(AViewWidth, AViewHeight);
  UpdateCameraVectors;


end;

function TCamera.GetViewMatrix: TMatrix4;
begin
  Result.InitLookAtRH(FPosition, FPosition + FFront, FUp);
end;

procedure TCamera.HandleInput(const ADeltaTimeSec: Single);
var
  Velocity: Single;
begin
  Velocity := FMovementSpeed * ADeltaTimeSec;
//  Velocity := 0.45;

  if (FKeyW) then
    FPosition := FPosition + (FFront * Velocity);

  if (FKeyS) then
    FPosition := FPosition - (FFront * Velocity);

  if (FKeyA) then
    FPosition := FPosition - (FRight * Velocity);

  if (FKeyD) then
    FPosition := FPosition + (FRight * Velocity);

  if (FKeyR) then
    FPosition := FPosition + (FUp * Velocity);

  if (FKeyF) then
    FPosition := FPosition - (FUp * Velocity);

end;

procedure TCamera.ProcessKeyDown(const AKey: Integer);
begin
  if (AKey = vkW) then
    FKeyW := True;

  if (AKey = vkA)  then
    FKeyA := True;

  if (AKey = vkS)  then
    FKeyS := True;

  if (AKey = vkD) then
    FKeyD := True;

  if (AKey = vkR) then
    FKeyR := True;

  if (AKey = vkF) then
    FKeyF := True;
end;

procedure TCamera.ProcessKeyUp(const AKey: Integer);
begin
  if (AKey = vkW) then
    FKeyW := False;

  if (AKey = vkA) then
    FKeyA := False;

  if (AKey = vkS) then
    FKeyS := False;

  if (AKey = vkD)  then
    FKeyD := False;

  if (AKey = vkR) then
    FKeyR := false;

  if (AKey = vkF) then
    FKeyF := false;
end;

procedure TCamera.ProcessMouseDown(const AX, AY: Single);
begin
  { Check if mouse/finger is pressed near the edge of the screen.
    If so, simulate a WASD key event. This way, we can move the camera around
    on mobile devices that don't have a keyboard. }
  FLookAround := True;

//  if (AX < FScreenEdge.Left) then
//  begin
//    FKeyA := True;
//    FLookAround := False;
//  end
//  else
//  if (AX > FScreenEdge.Right) then
//  begin
//    FKeyD := True;
//    FLookAround := False;
//  end;

//  if (AY < FScreenEdge.Top) then
//  begin
//    FKeyW := True;
//    FLookAround := False;
//  end
//  else
//  if (AY > FScreenEdge.Bottom) then
//  begin
//    FKeyS := True;
//    FLookAround := False;
//  end;

  if (FLookAround) then
  begin
    { Mouse/finger was pressed in center area of screen.
      This is used for Look Around mode. }
    FLastX := AX;
    FLastY := AY;
  end;
end;

procedure TCamera.ProcessMouseMove(const AX, AY: Single);
var
  XOffset, YOffset: Single;
begin
  if (FLookAround) then
  begin
    XOffset := AX - FLastX;
    YOffset := FLastY - AY; { Reversed since y-coordinates go from bottom to left }

    FLastX := AX;
    FLastY := AY;

    ProcessMouseMovement(XOffset, YOffset);
  end;
end;

procedure TCamera.ProcessMouseMovement(const AXOffset, AYOffset: Single; const AConstrainPitch: Boolean);
var
  XOff, YOff: Single;
begin
  XOff := AXOffset * FSensitivity;
  YOff := AYOffset * FSensitivity;

  FYaw := FYaw + XOff;
  FPitch := FPitch + YOff;

  if (AConstrainPitch) then
    { Make sure that when pitch is out of bounds, screen doesn't get flipped }
    FPitch := Neslib.FastMath.EnsureRange(FPitch, -89, 89);

  UpdateCameraVectors;
end;

procedure TCamera.ProcessMouseUp;
begin
  if (not FLookAround) then
  begin
    { Mouse/finger was pressed near edge of screen to emulate WASD keys.
      "Release" those keys now. }
    FKeyW := False;
    FKeyA := False;
    FKeyS := False;
    FKeyD := False;
  end;
  FLookAround := False;
end;

procedure TCamera.ProcessMouseWheel(const AWheelDelta: Integer);
begin
  FZoom := EnsureRange(FZoom - AWheelDelta, 1, 45);
end;

procedure TCamera.UpdateCameraVectors;
{ Calculates the front vector from the Camera's (updated) Euler Angles }
var
  Front: TVector3;
  SinYaw, CosYaw, SinPitch, CosPitch: Single;
begin
  { Calculate the new Front vector }
  FastSinCos(Radians(FYaw), SinYaw, CosYaw);
  FastSinCos(Radians(FPitch), SinPitch, CosPitch);

  Front.X := CosYaw * CosPitch;
  Front.Y := SinPitch;
  Front.Z := SinYaw * CosPitch;

  FFront := Front.NormalizeFast;

  { Also re-calculate the Right and Up vector.
    Normalize the vectors, because their length gets closer to 0 the more you
    look up or down which results in slower movement. }
  FRight := FFront.Cross(FWorldUp).NormalizeFast;
  FUp := FRight.Cross(FFront).NormalizeFast;
end;

procedure TCamera.UpdateScreenEdge(const AViewWidth, AViewHeight: Single);
const
  EDGE_THRESHOLD = 0.15; // 15%
var
  ViewWidth, ViewHeight: Single;
begin
  { Set the screen edge thresholds based on the dimensions of the screen/view.
    These threshold are used to emulate WASD keys when a mouse/finger is
    pressed near the edge of the screen. }

  ViewWidth := AViewWidth;
  ViewHeight := AViewHeight;
  FScreenEdge.Left := EDGE_THRESHOLD * ViewWidth;
  FScreenEdge.Top := EDGE_THRESHOLD * ViewHeight;
  FScreenEdge.Right := (1 - EDGE_THRESHOLD) * ViewWidth;
  FScreenEdge.Bottom := (1 - EDGE_THRESHOLD) * ViewHeight;
end;

procedure TCamera.ViewResized(const AWidth, AHeight: Integer);
begin
  UpdateScreenEdge(AWidth, AHeight);
end;

function TCamera._GetFront: TVector3;
begin
  Result := FFront;
end;

function TCamera._GetMovementSpeed: Single;
begin
  Result := FMovementSpeed;
end;

function TCamera._GetPitch: Single;
begin
  Result := FPitch;
end;

function TCamera._GetPosition: TVector3;
begin
  Result := FPosition;
end;

function TCamera._GetRight: TVector3;
begin
  Result := FRight;
end;

function TCamera._GetSensitivity: Single;
begin
  Result := FSensitivity;
end;

function TCamera._GetUp: TVector3;
begin
  Result := FUp;
end;

function TCamera._GetWorldUp: TVector3;
begin
  Result := FWorldUp;
end;

function TCamera._GetYaw: Single;
begin
  Result := FYaw;
end;

function TCamera._GetZoom: Single;
begin
  Result := FZoom;
end;

procedure TCamera._SetFront(const AValue: TVector3);
begin
  FFront := AValue;
end;

procedure TCamera._SetMovementSpeed(const AValue: Single);
begin
  FMovementSpeed := AValue;
end;

procedure TCamera._SetPitch(const AValue: Single);
begin
  FPitch := AValue;
end;

procedure TCamera._SetPosition(const AValue: TVector3);
begin
  FPosition := AValue;
end;

procedure TCamera._SetRight(const AValue: TVector3);
begin
  FRight := AValue;
end;

procedure TCamera._SetSensitivity(const AValue: Single);
begin
  FSensitivity := AValue;
end;

procedure TCamera._SetUp(const AValue: TVector3);
begin
  FUp := AValue;
end;

procedure TCamera._SetWorldUp(const AValue: TVector3);
begin
  FWorldUp := AValue;
end;

procedure TCamera._SetYaw(const AValue: Single);
begin
  FYaw := AValue;
end;

procedure TCamera._SetZoom(const AValue: Single);
begin
  FZoom := AValue;

  aZoomX := Neslib.FastMath.FastTan(AValue/2) * fViewWidth / fViewHeight;
  aZoomY := Neslib.FastMath.FastTan(AValue/2) * fViewHeight / fViewWidth;
end;

{$ENDREGION}



end.
