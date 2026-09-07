program JstudyClientSpike;

// ============================================================================
//  Jstudy 考试客户端 - 界面 Spike (纯 Delphi VCL, 无第三方依赖)
//  编译: Windows + Delphi 10.3+ (Community 版可用)
//  运行: 考前检测页 -> 拍摄(桩, 900ms)/跳过 -> 内嵌考试系统视图(桩) -> 演示违规弹窗
// ============================================================================

uses
  Vcl.Forms,
  uPainting in 'uPainting.pas',
  uTheme in 'uTheme.pas',
  uMainForm in 'uMainForm.pas';

var
  FMain: TMainForm;

begin
  Application.Initialize;
  Application.Title := 'Jstudy 考试客户端 - UI Spike';
  Application.MainFormOnTaskbar := True;
  FMain := TMainForm.CreateNew(Application);
  FMain.Show;
  Application.Run;
end.
