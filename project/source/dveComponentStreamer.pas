{

  Streams and retrieves any registered TComponent to a string, file or memorystream

  History
    RJ 19.03.2009 - Initial version, from Iggy?
    RJ 28.06.2012 - Changed all from class functions to general functions
}

unit dveComponentStreamer;

interface

uses
  SysUtils,
  Classes;

  procedure ComponentToStream(AComponent: TComponent; var AStream: TMemoryStream);
  function ComponentToText(AComponent: TComponent): string;
  procedure ComponentToFile(AComponent: TComponent; const FileName: TFileName);
  function StreamToComponent(AStream: TMemoryStream): TComponent;
  function TextToComponent(const Text: string): TComponent;
  function FileToComponent(const FileName: TFileName): TComponent;

implementation

procedure ComponentToStream(AComponent: TComponent; var AStream: TMemoryStream);
begin
  AStream.Clear;
  AStream.WriteComponent(AComponent);
  AStream.Position := 0;
end;

function ComponentToText(AComponent: TComponent): string;
var
  AStringStream : TStringStream;
  AStream       : TMemoryStream;
  AString       : String;
begin
  AStringStream := TStringStream.Create(AString);
  try
    AStream := TMemoryStream.Create;
    try
      ComponentToStream(AComponent, AStream);
      ObjectBinaryToText((AStream as TMemoryStream), AStringStream);
      AStringStream.Seek(0, soFromBeginning);
      Result := AStringStream.DataString
    finally
      FreeAndNil(AStream);
    end;
  finally
    FreeAndNil(AStringStream);
  end;
end;

procedure ComponentToFile(AComponent: TComponent; const FileName: TFileName);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := ComponentToText(AComponent);
    SL.SaveToFile(FileName);
  finally
    SL.Free;
  end;
end;

function StreamToComponent(AStream: TMemoryStream): TComponent;
begin
  AStream.Seek(0, soFromBeginning);
  Result:= AStream.ReadComponent(nil);
end;

function TextToComponent(const Text: string): TComponent;
var
  StrStream: TStringStream;
  BinStream: TMemoryStream;
begin
  StrStream := TStringStream.Create(Text);
  try
    BinStream := TMemoryStream.Create;
    try
      ObjectTextToBinary(StrStream, BinStream);
      BinStream.Seek(0, soFromBeginning);
      Result:= BinStream.ReadComponent(nil);
    finally
      BinStream.Free;
    end;
  finally
    StrStream.Free;
  end;
end;

function FileToComponent(const FileName: TFileName): TComponent;
var
  StrStream : TStringStream;
  BinStream : TMemoryStream;
  StrList   : TStringList;
begin
  StrList := TStringList.Create;
  try
    StrList.LoadFromFile(FileName);
    StrStream := TStringStream.Create(StrList.Text);
    try
      BinStream := TMemoryStream.Create;
      try
        ObjectTextToBinary(StrStream, BinStream);
        BinStream.Seek(0, soFromBeginning);
        Result:= BinStream.ReadComponent(nil);
      finally
        BinStream.Free;
      end;
    finally
      StrStream.Free;
    end;
  finally
    StrList.Free;
  end;
end;



end.


