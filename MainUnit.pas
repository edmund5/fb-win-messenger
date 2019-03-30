unit MainUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  cefvcl, ceflib, Vcl.Menus, Winapi.ShellApi, Registry, System.UITypes,
  WinInet, Vcl.ExtCtrls, Vcl.Imaging.pngimage, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdAntiFreezeBase, Vcl.IdAntiFreeze;

const
  WM_ICONTRAY = WM_USER + 1;

type
  TForm1 = class(TForm)
    Chromium1: TChromium;
    PopupMenu1: TPopupMenu;
    OpenMessenger1: TMenuItem;
    N1: TMenuItem;
    RunMessengeronWindowsStartup1: TMenuItem;
    Yes1: TMenuItem;
    No1: TMenuItem;
    N2: TMenuItem;
    AboutMessenger1: TMenuItem;
    N3: TMenuItem;
    Exit1: TMenuItem;
    ReloadMessenger1: TMenuItem;
    Timer1: TTimer;
    IdTCPClient1: TIdTCPClient;
    IdAntiFreeze1: TIdAntiFreeze;
    Image1: TImage;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure OpenMessenger1Click(Sender: TObject);
    procedure ReloadMessenger1Click(Sender: TObject);
    procedure Yes1Click(Sender: TObject);
    procedure No1Click(Sender: TObject);
    procedure AboutMessenger1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
  private
    { Private declarations }
    OrgWndProc: pointer;
    NewWndProc: pointer;
    TrayIconData: TNotifyIconData;
    procedure WMSize(var Msg: TMessage); message WM_SIZE;
    procedure WndProc(var message: TMessage);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

function IsConnectedToInternet: Boolean;
begin
  Result := False;
  try
    Form1.IdTCPClient1.ReadTimeout := 5000;
    Form1.IdTCPClient1.ConnectTimeout := 5000;
    Form1.IdTCPClient1.Port := 80;
    Form1.IdTCPClient1.Host := 'messenger.com';
    Form1.IdTCPClient1.Connect;
    Form1.IdTCPClient1.Disconnect;
    Result := True;
  except
    Result := False;
  end;
end;

procedure SetAutoStart(AppName, AppTitle: string; bRegister: Boolean);
const
  RegKey = '\Software\Microsoft\Windows\CurrentVersion\Run';
  // or: RegKey = '\Software\Microsoft\Windows\CurrentVersion\RunOnce';
var
  Registry: TRegistry;
begin
  Registry := TRegistry.Create;
  try
    Registry.RootKey := HKEY_LOCAL_MACHINE;
    if Registry.OpenKey(RegKey, False) then
    begin
      if bRegister = False then
        Registry.DeleteValue(AppTitle)
      else
        Registry.WriteString(AppTitle, AppName);
    end;
  finally
    Registry.Free;
  end;
end;

procedure TForm1.WMSize(var Msg: TMessage);
begin
  if Msg.WParam = SIZE_MINIMIZED then
  begin
    Hide();

    with TrayIconData do
    begin
      StrPLCopy(TrayIconData.szInfoTitle, 'Messenger is running', 20);
      StrPLCopy(TrayIconData.szInfo, 'Click here to open messenger.', 29);
      dwInfoFlags := 1;
      uTimeout := 1000;
      uFlags := NIF_INFO;
    end;

    // Show the balloon
    Shell_NotifyIcon(NIM_MODIFY, @TrayIconData);
  end;
end;

procedure TForm1.WndProc(var message: TMessage);
var
  tmpPoint: Tpoint;
begin
  if Message.Msg = WM_ICONTRAY then
  begin
    case Message.LParam of
      WM_LBUTTONDOWN:
        begin
          GetCursorPos(tmpPoint);
          SetForegroundWindow(Handle);
          OpenMessenger1Click(Self);
          PostMessage(Handle, WM_NULL, 0, 0);
        end;
      WM_RBUTTONDOWN:
        if Assigned(PopupMenu1) then
        begin
          GetCursorPos(tmpPoint);
          SetForegroundWindow(Handle);
          PopupMenu1.Popup(tmpPoint.X, tmpPoint.Y);
          PostMessage(Handle, WM_NULL, 0, 0);
        end;
    else
      Message.Result := CallWindowProc(OrgWndProc, Handle, Message.Msg,
        Message.WParam, Message.LParam);
    end;
  end
  else
    Message.Result := CallWindowProc(OrgWndProc, Handle, Message.Msg,
      Message.WParam, Message.LParam);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  LInstance: pointer;
  reg: TRegistry;
  bRunOnce: string;
