{
Soft drop-shadow rendering for HtmlViewer's box-shadow support.

Kept in its own unit because it uses the RTL GDI+ wrapper (Winapi.GDIPOBJ /
Winapi.GDIPAPI), whose type names clash with the engine's own flat GDI+ wrapper
(GDIPL2A) used elsewhere. Isolating it here avoids the clash.

The whole implementation is guarded by the Compiler23_Plus define (RAD Studio
XE2 and later). On earlier compilers (including Delphi 7) DrawBoxShadow is a
no-op, so box-shadow simply doesn't render there but everything still compiles.
}

{$include htmlcons.inc}

unit HtmlBoxShadow;

interface

uses
  Windows, Graphics, Types;

// Draws a soft outer drop shadow for the box R (outer border rect, screen coords).
// Offset/Blur/Radius are in pixels; Alpha is the overall shadow opacity (0..255).
procedure DrawBoxShadow(Canvas: TCanvas; const R: TRect;
  OffsetX, OffsetY, Blur, Radius: Integer; Color: TColor; Alpha: Integer);

implementation

{$ifdef Compiler23_Plus}

uses
  Winapi.GDIPOBJ, Winapi.GDIPAPI;

procedure AddRoundRect(Path: TGPGraphicsPath; const Rc: TRect; Rad: Integer);
var
  d: Integer;
begin
  Path.Reset;
  if Rad <= 0 then
    Path.AddRectangle(MakeRect(Rc.Left, Rc.Top, Rc.Right - Rc.Left, Rc.Bottom - Rc.Top))
  else
  begin
    d := 2 * Rad;
    Path.AddArc(Rc.Left, Rc.Top, d, d, 180, 90);
    Path.AddArc(Rc.Right - d, Rc.Top, d, d, 270, 90);
    Path.AddArc(Rc.Right - d, Rc.Bottom - d, d, d, 0, 90);
    Path.AddArc(Rc.Left, Rc.Bottom - d, d, d, 90, 90);
    Path.CloseFigure;
  end;
end;

procedure DrawBoxShadow(Canvas: TCanvas; const R: TRect;
  OffsetX, OffsetY, Blur, Radius: Integer; Color: TColor; Alpha: Integer);
// Fakes a Gaussian blur by filling progressively larger rounded rects at a low
// per-pass alpha: the centre is covered by every pass (darkest) and the outer
// ring by only the last pass (lightest), giving a soft falloff.
var
  g: TGPGraphics;
  path: TGPGraphicsPath;
  brush: TGPSolidBrush;
  i, passes, a, d: Integer;
  rgb: TColor;
  rr: TRect;
begin
  passes := Blur;
  if passes < 1 then
    passes := 1;
  if passes > 32 then
    passes := 32;
  a := Alpha div passes;
  if a < 1 then
    a := 1;
  if a > 255 then
    a := 255;
  rgb := ColorToRGB(Color);
  g := TGPGraphics.Create(Canvas.Handle);
  path := TGPGraphicsPath.Create;
  try
    g.SetSmoothingMode(SmoothingModeAntiAlias);
    for i := 0 to passes - 1 do
    begin
      d := i;
      rr := Rect(R.Left + OffsetX - d, R.Top + OffsetY - d,
                 R.Right + OffsetX + d, R.Bottom + OffsetY + d);
      AddRoundRect(path, rr, Radius + d);
      brush := TGPSolidBrush.Create(MakeColor(Byte(a), GetRValue(rgb), GetGValue(rgb), GetBValue(rgb)));
      try
        g.FillPath(brush, path);
      finally
        brush.Free;
      end;
    end;
  finally
    path.Free;
    g.Free;
  end;
end;

{$else}

procedure DrawBoxShadow(Canvas: TCanvas; const R: TRect;
  OffsetX, OffsetY, Blur, Radius: Integer; Color: TColor; Alpha: Integer);
begin
  // GDI+ wrapper not available (pre-XE2 / Delphi 7): box-shadow is a no-op.
end;

{$endif}

end.
