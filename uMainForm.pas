unit uMainForm;

// ============================================================================
//  uMainForm — 考生端界面 Spike 主窗体(纯代码构建, 无 DFM)
//  流转: 考前检测页 --(拍摄/跳过)--> 内嵌考试系统视图(桩) --(演示)--> 违规弹窗
//  全部界面为自绘 Canvas, 颜色/字号/圆角取自 uTheme(Jstudy 令牌)。
//  摄像头为桩实现: 拍摄按钮走 900ms 定时后进入内嵌页, 不依赖真实设备。
//  Windows + Delphi 10.3+ 编译; 无任何第三方组件。
// ============================================================================

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Types,
  System.Classes,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  uPainting,     // 绘制原语 + MDL2 图标
  uTheme;        // Jstudy 设计令牌(色板/圆角/字号)

type
  TClientPage = (cpCheck, cpWeb);

  TCheckRec = record
    Nm: string;
    Ds: string;
  end;

  TMainForm = class(TForm)
  private
    FPage: TClientPage;
    FShooting: Boolean;
    FShowWarn: Boolean;
    FHot: Integer;              // 热区命中(见表 FHotXxx)
    FTracked: Boolean;          // TrackMouseEvent 已注册
    FShootTimer: TTimer;
    FGradLight: TBitmap;        // 内容区三色渐变缓存
    FGradCam: TBitmap;          // 摄像头取景框渐变缓存(圆角, 角部挖成卡片白)
    FCamHint: string;           // 取景框提示文案(重新检测会改写)
    procedure EnsureGradients;
    procedure BuildGradCamRounded(AW, AH: Integer);
    function PtIn(const R: TRect; X, Y: Integer): Boolean;
    // ---- 布局(纯函数, 供绘制与命中共用, 保证一致) ----
    function HeaderR: TRect;
    function BtnMinR: TRect;
    function BtnCloseR: TRect;
    function BtnShootR: TRect;
    function BtnSkipR: TRect;
    function BtnRecheckR: TRect;
    function BtnExitR: TRect;
    function BtnWarnDemoR: TRect;
    function WarnDialogR: TRect;
    function WarnBtnOkR: TRect;
    function WarnBtnAppealR: TRect;
    // ---- 绘制 ----
    procedure PaintHeader(C: TCanvas);
    procedure PaintPageCheck(C: TCanvas);
    procedure PaintPageWeb(C: TCanvas);
    procedure PaintWarnModal(C: TCanvas);
    procedure PaintCameraBox(C: TCanvas; const R: TRect);
    // ---- 动作 ----
    procedure DoShoot;
    procedure DoEnterWeb;
    procedure DoExitWeb;
    procedure UpdateHover(X, Y: Integer);
    procedure DoClick(X, Y: Integer);
    procedure TimerShoot(Sender: TObject);
  protected
    constructor CreateNew(AOwner: TComponent); override;
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure WMNCHitTest(var Message: TWMNCHitTest); message WM_NCHITTEST;
    procedure WMMouseLeave(var Message: TMessage); message WM_MOUSELEAVE;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  public
    destructor Destroy; override;
  end;

const
  // 热区码
  HT_NONE = 0;
  HT_MIN = 1;
  HT_CLOSE = 2;
  HT_SHOOT = 3;
  HT_SKIP = 4;
  HT_EXIT = 5;
  HT_WARN_DEMO = 6;
  HT_WARN_OK = 7;
  HT_WARN_APPEAL = 8;
  HT_RECHECK = 9;

  // 考前检测页两卡布局(绘制与命中共用)
  LAY_LW  = 694;   // 左卡(摄像头)宽
  LAY_RW  = 330;   // 右卡(检测清单)宽
  LAY_GAP = 20;    // 两卡间距
  CAM_RAD = 10;    // 摄像头取景框圆角(网页 10px)

implementation

