program DelphiCCFlags;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  uMMDBInfo in 'uMMDBInfo.pas',
  uMMDBIPAddress in 'uMMDBIPAddress.pas',
  uMMDBReader in 'uMMDBReader.pas',
  IPTypesX in 'IPTypesX.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Carbon');
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
