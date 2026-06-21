{
Version   11.10

HTTP/HTTPS connector for HtmlViewer's TFrameBrowser built on the RTL's
System.Net.HttpClient. It needs no third-party libraries, does HTTPS via the
operating system, and builds for Win32 and Win64.

The whole unit is guarded by the Compiler29_Plus define: System.Net.HttpClient
was introduced in RAD Studio XE8 (compiler 29). On older compilers this is an
empty unit, so it is safe to keep in any package's contains list.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

{$include htmlcons.inc}

unit UrlConnHttp;

interface
{$ifdef Compiler29_Plus} // System.Net.HttpClient: RAD Studio XE8 (compiler 29) and later

uses
  Classes, SysUtils,
  System.Net.HttpClient, System.Net.URLClient, System.NetEncoding,
  URLSubs, HtmlGlobals, UrlConn;

type
  //-- Loads a document for the 'http' and 'https' protocols via THTTPClient.
  ThtHttpConnection = class(ThtConnection)
  private
    FClient: THTTPClient;
    FStatusText: ThtString;
    procedure ReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64; var AAbort: Boolean);
  protected
    procedure Get(ADoc: ThtUrlDoc); override;
  public
    constructor Create;
    destructor Destroy; override;
    function ReasonPhrase: ThtString; override;
    property Client: THTTPClient read FClient;
  end;

  ThtHttpConnector = class(ThtProxyConnector)
  private
    FUserAgent: string;
    function StoreUserAgent: Boolean;
  protected
    class function GetDefaultProtocols: ThtString; override;
    class function GetVersion: string; override;
  public
    constructor Create(AOwner: TComponent); override;
    function CreateConnection(const Protocol: ThtString): ThtConnection; override;
  published
    property OnGetAuthorization;
    property UserAgent: string read FUserAgent write FUserAgent stored StoreUserAgent;
  end;

{$endif}

implementation
{$ifdef Compiler29_Plus}

uses
  HtmlUn2;

const
  CUserAgent = 'Mozilla/5.0 (compatible; HtmlViewer)';

{ ThtHttpConnection }

constructor ThtHttpConnection.Create;
begin
  inherited Create;
  FClient := THTTPClient.Create;
  FClient.HandleRedirects := True;
  FClient.OnReceiveData := ReceiveData;
end;

destructor ThtHttpConnection.Destroy;
begin
  FClient.Free;
  inherited;
end;

procedure ThtHttpConnection.ReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64; var AAbort: Boolean);
begin
  ExpectedSize := AContentLength;
  ReceivedSize := AReadCount;
  if Assigned(OnDocData) then
    OnDocData(Self);
  AAbort := Aborted;
end;

function ThtHttpConnection.ReasonPhrase: ThtString;
begin
  Result := FStatusText;
end;

procedure ThtHttpConnection.Get(ADoc: ThtUrlDoc);
const
  MaxTries = 5;
var
  Response: IHTTPResponse;
  Body: TStringStream;
  Url1, Query1: string;
  PostIt1, TryAgain, TryRealm: Boolean;
  Headers: TNetHeaders;
  Tries: Integer;
begin
  Query1 := string(ADoc.Query);
  PostIt1 := ADoc.PostIt;
  Tries := 0;

  if Assigned(OnDocBegin) then
    OnDocBegin(Self);

  repeat
    TryRealm := Tries = 0;
    TryAgain := False;
    Inc(Tries);
    ADoc.Clear;          // releases any partial stream from a previous (e.g. 401) try
    Aborted := False;
    Url1 := string(ADoc.Url);

    Headers := [];
    if BasicAuthentication and (Username <> '') then
      Headers := Headers + [TNameValuePair.Create('Authorization',
        'Basic ' + TNetEncoding.Base64.Encode(Username + ':' + Password))];

    if PostIt1 then
    begin
      if Length(ADoc.QueryEncType) > 0 then
        Headers := Headers + [TNameValuePair.Create('Content-Type', string(ADoc.QueryEncType))]
      else
        Headers := Headers + [TNameValuePair.Create('Content-Type', 'application/x-www-form-urlencoded')];
      Body := TStringStream.Create(Query1, TEncoding.UTF8);
      try
        Response := FClient.Post(Url1, Body, ADoc.Stream, Headers);
      finally
        Body.Free;
      end;
    end
    else
    begin
      if Length(Query1) > 0 then
        Url1 := Url1 + '?' + Query1;
      Response := FClient.Get(Url1, ADoc.Stream, Headers);
    end;

    FStatusText := ThtString(Response.StatusText);
    ADoc.DocType := ContentType2DocType(ThtString(Response.HeaderValue['Content-Type']));

    if (Response.StatusCode = 401) and (Tries < MaxTries) then
    begin
      TryAgain := GetAuthorization(TryRealm);
      TryRealm := False;
    end;
  until not TryAgain;

  if ADoc.Stream <> nil then
    ADoc.Stream.Position := 0;
  ADoc.Status := ucsLoaded;

  if Assigned(OnDocEnd) then
    OnDocEnd(Self);
end;

{ ThtHttpConnector }

constructor ThtHttpConnector.Create(AOwner: TComponent);
begin
  inherited;
  FUserAgent := CUserAgent;
end;

function ThtHttpConnector.CreateConnection(const Protocol: ThtString): ThtConnection;
var
  Connection: ThtHttpConnection absolute Result;
begin
  Result := ThtHttpConnection.Create;
  Connection.Client.UserAgent := FUserAgent;
  if ProxyServer <> '' then
    Connection.Client.ProxySettings := TProxySettings.Create(
      string(ProxyServer), StrToIntDef(string(ProxyPort), 8080),
      string(ProxyUsername), string(ProxyPassword));
end;

class function ThtHttpConnector.GetDefaultProtocols: ThtString;
begin
  Result := 'http,https';
end;

class function ThtHttpConnector.GetVersion: string;
begin
  Result := 'HtmlViewer ' + VersionNo + ' (System.Net.HttpClient)';
end;

function ThtHttpConnector.StoreUserAgent: Boolean;
begin
  Result := FUserAgent <> CUserAgent;
end;

{$endif}

end.