const
  CHECKS: array[0..3] of TCheckRec = (
    (Nm: '摄像头可用'; Ds: '画面预览正常, 自动聚焦中'),
    (Nm: '屏幕环境检查'; Ds: '显示器分辨率 1920×1080 · 100%'),
    (Nm: '网络连通'; Ds: '考试服务器 192.168.10.41 · 12ms'),
    (Nm: '人脸入镜'; Ds: '请正对摄像头, 保持面部完整')
  );

  // 线性渐变填充位图缓存(宽高变化时重建)
  //   Mode=0: 内容区对角渐变 150°(三色段近似)
  //   Mode=1: 取景框纵向渐变(三色段)
  procedure EnsureGradient(Bmp: TBitmap; W, H, Mode: Integer);
  var
    X, Y, Idx: Integer;
    P: PByte;
    T, K: Double;
    S1, S2, S3: TColor;
    RA1, GA1, BA1, RA2, GA2, BA2: Byte;
  begin
    if (Bmp.Width = W) and (Bmp.Height = H) then Exit;
    Bmp.Width := W;
    Bmp.Height := H;
    Bmp.PixelFormat := pf32bit;   // 尺寸后再定格式, 避免重新分配丢格式
    if Mode = 0 then begin
      S1 := ClrGrad1; S2 := ClrGrad2; S3 := ClrGrad3;
    end else begin
      S1 := ClrCam1; S2 := ClrCam2; S3 := ClrCam3;
    end;
    for Y := 0 to H - 1 do begin
      P := Bmp.ScanLine[Y];
      for X := 0 to W - 1 do begin
        if Mode = 0 then
          T := (X / W + Y / H) / 2   // 150° 对角近似
        else
          T := Y / H;                 // 纵向渐变
        if T < 0.5 then begin
          K := T * 2;
          // 起点色 = S1, 终点色 = S2
          RA1 := S1 and $FF;       GA1 := (S1 shr 8) and $FF;  BA1 := (S1 shr 16) and $FF;
          RA2 := S2 and $FF;       GA2 := (S2 shr 8) and $FF;  BA2 := (S2 shr 16) and $FF;
        end else begin
          K := (T - 0.5) * 2;
          // 起点色 = S2, 终点色 = S3
          RA1 := S2 and $FF;       GA1 := (S2 shr 8) and $FF;  BA1 := (S2 shr 16) and $FF;
          RA2 := S3 and $FF;       GA2 := (S3 shr 8) and $FF;  BA2 := (S3 shr 16) and $FF;
        end;
        Idx := X * 4;
        P[Idx]     := BA1 + Byte(Round((BA2 - BA1) * K));
        P[Idx + 1] := GA1 + Byte(Round((GA2 - GA1) * K));
        P[Idx + 2] := RA1 + Byte(Round((RA2 - RA1) * K));
        P[Idx + 3] := $FF;
      end;
    end;
  end;

constructor TMainForm.CreateNew(AOwner: TComponent);
begin
  inherited CreateNew(AOwner, 0);
  FPage := cpCheck;
  FHot := HT_NONE;
  FCamHint := '画面就绪, 请正对摄像头后点击拍摄';
  FShooting := False;
  FShowWarn := False;
  FTracked := False;
  Caption := 'Jstudy 考试客户端 - UI Spike';
  BorderStyle := bsNone;
  Width := WIN_W;
  Height := WIN_H;
  DoubleBuffered := True;
  Position := poScreenCenter;
  FGradLight := TBitmap.Create;
  FGradCam := TBitmap.Create;
  FShootTimer := TTimer.Create(Self);
  FShootTimer.Enabled := False;
  FShootTimer.Interval := 900;
  FShootTimer.OnTimer := TimerShoot;
  OnClose := FormClose;
end;

destructor TMainForm.Destroy;
begin
  FGradLight.Free;
  FGradCam.Free;
  inherited Destroy;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  Application.Terminate;
end;

// ---------------------------------------------------------------------------
// 布局(几何计算与绘制/命中共用)
// ---------------------------------------------------------------------------

function TMainForm.PtIn(const R: TRect; X, Y: Integer): Boolean;
begin
  Result := (X >= R.Left) and (X < R.Right) and (Y >= R.Top) and (Y < R.Bottom);
end;

function TMainForm.HeaderR: TRect;
begin
  Result := Rect(0, 0, ClientWidth, HDR_H);
end;

function TMainForm.BtnMinR: TRect;
begin
  Result := Rect(ClientWidth - 102, 13, ClientWidth - 58, 45);
end;

function TMainForm.BtnCloseR: TRect;
begin
  Result := Rect(ClientWidth - 52, 13, ClientWidth - 6, 45);
end;

