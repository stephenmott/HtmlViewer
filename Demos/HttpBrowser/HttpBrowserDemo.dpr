program HttpBrowserDemo;

uses
  Vcl.Forms,
  BrowserMain in 'BrowserMain.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'HtmlViewer HTTP Browser Demo';
  Application.CreateForm(TBrowserForm, BrowserForm);
  Application.Run;
end.
