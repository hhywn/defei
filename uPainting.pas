unit uPainting;

// ============================================================================
//  uPainting — VCL 自绘基础工具(UI Beauty Spike 专用, 无第三方依赖)
//  提供: 颜色构造 / 圆角矩形填充 / 文本排版 / Segoe MDL2 图标字形
//  说明:
//   - 全部基于 GDI + ClearType 文本质量, Delphi 10.3 及以上可编译
//   - Segoe MDL2 Assets 字形需 Windows 10+ (界面演示环境即满足)
//   - 演示用代码, 生产建议换 GDI+/Skia4Delphi 换取抗锯齿
// ============================================================================

interface

uses
  Winapi.Windows,
  System.Types,
  System.SysUtils,
  System.UITypes,
  Vcl.Graphics;

const
  FONT_UI   = 'Microsoft YaHei UI'; // 中英文统一观感(中文环境下优于 Segoe UI)
  FONT_GLYPH = 'Segoe MDL2 Assets';  // Windows 10+ 内置图标字体

  // ---- 常用图标码点(微软官方 MDL2 表, 均为稳定公开码点) ----
  GP_HOME      = $E80F;  // 首页
  GP_DOC       = $E8A5;  // 文档/考试
  GP_LIBRARY   = $E8F1;  // 题库(书本)
  GP_PEOPLE    = $E716;  // 考生
  GP_SETTINGS  = $E713;  // 设置
  GP_CLOCK     = $E823;  // 时钟(最近)
  GP_PLAY      = $E768;  // 播放(进行中)
  GP_CHECK     = $E73E;  // 对勾(已完成)
  GP_CALENDAR  = $E77B;  // 日历
  GP_MINIMIZE  = $E921;  // 最小化
  GP_CLOSE     = $E8BB;  // 关闭

/// RGB -> TColor (Delphi 的 TColor 十六进制易写错, 用函数杜绝笔误)
function Rgb(R, G, B: Byte): TColor; inline;

/// 圆角矩形实心填充(画刷与画笔同色, 消除 GDI 边角留白)
procedure FillRoundCard(ACanvas: TCanvas; const ARect: TRect; Radius: Integer; AColor: TColor);

/// 应用字体设置(带 ClearType; 图标字形请用默认质量避免彩边)
procedure ApplyFontU(ACanvas: TCanvas; const AFontName: string; ASizePt: Single;
  AColor: TColor; ABold: Boolean; AQuality: TFontQuality = fqClearType);

/// 测量文本像素宽度
function MeasureU(ACanvas: TCanvas; const AFontName: string; ASizePt: Single;
  const AText: string; ABold: Boolean = False): Integer;

/// 排版绘制文本(可左右对齐 + 垂直居中)
procedure DrawU(ACanvas: TCanvas; const ARect: TRect; const AText: string;
  AColor: TColor; ASizePt: Single; ABold: Boolean = False;
  const AFontName: string = FONT_UI;
  AHorz: TAlignment = taLeftJustify; AVertCenter: Boolean = True);

/// 绘制一个 MDL2 图标, 在 ARect 内居中
procedure DrawGlyphU(ACanvas: TCanvas; const ARect: TRect; ACode: Word;
  AColor: TColor; ASizePx: Integer);

implementation

function Rgb(R, G, B: Byte): TColor; inline;
begin
  Result := R or (G shl 8) or (B shl 16);
end;

procedure FillRoundCard(ACanvas: TCanvas; const ARect: TRect; Radius: Integer; AColor: TColor);
var
  RW: Integer;
begin
  RW := Radius;
  if RW < 0 then RW := 0;
  // GDI 椭圆半径不能超过矩形短边一半, 否则圆角畸形
  if RW > (ARect.Width div 2) then RW := ARect.Width div 2;
  if RW > (ARect.Height div 2) then RW := ARect.Height div 2;

  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Width := 1;
  ACanvas.Pen.Color := AColor;      // 边与填充同色 -> 圆角像素被正确覆盖
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := AColor;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, RW * 2, RW * 2);
end;

procedure ApplyFontU(ACanvas: TCanvas; const AFontName: string; ASizePt: Single;
  AColor: TColor; ABold: Boolean; AQuality: TFontQuality = fqClearType);
begin
  ACanvas.Font.Name := AFontName;
  ACanvas.Font.Size := ASizePt;
  ACanvas.Font.Color := AColor;
  ACanvas.Font.Style := [];
  if ABold then ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Quality := AQuality;
end;

function MeasureU(ACanvas: TCanvas; const AFontName: string; ASizePt: Single;
  const AText: string; ABold: Boolean = False): Integer;
begin
  ApplyFontU(ACanvas, AFontName, ASizePt, clBlack, ABold);
  Result := ACanvas.TextWidth(AText);
end;

procedure DrawU(ACanvas: TCanvas; const ARect: TRect; const AText: string;
  AColor: TColor; ASizePt: Single; ABold: Boolean = False;
  const AFontName: string = FONT_UI;
  AHorz: TAlignment = taLeftJustify; AVertCenter: Boolean = True);
var
  TW, TH, X, Y: Integer;
begin
  ApplyFontU(ACanvas, AFontName, ASizePt, AColor, ABold);
  TW := ACanvas.TextWidth(AText);
  TH := ACanvas.TextHeight(AText);
  case AHorz of
    taLeftJustify:  X := ARect.Left;
    taCenter:       X := ARect.Left + (ARect.Width - TW) div 2;
    taRightJustify: X := ARect.Right - TW;
  else
    X := ARect.Left;
  end;
  if AVertCenter then
    Y := ARect.Top + (ARect.Height - TH) div 2
  else
    Y := ARect.Top;
  ACanvas.Brush.Style := bsClear;   // 文本不涂背景
  ACanvas.TextOut(X, Y, AText);
end;

procedure DrawGlyphU(ACanvas: TCanvas; const ARect: TRect; ACode: Word;
  AColor: TColor; ASizePx: Integer);
var
  S: string;
  TW, TH, X, Y: Integer;
  Pt: Single;
begin
  // MDL2 图标字体不要 ClearType(彩边), 用默认灰阶抗锯齿
  ApplyFontU(ACanvas, FONT_GLYPH, ASizePx * 0.75, AColor, False, fqDefault);
  S := WideChar(ACode);
  TW := ACanvas.TextWidth(S);
  TH := ACanvas.TextHeight(S);
  X := ARect.Left + (ARect.Width - TW) div 2;
  // 字形表观中心比文本盒略偏下, 上移 1px 视觉居中
  Y := ARect.Top + (ARect.Height - TH) div 2 - 1;
  ACanvas.Brush.Style := bsClear;
  ACanvas.TextOut(X, Y, S);
end;

end.