// 考前检测页按钮(右卡底带: 卡底-56 .. 卡底-20, 右缘贴卡内边距 20)
function TMainForm.BtnShootR: TRect;
var
  W: Integer;
begin
  W := Round(MeasureU(Canvas, TXT_UI, SZ_BODY, '拍摄并进入考试')) + 16;
  Result := Rect(PAD_X + LAY_LW + LAY_GAP + LAY_RW - 20 - W,
    ClientHeight - 82, PAD_X + LAY_LW + LAY_GAP + LAY_RW - 20,
    ClientHeight - 46);
end;

function TMainForm.BtnSkipR: TRect;
var
  R: TRect;
  W: Integer;
begin
  R := BtnShootR;
  W := Round(MeasureU(Canvas, TXT_UI, SZ_BODY, '跳过拍照')) + 26;
  Result := Rect(R.Left - 8 - W, R.Top, R.Left - 8, R.Bottom);
end;

// 左卡底带右侧「重新检测」描边按钮
function TMainForm.BtnRecheckR: TRect;
var
  W: Integer;
begin
  W := Round(MeasureU(Canvas, TXT_UI, SZ_BODY, '重新检测')) + 28;
  Result := Rect(PAD_X + LAY_LW - 22 - W, ClientHeight - 82,
    PAD_X + LAY_LW - 22, ClientHeight - 46);
end;

// 内嵌视图: 顶部细条右侧退出按钮
function TMainForm.BtnExitR: TRect;
var
  W: Integer;
begin
  W := Round(MeasureU(Canvas, TXT_UI, SZ_SMALL, '退出演示')) + 26;
  Result := Rect(ClientWidth - 20 - W, 66, ClientWidth - 20, 92 - 8);
end;

// 内嵌视图: 桩卡片内按钮
function TMainForm.BtnWarnDemoR: TRect;
var
  CX, W, Top: Integer;
begin
  CX := ClientWidth div 2;
  Top := 251 + 222;
  W := Round(MeasureU(Canvas, TXT_UI, SZ_BODY, '演示切屏警告')) + 60;
  Result := Rect(CX - W div 2, Top, CX + W div 2, Top + 36);
end;

function TMainForm.WarnDialogR: TRect;
begin
  Result := Rect((ClientWidth - 440) div 2, (ClientHeight - 238) div 2,
    (ClientWidth + 440) div 2, (ClientHeight + 238) div 2);
end;

function TMainForm.WarnBtnOkR: TRect;
var
  D, W, B: Integer;
begin
  D := WarnDialogR;
  W := Round(MeasureU(Canvas, TXT_UI, SZ_BODY, '返回考试')) + 52;
  B := D.Bottom - 20;
  Result := Rect(D.Right - 26 - W, B - 36, D.Right - 26, B);
end;

function TMainForm.WarnBtnAppealR: TRect;
var
  D, W, R: Integer;
begin
  D := WarnDialogR;
  R := WarnBtnOkR;
  W := Round(MeasureU(Canvas, TXT_UI, SZ_BODY, '申诉')) + 52;
  Result := Rect(R.Left - 10 - W, R.Top, R.Left - 10, R.Bottom);
end;

// ---------------------------------------------------------------------------
// 绘制
// ---------------------------------------------------------------------------

procedure TMainForm.EnsureGradients;
begin
  EnsureGradient(FGradLight, ClientWidth, ClientHeight, 0);
end;

// 取景框渐变位图(尺寸未变则复用):
//   整块纵向三色渐变后, 用「全矩形 XOR 圆角矩形」的裁剪把四角挖成卡片白,
//   贴图后圆角自然成立, 不再有方形角泄漏。
procedure TMainForm.BuildGradCamRounded(AW, AH: Integer);
var
  Hr, Hc: HRGN;
  Save: Integer;
  HD: HDC;
begin
  if (FGradCam.Width = AW) and (FGradCam.Height = AH) then Exit;
  EnsureGradient(FGradCam, AW, AH, 1);
  HD := FGradCam.Canvas.Handle;
  Save := SaveDC(HD);
  Hr := CreateRectRgn(0, 0, AW, AH);
  Hc := CreateRoundRectRgn(0, 0, AW, AH, CAM_RAD * 2, CAM_RAD * 2);
  CombineRgn(Hr, Hr, Hc, RGN_XOR);   // 异或 = 四个角片(矩形减圆角矩形)
  SelectClipRgn(HD, Hr);
  FGradCam.Canvas.Brush.Color := ClrCard;
  FGradCam.Canvas.FillRect(Rect(0, 0, AW, AH));
  RestoreDC(HD, Save);
  DeleteObject(Hr);
  DeleteObject(Hc);
