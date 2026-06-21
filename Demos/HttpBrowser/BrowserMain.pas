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

unit BrowserMain;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  URLSubs,      // GetProtocol, ThtDocType, HTMLType
  HtmlGlobals,  // ThtString
  HtmlView,     // THtmlFileType
  FramView,
  FramBrwz,     // TFrameBrowser
  UrlConn,      // ThtConnectionManager, ThtFileConnector, ThtResourceConnector, ThtConnection, ThtUrlDoc
  UrlConnHttp;  // ThtHttpConnector

type
  TBrowserForm = class(TForm)
  private
    FToolbar: TPanel;
    FAddress: TEdit;
    FGo: TButton;
    FStatus: TStatusBar;
    FBrowser: TFrameBrowser;
    // the plumbing:
    FConnectors: ThtConnectionManager;
    FHttp: ThtHttpConnector;
    FFile: ThtFileConnector;
    FRes: ThtResourceConnector;
    // reused buffers handed back to the browser (it does not own them):
    FDocStream: TMemoryStream;
    FImgStream: TMemoryStream;
    procedure GoClick(Sender: TObject);
    procedure AddressKeyPress(Sender: TObject; var Key: Char);
    procedure Navigate(const URL: ThtString);
    procedure LoadViaConnectors(const URL, Query: ThtString; IsGet: Boolean;
      Target: TMemoryStream; out DocType: ThtDocType; out NewURL: ThtString);
    procedure WriteHtml(Target: TMemoryStream; const Html: AnsiString);
    // TFrameBrowser event handlers:
    procedure BrowserGetPostRequest(Sender: TObject; IsGet: Boolean;
      const URL, Query: ThtString; Reload: Boolean; var NewURL: ThtString;
      var DocType: THtmlFileType; var Stream: TStream);
    procedure BrowserImageRequest(Sender: TObject; const SRC: ThtString; var Stream: TStream);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  BrowserForm: TBrowserForm;

implementation

constructor TBrowserForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner); // build the form by hand, no .dfm

  Caption := 'HtmlViewer - TFrameBrowser HTTP demo';
  Width := 1000;
  Height := 720;
  Position := poScreenCenter;

  FDocStream := TMemoryStream.Create;
  FImgStream := TMemoryStream.Create;

  // ---- toolbar: address bar + Go ----
  FToolbar := TPanel.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.Align := alTop;
  FToolbar.Height := 36;
  FToolbar.BevelOuter := bvNone;
  FToolbar.Padding.SetBounds(4, 6, 4, 6);

  FGo := TButton.Create(Self);
  FGo.Parent := FToolbar;
  FGo.Align := alRight;
  FGo.Width := 72;
  FGo.Caption := 'Go';
  FGo.OnClick := GoClick;

  FAddress := TEdit.Create(Self);
  FAddress.Parent := FToolbar;
  FAddress.Align := alClient;
  FAddress.Text := 'https://example.com';
  FAddress.OnKeyPress := AddressKeyPress;

  // ---- status bar ----
  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := True;

  // ---- the browser fills the rest ----
  FBrowser := TFrameBrowser.Create(Self);
  FBrowser.Parent := Self;
  FBrowser.Align := alClient;
  FBrowser.OnGetPostRequest := BrowserGetPostRequest;
  FBrowser.OnImageRequest := BrowserImageRequest;

  // ---- the connection plumbing ----
  // A manager, plus one connector per protocol. Setting ConnectionManager
  // registers each connector with the manager.
  FConnectors := ThtConnectionManager.Create(Self);

  FHttp := ThtHttpConnector.Create(Self);       // http + https via System.Net.HttpClient
  FHttp.ConnectionManager := FConnectors;

  FFile := ThtFileConnector.Create(Self);       // file://
  FFile.ConnectionManager := FConnectors;

  FRes := ThtResourceConnector.Create(Self);    // res:// (embedded resources)
  FRes.ConnectionManager := FConnectors;
end;

destructor TBrowserForm.Destroy;
begin
  FDocStream.Free;
  FImgStream.Free;
  inherited;
end;

procedure TBrowserForm.GoClick(Sender: TObject);
begin
  Navigate(FAddress.Text);
end;

procedure TBrowserForm.AddressKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0; // swallow the Enter beep
    Navigate(FAddress.Text);
  end;
end;

procedure TBrowserForm.Navigate(const URL: ThtString);
begin
  if Trim(URL) <> '' then
    FBrowser.LoadURL(URL); // fires OnGetPostRequest below
end;

procedure TBrowserForm.WriteHtml(Target: TMemoryStream; const Html: AnsiString);
begin
  // demo error pages are ASCII; HtmlViewer's buffer auto-detects the encoding.
  Target.Clear;
  if Length(Html) > 0 then
    Target.WriteBuffer(Html[1], Length(Html));
  Target.Position := 0;
end;

// The heart of it: ask the manager for a connection that handles the URL's
// protocol, load the document into Target, and report its type / final URL.
procedure TBrowserForm.LoadViaConnectors(const URL, Query: ThtString;
  IsGet: Boolean; Target: TMemoryStream; out DocType: ThtDocType; out NewURL: ThtString);
var
  Connection: ThtConnection;
  Doc: ThtUrlDoc;
begin
  DocType := HTMLType;
  NewURL := URL;

  if not FConnectors.TryCreateConnection(GetProtocol(URL), Connection) then
  begin
    WriteHtml(Target, '<html><body><h3>Unsupported protocol</h3><p>Supported protocols: ' +
      AnsiString(FConnectors.AllProtocols) + '</p></body></html>');
    Exit;
  end;

  try
    Doc := Connection.CreateUrlDoc(not IsGet, URL, Query, '', '');
    try
      Connection.LoadDoc(Doc);
      DocType := Doc.DocType;
      NewURL := Doc.NewUrl;
      Target.Clear;
      if Doc.Stream <> nil then
        Target.CopyFrom(Doc.Stream, 0);
      Target.Position := 0;
    finally
      Doc.Free;
    end;
  finally
    Connection.Free;
  end;
end;

procedure TBrowserForm.BrowserGetPostRequest(Sender: TObject; IsGet: Boolean;
  const URL, Query: ThtString; Reload: Boolean; var NewURL: ThtString;
  var DocType: THtmlFileType; var Stream: TStream);
var
  Dt: ThtDocType;
begin
  FStatus.SimpleText := 'Loading ' + URL + ' ...';
  try
    LoadViaConnectors(URL, Query, IsGet, FDocStream, Dt, NewURL);
    DocType := Dt;
    FStatus.SimpleText := Format('%s   (%d bytes)', [NewURL, FDocStream.Size]);
  except
    on E: Exception do
    begin
      WriteHtml(FDocStream, '<html><body><h3>Could not load</h3><p>' +
        AnsiString(URL) + '</p><pre>' + AnsiString(E.Message) + '</pre></body></html>');
      DocType := HTMLType;
      FStatus.SimpleText := 'Error: ' + E.Message;
    end;
  end;
  FAddress.Text := NewURL;
  Stream := FDocStream; // browser reads it; we keep ownership
end;

procedure TBrowserForm.BrowserImageRequest(Sender: TObject; const SRC: ThtString; var Stream: TStream);
var
  Dt: ThtDocType;
  NewURL: ThtString;
begin
  Stream := nil;
  try
    LoadViaConnectors(SRC, '', True, FImgStream, Dt, NewURL);
    if FImgStream.Size > 0 then
      Stream := FImgStream;
  except
    Stream := nil; // let the browser show its broken-image placeholder
  end;
end;

end.
