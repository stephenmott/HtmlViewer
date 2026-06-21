HttpBrowser demo
================

A minimal TFrameBrowser web browser (~1 source file) that demonstrates how to
make the browser fetch real http/https pages using the built-in HTTP connector
(ThtHttpConnector, based on System.Net.HttpClient -- no third-party libraries).

Build
-----
Open HttpBrowserDemo.dpr in RAD Studio and run, or build from the command line.
Requires the HtmlViewer source on the unit path (..\..\source) and RAD Studio
XE8 or later (ThtHttpConnector needs System.Net.HttpClient). Builds for both
Win32 and Win64.

What to look at
---------------
BrowserMain.pas builds everything in code (no .dfm) so the wiring is obvious:

  1. Create one ThtConnectionManager.
  2. Create one connector per protocol and point each at the manager:
       ThtHttpConnector      -> http, https
       ThtFileConnector      -> file://
       ThtResourceConnector  -> res://
  3. Handle TFrameBrowser.OnGetPostRequest and OnImageRequest: ask the manager
     for a connection for the URL's protocol, LoadDoc, and return the stream.

Type a URL in the address bar and press Enter / Go.
