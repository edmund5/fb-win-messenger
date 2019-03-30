program Messenger;

uses
  Vcl.Forms,
  MainUnit in 'MainUnit.pas' {Form1},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Light');
  Application.Title := 'Messenger for Windows';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