end;

procedure TMainForm.Paint;
var
  C: TCanvas;
begin
  inherited;
  C := Canvas;
  EnsureGradients;
  C.Draw(0, 0, FGradLight);           // 1) 内容区三色渐变底
  PaintHeader(C);                     // 2) 自绘标题栏
  if FPage = cpCheck then
    PaintPageCheck(C)
  else
    PaintPageWeb(C);
  if FShowWarn then
    PaintWarnModal(C);                // 4) 违规弹窗(最上层)
end;

procedure TMainForm.PaintHeader(C: TCanvas);
var
  R: TRect;
begin
  R := HeaderR;
  C.Brush.Color := ClrBarBg;
  C.FillRect(R);
  // 底部分隔线
  C.Pen.Color := ClrBarLine;
  C.MoveTo(0, HDR_H - 1);
  C.LineTo(ClientWidth, HDR_H - 1);
  // 品牌块
  R := Rect(20, 14, 50, 44);
  FillRoundCard(C, R, RAD_TILE, ClrPrimary);
  DrawU(C, R, 'J', ClrPrimaryFg, SZ_BRAND + 2, True);
  DrawU(C, Rect(58, 12, 260, 34), 'Jstudy 考试客户端', ClrFg, SZ_BRAND, True);
  DrawU(C, Rect(260, 12, 560, 34), '环境安全模式', ClrMuted, SZ_SMALL);
  // 窗口按钮
  R := BtnMinR;
  if FHot = HT_MIN then FillRoundCard(C, R, 8, ClrBorder);
  DrawGlyphU(C, R, GP_MINIMIZE, ClrMuted, 12);
  R := BtnCloseR;
  if FHot = HT_CLOSE then FillRoundCard(C, R, 8, ClrRedBg);
  DrawGlyphU(C, R, GP_CLOSE, ClrMuted, 12);
end;

procedure TMainForm.PaintPageCheck(C: TCanvas);
var
  Y, ColTop, ColBot, I: Integer;
  R, RC: TRect;
  BTxt: string;
