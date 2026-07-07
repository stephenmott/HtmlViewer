{
Minimal TFrameBrowser web-browser demo.

Shows the connector wiring needed to make TFrameBrowser fetch documents:

  * one ThtConnectionManager
  * one connector per protocol, each pointed at the manager:
      - ThtHttpConnector     -> http, https  (System.Net.HttpClient, no deps)
      - ThtFileConnector     -> file://
      - ThtResourceConnector -> res://

  * TFrameBrowser.OnGetPostRequest / OnImageRequest ask the manager for a
    connection for the URL's protocol, load the document, and hand the
    resulting stream back to the browser.

The whole UI is built in code (no .dfm) so the wiring is easy to follow.
}
UNIT frmBrowserMain;

INTERFACE

USES
  System.SysUtils, System.Classes,
  vcl.Forms, vcl.Controls, vcl.StdCtrls, vcl.ExtCtrls, vcl.ComCtrls,
  URLSubs,                              // GetProtocol, ThtDocType, HTMLType
  HtmlGlobals,                          // ThtString
  htmlview,                             // THtmlFileType
  framview,
  FramBrwz,                             // TFrameBrowser
  UrlConn, // ThtConnectionManager, ThtFileConnector, ThtResourceConnector, ThtConnection, ThtUrlDoc
  UrlConnHttp, HTMLUn2;                 // ThtHttpConnector

TYPE
  TBrowserForm = CLASS(TForm)
    FToolbar: TPanel;
    FBrowser: TFrameBrowser;
    FStatus: TStatusBar;
    lbAddress: TLabel;
    FGo: TButton;
    FAddress: TEdit;
    FConnectors: ThtConnectionManager;
    FFile: ThtFileConnector;
    FHttp: ThtHttpConnector;
    FRes: ThtResourceConnector;
    fForward: TButton;
    fBack: TButton;
    PROCEDURE GoClick(Sender: TObject);
    PROCEDURE AddressKeyPress(Sender: TObject; VAR Key: Char);
    PROCEDURE BrowserGetPostRequest(Sender: TObject; IsGet: Boolean; CONST URL,
      Query: ThtString; Reload: Boolean; VAR NewURL: ThtString;
      VAR DocType: THtmlFileType; VAR Stream: TStream);
    PROCEDURE BrowserImageRequest(Sender: TObject; CONST SRC: ThtString;
      VAR Stream: TStream);
    PROCEDURE FormCreate(Sender: TObject);
    PROCEDURE FormDestroy(Sender: TObject);
    PROCEDURE FormResize(Sender: TObject);
    PROCEDURE BackClick(Sender: TObject);
    PROCEDURE ForwardClick(Sender: TObject);
    PROCEDURE BrowserHistoryChange(Sender: TObject);
  PRIVATE
    { Private declarations }
    FDocStream: TMemoryStream;
    FImgStream: TMemoryStream;
    PROCEDURE WriteHtml(Target: TMemoryStream; CONST Html: AnsiString);
    PROCEDURE LoadViaConnectors(CONST URL, Query: ThtString; IsGet: Boolean;
      Target: TMemoryStream; OUT DocType: ThtDocType; OUT NewURL: ThtString);
    PROCEDURE Navigate(CONST URL: ThtString);
  PUBLIC
    { Public declarations }
  END;

VAR
  BrowserForm       : TBrowserForm;

IMPLEMENTATION

{$R *.dfm}

PROCEDURE TBrowserForm.AddressKeyPress(Sender: TObject; VAR Key: Char);
BEGIN
  IF Key = #13 THEN BEGIN
    Key := #0;                          // swallow the Enter beep
    Navigate(FAddress.Text);
  END;
END;

PROCEDURE TBrowserForm.FormCreate(Sender: TObject);
BEGIN
  Caption := 'HtmlViewer - TFrameBrowser HTTP demo';
  Width := 1000;
  Height := 720;
  Position := poScreenCenter;

  FDocStream := TMemoryStream.Create;
  FImgStream := TMemoryStream.Create;

  // Keep Back/Forward in sync after every navigation (address bar, links and
  // the buttons themselves).
  FBrowser.OnHistoryChange := BrowserHistoryChange;
  FBrowser.HistoryMaxCount := 16;       // enable Back/Forward history (0 = none kept)
  fBack.Enabled := False;
  fForward.Enabled := False;

  // Diagnostic: show the browser's pixel width (the @media breakpoints compare
  // against this) in the title bar as the window is resized.
  OnResize := FormResize;

  // Default page: a simple document kept in the repo, fetched over https.
  FAddress.Text :=
    'https://raw.githubusercontent.com/stephenmott/HtmlViewer/HtmlViewer-11.10/Demos/HttpBrowser/welcome.html';
  Navigate(FAddress.Text);
END;

PROCEDURE TBrowserForm.FormDestroy(Sender: TObject);
BEGIN
  FDocStream.Free;
  FImgStream.Free;
END;

PROCEDURE TBrowserForm.FormResize(Sender: TObject);
VAR
  W                 : Integer;
  Band              : STRING;