begin
  Form1.Caption := 'Messenger for Windows';

  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.OpenKey('Software\Messenger for Windows\', True);
    bRunOnce := reg.ReadString('bRunOnce');
  finally
    reg.Free
  end;

  if bRunOnce = 'Yes' then
  begin
    Yes1.Checked := True;
    No1.Checked := False;
  end
  else if bRunOnce = 'No' then
  begin
    Yes1.Checked := False;
    No1.Checked := True;
  end;

  // get the current WndProc
  OrgWndProc := pointer(GetWindowLong(Handle, GWL_WNDPROC));

  // Convert the class method to a Pointer
  LInstance := MakeObjectInstance(WndProc);

  // set the new WndProc
  NewWndProc := pointer(SetWindowLong(Handle, GWL_WNDPROC, IntPtr(LInstance)));

  with TrayIconData do
  begin
    uID := 1;
    Wnd := Handle;
    cbSize := SizeOf;
    hIcon := GetClassLong(Application.Handle, GCL_HICONSM);
    uCallbackMessage := WM_ICONTRAY;
    uFlags := NIF_TIP + NIF_MESSAGE + NIF_ICON;
    // Take the icon of the application window
    StrPCopy(szTip, 'Messenger');
  end;

  // Create the icon
  Shell_NotifyIcon(NIM_ADD, @TrayIconData);

  if not DirectoryExists('CefCache') then
  begin
    CreateDir('CefCache');
  end;

  Chromium1.browser.MainFrame.LoadUrl('https://www.messenger.com/login');
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  Msg: string;
begin
  Msg := 'Do you really want to close?';

  if MessageDlg(Msg, mtConfirmation, [mbYes, mbNo], 0) = mrNo then

    CanClose := False;

  Hide();

  with TrayIconData do
  begin
    StrPLCopy(TrayIconData.szInfoTitle, 'Messenger is still running', 26);
    StrPLCopy(TrayIconData.szInfo, 'Click here to open messenger.', 29);
    dwInfoFlags := 1;
    uTimeout := 1000;
    uFlags := NIF_INFO;
  end;

  // Show the balloon
  Shell_NotifyIcon(NIM_MODIFY, @TrayIconData);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  // Delete the icon
  Shell_NotifyIcon(NIM_DELETE, @TrayIconData);
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  if IsConnectedToInternet = True then
  begin
    Chromium1.Visible := True;
    Image1.Visible := False;
  end
  else if IsConnectedToInternet = False then
  begin
    Chromium1.Visible := False;
    Image1.Visible := True;
  end;
end;

procedure TForm1.OpenMessenger1Click(Sender: TObject);
begin
  Show();
  WindowState := wsNormal;
end;

procedure TForm1.ReloadMessenger1Click(Sender: TObject);
begin
  Chromium1.browser.MainFrame.LoadUrl('https://www.messenger.com/login');
end;

procedure TForm1.Yes1Click(Sender: TObject);
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.OpenKey('Software\Messenger for Windows\', True);
    reg.WriteString('bRunOnce', 'Yes');
  finally
    reg.Free
  end;

  Yes1.Checked := True;
  No1.Checked := False;

  SetAutoStart(ExtractFilePath(Application.ExeName) + 'Messenger.exe',
    'Messenger for Windows', True);
end;

procedure TForm1.No1Click(Sender: TObject);
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.OpenKey('Software\Messenger for Windows\', True);
    reg.WriteString('bRunOnce', 'No');
  finally
    reg.Free
  end;

  Yes1.Checked := False;
  No1.Checked := True;

  SetAutoStart(ExtractFilePath(Application.ExeName) + 'Messenger.exe',
    'Messenger for Windows', False);
end;

procedure TForm1.AboutMessenger1Click(Sender: TObject);
begin
  ShellExecute(0, 'OPEN', PChar('http://fbwinmessenger.herokuapp.com'), '', '',
    SW_SHOWNORMAL);
end;

procedure TForm1.Exit1Click(Sender: TObject);
begin
  Application.Terminate;
end;

initialization

CefCache := ExtractFilePath(Application.ExeName) + 'CefCache';

end.