begin
  // 标题
  Y := HDR_H + PAD_Y;
  DrawU(C, Rect(PAD_X, Y, PAD_X + 420, Y + 34), '考前环境检测', ClrFg, SZ_TITLE, True);
  DrawU(C, Rect(PAD_X, Y + 34, PAD_X + 700, Y + 56),
    '检测通过后将进入全屏考试模式, 期间将锁定桌面并监测切屏行为', ClrMuted, SZ_SUB);

  ColTop := 150;
  ColBot := ClientHeight - 26;

  // ---- 左卡: 摄像头 ----
  R := Rect(PAD_X, ColTop, PAD_X + LAY_LW, ColBot);
  FillRoundCard(C, R, RAD_CARD, ClrCard);
  DrawU(C, Rect(R.Left + 22, R.Top + 20, R.Left + 200, R.Top + 44),
    '摄像头', ClrFg, SZ_H4, True);
  // 取景框
  RC := Rect(R.Left + 22, R.Top + 52, R.Right - 22, R.Bottom - 56);
  PaintCameraBox(C, RC);
  // 卡底一行: 设备名(左) + 重新检测(右)
  DrawU(C, Rect(RC.Left, RC.Bottom + 9, RC.Right - 160, RC.Bottom + 27),
    'Camera 0 · Integrated Webcam', ClrMuted, SZ_SMALL);
  R := BtnRecheckR;
  if FHot = HT_RECHECK then FillRoundCard(C, R, RAD_BTN, ClrGhostHover)
  else FillRoundCard(C, R, RAD_BTN, ClrCard);
  C.Pen.Color := ClrBtnBorder;
  C.Brush.Style := bsClear;
  C.RoundRect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1, RAD_BTN * 2, RAD_BTN * 2);
  C.Brush.Style := bsSolid;
  DrawU(C, R, '重新检测', ClrGhostFg, SZ_BODY, True);

  // ---- 右卡: 检测清单 ----
  R := Rect(PAD_X + LAY_LW + LAY_GAP, ColTop, PAD_X + LAY_LW + LAY_GAP + LAY_RW, ColBot);
  FillRoundCard(C, R, RAD_CARD, ClrCard);
  DrawU(C, Rect(R.Left + 20, R.Top + 18, R.Left + 180, R.Top + 42),
    '检测项目', ClrFg, SZ_H4, True);

  for I := 0 to High(CHECKS) do begin
    RC := Rect(R.Left + 20, R.Top + 50 + I * 52, R.Right - 20, R.Top + 50 + I * 52 + 52);
    // 图标
    FillRoundCard(C, Rect(RC.Left, RC.Top + 12, RC.Left + 26, RC.Top + 38), 13, ClrGreenBg);
    DrawGlyphU(C, Rect(RC.Left, RC.Top + 12, RC.Left + 26, RC.Top + 38), GP_CHECK, ClrGreenFg, 13);
    // 名称/描述
    DrawU(C, Rect(RC.Left + 38, RC.Top + 7, RC.Right - 70, RC.Top + 29),
      CHECKS[I].Nm, ClrFg, 9.5);
    DrawU(C, Rect(RC.Left + 38, RC.Top + 28, RC.Right - 70, RC.Top + 46),
      CHECKS[I].Ds, ClrHint, SZ_SMALL);
    // 状态
    DrawU(C, Rect(RC.Right - 64, RC.Top, RC.Right, RC.Bottom),
      '通过', ClrGreenFg, SZ_SMALL, False, TXT_UI, taRightJustify);
    // 分隔线(最后一项省略)
    if I < High(CHECKS) then begin
      C.Pen.Color := ClrHairline;
      C.MoveTo(RC.Left, RC.Bottom);
      C.LineTo(RC.Right, RC.Bottom);
    end;
  end;

  // ---- 右卡底带: 摘要(两行小字) + 跳过/拍摄 ----
  DrawU(C, Rect(R.Left + 20, ColBot - 54, R.Left + 300, ColBot - 38),
    '共 4 项 ·', ClrHint, SZ_SMALL);
  DrawU(C, Rect(R.Left + 20, ColBot - 38, R.Left + 300, ColBot - 22),
    '全部通过', ClrHint, SZ_SMALL);

  // 拍摄(主) 按钮
  R := BtnShootR;
  if FShooting then BTxt := '拍摄中…' else BTxt := '拍摄并进入考试';
  if FHot = HT_SHOOT then
    FillRoundCard(C, R, RAD_BTN, ClrPrimaryHover)
  else
    FillRoundCard(C, R, RAD_BTN, ClrPrimary);
  DrawU(C, R, BTxt, ClrPrimaryFg, SZ_BODY, True);

  // 跳过(描边)按钮
  R := BtnSkipR;
  if FHot = HT_SKIP then FillRoundCard(C, R, RAD_BTN, ClrGhostHover)
  else FillRoundCard(C, R, RAD_BTN, ClrCard);
  C.Pen.Color := ClrBtnBorder;
  C.Brush.Style := bsClear;
  C.RoundRect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1, RAD_BTN * 2, RAD_BTN * 2);
  C.Brush.Style := bsSolid;
  DrawU(C, R, '跳过拍照', ClrGhostFg, SZ_BODY, True);
end;

procedure TMainForm.PaintPageWeb(C: TCanvas);
var
  R, RC: TRect;
  CX: Integer;
