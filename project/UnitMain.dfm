object FormTest: TFormTest
  Left = 0
  Top = 0
  Anchors = [akLeft, akTop, akRight, akBottom]
  Caption = 'Tests'
  ClientHeight = 697
  ClientWidth = 1224
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnKeyUp = FormKeyUp
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter1: TSplitter
    Left = 700
    Top = 0
    Height = 697
    ExplicitLeft = 328
    ExplicitTop = 352
    ExplicitHeight = 100
  end
  object PanelLeftSide: TPanel
    Left = 0
    Top = 0
    Width = 700
    Height = 697
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object PanelDrawSurface: TPanel
      Left = 0
      Top = 0
      Width = 700
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 0
      OnMouseDown = PanelDrawSurfaceMouseDown
      OnMouseMove = PanelDrawSurfaceMouseMove
      OnMouseUp = PanelDrawSurfaceMouseUp
      OnResize = PanelDrawSurfaceResize
    end
    object GroupBox1: TGroupBox
      Left = 0
      Top = 432
      Width = 700
      Height = 265
      Align = alBottom
      Caption = 'Controls'
      TabOrder = 1
      DesignSize = (
        700
        265)
      object CheckBoxRender: TCheckBox
        Left = 23
        Top = 20
        Width = 114
        Height = 17
        Caption = 'Render idle'
        Checked = True
        State = cbChecked
        TabOrder = 0
      end
      object ButtonChunkManager: TButton
        Left = 136
        Top = 47
        Width = 145
        Height = 25
        Caption = 'Create on the fly'
        TabOrder = 1
        OnClick = ButtonChunkManagerClick
      end
      object ButtonListListVicinity: TButton
        Left = 596
        Top = 16
        Width = 98
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'List Vicinity'
        TabOrder = 2
        OnClick = ButtonListListVicinityClick
      end
      object CheckBoxDebug: TCheckBox
        Left = 23
        Top = 43
        Width = 97
        Height = 17
        Caption = 'Debug'
        TabOrder = 3
      end
      object ButtonCreateBenchmark: TButton
        Left = 136
        Top = 16
        Width = 145
        Height = 25
        Caption = 'Create benchmark'
        TabOrder = 4
        OnClick = ButtonCreateBenchmarkClick
      end
      object ButtonOffsetbuilder: TButton
        Left = 596
        Top = 47
        Width = 98
        Height = 25
        Caption = 'Build offsets'
        TabOrder = 5
        OnClick = ButtonOffsetbuilderClick
      end
    end
  end
  object PageControl1: TPageControl
    Left = 703
    Top = 0
    Width = 521
    Height = 697
    ActivePage = TabSheetWorld
    Align = alClient
    TabOrder = 1
    object TabSheetWorld: TTabSheet
      Caption = 'World'
      object Memo1: TMemo
        Left = 0
        Top = 0
        Width = 513
        Height = 669
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Courier New'
        Font.Style = []
        Lines.Strings = (
          'Move: asdwrf'
          'Turn:Mouse+Left click')
        ParentFont = False
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
    object TabSheetLog: TTabSheet
      Caption = 'Log'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -8
      Font.Name = 'Courier New'
      Font.Style = []
      ImageIndex = 1
      ParentFont = False
      DesignSize = (
        513
        669)
      object ButtonClearLog: TButton
        Left = 435
        Top = 3
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Clear Log'
        TabOrder = 0
        OnClick = ButtonClearLogClick
      end
    end
  end
end
