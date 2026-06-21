program HttpBrowserDemo;

uses
  Vcl.Forms,
  frmBrowserMain in 'frmBrowserMain.pas' {TBrowserForm};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'HtmlViewer HTTP Browser Demo';
  Application.CreateForm(TBrowserForm, BrowserForm);
  Application.Run;
end.