begin
  // ---- 顶部状态条 ----
  R := Rect(0, HDR_H, ClientWidth, HDR_H + 34);
  C.Brush.Color := ClrBarBg;
  C.FillRect(R);
  C.Pen.Color := ClrBarLine;
  C.MoveTo(0, R.Bottom - 1);
  C.LineTo(ClientWidth, R.Bottom - 1);
  // 绿点 + 状态文字
  C.Brush.Color := ClrGreenFg;
  C.Ellipse(28, R.Top + 13, 35, R.Top + 20);
  DrawU(C, Rect(44, R.Top, 560, R.Bottom),
    '考试安全模式运行中 · 防切屏监测已开启(桩)', ClrBody, SZ_SMALL);
  // 退出演示
  R := BtnExitR;
  if FHot = HT_EXIT then FillRoundCard(C, R, 6, ClrGhostHover);
  DrawU(C, R, '退出演示', ClrGhostFg, SZ_SMALL, False);

  // ---- 网页内容区(桩) ----
  C.Brush.Color := ClrCard;
  C.FillRect(Rect(0, HDR_H + 34, ClientWidth, ClientHeight));

  // 虚线桩卡片
  R := Rect((ClientWidth - 540) div 2, 251, (ClientWidth + 540) div 2, 561);
  C.Pen.Style := psDash;
  C.Pen.Color := ClrBorder;
  C.Pen.Width := 1;
  C.Brush.Color := ClrCard;
  C.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 32, 32);
  C.Pen.Style := psSolid;

  CX := ClientWidth div 2;
  // 品牌块
  RC := Rect(CX - 28, 251 + 48, CX + 28, 251 + 104);
  FillRoundCard(C, RC, 12, ClrPrimary);
  DrawU(C, RC, 'J', ClrPrimaryFg, 18, True);

  // 标题
  DrawU(C, Rect(CX - 300, 251 + 122, CX + 300, 251 + 150),
    '内嵌考试系统加载区', ClrFg, 11, True, TXT_UI, taCenter);
  // 说明两行
  DrawU(C, Rect(CX - 300, 251 + 156, CX + 300, 251 + 176),
    '生产环境将由 CEF / WebView2 整页加载考试系统', ClrMuted, SZ_SMALL, False, TXT_UI, taCenter);
  DrawU(C, Rect(CX - 300, 251 + 176, CX + 300, 251 + 196),
    'http://192.168.10.41:3000/#/exams', ClrHint, SZ_SMALL, False, TXT_UI, taCenter);

  // 演示按钮
  R := BtnWarnDemoR;
  if FHot = HT_WARN_DEMO then FillRoundCard(C, R, RAD_BTN, ClrGhostHover);
  C.Brush.Style := bsClear;
  FillRoundCard(C, R, RAD_BTN, ClrCard);
  // 描边按钮: 先填白再描边
  FillRoundCard(C, Rect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1), RAD_BTN, ClrCard);
  DrawU(C, R, '演示切屏警告', ClrGhostFg, SZ_BODY, True);

  // 桩角标
  DrawU(C, Rect(CX - 300, 561 - 28, CX + 300, 561 - 10),
    '调研桩版本 — 内嵌区为占位, 真实渲染由浏览器组件提供', ClrHint, SZ_SMALL, False, TXT_UI, taCenter);
end;

procedure TMainForm.PaintCameraBox(C: TCanvas; const R: TRect);
var
  CR, TR: TRect;
  CX, GTop, W: Integer;
begin
  // 深色纵向三色渐变(圆角位图缓存, 贴图即圆角)
  BuildGradCamRounded(R.Width, R.Height);
  C.Draw(R.Left, R.Top, FGradCam);

  // 内侧 1px 高光描边(网页 inset 0 0 0 1px rgba(255,255,255,.12) 的近似色)
  C.Pen.Color := RgbT(52, 64, 86);
  C.Brush.Style := bsClear;
  C.RoundRect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1,
    (CAM_RAD - 1) * 2, (CAM_RAD - 1) * 2);
  C.Brush.Style := bsSolid;

  // REC 胶囊(全圆角, 深底近似 rgba(2,8,23,.55))
  W := Round(MeasureU(C, TXT_UI, SZ_SMALL, 'REC · 摄像头检测')) + 44;
  CR := Rect(R.Left + 14, R.Top + 12, R.Left + 14 + W, R.Top + 36);
  FillRoundCard(C, CR, 999, RgbT(9, 16, 30));
  C.Brush.Color := RgbT(239, 68, 68);          // #EF4444 录制点
  C.Ellipse(CR.Left + 10, CR.Top + 8, CR.Left + 18, CR.Top + 16);
  DrawU(C, Rect(CR.Left + 24, CR.Top, CR.Right - 10, CR.Bottom),
    'REC · 摄像头检测', ClrPrimaryFg, SZ_SMALL);

  // 中央人脸示意(桩): 人物图标 + 提示(与网页 .cam-face 对应)
  CX := R.Left + R.Width div 2;
  GTop := R.Top + (R.Height - 176) div 2;      // 组高 ≈ 图标 150 + 8 + 提示 18
  DrawGlyphU(C, Rect(CX - 75, GTop, CX + 75, GTop + 150), GP_PEOPLE, ClrMuted, 122);
  TR := Rect(CX - 300, GTop + 158, CX + 300, GTop + 176);
  DrawU(C, TR, FCamHint, ClrHint, SZ_SMALL, False, TXT_UI, taCenter);
