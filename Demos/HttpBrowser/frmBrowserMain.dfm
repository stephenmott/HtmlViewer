object BrowserForm: TBrowserForm
  Left = 0
  Top = 0
  Caption = 'BrowserForm'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object FToolbar: TPanel
    Left = 0
    Top = 0
    Width = 624
    Height = 45
    Align = alTop
    TabOrder = 0
    DesignSize = (
      624
      45)
    object lbAddress: TLabel
      Left = 66
      Top = 15
      Width = 42
      Height = 15
      Caption = 'Address'
    end
    object FGo: TButton
      Left = 544
      Top = 10
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Go'
      TabOrder = 0
      OnClick = GoClick
    end
    object FAddress: TEdit
      Left = 114
      Top = 11
      Width = 424
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
      Text = 
        'https://raw.githubusercontent.com/stephenmott/HtmlViewer/HtmlVie' +
        'wer-11.10/Demos/HttpBrowser/welcome.html'
      OnKeyPress = AddressKeyPress
    end
    object fForward: TButton
      Left = 31
      Top = 10
      Width = 30
      Height = 25
      Caption = '>'
      TabOrder = 2
      OnClick = ForwardClick
    end
    object fBack: TButton
      Left = 0
      Top = 10
      Width = 30
      Height = 25
      Caption = '<'
      TabOrder = 3
      OnClick = BackClick
    end
  end
  object FBrowser: TFrameBrowser
    Left = 0
    Top = 45
    Width = 624
    Height = 377
    CodePage = 0
    HistoryIndex = 0
    HistoryMaxCount = 0
    NoSelect = False
    PrintMarginBottom = 2.000000000000000000
    PrintMarginLeft = 2.000000000000000000
    PrintMarginRight = 2.000000000000000000
    PrintMarginTop = 2.000000000000000000
    PrintScale = 1.000000000000000000
    Text = ''
    OnImageRequest = BrowserImageRequest
    Align = alClient
    TabOrder = 1
    Touch.InteractiveGestures = [igPan]
    Touch.InteractiveGestureOptions = [igoPanSingleFingerHorizontal, igoPanSingleFingerVertical, igoPanInertia]
    OnGetPostRequest = BrowserGetPostRequest
  end
  object FStatus: TStatusBar
    Left = 0
    Top = 422
    Width = 624
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object FConnectors: ThtConnectionManager
    Left = 136
    Top = 128
  end
  object FFile: ThtFileConnector
    ConnectionManager = FConnectors
    Left = 136
    Top = 240
  end
  object FHttp: ThtHttpConnector
    ConnectionManager = FConnectors
    Left = 136
    Top = 184
  end
  object FRes: ThtResourceConnector
    ConnectionManager = FConnectors
    Left = 136
    Top = 296
  end
end
