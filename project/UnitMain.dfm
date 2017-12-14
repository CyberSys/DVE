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
    Left = 800
    Top = 0
    Height = 697
    ExplicitLeft = 328
    ExplicitTop = 352
    ExplicitHeight = 100
  end
  object Panel2: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 697
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object Panel1: TPanel
      Left = 0
      Top = 0
      Width = 800
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 0
      OnMouseDown = Panel1MouseDown
      OnMouseMove = Panel1MouseMove
      OnMouseUp = Panel1MouseUp
      OnResize = Panel1Resize
    end
    object GroupBox1: TGroupBox
      Left = 0
      Top = 432
      Width = 800
      Height = 265
      Align = alBottom
      Caption = 'Controls'
      TabOrder = 1
      DesignSize = (
        800
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
        Left = 23
        Top = 43
        Width = 98
        Height = 25
        Caption = 'Setup from CM'
        TabOrder = 1
        OnClick = ButtonChunkManagerClick
      end
      object ButtonListListVicinity: TButton
        Left = 719
        Top = 16
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'List Vicinity'
        TabOrder = 2
        OnClick = ButtonListListVicinityClick
      end
      object ButtonCMUpdate: TButton
        Left = 719
        Top = 47
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'CM Update'
        TabOrder = 3
        OnClick = ButtonCMUpdateClick
      end
      object ButtonToggleMemo: TButton
        Left = 719
        Top = 78
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Toggle Memo'
        TabOrder = 4
        OnClick = ButtonToggleMemoClick
      end
      object Button1: TButton
        Left = 638
        Top = 16
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Set cull'
        TabOrder = 5
        OnClick = Button1Click
      end
      object StringGrid1: TStringGrid
        Left = 288
        Top = 80
        Width = 209
        Height = 89
        ColCount = 3
        DragCursor = crDefault
        FixedCols = 0
        RowCount = 3
        FixedRows = 0
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goEditing]
        TabOrder = 6
        ColWidths = (
          64
          64
          64)
        RowHeights = (
          24
          24
          24)
      end
      object AlphaTrackBar: TTrackBar
        Left = 519
        Top = 102
        Width = 169
        Height = 24
        Max = 255
        PageSize = 25
        Position = 160
        PositionToolTip = ptTop
        TabOrder = 7
        TickStyle = tsNone
      end
      object TextTrackBar: TTrackBar
        Left = 519
        Top = 132
        Width = 169
        Height = 24
        Max = 255
        PageSize = 25
        Position = 255
        PositionToolTip = ptTop
        TabOrder = 8
        TickStyle = tsNone
      end
      object CompositionAlphaTrackBar: TTrackBar
        Left = 519
        Top = 162
        Width = 169
        Height = 24
        Max = 255
        PageSize = 25
        Position = 255
        PositionToolTip = ptTop
        TabOrder = 9
        TickStyle = tsNone
      end
      object CheckBoxDebug: TCheckBox
        Left = 232
        Top = 24
        Width = 97
        Height = 17
        Caption = 'Debug'
        TabOrder = 10
      end
      object Button2: TButton
        Left = 23
        Top = 88
        Width = 75
        Height = 25
        Caption = 'Button2'
        TabOrder = 11
        OnClick = Button2Click
      end
    end
  end
  object PageControl1: TPageControl
    Left = 803
    Top = 0
    Width = 421
    Height = 697
    ActivePage = TabSheetWorld
    Align = alClient
    TabOrder = 1
    object TabSheetWorld: TTabSheet
      Caption = 'World'
      object Memo1: TMemo
        Left = 0
        Top = 0
        Width = 413
        Height = 669
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Courier New'
        Font.Style = []
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
        413
        669)
      object ButtonClearLog: TButton
        Left = 335
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