end;

procedure TMainForm.PaintWarnModal(C: TCanvas);
var
  D, R, T: TRect;
  S: string;
  W: Integer;
  CX: Integer;
begin
  // 遮罩(整窗)
  C.Brush.Color := ClrScrim;
  C.FillRect(ClientRect);
  // 对话框
  D := WarnDialogR;
  FillRoundCard(C, D, 12, ClrCard);
  // 头部
  R := Rect(D.Left + 26, D.Top + 24, D.Left + 60, D.Top + 58);
  FillRoundCard(C, R, 10, ClrRedBg);
  CX := R.Left + R.Width div 2;
  C.Brush.Color := RgbT(220, 38, 38);
  C.Pen.Color := RgbT(220, 38, 38);
  C.Polygon([
    Point(CX - 8, R.Top + 8),
    Point(CX + 8, R.Top + 8),
    Point(CX, R.Bottom - 6)
  ]);
  DrawU(C, R, '!', clWhite, SZ_SMALL + 1, True);
  // 标题
  DrawU(C, Rect(D.Left + 72, D.Top + 22, D.Right - 26, D.Top + 46),
    '检测到离开考试窗口', ClrFg, SZ_H4, True);
  DrawU(C, Rect(D.Left + 72, D.Top + 44, D.Right - 26, D.Top + 62),
    '09-07 14:32:08 · 窗口失去焦点', ClrHint, SZ_SMALL);
  // 正文
  DrawU(C, Rect(D.Left + 26, D.Top + 86, D.Right - 26, D.Top + 110),
    '您已切换至其他窗口/程序, 该行为已被记录。', ClrBody, SZ_BODY);
  // 混合色第二行: 累计 <1 / 3> 次, ...
  T := Rect(D.Left + 26, D.Top + 112, D.Right - 26, D.Top + 134);
  S := '累计 ';
  DrawU(C, T, S, ClrBody, SZ_BODY);
  W := Round(MeasureU(C, TXT_UI, SZ_BODY, S));
  T.Left := T.Left + W;
  S := '1 / 3';
  DrawU(C, T, S, ClrAmberFg, SZ_BODY, True);
  W := Round(MeasureU(C, TXT_UI, SZ_BODY, S));
  T.Left := T.Left + W;
  DrawU(C, T, ' 次, 超过 3 次将自动交卷, 请立即返回考试。', ClrBody, SZ_BODY);
  // 底部按钮
  R := WarnBtnOkR;
  if FHot = HT_WARN_OK then
    FillRoundCard(C, R, RAD_BTN, ClrPrimaryHover)
  else
    FillRoundCard(C, R, RAD_BTN, ClrPrimary);
  DrawU(C, R, '返回考试', ClrPrimaryFg, SZ_BODY, True);
  R := WarnBtnAppealR;
  if FHot = HT_WARN_APPEAL then FillRoundCard(C, R, RAD_BTN, ClrGhostHover);
  FillRoundCard(C, R, RAD_BTN, ClrCard);
  // 描边按钮重绘: 填充后描边会吃掉内侧 1px, 直接描边外圈
  C.Pen.Color := ClrBtnBorder;
  C.Brush.Style := bsClear;
  C.RoundRect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1, 16, 16);
  C.Brush.Style := bsSolid;
  DrawU(C, R, '申诉', ClrGhostFg, SZ_BODY, True);
end;

// ---------------------------------------------------------------------------
// 动作
// ---------------------------------------------------------------------------

procedure TMainForm.DoShoot;
begin
  if FShooting then Exit;
  FShooting := True;
  FShootTimer.Enabled := True;
  Invalidate;
end;

procedure TMainForm.TimerShoot(Sender: TObject);
begin
  FShootTimer.Enabled := False;
  FShooting := False;
  DoEnterWeb;
end;