BEGIN
  W := FBrowser.ClientWidth;            // device px - what @media is compared to
  IF W > 1000 THEN Band := 'green (>1000)'
  ELSE IF W > 700 THEN Band := 'amber (700-1000)'
  ELSE Band := 'red (<=700)';
  Caption := Format('HtmlViewer demo  -  browser width %d px  ->  %s', [W, Band]);
END;

PROCEDURE TBrowserForm.ForwardClick(Sender: TObject);
BEGIN
  IF FBrowser.FwdButtonEnabled THEN
    FBrowser.GoFwd;
END;

PROCEDURE TBrowserForm.Navigate(CONST URL: ThtString);
BEGIN
  IF Trim(URL) <> '' THEN
    FBrowser.LoadURL(URL);              // fires OnGetPostRequest below
END;

PROCEDURE TBrowserForm.GoClick(Sender: TObject);
BEGIN
  Navigate(FAddress.Text);
END;

PROCEDURE TBrowserForm.WriteHtml(Target: TMemoryStream; CONST Html: AnsiString);
BEGIN
  // demo error pages are ASCII; HtmlViewer's buffer auto-detects the encoding.
  Target.Clear;
  IF Length(Html) > 0 THEN
    Target.WriteBuffer(Html[1], Length(Html));
  Target.Position := 0;
END;

// The heart of it: ask the manager for a connection that handles the URL's
// protocol, load the document into Target, and report its type / final URL.
PROCEDURE TBrowserForm.LoadViaConnectors(CONST URL, Query: ThtString;
  IsGet: Boolean; Target: TMemoryStream; OUT DocType: ThtDocType; OUT NewURL: ThtString);
VAR
  Connection        : ThtConnection;
  Doc               : ThtUrlDoc;
BEGIN
  DocType := HTMLType;
  NewURL := URL;

  IF NOT FConnectors.TryCreateConnection(GetProtocol(URL), Connection) THEN BEGIN
    WriteHtml(Target, '<html><body><h3>Unsupported protocol</h3><p>Supported protocols: ' +
      AnsiString(FConnectors.AllProtocols) + '</p></body></html>');
    Exit;
  END;

  TRY
    Doc := Connection.CreateUrlDoc(NOT IsGet, URL, Query, '', '');
    TRY
      Connection.LoadDoc(Doc);
      DocType := Doc.DocType;
      // Some servers mislabel HTML (raw.githubusercontent.com serves .html as
      // text/plain); trust the URL extension when it says (x)html.
      IF DocType IN [TextType, OtherType] THEN
        CASE FileExt2DocType(GetURLExtension(URL)) OF
          HTMLType: DocType := HTMLType;
          XHtmlType: DocType := XHtmlType;
        END;
      NewURL := Doc.NewURL;
      Target.Clear;
      IF Doc.Stream <> NIL THEN
        Target.CopyFrom(Doc.Stream, 0);
      Target.Position := 0;
    FINALLY
      Doc.Free;
    END;
  FINALLY
    Connection.Free;
  END;
END;

PROCEDURE TBrowserForm.BackClick(Sender: TObject);
BEGIN
  IF FBrowser.BackButtonEnabled THEN
    FBrowser.GoBack;
END;

PROCEDURE TBrowserForm.BrowserHistoryChange(Sender: TObject);
BEGIN
  fBack.Enabled := FBrowser.BackButtonEnabled;
  fForward.Enabled := FBrowser.FwdButtonEnabled;
  IF (FBrowser.HistoryIndex >= 0) AND (FBrowser.HistoryIndex < FBrowser.History.Count) THEN
    FAddress.Text := FBrowser.History[FBrowser.HistoryIndex];
END;

PROCEDURE TBrowserForm.BrowserGetPostRequest(Sender: TObject; IsGet: Boolean;
  CONST URL, Query: ThtString; Reload: Boolean; VAR NewURL: ThtString;
  VAR DocType: THtmlFileType; VAR Stream: TStream);
VAR
  Dt                : ThtDocType;
BEGIN
  FStatus.SimpleText := 'Loading ' + URL + ' ...';
  TRY
    LoadViaConnectors(URL, Query, IsGet, FDocStream, Dt, NewURL);
    DocType := Dt;
    FStatus.SimpleText := Format('%s   (%d bytes)', [NewURL, FDocStream.Size]);
  EXCEPT
    ON E: Exception DO BEGIN
      WriteHtml(FDocStream, '<html><body><h3>Could not load</h3><p>' +
        AnsiString(URL) + '</p><pre>' + AnsiString(E.Message) + '</pre></body></html>');
      DocType := HTMLType;
      FStatus.SimpleText := 'Error: ' + E.Message;
    END;
  END;
  IF NewURL <> '' THEN
    FAddress.Text := NewURL;
  Stream := FDocStream;                 // browser reads it; we keep ownership
END;

PROCEDURE TBrowserForm.BrowserImageRequest(Sender: TObject; CONST SRC: ThtString; VAR Stream:
  TStream);
VAR
  Dt                : ThtDocType;
  NewURL            : ThtString;
BEGIN
  Stream := NIL;
  TRY
    LoadViaConnectors(SRC, '', True, FImgStream, Dt, NewURL);
    IF FImgStream.Size > 0 THEN
      Stream := FImgStream;
  EXCEPT
    Stream := NIL;                      // let the browser show its broken-image placeholder
  END;
END;

END.

