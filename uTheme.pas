unit uTheme;

// ============================================================================
//  uTheme — Jstudy 设计令牌(Delphi 侧单一来源)
//  与 frontend/src/index.css(shadcn 亮色主题) 及登录页令牌一一对应:
//    primary #2563EB / radius 8 / 三色渐变内容底 #E8F0FD→#F1F0FC→#EEFAF6
//    glass 卡片近似为纯白实卡(自绘无法 backdrop-blur, 渐变底上视觉等价)
//  界面全部颜色/字号/圆角必须从本单元取, 禁止在业务代码里写死颜色。
// ============================================================================

interface

uses
  Winapi.Windows,
  Vcl.Graphics;

const
  // ---- 字体 ----
  TXT_UI = 'Microsoft YaHei UI';       // Win8.1+ 自带(与网页字体栈对齐)
  TXT_GLYPH = 'Segoe MDL2 Assets';     // Windows 10+ 图标字体

  // ---- 圆角(网页 --radius: 0.5rem=8px; 卡片类元素略大取 12) ----
  RAD_BTN  = 8;
  RAD_TILE = 8;
  RAD_CARD = 12;
  RAD_PILL = 999;                       // 全圆角(状态胶囊等, 由 FillRound 自钳制)

  // ---- 布局骨架 ----
  WIN_W = 1100;
  WIN_H = 720;
  HDR_H = 58;                           // 自绘标题栏高
  PAD_X = 28;                           // 内容区左右边距
  PAD_Y = 24;                           // 内容区上边距

  // ---- 字号(点) ----
  SZ_TITLE  = 15;
  SZ_SUB    = 9;
  SZ_H4     = 10.5;
  SZ_BODY   = 9.5;
  SZ_SMALL  = 8.5;
  SZ_BRAND  = 10.5;

/// 便捷取色: TColor 十六进制易写错, 一律 R,G,B 三元组
function RgbT(R, G, B: Byte): TColor; inline;

// ---- 语义色(网页令牌) ----
function ClrPrimary: TColor; inline;           // #2563EB
function ClrPrimaryHover: TColor; inline;      // #1D4ED8
function ClrFg: TColor; inline;                // #020817 正文
function ClrBody: TColor; inline;              // #475569 次级正文
function ClrMuted: TColor; inline;             // #64748B 弱化
function ClrHint: TColor; inline;              // #94A3B8 占位/更弱
function ClrBorder: TColor; inline;            // #E2E8F0 分隔线
function ClrBtnBorder: TColor; inline;         // #CBD5E1 描边按钮
function ClrHairline: TColor; inline;          // #EEF1F8 白卡内行分隔
function ClrCard: TColor; inline;              // #FFFFFF 卡片底
function ClrPrimaryFg: TColor; inline;         // #F8FAFC 主按钮文字

// ---- 内容区三色渐变(content-bg) ----
function ClrGrad1: TColor; inline;             // #E8F0FD 浅蓝
function ClrGrad2: TColor; inline;             // #F1F0FC 淡紫
function ClrGrad3: TColor; inline;             // #EEFAF6 浅薄荷

// ---- 状态色(与网页常用语义一致) ----
function ClrGreenFg: TColor; inline;           // #15803D
function ClrGreenBg: TColor; inline;           // #DCFCE7
function ClrAmberFg: TColor; inline;           // #B45309
function ClrAmberBg: TColor; inline;           // #FEF3C7
function ClrRedFg: TColor; inline;             // #B91C1C
function ClrRedBg: TColor; inline;             // #FEE2E2

// ---- 摄像头取景框(深色) ----
function ClrCam1: TColor; inline;              // #10182B
function ClrCam2: TColor; inline;              // #1E293B
function ClrCam3: TColor; inline;              // #2A3A55

// ---- 其他 ----
function ClrBarBg: TColor; inline;             // 玻璃顶栏近似底
function ClrBarLine: TColor; inline;           // 顶栏下分隔
function ClrScrim: TColor; inline;             // 弹窗遮罩(0.45 黑近似混合)
function ClrGhostFg: TColor; inline;           // 描边按钮文字 #334155
function ClrGhostHover: TColor; inline;        // 描边按钮悬浮底 #F8FAFB

implementation

function RgbT(R, G, B: Byte): TColor; inline;
begin
  Result := R or (G shl 8) or (B shl 16);
end;

function ClrPrimary: TColor; inline;           begin Result := RgbT(37, 99, 235); end;
function ClrPrimaryHover: TColor; inline;      begin Result := RgbT(29, 78, 216); end;
function ClrFg: TColor; inline;                begin Result := RgbT(2, 8, 23); end;
function ClrBody: TColor; inline;              begin Result := RgbT(71, 85, 105); end;
function ClrMuted: TColor; inline;             begin Result := RgbT(100, 116, 139); end;
function ClrHint: TColor; inline;              begin Result := RgbT(148, 163, 184); end;
function ClrBorder: TColor; inline;            begin Result := RgbT(226, 232, 240); end;
function ClrBtnBorder: TColor; inline;         begin Result := RgbT(203, 213, 225); end;
function ClrHairline: TColor; inline;          begin Result := RgbT(238, 241, 248); end;
function ClrCard: TColor; inline;              begin Result := RgbT(255, 255, 255); end;
function ClrPrimaryFg: TColor; inline;         begin Result := RgbT(248, 250, 252); end;

function ClrGrad1: TColor; inline;             begin Result := RgbT(232, 240, 253); end;
function ClrGrad2: TColor; inline;             begin Result := RgbT(241, 240, 252); end;
function ClrGrad3: TColor; inline;             begin Result := RgbT(238, 250, 246); end;

function ClrGreenFg: TColor; inline;           begin Result := RgbT(21, 128, 61); end;
function ClrGreenBg: TColor; inline;           begin Result := RgbT(220, 252, 231); end;
function ClrAmberFg: TColor; inline;           begin Result := RgbT(180, 83, 9); end;
function ClrAmberBg: TColor; inline;           begin Result := RgbT(254, 243, 199); end;
function ClrRedFg: TColor; inline;             begin Result := RgbT(185, 28, 28); end;
function ClrRedBg: TColor; inline;             begin Result := RgbT(254, 226, 226); end;

function ClrCam1: TColor; inline;              begin Result := RgbT(16, 24, 43); end;
function ClrCam2: TColor; inline;              begin Result := RgbT(30, 41, 59); end;
function ClrCam3: TColor; inline;              begin Result := RgbT(42, 58, 85); end;

function ClrBarBg: TColor; inline;             begin Result := RgbT(246, 249, 254); end;
function ClrBarLine: TColor; inline;           begin Result := RgbT(227, 234, 245); end;
function ClrScrim: TColor; inline;             begin Result := RgbT(128, 134, 148); end;
function ClrGhostFg: TColor; inline;           begin Result := RgbT(51, 65, 85); end;
function ClrGhostHover: TColor; inline;        begin Result := RgbT(248, 250, 251); end;

end.