procedure TMainForm.DoEnterWeb;
begin
  FPage := cpWeb;
  FShowWarn := False;
  FHot := HT_NONE;
  Invalidate;
end;

procedure TMainForm.DoExitWeb;
begin
  FPage := cpCheck;
  FShowWarn := False;
  FHot := HT_NONE;
  Invalidate;
end;

procedure TMainForm.UpdateHover(X, Y: Integer);
var
  H: Integer;
begin
  H := HT_NONE;
  if FShowWarn then begin
    // 弹窗层拦截(窗口按钮仍可用)
    if PtIn(BtnCloseR, X, Y) then H := HT_CLOSE
    else if PtIn(BtnMinR, X, Y) then H := HT_MIN
    else if PtIn(WarnBtnOkR, X, Y) then H := HT_WARN_OK
    else if PtIn(WarnBtnAppealR, X, Y) then H := HT_WARN_APPEAL;
  end else if FPage = cpCheck then begin
    if PtIn(BtnCloseR, X, Y) then H := HT_CLOSE
    else if PtIn(BtnMinR, X, Y) then H := HT_MIN
    else if PtIn(BtnShootR, X, Y) then H := HT_SHOOT
    else if PtIn(BtnSkipR, X, Y) then H := HT_SKIP
    else if PtIn(BtnRecheckR, X, Y) then H := HT_RECHECK;
  end else begin
    if PtIn(BtnCloseR, X, Y) then H := HT_CLOSE
    else if PtIn(BtnMinR, X, Y) then H := HT_MIN
    else if PtIn(BtnExitR, X, Y) then H := HT_EXIT
    else if PtIn(BtnWarnDemoR, X, Y) then H := HT_WARN_DEMO;
  end;

  if H <> FHot then begin
    FHot := H;
    Cursor := crDefault;
    if H <> HT_NONE then Cursor := crHandPoint;
    Invalidate;
  end;

  if not FTracked then begin
    // 注册鼠标离开跟踪(只有离开时鼠标事件才会恢复)
    var TME: TRACKMOUSEEVENT;
    TME.cbSize := SizeOf(TRACKMOUSEEVENT);
    TME.dwFlags := TME_LEAVE;
    TME.hwndTrack := Handle;
    TME.dwHoverTime := 0;
    TrackMouseEvent(TME);
    FTracked := True;
  end;
end;

procedure TMainForm.DoClick(X, Y: Integer);
begin
  case FHot of
    HT_CLOSE: Close;
    HT_MIN: Perform(WM_SYSCOMMAND, SC_MINIMIZE, 0);
    HT_SHOOT: DoShoot;
    HT_SKIP: DoEnterWeb;
    HT_RECHECK: begin
      // 桩: 仅重置提示文案(真实实现为重新打开摄像头并自检)
      FCamHint := '画面已重置, 请再次检测';
      Invalidate;
    end;
    HT_EXIT: DoExitWeb;
    HT_WARN_DEMO: begin
      FShowWarn := True;
      FHot := HT_NONE;
      Invalidate;
    end;
    HT_WARN_OK, HT_WARN_APPEAL: begin
      FShowWarn := False;
      FHot := HT_NONE;
      Invalidate;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// 事件
// ---------------------------------------------------------------------------

procedure TMainForm.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  UpdateHover(X, Y);
end;

procedure TMainForm.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then begin
    UpdateHover(X, Y);
    DoClick(X, Y);
  end;
end;

procedure TMainForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and FShowWarn then begin
    FShowWarn := False;
    FHot := HT_NONE;
    Invalidate;
  end else
    inherited;
end;

procedure TMainForm.WMMouseLeave(var Message: TMessage);
begin
  inherited;
  FTracked := False;
  if FHot <> HT_NONE then begin
    FHot := HT_NONE;
    Cursor := crDefault;
    Invalidate;
  end;
end;

procedure TMainForm.WMNCHitTest(var Message: TWMNCHitTest);
var
  P: TPoint;
begin
  inherited;
  // 顶部自绘标题栏(排除窗口按钮区) -> 交给系统拖拽(含双击标题栏逻辑)
  P := ScreenToClient(Point(Message.XPos, Message.YPos));
  if (P.Y < HDR_H) and (P.X < ClientWidth - 106) then
    Message.Result := HTCAPTION;
end;

end.
