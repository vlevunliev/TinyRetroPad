program trpad;
{ ---------------------------------------------------------
  TinyRetroPad 2.0 - Pascal port of Dave Plummer's trpad.asm
  (Dave's Tiny Editor / Tiny App lineage, Apache 2.0)
  Pure Win32 API, no LCL, no external units beyond RTL.
  fpc -Twin64 -WG trpad.pas   (или -Twin32)

  2.0 "tuned":
   * изцяло Unicode (W API) - кирилица, UTF-8, UTF-16, ANSI
   * разпознаване на кодировка и край на ред, запис в същия формат
   * Encoding меню, предупреждение при загуба на символи в ANSI
   * drag & drop, zoom, истински status bar, печат с полета
   * Find нагоре / цяла дума / wrap-around, Replace All с брояч
   * настройки в HKCU\Software\TinyRetroPad
   * манифест: visual styles + DPI awareness (trpad_res.res)
  2.1 екстри:
   * проверка на правописа (Windows 8+), брояч на думи и знаци
   * UPPER / lower / Title Case, транслитерация кирилица <-> латиница
   * последни файлове, предупреждение при външна промяна на файла
   * сортиране / дубликати / trim на редове, колонтитули при печат
   * четене на глас (SAPI), autosave и възстановяване след срив
  2.2: избор на глас и скорост; ползва и OneCore гласовете от Settings
       (вкл. българския), без registry трикове
  2.3: поправка на грешна подредба (Ctrl+Shift+K), калкулатор в текста (F9),
       auto-indent
  2.4: при четене на глас текущата дума се маркира (караоке)
  2.5: помни докъде е стигнало четенето - за всеки файл, и след рестарт
  2.6: Ctrl+Enter изпълнява текущия ред като команда, изходът идва отдолу
  2.6.1: cmd /u - вградените команди на cmd вече не губят кирилица ("г." в dir)
  2.7: планер - ред "@ утре 09:00 ..." + Ctrl+Enter = задача в Task Scheduler
  --------------------------------------------------------- }
{$mode objfpc}{$H+}
{$APPTYPE GUI}
{$R trpad_res.res}                 // манифест (виж trpad_res.rc)

{ =====================  FEATURE MENU  =====================
  Сложи интервал след отварящата скоба, за да изключиш екстра
  (еквивалент на FEAT_* switch-овете в asm-а).           }
{$DEFINE FEAT_LINENUMBERS}
{$DEFINE FEAT_DARKMODE}
{ ========================================================== }

uses
  Windows;

{ ---- shell32 / comctl32 / user32 / advapi32 ---- }
function ShellExecuteW(hWnd: HWND; lpOperation, lpFile, lpParameters,
  lpDirectory: PWideChar; nShowCmd: LongInt): HINST; stdcall;
  external 'shell32.dll' name 'ShellExecuteW';
procedure DragAcceptFiles(hWnd: HWND; fAccept: BOOL); stdcall;
  external 'shell32.dll' name 'DragAcceptFiles';
function DragQueryFileW(hDrop: THandle; iFile: UINT; lpszFile: PWideChar;
  cch: UINT): UINT; stdcall; external 'shell32.dll' name 'DragQueryFileW';
procedure DragFinish(hDrop: THandle); stdcall;
  external 'shell32.dll' name 'DragFinish';
procedure InitCommonControls; stdcall;
  external 'comctl32.dll' name 'InitCommonControls';
function IsCharAlphaNumericW(ch: WideChar): BOOL; stdcall;
  external 'user32.dll' name 'IsCharAlphaNumericW';
function IsCharAlphaW(ch: WideChar): BOOL; stdcall;
  external 'user32.dll' name 'IsCharAlphaW';
function CharUpperBuffW(lpsz: PWideChar; cch: DWORD): DWORD; stdcall;
  external 'user32.dll' name 'CharUpperBuffW';
function CharLowerBuffW(lpsz: PWideChar; cch: DWORD): DWORD; stdcall;
  external 'user32.dll' name 'CharLowerBuffW';
function lstrcmpiW(a, b: PWideChar): LongInt; stdcall;
  external 'kernel32.dll' name 'lstrcmpiW';
function GetFullPathNameW(lpFileName: PWideChar; nBufferLength: DWORD;
  lpBuffer: PWideChar; lpFilePart: Pointer): DWORD; stdcall;
  external 'kernel32.dll' name 'GetFullPathNameW';
function GetFileAttributesExW(lpFileName: PWideChar; fInfoLevelId: LongInt;
  lpFileInformation: Pointer): BOOL; stdcall;
  external 'kernel32.dll' name 'GetFileAttributesExW';
function VkKeyScanExW(ch: WideChar; dwhkl: HKL): SmallInt; stdcall;
  external 'user32.dll' name 'VkKeyScanExW';
function ToUnicodeEx(wVirtKey, wScanCode: UINT; lpKeyState: PByte;
  pwszBuff: PWideChar; cchBuff: LongInt; wFlags: UINT; dwhkl: HKL): LongInt;
  stdcall; external 'user32.dll' name 'ToUnicodeEx';
function MapVirtualKeyExW(uCode, uMapType: UINT; dwhkl: HKL): UINT; stdcall;
  external 'user32.dll' name 'MapVirtualKeyExW';
function GetKeyboardLayoutList(nBuff: LongInt; lpList: Pointer): LongInt; stdcall;
  external 'user32.dll' name 'GetKeyboardLayoutList';
function GetKeyboardLayout(idThread: DWORD): HKL; stdcall;
  external 'user32.dll' name 'GetKeyboardLayout';
function ActivateKeyboardLayout(h: HKL; Flags: UINT): HKL; stdcall;
  external 'user32.dll' name 'ActivateKeyboardLayout';
function LoadKeyboardLayoutW(pwszKLID: PWideChar; Flags: UINT): HKL; stdcall;
  external 'user32.dll' name 'LoadKeyboardLayoutW';
function CreateJobObjectW(lpJobAttributes: Pointer; lpName: PWideChar): THandle; stdcall;
  external 'kernel32.dll' name 'CreateJobObjectW';
function AssignProcessToJobObject(hJob, hProcess: THandle): BOOL; stdcall;
  external 'kernel32.dll' name 'AssignProcessToJobObject';
function TerminateJobObject(hJob: THandle; uExitCode: UINT): BOOL; stdcall;
  external 'kernel32.dll' name 'TerminateJobObject';
function SetHandleInformation(hObject: THandle; dwMask, dwFlags: DWORD): BOOL; stdcall;
  external 'kernel32.dll' name 'SetHandleInformation';
function SystemTimeToFileTime(lpSystemTime: PSystemTime; lpFileTime: PFileTime): BOOL; stdcall;
  external 'kernel32.dll' name 'SystemTimeToFileTime';
function FileTimeToSystemTime(lpFileTime: PFileTime; lpSystemTime: PSystemTime): BOOL; stdcall;
  external 'kernel32.dll' name 'FileTimeToSystemTime';
function SearchPathW(lpPath, lpFileName, lpExtension: PWideChar; nBufferLength: DWORD;
  lpBuffer: PWideChar; lpFilePart: Pointer): DWORD; stdcall;
  external 'kernel32.dll' name 'SearchPathW';
function CoInitialize(pvReserved: Pointer): HRESULT; stdcall;
  external 'ole32.dll' name 'CoInitialize';
function CoCreateInstance(constref rclsid: TGUID; pUnkOuter: Pointer;
  dwClsContext: DWORD; constref riid: TGUID; out ppv): HRESULT; stdcall;
  external 'ole32.dll' name 'CoCreateInstance';

type
  TAccelEntry = record
    fVirt: Byte;
    key: Word;
    cmd: Word;
  end;

function CreateAcceleratorTableW(lpaccl: Pointer; cEntries: LongInt): HACCEL;
  stdcall; external 'user32.dll' name 'CreateAcceleratorTableW';
function TranslateAcceleratorW(hWnd: HWND; hAccTable: HACCEL;
  lpMsg: Pointer): LongInt; stdcall; external 'user32.dll' name 'TranslateAcceleratorW';
function DestroyAcceleratorTable(gAccel: HACCEL): BOOL; stdcall;
  external 'user32.dll' name 'DestroyAcceleratorTable';
function CheckMenuRadioItem(hMenu: HMENU; first, last, check, flags: UINT): BOOL;
  stdcall; external 'user32.dll' name 'CheckMenuRadioItem';
function MonitorFromRect(lprc: PRect; dwFlags: DWORD): THandle; stdcall;
  external 'user32.dll' name 'MonitorFromRect';
function DialogBoxIndirectParamW(hInst: HINST; lpTemplate: Pointer;
  hWndParent: HWND; lpDialogFunc: Pointer; dwInitParam: LPARAM): PtrInt;
  stdcall; external 'user32.dll' name 'DialogBoxIndirectParamW';

function RegCreateKeyExW(hKey: HKEY; lpSubKey: PWideChar; Reserved: DWORD;
  lpClass: PWideChar; dwOptions, samDesired: DWORD; lpSecAttr: Pointer;
  out phkResult: HKEY; lpdwDisposition: PDWORD): LONG; stdcall;
  external 'advapi32.dll' name 'RegCreateKeyExW';
function RegOpenKeyExW(hKey: HKEY; lpSubKey: PWideChar; ulOptions,
  samDesired: DWORD; out phkResult: HKEY): LONG; stdcall;
  external 'advapi32.dll' name 'RegOpenKeyExW';
function RegQueryValueExW(hKey: HKEY; lpValueName: PWideChar; lpReserved: Pointer;
  lpType: PDWORD; lpData: Pointer; lpcbData: PDWORD): LONG; stdcall;
  external 'advapi32.dll' name 'RegQueryValueExW';
function RegSetValueExW(hKey: HKEY; lpValueName: PWideChar; Reserved,
  dwType: DWORD; lpData: Pointer; cbData: DWORD): LONG; stdcall;
  external 'advapi32.dll' name 'RegSetValueExW';
function RegEnumKeyExW(hKey: HKEY; dwIndex: DWORD; lpName: PWideChar;
  lpcchName: PDWORD; lpReserved: Pointer; lpClass: PWideChar; lpcchClass: PDWORD;
  lpftLastWriteTime: Pointer): LONG; stdcall;
  external 'advapi32.dll' name 'RegEnumKeyExW';
function RegDeleteValueW(hKey: HKEY; lpValueName: PWideChar): LONG; stdcall;
  external 'advapi32.dll' name 'RegDeleteValueW';
function RegCloseKey(hKey: HKEY): LONG; stdcall;
  external 'advapi32.dll' name 'RegCloseKey';

{ ---- commdlg: липсва в FPC Windows unit-а, декларираме си го ----
  ВАЖНО: commdlg.h е #pragma pack(1) на Win32 (на Win64 - естествено
  подравняване). Без това PRINTDLG е 68 вместо 66 байта и PrintDlg
  отказва на 32 бита. }
{$IFDEF CPU32}{$PACKRECORDS 1}{$ENDIF}
type
  TOpenFilenameW = record
    lStructSize: DWORD;
    hwndOwner: HWND;
    hInstance: HINST;
    lpstrFilter: PWideChar;
    lpstrCustomFilter: PWideChar;
    nMaxCustFilter: DWORD;
    nFilterIndex: DWORD;
    lpstrFile: PWideChar;
    nMaxFile: DWORD;
    lpstrFileTitle: PWideChar;
    nMaxFileTitle: DWORD;
    lpstrInitialDir: PWideChar;
    lpstrTitle: PWideChar;
    Flags: DWORD;
    nFileOffset: Word;
    nFileExtension: Word;
    lpstrDefExt: PWideChar;
    lCustData: LPARAM;
    lpfnHook: Pointer;
    lpTemplateName: PWideChar;
    pvReserved: Pointer;
    dwReserved: DWORD;
    FlagsEx: DWORD;
  end;

  TChooseFontW = record
    lStructSize: DWORD;
    hwndOwner: HWND;
    hDC: HDC;
    lpLogFont: Pointer;               // ^LOGFONTW
    iPointSize: LongInt;
    Flags: DWORD;
    rgbColors: COLORREF;
    lCustData: LPARAM;
    lpfnHook: Pointer;
    lpTemplateName: PWideChar;
    hInstance: HINST;
    lpszStyle: PWideChar;
    nFontType: Word;
    wPad: Word;                       // ___MISSING_ALIGNMENT__
    nSizeMin: LongInt;
    nSizeMax: LongInt;
  end;

  TFindReplaceW = record
    lStructSize: DWORD;
    hwndOwner: HWND;
    hInstance: HINST;
    Flags: DWORD;
    lpstrFindWhat: PWideChar;
    lpstrReplaceWith: PWideChar;
    wFindWhatLen: Word;
    wReplaceWithLen: Word;
    lCustData: LPARAM;
    lpfnHook: Pointer;
    lpTemplateName: PWideChar;
  end;

  TPrintDlgW = record
    lStructSize: DWORD;
    hwndOwner: HWND;
    hDevMode: HGLOBAL;
    hDevNames: HGLOBAL;
    hDC: HDC;
    Flags: DWORD;
    nFromPage: Word;
    nToPage: Word;
    nMinPage: Word;
    nMaxPage: Word;
    nCopies: Word;
    hInstance: HINST;
    lCustData: LPARAM;
    lpfnPrintHook: Pointer;
    lpfnSetupHook: Pointer;
    lpPrintTemplateName: PWideChar;
    lpSetupTemplateName: PWideChar;
    hPrintTemplate: HGLOBAL;
    hSetupTemplate: HGLOBAL;
  end;

  TPageSetupDlgW = record
    lStructSize: DWORD;
    hwndOwner: HWND;
    hDevMode: HGLOBAL;
    hDevNames: HGLOBAL;
    Flags: DWORD;
    ptPaperSize: TPoint;
    rtMinMargin: TRect;
    rtMargin: TRect;
    hInstance: HINST;
    lCustData: LPARAM;
    lpfnPageSetupHook: Pointer;
    lpfnPagePaintHook: Pointer;
    lpPageSetupTemplateName: PWideChar;
    hPageSetupTemplate: HGLOBAL;
  end;
{$PACKRECORDS DEFAULT}

function GetOpenFileNameW(lpofn: Pointer): BOOL; stdcall;
  external 'comdlg32.dll' name 'GetOpenFileNameW';
function GetSaveFileNameW(lpofn: Pointer): BOOL; stdcall;
  external 'comdlg32.dll' name 'GetSaveFileNameW';
function ChooseFontW(lpcf: Pointer): BOOL; stdcall;
  external 'comdlg32.dll' name 'ChooseFontW';
function FindTextW(lpfr: Pointer): HWND; stdcall;
  external 'comdlg32.dll' name 'FindTextW';
function ReplaceTextW(lpfr: Pointer): HWND; stdcall;
  external 'comdlg32.dll' name 'ReplaceTextW';
function PrintDlgW(lppd: Pointer): BOOL; stdcall;
  external 'comdlg32.dll' name 'PrintDlgW';
function PageSetupDlgW(lppsd: Pointer): BOOL; stdcall;
  external 'comdlg32.dll' name 'PageSetupDlgW';

const
  WindowWidth  = 800;              // при 96 DPI, скалира се
  WindowHeight = 640;
  MAX_PATHBUF  = 4096;             // дълги пътища (asm-ът имаше 128)
  MAX_FILESIZE = 512 * 1024 * 1024;
  IDC_GOEDIT   = 1000;             // Go To dialog edit field
  WM_APP_OPENDROP = WM_APP + 1;

  // Rich Edit (не са в Windows unit-а)
  EM_CANPASTE        = WM_USER + 50;
  EM_EXGETSEL        = WM_USER + 52;
  EM_EXLIMITTEXT     = WM_USER + 53;
  EM_EXLINEFROMCHAR  = WM_USER + 54;
  EM_EXSETSEL        = WM_USER + 55;
  EM_FORMATRANGE     = WM_USER + 57;
  EM_GETSELTEXT      = WM_USER + 62;
  EM_SETBKGNDCOLOR   = WM_USER + 67;
  EM_SETCHARFORMAT   = WM_USER + 68;
  EM_SETEVENTMASK    = WM_USER + 69;
  EM_SETTARGETDEVICE = WM_USER + 72;
  EM_REDO            = WM_USER + 84;
  EM_CANREDO         = WM_USER + 85;
  EM_SETTEXTMODE     = WM_USER + 89;
  EM_GETTEXTLENGTHEX = WM_USER + 95;
  EM_SHOWSCROLLBAR   = WM_USER + 96;
  EM_FINDTEXTEXW     = WM_USER + 124;
  EM_GETZOOM         = WM_USER + 224;
  EM_SETZOOM         = WM_USER + 225;
  EM_GETTEXTRANGE    = WM_USER + 75;
  EM_SETLANGOPTIONS  = WM_USER + 120;
  EM_GETLANGOPTIONS  = WM_USER + 121;
  EM_SETEDITSTYLE    = WM_USER + 204;
  IMF_SPELLCHECKING  = $00000800;
  SES_USECTF            = $00010000;
  SES_CTFALLOWPROOFING  = $00800000;

  // SAPI
  SPF_ASYNC            = 1;
  SPF_PURGEBEFORESPEAK = 2;
  SPF_IS_XML           = 8;
  SPF_IS_NOT_XML       = $10;
  KEY_WOW64_64KEY_F    = $0100;
  CLSID_SpObjectToken: TGUID = '{EF411752-3736-4CB4-9C8C-8EF4CCB58EFE}';
  IID_ISpObjectToken:  TGUID = '{14056589-E16C-11D2-BB90-00C04F8EE6C0}';
  MAX_VOICES     = 32;
  KLF_NOTELLSHELL = $80;
  LANG_BG        = $0402;
  CLSCTX_ALL           = $17;
  CLSID_SpVoice: TGUID = '{96749377-3391-11D2-9EE3-00C04F797396}';
  IID_ISpVoice:  TGUID = '{6C44DF74-72B9-4992-A1EC-EF996E0422D4}';

  TIMER_STATS    = 1;
  TIMER_AUTOSAVE = 2;
  AUTOSAVE_MS    = {$IFDEF TESTFAST}1500{$ELSE}30000{$ENDIF};
  MRU_MAX        = 8;
  WM_APP_CHECKFILE = WM_APP + 2;
  WM_APP_SPEECH    = WM_APP + 3;     // SAPI събития (дума, край)
  WM_APP_RUNOUT    = WM_APP + 4;     // парче изход от командата (wParam = байтове)
  WM_APP_RUNDONE   = WM_APP + 5;     // командата приключи (wParam = exit code)
  HANDLE_FLAG_INHERIT = 1;
  CREATE_NO_WINDOW_F  = $08000000;
  SPEI_END_INPUT_STREAM = 2;
  SPEI_WORD_BOUNDARY    = 5;
  SPFEI_FLAGCHECK  = QWord($240000000);   // (1 shl 30) or (1 shl 33)

  TM_PLAINTEXT      = 1;
  TM_MULTILEVELUNDO = 8;
  TM_MULTICODEPAGE  = 32;
  GTL_PRECISE       = 2;
  GTL_NUMCHARS      = 8;

  SCF_ALL         = $00000004;
  ENM_CHANGE      = $00000001;
  ENM_UPDATE      = $00000002;
  ENM_SCROLL      = $00000004;
  ENM_MOUSEEVENTS = $00020000;
  ENM_SELCHANGE   = $00080000;
  ENM_DROPFILES   = $00100000;
  EN_MSGFILTER    = $0700;
  EN_SELCHANGE    = $0702;
  EN_DROPFILES    = $0703;
  CFM_BOLD        = $00000001;
  CFM_ITALIC      = $00000002;
  CFM_SIZE        = DWORD($80000000);
  CFM_FACE        = $20000000;
  CFM_COLOR       = $40000000;
  CFE_BOLD        = $00000001;
  CFE_ITALIC      = $00000002;
  CFE_AUTOCOLOR   = $40000000;

  // status bar (comctl32)
  SB_SETTEXTW     = WM_USER + 11;
  SB_SETPARTS     = WM_USER + 4;
  SBARS_SIZEGRIP  = $0100;

  // commdlg extras
  PSD_MARGINS                  = $00000002;
  PSD_INHUNDREDTHSOFMILLIMETERS = $00000008;
  PD_SELECTION_F               = $00000001;
  PD_NOSELECTION_F             = $00000004;
  PD_NOPAGENUMS_F              = $00000008;
  PD_RETURNDC_F                = $00000100;
  CF_INITTOLOGFONTSTRUCT_F     = $00000040;
  CF_SCREENFONTS_F             = $00000001;

  // accelerators
  FVIRTKEY  = $01;
  FSHIFT    = $04;
  FCONTROL  = $08;
  VK_OEM_PLUS_K  = $BB;
  VK_OEM_MINUS_K = $BD;

  // command IDs (WM_COMMAND / WM_SYSCOMMAND)
  IDM_SAVE           = $E100;
  IDM_FILE_NEW       = $E200;
  IDM_FILE_EXIT      = $E201;
  IDM_FILE_OPEN      = $E202;
  IDM_FILE_SAVEAS    = $E203;
  IDM_FILE_PRINT     = $E204;
  IDM_FILE_PAGESETUP = $E205;
  IDM_EDIT_UNDO      = $E210;
  IDM_EDIT_CUT       = $E211;
  IDM_EDIT_COPY      = $E212;
  IDM_EDIT_PASTE     = $E213;
  IDM_EDIT_DELETE    = $E214;
  IDM_EDIT_SELALL    = $E215;
  IDM_EDIT_TIME      = $E216;
  IDM_EDIT_FIND      = $E217;
  IDM_EDIT_FINDNEXT  = $E218;
  IDM_EDIT_REPLACE   = $E219;
  IDM_EDIT_GOTO      = $E21A;
  IDM_EDIT_FINDPREV  = $E21B;
  IDM_EDIT_REDO      = $E21C;
  IDM_EDIT_SPEAK     = $E21D;
  IDM_EDIT_CALC      = $E21E;
  IDM_EDIT_FIXLAYOUT = $E21F;
  IDM_FMT_AUTOINDENT = $E228;
  IDM_FMT_SPELL      = $E222;
  IDM_FMT_UPPER      = $E223;
  IDM_FMT_LOWER      = $E224;
  IDM_FMT_TITLE      = $E225;
  IDM_FMT_TOLATIN    = $E226;
  IDM_FMT_TOCYR      = $E227;
  IDM_LINES_SORTASC  = $E270;
  IDM_LINES_SORTDESC = $E271;
  IDM_LINES_DEDUP    = $E272;
  IDM_LINES_TRIM     = $E273;
  IDM_MRU_FIRST      = $E280;      // + индекс
  IDM_MRU_LAST       = $E287;
  IDM_MRU_CLEAR      = $E288;
  IDM_VOICE_AUTO     = $E290;
  IDM_VOICE_FIRST    = $E291;      // + индекс в gVoices
  IDM_VOICE_LAST     = $E291 + MAX_VOICES - 1;
  IDM_RATE_FIRST     = $E2C0;      // Slow, Normal, Fast, Very fast
  IDM_RATE_LAST      = $E2C3;
  IDM_SPEAK_HILITE   = $E2C8;
  IDM_EDIT_RUNLINE   = $E2D0;
  IDM_EDIT_RUNSTOP   = $E2D1;
  IDM_TOOLS_TASKS    = $E2D2;
  IDM_TOOLS_DELTASK  = $E2D3;
  IDM_TOOLS_SCHEDHELP = $E2D4;
  IDM_SPEAK_REMIND   = $E2C9;
  IDM_FMT_WRAP       = $E220;
  IDM_FMT_FONT       = $E221;
  IDM_VIEW_STATUS    = $E230;
  IDM_VIEW_ZOOMIN    = $E233;
  IDM_VIEW_ZOOMOUT   = $E234;
  IDM_VIEW_ZOOMRESET = $E235;
  IDM_HELP_ABOUT     = $E240;
  IDM_HELP_VIEWHELP  = $E241;
  IDM_ENC_FIRST      = $E250;      // + Ord(TEncoding)
  IDM_ENC_LAST       = $E254;
  IDM_EOL_FIRST      = $E258;      // + Ord(TEol)
  IDM_EOL_LAST       = $E25A;

{$IFDEF FEAT_LINENUMBERS}
  LN_MARGIN_W      = 48;           // gutter width при 96 DPI
  LN_PAD           = 6;            // дясно поле на числата
  IDM_VIEW_LINENUM = $E231;
{$ENDIF}
{$IFDEF FEAT_DARKMODE}
  DARK_BG       = $001E1E1E;       // 00BBGGRR
  DARK_FG       = $00DCDCDC;
  DARK_GUTTER   = $00252526;
  DARK_GUTTERFG = $00858585;
  IDM_VIEW_DARK = $E232;
{$ENDIF}

  ClassName : PWideChar = '.';           // saves bytes, seems to work :)
  RichDll   : PWideChar = 'Msftedit.dll';
  EditClass : PWideChar = 'RICHEDIT50W';
  AppName   = 'TinyRetroPad';
  AboutText = 'TinyRetroPad 2.7 - tiny notepad-style editor'#13#10 +
              'Pascal port of Dave Plummer''s trpad.asm, tuned.';
  HelpUrl   = 'https://github.com/davepl';
  RegKey    = 'Software\TinyRetroPad';
  FileFilter = 'Text Documents (*.txt)'#0'*.txt'#0'All Files (*.*)'#0'*.*'#0;

type
  TEncoding = (encANSI, encUTF8, encUTF8BOM, encUTF16LE, encUTF16BE);
  TEol      = (eolCRLF, eolLF, eolCR);

const
  EncNames: array[TEncoding] of UnicodeString =
    ('ANSI', 'UTF-8', 'UTF-8 with BOM', 'UTF-16 LE', 'UTF-16 BE');
  EolNames: array[TEol] of UnicodeString =
    ('Windows (CRLF)', 'Unix (LF)', 'Macintosh (CR)');

type
  TBytes = array of Byte;

  TCharRange = packed record
    cpMin, cpMax: LongInt;
  end;

  TFindTextExW = record
    chrg: TCharRange;
    lpstrText: PWideChar;
    chrgText: TCharRange;
  end;

  TFormatRange = record
    hdc, hdcTarget: HDC;
    rc, rcPage: TRect;
    chrg: TCharRange;
  end;

  TGetTextLengthEx = record
    flags: DWORD;
    codepage: UINT;
  end;

  TCharFormatW = packed record
    cbSize: DWORD;
    dwMask: DWORD;
    dwEffects: DWORD;
    yHeight: LongInt;
    yOffset: LongInt;
    crTextColor: COLORREF;
    bCharSet: Byte;
    bPitchAndFamily: Byte;
    szFaceName: array[0..LF_FACESIZE-1] of WideChar;
    wPad: Word;                    // -> 92 bytes, като richedit.h
  end;

  // NMHDR като отделен record: на Win64 той е 24 байта (с padding),
  // затова MSGFILTER.msg е на offset 24, а не 20 (бъг в 1.0)
  TNmHdrRec = record
    hwndFrom: HWND;
    idFrom: UINT_PTR;
    code: UINT;
  end;
  PNmHdrRec = ^TNmHdrRec;

  TMsgFilterRec = record
    nmhdr: TNmHdrRec;
    msg: UINT;                     // wParam/lParam не ни трябват
  end;
  PMsgFilterRec = ^TMsgFilterRec;

  TTextRangeW = record
    chrg: TCharRange;
    lpstrText: PWideChar;
  end;

  TFileAttrData = record              // WIN32_FILE_ATTRIBUTE_DATA
    dwFileAttributes: DWORD;
    ftCreationTime, ftLastAccessTime, ftLastWriteTime: TFileTime;
    nFileSizeHigh, nFileSizeLow: DWORD;
  end;

  // SAPI 5 ISpObjectToken: 12 метода от ISpDataKey, после SetId
  ISpObjectToken = interface(IUnknown)
    ['{14056589-E16C-11D2-BB90-00C04F8EE6C0}']
    procedure _SetData; stdcall;
    procedure _GetData; stdcall;
    procedure _SetStringValue; stdcall;
    procedure _GetStringValue; stdcall;
    procedure _SetDWORD; stdcall;
    procedure _GetDWORD; stdcall;
    procedure _OpenKey; stdcall;
    procedure _CreateKey; stdcall;
    procedure _DeleteKey; stdcall;
    procedure _DeleteValue; stdcall;
    procedure _EnumKeys; stdcall;
    procedure _EnumValues; stdcall;
    function SetId(pszCategoryId, pszTokenId: PWideChar; fCreateIfNotExist: BOOL): HRESULT; stdcall;
  end;

  TSpEvent = record                   // SPEVENT
    eEventId: Word;
    elParamType: Word;
    ulStreamNum: ULONG;
    ullAudioStreamOffset: QWord;
    wp: WPARAM;                       // за WORD_BOUNDARY: дължина на думата
    lp: LPARAM;                       //                   позиция в текста
  end;

  TVoiceInfo = record
    Id: UnicodeString;                // пълен registry път - token id за SAPI
    Name: UnicodeString;
    Lang: Integer;                    // LCID, напр. $402 = български
  end;

  // SAPI 5 ISpVoice: първите 10 метода (ISpNotifySource + ISpEventSource)
  // не ни трябват, но трябва да заемат местата си във vtable-а
  ISpVoice = interface(IUnknown)
    ['{6C44DF74-72B9-4992-A1EC-EF996E0422D4}']
    procedure _SetNotifySink; stdcall;
    function SetNotifyWindowMessage(h: HWND; Msg: UINT; wp: WPARAM; lp: LPARAM): HRESULT; stdcall;
    procedure _SetNotifyCallbackFunction; stdcall;
    procedure _SetNotifyCallbackInterface; stdcall;
    procedure _SetNotifyWin32Event; stdcall;
    procedure _WaitForNotifyEvent; stdcall;
    procedure _GetNotifyEventHandle; stdcall;
    function SetInterest(ullEventInterest, ullQueuedInterest: QWord): HRESULT; stdcall;
    function GetEvents(ulCount: ULONG; pEventArray: Pointer; pulFetched: PULONG): HRESULT; stdcall;
    procedure _GetInfo; stdcall;
    function SetOutput(pUnkOutput: Pointer; fAllowFormatChanges: BOOL): HRESULT; stdcall;
    function GetOutputObjectToken(out ppObjectToken: Pointer): HRESULT; stdcall;
    function GetOutputStream(out ppStream: Pointer): HRESULT; stdcall;
    function Pause: HRESULT; stdcall;
    function Resume: HRESULT; stdcall;
    function SetVoice(pToken: Pointer): HRESULT; stdcall;
    function GetVoice(out ppToken: Pointer): HRESULT; stdcall;
    function Speak(pwcs: PWideChar; dwFlags: DWORD; pulStreamNumber: PDWORD): HRESULT; stdcall;
    procedure _SpeakStream; stdcall;
    procedure _GetStatus; stdcall;
    procedure _Skip; stdcall;
    procedure _SetPriority; stdcall;
    procedure _GetPriority; stdcall;
    procedure _SetAlertBoundary; stdcall;
    procedure _GetAlertBoundary; stdcall;
    function SetRate(adjust: LongInt): HRESULT; stdcall;
    procedure _GetRate; stdcall;
    procedure _SetVolume; stdcall;
    procedure _GetVolume; stdcall;
    function WaitUntilDone(msTimeout: DWORD): HRESULT; stdcall;
  end;

  TEnDropFilesRec = record
    nmhdr: TNmHdrRec;
    hDrop: THandle;
  end;
  PEnDropFilesRec = ^TEnDropFilesRec;

var
  hInstApp : HINST = 0;
  hMain    : HWND  = 0;
  hEdit    : HWND  = 0;
  hStatus  : HWND  = 0;
  hFindDlg : HWND  = 0;               // modeless Find/Replace
  fFindIsReplace: Boolean = False;
  uFindMsg : UINT  = 0;               // registered FINDMSGSTRING
  gAccel   : HACCEL = 0;
  fDirty   : Boolean = False;
  fLoading : Boolean = True;          // потиска EN_CHANGE при зареждане
  fWrap    : Boolean = True;
  fStatus  : Boolean = True;
{$IFDEF FEAT_LINENUMBERS}
  fLineNum : Boolean = False;
{$ENDIF}
{$IFDEF FEAT_DARKMODE}
  fDark    : Boolean = False;
{$ENDIF}
  gDpi     : Integer = 96;
  gZoom    : Integer = 100;           // последно показан zoom, %
  gStartZoom: Integer = 100;          // от registry
  gFile    : UnicodeString = '';
  gEnc     : TEncoding = encUTF8;
  gEol     : TEol = eolCRLF;
  gDropFile: UnicodeString = '';
  gDevMode : HGLOBAL = 0;             // принтер, споделен между диалозите
  gDevNames: HGLOBAL = 0;
  gMargins : TRect = (Left: 2000; Top: 2000; Right: 2000; Bottom: 2000); // 1/100 mm
  gPlacement: TWindowPlacement;
  gHavePlacement: Boolean = False;
  gLineCount: LongInt = 0;            // за Go To проверката
  FindWhat : array[0..255] of WideChar;
  ReplaceWith: array[0..255] of WideChar;
  fr       : TFindReplaceW;           // shared find/replace request
  fSpell   : Boolean = True;
  fAutoIndent: Boolean = True;
  gMru     : array[0..MRU_MAX-1] of UnicodeString;
  gMruMenu : HMENU = 0;
  gStamp   : TFileAttrData;           // кога е записан файлът на диска
  gHaveStamp: Boolean = False;
  fChecking: Boolean = False;
  gRecFile : UnicodeString = '';
  gRecHandle: THandle = INVALID_HANDLE_VALUE;
  gRecPending: Boolean = False;       // има промени след последната снимка
  gVoice   : ISpVoice = nil;
  gVoices  : array of TVoiceInfo;
  gVoiceSel: UnicodeString = '';      // '' = автоматично по езика
  gRateIdx : Integer = 1;             // Normal
  gVoiceMenu: HMENU = 0;
  gBgHintShown: Boolean = False;
  fSpeakHilite: Boolean = True;
  gSpeaking: Boolean = False;
  gSpeakStream: ULONG = 0;
  gSpeakBase: LongInt = 0;            // от коя позиция в редактора започва четеният текст
  gSpeakSel: TCharRange;              // селекцията преди четенето - връщаме я накрая
  gSpeakToEnd: Boolean = False;       // четем до края на документа (не селекция)
  gLastWordPos: LongInt = -1;         // последната изговорена дума
  gStatusNote: UnicodeString = '';    // еднократно съобщение в status bar-а
  gRunning : Boolean = False;
  gRunStopped: Boolean = False;
  gRunProc : THandle = 0;
  gRunThreadH: THandle = 0;
  gRunJob  : THandle = 0;
  gRunRead : THandle = 0;
  gRunPos  : LongInt = 0;             // къде отива следващото парче изход
  gRunPend : TBytes;                  // байтове, още недекодирани (разцепен UTF-8)
  gRunTotal: Int64 = 0;
  gRunEndsWithBreak: Boolean = True;
  gRunDir  : UnicodeString = '';      // работна папка; '' = папката на файла
  gRunCmd  : UnicodeString = '';
  // споделен буфер нишка -> UI: нишката трупа, UI-ят прибира наведнъж.
  // Така в опашката има най-много едно WM_APP_RUNOUT и Esc винаги минава.
  gRunCS   : TRTLCriticalSection;
  gRunBuf  : PByte = nil;
  gRunBufLen, gRunBufCap: DWORD;
  gRunNotified: Boolean = False;
  gRunPendCR: Boolean = False;        // CR в края на парче - LF може да дойде в следващото
  gRunTempFile: UnicodeString = '';   // XML на задачата - трие се след schtasks
  fRemindSpeak: Boolean = True;       // напомнянията се четат на глас
  RichFont : TCharFormatW;            // текущ шрифт (face, size, bold/italic)

{ ======================= помощни ======================= }

function EdMsg(m: UINT; w: WPARAM; l: LPARAM): LRESULT; inline;
begin
  Result := SendMessageW(hEdit, m, w, l);
end;

// LOWORD/HIWORD от FPC взимат DWORD -> range error при lParam = -1
function LoWrd(x: PtrInt): Integer; inline;
begin
  Result := x and $FFFF;
end;

function HiWrd(x: PtrInt): Integer; inline;
begin
  Result := (x shr 16) and $FFFF;
end;

function S(px: Integer): Integer; inline;   // DPI скалиране
begin
  Result := MulDiv(px, gDpi, 96);
end;

function IStr(n: Int64): UnicodeString;
var
  t: ShortString;
begin
  Str(n, t);
  Result := UnicodeString(t);
end;

function MsgBox(const Text: UnicodeString; Flags: UINT): Integer;
var
  owner: HWND;
begin
  owner := hMain;
  if hFindDlg <> 0 then owner := hFindDlg;
  Result := MessageBoxW(owner, PWideChar(Text), AppName, Flags);
end;

function BaseName(const fn: UnicodeString): UnicodeString;
var
  i: Integer;
begin
  i := Length(fn);
  while (i > 0) and (fn[i] <> '\') and (fn[i] <> '/') do Dec(i);
  Result := Copy(fn, i + 1, MaxInt);
end;

function DocTitle: UnicodeString;
begin
  if gFile = '' then Result := 'Untitled' else Result := BaseName(gFile);
end;

function FileExists(const fn: UnicodeString): Boolean;
var
  a: DWORD;
begin
  a := GetFileAttributesW(PWideChar(fn));
  Result := (a <> $FFFFFFFF) and ((a and FILE_ATTRIBUTE_DIRECTORY) = 0);
end;

function TextLenInternal: LongInt;   // дължина в RichEdit позиции (CR = 1)
var
  gtl: TGetTextLengthEx;
begin
  gtl.flags := GTL_PRECISE or GTL_NUMCHARS;
  gtl.codepage := 1200;
  Result := EdMsg(EM_GETTEXTLENGTHEX, WPARAM(@gtl), 0);
end;

function GetEditText: UnicodeString;
var
  len: LongInt;
begin
  Result := '';
  len := SendMessageW(hEdit, WM_GETTEXTLENGTH, 0, 0);
  if len <= 0 then Exit;
  SetLength(Result, len);
  len := SendMessageW(hEdit, WM_GETTEXT, len + 1, LPARAM(PWideChar(Result)));
  SetLength(Result, len);
end;

{ ================= кодировки и край на ред ================= }

{ Превръща всички видове нов ред (CRLF, LF, CR) в избрания.
  Ако Detected <> nil - връща вида на първия срещнат. }
function ConvertEol(const src: UnicodeString; eol: TEol; Detected: PBoolean;
  out First: TEol): UnicodeString;
var
  i, n, o: Integer;
  r: UnicodeString;
  e: TEol;
  brk: Boolean;
begin
  First := eolCRLF;
  n := Length(src);
  SetLength(r, n * 2);
  o := 0;
  i := 1;
  while i <= n do
  begin
    brk := True;
    e := eolCRLF;
    if src[i] = #13 then
    begin
      if (i < n) and (src[i + 1] = #10) then Inc(i)
      else e := eolCR;
    end
    else if src[i] = #10 then
      e := eolLF
    else
      brk := False;
    if brk then
    begin
      if (Detected <> nil) and not Detected^ then
      begin First := e; Detected^ := True; end;
      case eol of
        eolCRLF: begin Inc(o); r[o] := #13; Inc(o); r[o] := #10; end;
        eolLF:   begin Inc(o); r[o] := #10; end;
        eolCR:   begin Inc(o); r[o] := #13; end;
      end;
    end
    else
    begin
      Inc(o); r[o] := src[i];
    end;
    Inc(i);
  end;
  SetLength(r, o);
  Result := r;
end;

procedure SwapBytes16(var s: UnicodeString);
var
  i: Integer;
begin
  UniqueString(s);
  for i := 1 to Length(s) do
    s[i] := WideChar(Swap(Word(s[i])));
end;

function MbToWide(cp: UINT; flags: DWORD; p: PAnsiChar; n: LongInt;
  out s: UnicodeString): Boolean;
var
  len: LongInt;
begin
  s := '';
  if n <= 0 then Exit(True);
  len := MultiByteToWideChar(cp, flags, p, n, nil, 0);
  if len <= 0 then Exit(False);
  SetLength(s, len);
  MultiByteToWideChar(cp, flags, p, n, PWideChar(s), len);
  Result := True;
end;

procedure DecodeBytes(p: PByte; n: LongInt; out s: UnicodeString;
  out enc: TEncoding);
var
  cnt: LongInt;
begin
  s := '';
  if (n >= 2) and (p[0] = $FF) and (p[1] = $FE) then
  begin
    enc := encUTF16LE;
    cnt := (n - 2) div 2;
    SetLength(s, cnt);
    if cnt > 0 then Move(p[2], s[1], cnt * 2);
  end
  else if (n >= 2) and (p[0] = $FE) and (p[1] = $FF) then
  begin
    enc := encUTF16BE;
    cnt := (n - 2) div 2;
    SetLength(s, cnt);
    if cnt > 0 then
    begin
      Move(p[2], s[1], cnt * 2);
      SwapBytes16(s);
    end;
  end
  else if (n >= 3) and (p[0] = $EF) and (p[1] = $BB) and (p[2] = $BF) then
  begin
    enc := encUTF8BOM;
    MbToWide(CP_UTF8, 0, PAnsiChar(p) + 3, n - 3, s);
  end
  else if MbToWide(CP_UTF8, MB_ERR_INVALID_CHARS, PAnsiChar(p), n, s) then
    enc := encUTF8                    // валиден UTF-8 (вкл. чист ASCII)
  else
  begin
    enc := encANSI;                   // напр. cp1251
    MbToWide(CP_ACP, 0, PAnsiChar(p), n, s);
  end;
end;

{ Lossy = True, ако в ANSI има символи, които не се побират }
function EncodeText(const s: UnicodeString; enc: TEncoding;
  out Lossy: Boolean): TBytes;
var
  n, bom: LongInt;
  used: BOOL;
  t: UnicodeString;
  cp: UINT;
begin
  Lossy := False;
  Result := nil;
  case enc of
    encUTF16LE, encUTF16BE:
      begin
        n := Length(s);
        SetLength(Result, 2 + n * 2);
        if enc = encUTF16LE then
        begin Result[0] := $FF; Result[1] := $FE; t := s; end
        else
        begin Result[0] := $FE; Result[1] := $FF; t := s; SwapBytes16(t); end;
        if n > 0 then Move(t[1], Result[2], n * 2);
      end;
  else
    begin
      bom := 0;
      if enc = encUTF8BOM then bom := 3;
      if enc = encANSI then cp := CP_ACP else cp := CP_UTF8;
      n := 0;
      if s <> '' then
        n := WideCharToMultiByte(cp, 0, PWideChar(s), Length(s), nil, 0, nil, nil);
      SetLength(Result, bom + n);
      if bom = 3 then
      begin Result[0] := $EF; Result[1] := $BB; Result[2] := $BF; end;
      if n > 0 then
      begin
        used := False;
        if cp = CP_ACP then
          WideCharToMultiByte(cp, 0, PWideChar(s), Length(s),
            PAnsiChar(@Result[bom]), n, nil, @used)
        else
          WideCharToMultiByte(cp, 0, PWideChar(s), Length(s),
            PAnsiChar(@Result[bom]), n, nil, nil);
        Lossy := used;
      end;
    end;
  end;
end;

{ ======================= заглавие и status ======================= }

procedure ApplyTitle;
var
  t: UnicodeString;
begin
  t := DocTitle + ' - ' + AppName;
  if fDirty then t := '*' + t;        // TODO-то от оригинала, вече направено
  SetWindowTextW(hMain, PWideChar(t));
end;

function CurZoom: Integer;
var
  num, den: LongInt;
begin
  num := 0; den := 0;
  EdMsg(EM_GETZOOM, WPARAM(@num), LPARAM(@den));
  if (num <= 0) or (den <= 0) then Result := 100
  else Result := MulDiv(num, 100, den);
end;

procedure SetStatusText(part: Integer; const t: UnicodeString);
begin
  SendMessageW(hStatus, SB_SETTEXTW, part, LPARAM(PWideChar(t)));
end;

procedure UpdateStatus;
var
  cr: TCharRange;
  li, col: LongInt;
begin
  if (hStatus = 0) or not fStatus then Exit;
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  li  := EdMsg(EM_EXLINEFROMCHAR, 0, cr.cpMax);
  col := cr.cpMax - EdMsg(EM_LINEINDEX, li, 0) + 1;
  SetStatusText(1, '  Ln ' + IStr(li + 1) + ', Col ' + IStr(col));
  gZoom := CurZoom;
  SetStatusText(2, '  ' + IStr(gZoom) + '%');
  SetStatusText(3, '  ' + EolNames[gEol]);
  SetStatusText(4, '  ' + EncNames[gEnc]);
end;

procedure LayoutStatusParts(w: Integer);
var
  parts: array[0..4] of LongInt;
begin
  parts[4] := -1;
  parts[3] := w - S(120);
  parts[2] := parts[3] - S(120);
  parts[1] := parts[2] - S(60);
  parts[0] := parts[1] - S(150);
  if parts[0] < 0 then parts[0] := 0;
  SendMessageW(hStatus, SB_SETPARTS, 5, LPARAM(@parts[0]));
end;

{ ======================= менюта: отметки ======================= }

procedure CheckItem(id: UINT; on: Boolean);
var
  f: UINT;
begin
  f := MF_BYCOMMAND;
  if on then f := f or MF_CHECKED;
  CheckMenuItem(GetMenu(hMain), id, f);
end;

procedure SyncVoiceMenu; forward;

procedure SyncMenus;
var
  m: HMENU;
begin
  m := GetMenu(hMain);
  CheckItem(IDM_FMT_WRAP, fWrap);
  CheckItem(IDM_VIEW_STATUS, fStatus);
  CheckItem(IDM_FMT_SPELL, fSpell);
  CheckItem(IDM_FMT_AUTOINDENT, fAutoIndent);
  SyncVoiceMenu;
{$IFDEF FEAT_LINENUMBERS}
  CheckItem(IDM_VIEW_LINENUM, fLineNum);
{$ENDIF}
{$IFDEF FEAT_DARKMODE}
  CheckItem(IDM_VIEW_DARK, fDark);
{$ENDIF}
  CheckMenuRadioItem(m, IDM_ENC_FIRST, IDM_ENC_LAST,
    IDM_ENC_FIRST + Ord(gEnc), MF_BYCOMMAND);
  CheckMenuRadioItem(m, IDM_EOL_FIRST, IDM_EOL_LAST,
    IDM_EOL_FIRST + Ord(gEol), MF_BYCOMMAND);
end;

procedure EnableItem(m: HMENU; id: UINT; on: Boolean);
begin
  if on then EnableMenuItem(m, id, MF_BYCOMMAND or MF_ENABLED)
  else EnableMenuItem(m, id, MF_BYCOMMAND or MF_GRAYED);
end;

// Undo/Cut/Copy... сиви, когато нямат смисъл (като в Notepad)
procedure UpdateEditMenu(m: HMENU);
var
  cr: TCharRange;
  sel: Boolean;
begin
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  sel := cr.cpMax > cr.cpMin;
  EnableItem(m, IDM_EDIT_UNDO,   EdMsg(EM_CANUNDO, 0, 0) <> 0);
  EnableItem(m, IDM_EDIT_REDO,   EdMsg(EM_CANREDO, 0, 0) <> 0);
  EnableItem(m, IDM_EDIT_CUT,    sel);
  EnableItem(m, IDM_EDIT_COPY,   sel);
  EnableItem(m, IDM_EDIT_DELETE, sel);
  EnableItem(m, IDM_EDIT_PASTE,  EdMsg(EM_CANPASTE, 0, 0) <> 0);
  EnableItem(m, IDM_EDIT_RUNLINE, not gRunning);
  EnableItem(m, IDM_EDIT_RUNSTOP, gRunning);
end;

{ ======================= външен вид ======================= }

procedure ApplyCharFormat;
var
  fmt: TCharFormatW;
begin
  fmt := RichFont;
  fmt.cbSize := SizeOf(fmt);
  fmt.dwMask := CFM_FACE or CFM_SIZE or CFM_BOLD or CFM_ITALIC or CFM_COLOR;
  fmt.dwEffects := RichFont.dwEffects and (CFE_BOLD or CFE_ITALIC);
{$IFDEF FEAT_DARKMODE}
  if fDark then
    fmt.crTextColor := DARK_FG
  else
{$ENDIF}
    fmt.dwEffects := fmt.dwEffects or CFE_AUTOCOLOR;
  EdMsg(EM_SETCHARFORMAT, SCF_ALL, LPARAM(@fmt));
end;

procedure ApplyWrap;
begin
  if fWrap then
  begin
    EdMsg(EM_SETTARGETDEVICE, 0, 0);  // wrap към ширината на прозореца
    EdMsg(EM_SHOWSCROLLBAR, SB_HORZ, 0);
  end
  else
  begin
    EdMsg(EM_SETTARGETDEVICE, 0, 1);  // 1 = без wrap
    EdMsg(EM_SHOWSCROLLBAR, SB_HORZ, 1);
  end;
end;

procedure RelayoutClient;
var
  rc: TRect;
begin
  GetClientRect(hMain, @rc);
  SendMessageW(hMain, WM_SIZE, 0, MakeLong(rc.Right and $FFFF, rc.Bottom and $FFFF));
end;

{$IFDEF FEAT_DARKMODE}
type
  TDwmSetWindowAttribute = function(hwnd: HWND; attr: DWORD; pv: Pointer;
    cb: DWORD): HRESULT; stdcall;
  TSetWindowTheme = function(hwnd: HWND; app, idlist: PWideChar): HRESULT; stdcall;

// тъмна заглавна лента + тъмни scrollbar-и (Win10 1809+), тихо се
// игнорира на по-стари Windows
procedure ApplyDarkChrome;
var
  lib: HMODULE;
  dwmSet: TDwmSetWindowAttribute;
  setTheme: TSetWindowTheme;
  v: BOOL;
begin
  v := fDark;
  lib := LoadLibraryW('dwmapi.dll');
  if lib <> 0 then
  begin
    dwmSet := TDwmSetWindowAttribute(GetProcAddress(lib, 'DwmSetWindowAttribute'));
    if Assigned(dwmSet) then
      if dwmSet(hMain, 20, @v, SizeOf(v)) <> 0 then   // DWMWA_USE_IMMERSIVE_DARK_MODE
        dwmSet(hMain, 19, @v, SizeOf(v));             // преди 20H1
  end;
  lib := LoadLibraryW('uxtheme.dll');
  if lib <> 0 then
  begin
    setTheme := TSetWindowTheme(GetProcAddress(lib, 'SetWindowTheme'));
    if Assigned(setTheme) then
      if fDark then setTheme(hEdit, 'DarkMode_Explorer', nil)
      else setTheme(hEdit, nil, nil);
  end;
  SetWindowPos(hMain, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or
    SWP_NOZORDER or SWP_FRAMECHANGED);
end;

procedure ApplyDark;
begin
  if fDark then
    EdMsg(EM_SETBKGNDCOLOR, 0, DARK_BG)        // wParam 0 = даден цвят
  else
    EdMsg(EM_SETBKGNDCOLOR, 1, 0);             // wParam 1 = system цвят
  ApplyCharFormat;
  ApplyDarkChrome;
  InvalidateRect(hMain, nil, True);
end;
{$ENDIF}

{$IFDEF FEAT_LINENUMBERS}
function GutterW: Integer;
begin
  if fLineNum then Result := S(LN_MARGIN_W) else Result := 0;
end;

procedure LnInvalidate;
var
  rc: TRect;
begin
  if (not fLineNum) or (hMain = 0) then Exit;   // InvalidateRect(0) = целия desktop
  rc.Left := 0; rc.Top := 0; rc.Right := GutterW; rc.Bottom := $7FFF;
  InvalidateRect(hMain, @rc, False);
end;

procedure PaintGutter(hWnd: HWND);
var
  ps: TPaintStruct;
  rc, er: TRect;
  pt: TPoint;
  dc: HDC;
  li, total, ci: LongInt;
  nbuf: UnicodeString;
  br: HBRUSH;
  oldFont: HGDIOBJ;
begin
  dc := BeginPaint(hWnd, @ps);
  GetClientRect(hWnd, @rc);
  if hStatus <> 0 then
    if fStatus then
    begin
      GetWindowRect(hStatus, @er);
      Dec(rc.Bottom, er.Bottom - er.Top);
    end;
  rc.Right := GutterW;
{$IFDEF FEAT_DARKMODE}
  if fDark then
  begin
    br := CreateSolidBrush(DARK_GUTTER);
    FillRect(dc, rc, br);
    DeleteObject(br);
    SetTextColor(dc, DARK_GUTTERFG);
  end
  else
{$ENDIF}
  begin
    br := GetSysColorBrush(COLOR_BTNFACE);
    FillRect(dc, rc, br);
    SetTextColor(dc, GetSysColor(COLOR_GRAYTEXT));
  end;
  SetBkMode(dc, TRANSPARENT);
  SetTextAlign(dc, TA_RIGHT or TA_TOP);
  oldFont := SelectObject(dc, GetStockObject(DEFAULT_GUI_FONT));
  li := EdMsg(EM_GETFIRSTVISIBLELINE, 0, 0);
  total := EdMsg(EM_GETLINECOUNT, 0, 0);
  while li < total do
  begin
    ci := EdMsg(EM_LINEINDEX, li, 0);
    EdMsg(EM_POSFROMCHAR, WPARAM(@pt), ci);     // pt.y = line top, client px
    if pt.Y > rc.Bottom then Break;
    nbuf := IStr(li + 1);
    TextOutW(dc, rc.Right - S(LN_PAD), pt.Y, PWideChar(nbuf), Length(nbuf));
    Inc(li);
  end;
  SelectObject(dc, oldFont);
  EndPaint(hWnd, @ps);
end;
{$ENDIF}

{ ======================= меню и registry помощни ======================= }

procedure Item(hMenu: HMENU; uID: UINT; const t: UnicodeString);
begin
  AppendMenuW(hMenu, MF_STRING, uID, PWideChar(t));
end;

procedure Sep(hMenu: HMENU);
begin
  AppendMenuW(hMenu, MF_SEPARATOR, 0, nil);
end;

procedure Popup(hBar, hPop: HMENU; const t: UnicodeString);
begin
  AppendMenuW(hBar, MF_POPUP or MF_STRING, hPop, PWideChar(t));
end;

function RegGetBin(k: HKEY; const name: UnicodeString; p: Pointer; size: DWORD): Boolean;
var
  sz, typ: DWORD;
begin
  sz := size;
  Result := (RegQueryValueExW(k, PWideChar(name), nil, @typ, p, @sz) = 0) and
            (sz = size);
end;

function RegGetBool(k: HKEY; const name: UnicodeString; def: Boolean): Boolean;
var
  v: DWORD;
begin
  if RegGetBin(k, name, @v, SizeOf(v)) then Result := v <> 0 else Result := def;
end;

function RegGetStr(k: HKEY; const name: UnicodeString): UnicodeString;
var
  sz, typ: DWORD;
begin
  Result := '';
  sz := 0;
  if (RegQueryValueExW(k, PWideChar(name), nil, @typ, nil, @sz) <> 0) or
     (typ <> REG_SZ) or (sz < 4) then Exit;
  SetLength(Result, sz div 2);
  if RegQueryValueExW(k, PWideChar(name), nil, nil, PWideChar(Result), @sz) <> 0 then
    Exit('');
  Result := PWideChar(Result);        // отрязва нулата накрая
end;

procedure RegPutBin(k: HKEY; const name: UnicodeString; p: Pointer; size: DWORD);
begin
  RegSetValueExW(k, PWideChar(name), 0, REG_BINARY, p, size);
end;

procedure RegPutDW(k: HKEY; const name: UnicodeString; v: DWORD);
begin
  RegSetValueExW(k, PWideChar(name), 0, REG_DWORD, @v, SizeOf(v));
end;

procedure RegPutStr(k: HKEY; const name, s: UnicodeString);
begin
  RegSetValueExW(k, PWideChar(name), 0, REG_SZ, PWideChar(s), (Length(s) + 1) * 2);
end;

function FullPath(const fn: UnicodeString): UnicodeString;
var
  buf: array[0..MAX_PATHBUF-1] of WideChar;
  n: DWORD;
begin
  n := GetFullPathNameW(PWideChar(fn), MAX_PATHBUF, @buf[0], nil);
  if (n = 0) or (n >= MAX_PATHBUF) then Result := fn
  else Result := PWideChar(@buf[0]);
end;

{ ======================= позиция на четене ======================= }

{ HKCU\Software\TinyRetroPad\ReadPos: <пълен път> = позиция }

function ReadPosName(const fn: UnicodeString): UnicodeString;
begin
  Result := fn;
  UniqueString(Result);
  if Result <> '' then CharLowerBuffW(PWideChar(Result), Length(Result));
end;

procedure SaveReadPos(pos: LongInt);
var
  k: HKEY;
begin
  if (gFile = '') or (pos < 0) then Exit;
  if RegCreateKeyExW(HKEY_CURRENT_USER, RegKey + '\ReadPos', 0, nil, 0, KEY_WRITE,
                     nil, k, nil) <> 0 then Exit;
  RegPutDW(k, ReadPosName(gFile), DWORD(pos));
  RegCloseKey(k);
end;

procedure ClearReadPos;
var
  k: HKEY;
begin
  if gFile = '' then Exit;
  if RegOpenKeyExW(HKEY_CURRENT_USER, RegKey + '\ReadPos', 0, KEY_WRITE, k) <> 0 then Exit;
  RegDeleteValueW(k, PWideChar(ReadPosName(gFile)));
  RegCloseKey(k);
end;

function LoadReadPos(const fn: UnicodeString): LongInt;
var
  k: HKEY;
  v: DWORD;
begin
  Result := -1;
  if RegOpenKeyExW(HKEY_CURRENT_USER, RegKey + '\ReadPos', 0, KEY_READ, k) <> 0 then Exit;
  if RegGetBin(k, ReadPosName(fn), @v, SizeOf(v)) and (v < $7FFFFFFF) then
    Result := v;
  RegCloseKey(k);
end;

{ ======================= текстови диапазони ======================= }

// текст между RichEdit позиции [a, b)
function GetRange(a, b: LongInt): UnicodeString;
var
  tr: TTextRangeW;
  n: LRESULT;
begin
  Result := '';
  if b <= a then Exit;
  SetLength(Result, (b - a) * 2 + 1);  // запас, ако върне CRLF
  tr.chrg.cpMin := a;
  tr.chrg.cpMax := b;
  tr.lpstrText := PWideChar(Result);
  n := EdMsg(EM_GETTEXTRANGE, 0, LPARAM(@tr));
  if n < 0 then n := 0;
  SetLength(Result, n);
end;

// заменя [a, b) с t като едно Undo действие
procedure ReplaceRange(a, b: LongInt; const t: UnicodeString; selectResult: Boolean);
var
  cr: TCharRange;
  e: LongInt;
begin
  cr.cpMin := a; cr.cpMax := b;
  EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  EdMsg(EM_REPLACESEL, WPARAM(True), LPARAM(PWideChar(t)));
  if selectResult then
  begin
    EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));   // курсорът е в края на вмъкнатото
    e := cr.cpMax;
    cr.cpMin := a; cr.cpMax := e;
    EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  end;
end;

{ ======================= брояч на думи ======================= }

procedure ScheduleStats;               // броенето е отложено - бързо писане
begin
  if hMain <> 0 then SetTimer(hMain, TIMER_STATS, 250, nil);
end;

procedure UpdateWordStats;
var
  s, t: UnicodeString;
  cr: TCharRange;
  i, words, chars: LongInt;
  inWord, sel: Boolean;
  c: WideChar;
begin
  if (hStatus = 0) or not fStatus then Exit;
  if gRunning then
  begin
    SetStatusText(0, '  Running: ' + gRunCmd + '   (Esc stops)');
    Exit;
  end;
  if gStatusNote <> '' then
  begin                               // еднократно съобщение, после пак броим
    SetStatusText(0, '  ' + gStatusNote);
    gStatusNote := '';
    Exit;
  end;
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  sel := cr.cpMax > cr.cpMin;
  if sel then s := GetRange(cr.cpMin, cr.cpMax) else s := GetEditText;
  words := 0; chars := 0; inWord := False;
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if (c = #13) or (c = #10) then begin inWord := False; Continue; end;
    if (Ord(c) < $DC00) or (Ord(c) > $DFFF) then Inc(chars);   // емоджи = 1 знак
    if IsCharAlphaNumericW(c) then
    begin
      if not inWord then begin Inc(words); inWord := True; end;
    end
    else if not (inWord and ((c = '''') or (c = '-') or (c = #$2019))) then
      inWord := False;                // "по-добре", "don't" = една дума
  end;
  t := IStr(words) + ' words, ' + IStr(chars) + ' characters';
  if sel then t := 'Selection: ' + t;
  SetStatusText(0, '  ' + t);
end;

{ ======================= последни файлове ======================= }

function SameFile(const a, b: UnicodeString): Boolean;
begin
  Result := lstrcmpiW(PWideChar(a), PWideChar(b)) = 0;
end;

function EscapeAmp(const s: UnicodeString): UnicodeString;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    if s[i] = '&' then Result := Result + '&&' else Result := Result + s[i];
end;

procedure MruRebuild;
var
  i, n: Integer;
begin
  if gMruMenu = 0 then Exit;
  while GetMenuItemCount(gMruMenu) > 0 do
    DeleteMenu(gMruMenu, 0, MF_BYPOSITION);
  n := 0;
  for i := 0 to MRU_MAX - 1 do
    if gMru[i] <> '' then
    begin
      Item(gMruMenu, IDM_MRU_FIRST + i, '&' + IStr(i + 1) + '  ' + EscapeAmp(gMru[i]));
      Inc(n);
    end;
  if n = 0 then
    AppendMenuW(gMruMenu, MF_STRING or MF_GRAYED, 0, '(empty)')
  else
  begin
    Sep(gMruMenu);
    Item(gMruMenu, IDM_MRU_CLEAR, '&Clear Recent Files');
  end;
end;

procedure MruRemove(idx: Integer);
var
  i: Integer;
begin
  for i := idx to MRU_MAX - 2 do gMru[i] := gMru[i + 1];
  gMru[MRU_MAX - 1] := '';
  MruRebuild;
end;

procedure MruAdd(const fn: UnicodeString);
var
  i, j: Integer;
  f: UnicodeString;
begin
  if fn = '' then Exit;
  f := fn;                            // fn може да е самият gMru[x]
  j := MRU_MAX - 1;
  for i := 0 to MRU_MAX - 1 do
    if SameFile(gMru[i], f) then begin j := i; Break; end;
  for i := j downto 1 do gMru[i] := gMru[i - 1];
  gMru[0] := f;
  MruRebuild;
end;

{ ======================= външни промени на файла ======================= }

function ReadStamp(const fn: UnicodeString; out d: TFileAttrData): Boolean;
begin
  FillChar(d, SizeOf(d), 0);
  Result := GetFileAttributesExW(PWideChar(fn), 0, @d);
end;

procedure TakeStamp;
begin
  gHaveStamp := (gFile <> '') and ReadStamp(gFile, gStamp);
end;

function StampChanged(const a, b: TFileAttrData): Boolean;
begin
  Result := (a.ftLastWriteTime.dwLowDateTime  <> b.ftLastWriteTime.dwLowDateTime) or
            (a.ftLastWriteTime.dwHighDateTime <> b.ftLastWriteTime.dwHighDateTime) or
            (a.nFileSizeLow <> b.nFileSizeLow) or (a.nFileSizeHigh <> b.nFileSizeHigh);
end;

{ ======================= autosave / възстановяване ======================= }

{ Всяка инстанция държи свой recovery-<pid>.trp заключен (share 0).
  Ако програмата умре, заключването изчезва и следващото стартиране
  го намира. При нормален изход файлът се изтрива. }

function RecoveryDir: UnicodeString;
var
  buf: array[0..MAX_PATHBUF-1] of WideChar;
  n: DWORD;
begin
  n := GetEnvironmentVariableW('LOCALAPPDATA', @buf[0], MAX_PATHBUF);
  if (n = 0) or (n >= MAX_PATHBUF) then
    n := GetTempPathW(MAX_PATHBUF, @buf[0]);
  Result := PWideChar(@buf[0]);
  while (Result <> '') and (Result[Length(Result)] = '\') do
    SetLength(Result, Length(Result) - 1);
  Result := Result + '\TinyRetroPad';
end;

procedure RecoveryWrite(const data: TBytes);
var
  w: DWORD;
begin
  if gRecHandle = INVALID_HANDLE_VALUE then
  begin
    if Length(data) = 0 then Exit;
    CreateDirectoryW(PWideChar(RecoveryDir), nil);
    gRecFile := RecoveryDir + '\recovery-' + IStr(GetCurrentProcessId) + '.trp';
    gRecHandle := CreateFileW(PWideChar(gRecFile), GENERIC_WRITE, 0, nil,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
    if gRecHandle = INVALID_HANDLE_VALUE then Exit;
  end;
  SetFilePointer(gRecHandle, 0, nil, FILE_BEGIN);
  w := 0;
  if Length(data) > 0 then WriteFile(gRecHandle, data[0], Length(data), w, nil);
  SetEndOfFile(gRecHandle);
  FlushFileBuffers(gRecHandle);
end;

procedure RecoveryClear;              // документът е записан - снимката е излишна
begin
  gRecPending := False;
  RecoveryWrite(nil);
end;

procedure RecoverySnapshot;
var
  s: UnicodeString;
  lossy: Boolean;
begin
  if not gRecPending then Exit;
  gRecPending := False;
  if not fDirty then begin RecoveryClear; Exit; end;
  s := 'TRPAD1'#9 + IStr(Ord(gEnc)) + #9 + IStr(Ord(gEol)) + #9 + gFile + #10 +
       GetEditText;
  RecoveryWrite(EncodeText(s, encUTF16LE, lossy));
end;

procedure RecoveryClose;
begin
  if gRecHandle = INVALID_HANDLE_VALUE then Exit;
  CloseHandle(gRecHandle);
  gRecHandle := INVALID_HANDLE_VALUE;
  DeleteFileW(PWideChar(gRecFile));
end;

{ ======================= файлове ======================= }

function PickFile(save: Boolean; var fn: UnicodeString): Boolean;
var
  ofn: TOpenFilenameW;
  buf: array[0..MAX_PATHBUF-1] of WideChar;
  n: Integer;
begin
  FillChar(ofn, SizeOf(ofn), 0);
  FillChar(buf, SizeOf(buf), 0);
  n := Length(fn);
  if n >= MAX_PATHBUF then n := MAX_PATHBUF - 1;
  if save and (n > 0) then Move(fn[1], buf[0], n * 2);
  ofn.lStructSize := SizeOf(ofn);
  ofn.hwndOwner   := hMain;
  ofn.lpstrFilter := FileFilter;
  ofn.lpstrFile   := @buf[0];
  ofn.nMaxFile    := MAX_PATHBUF;
  if save then
  begin
    ofn.nFilterIndex := 1;
    ofn.lpstrDefExt  := 'txt';
    ofn.Flags := OFN_PATHMUSTEXIST or OFN_HIDEREADONLY or OFN_OVERWRITEPROMPT;
    Result := GetSaveFileNameW(@ofn);
  end
  else
  begin
    ofn.nFilterIndex := 2;            // All Files - за .pas, .ini и т.н.
    ofn.Flags := OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_HIDEREADONLY;
    Result := GetOpenFileNameW(@ofn);
  end;
  if Result then fn := PWideChar(@buf[0]);
end;

function LoadFile(const fn: UnicodeString): Boolean;
var
  hFile: THandle;
  size, hi, got: DWORD;
  buf: PByte;
  text: UnicodeString;
  enc: TEncoding;
  eol: TEol;
  seen: Boolean;
  cr: TCharRange;
  rp: LongInt;
begin
  Result := False;
  hFile := CreateFileW(PWideChar(fn), GENERIC_READ,
             FILE_SHARE_READ or FILE_SHARE_WRITE, nil,
             OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if hFile = INVALID_HANDLE_VALUE then
  begin
    MsgBox('Cannot open file:'#13#10 + fn, MB_OK or MB_ICONERROR);
    Exit;
  end;
  hi := 0;
  size := GetFileSize(hFile, @hi);
  if (size = $FFFFFFFF) or (hi <> 0) or (size > MAX_FILESIZE) then
  begin
    CloseHandle(hFile);
    MsgBox('File is too large:'#13#10 + fn, MB_OK or MB_ICONERROR);
    Exit;
  end;
  GetMem(buf, size + 2);
  got := 0;
  if not ReadFile(hFile, buf^, size, got, nil) then got := 0;
  CloseHandle(hFile);

  DecodeBytes(buf, got, text, enc);
  FreeMem(buf);
  seen := False;
  text := ConvertEol(text, eolCRLF, @seen, eol);   // RichEdit иска CRLF

  fLoading := True;
  SendMessageW(hEdit, WM_SETTEXT, 0, LPARAM(PWideChar(text)));
  ApplyCharFormat;                    // шрифтът вече не се връща на Courier
  EdMsg(EM_EMPTYUNDOBUFFER, 0, 0);    // Ctrl+Z да не изтрие целия файл
  cr.cpMin := 0; cr.cpMax := 0;
  EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  fLoading := False;

  gFile := FullPath(fn);
  gEnc := enc;
  gEol := eol;
  fDirty := False;
  // има ли запомнена позиция на четене за този файл?
  rp := LoadReadPos(gFile);
  if (rp > 0) and (rp < TextLenInternal) then
  begin
    cr.cpMin := rp; cr.cpMax := rp;
    EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
    EdMsg(EM_SCROLLCARET, 0, 0);
    gStatusNote := 'Reading position restored - Ctrl+R continues from here';
  end;
  MruAdd(gFile);
  TakeStamp;
  RecoveryClear;
  ApplyTitle;
  SyncMenus;
  UpdateStatus;
  ScheduleStats;
  Result := True;
end;

function SaveTo(const fn: UnicodeString): Boolean;
var
  hFile: THandle;
  data: TBytes;
  written: DWORD;
  lossy: Boolean;
  text: UnicodeString;
  first: TEol;
begin
  Result := False;
  text := ConvertEol(GetEditText, gEol, nil, first);
  data := EncodeText(text, gEnc, lossy);
  if lossy then
    case MsgBox('This file contains characters that cannot be saved in ANSI ' +
                'encoding and will be lost.'#13#10#13#10 +
                'Save as UTF-8 instead?', MB_YESNOCANCEL or MB_ICONWARNING) of
      IDYES:
        begin
          gEnc := encUTF8;
          data := EncodeText(text, gEnc, lossy);
          SyncMenus;
        end;
      IDCANCEL: Exit;
    end;

  hFile := CreateFileW(PWideChar(fn), GENERIC_WRITE, 0, nil,
                       CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if hFile = INVALID_HANDLE_VALUE then
  begin
    MsgBox('Cannot save file:'#13#10 + fn, MB_OK or MB_ICONERROR);
    Exit;
  end;
  written := 0;
  if Length(data) > 0 then
    WriteFile(hFile, data[0], Length(data), written, nil);
  CloseHandle(hFile);
  if written <> DWORD(Length(data)) then
  begin
    MsgBox('Error writing file:'#13#10 + fn, MB_OK or MB_ICONERROR);
    Exit;
  end;
  gFile := FullPath(fn);
  fDirty := False;
  MruAdd(gFile);
  TakeStamp;                          // собственият запис не е "външна промяна"
  RecoveryClear;
  ApplyTitle;
  UpdateStatus;
  Result := True;
end;

function CmdSaveAs: Boolean;
var
  fn: UnicodeString;
begin
  fn := gFile;
  Result := PickFile(True, fn) and SaveTo(fn);
end;

function CmdSave: Boolean;
begin
  if gFile = '' then Result := CmdSaveAs
  else Result := SaveTo(gFile);
end;

{ ---- dirty prompt: True = продължи, False = cancel ---- }
function MaybeSaveChanges: Boolean;
begin
  Result := True;
  if not fDirty then Exit;
  case MsgBox('Do you want to save changes to ' + DocTitle + '?',
              MB_YESNOCANCEL or MB_ICONQUESTION) of
    IDCANCEL: Exit(False);
    IDNO:     Exit(True);
  end;
  Result := CmdSave;
end;

procedure NewFile;
begin
  fLoading := True;
  SendMessageW(hEdit, WM_SETTEXT, 0, LPARAM(PWideChar(UnicodeString(''))));
  ApplyCharFormat;
  EdMsg(EM_EMPTYUNDOBUFFER, 0, 0);
  fLoading := False;
  gFile := '';
  gEnc := encUTF8;
  gEol := eolCRLF;
  fDirty := False;
  gHaveStamp := False;
  RecoveryClear;
  ApplyTitle;
  SyncMenus;
  UpdateStatus;
  ScheduleStats;
end;

procedure OpenPath(const fn: UnicodeString);
begin
  if MaybeSaveChanges then LoadFile(fn);
end;

{ ---- команден ред: всичко след exe-то (с или без кавички) ---- }
function ParseStartupFile: UnicodeString;
var
  s: PWideChar;
  n: Integer;
begin
  Result := '';
  s := GetCommandLineW;
  if s = nil then Exit;
  if s^ = '"' then
  begin                               // skip quoted exe path
    Inc(s);
    while (s^ <> #0) and (s^ <> '"') do Inc(s);
    if s^ = '"' then Inc(s);
  end
  else                                // skip bare exe path
    while (s^ <> #0) and (s^ <> ' ') and (s^ <> #9) do Inc(s);
  while (s^ = ' ') or (s^ = #9) do Inc(s);
  if s^ = #0 then Exit;

  if s^ = '"' then
  begin
    Inc(s);
    while (s^ <> #0) and (s^ <> '"') do
    begin Result := Result + s^; Inc(s); end;
  end
  else
  begin                               // като Notepad: пътят може да има интервали
    Result := s;
    n := Length(Result);
    while (n > 0) and ((Result[n] = ' ') or (Result[n] = #9)) do Dec(n);
    SetLength(Result, n);
  end;
end;

{ ======================= редактиране ======================= }

{ ---- Edit > Time/Date: вмъква локални дата и час при курсора ---- }
procedure InsertTimeDate;
var
  st: TSystemTime;
  db, tb: array[0..63] of WideChar;
  t: UnicodeString;
begin
  GetLocalTime(@st);
  GetTimeFormatW(LOCALE_USER_DEFAULT, TIME_NOSECONDS, @st, nil, @tb[0], 64);
  GetDateFormatW(LOCALE_USER_DEFAULT, DATE_SHORTDATE, @st, nil, @db[0], 64);
  t := UnicodeString(PWideChar(@tb[0])) + ' ' + UnicodeString(PWideChar(@db[0]));   // като Notepad: час дата
  EdMsg(EM_REPLACESEL, WPARAM(True), LPARAM(PWideChar(t)));
end;

{ ---- Format > Font: common dialog -> EM_SETCHARFORMAT ---- }
procedure ChooseFontDlg;
var
  lf: LOGFONTW;
  cf: TChooseFontW;
begin
  FillChar(cf, SizeOf(cf), 0);
  FillChar(lf, SizeOf(lf), 0);
  // диалогът тръгва от текущия шрифт
  lf.lfHeight := -MulDiv(RichFont.yHeight, gDpi, 1440);
  if (RichFont.dwEffects and CFE_BOLD) <> 0 then lf.lfWeight := 700
  else lf.lfWeight := 400;
  if (RichFont.dwEffects and CFE_ITALIC) <> 0 then lf.lfItalic := 1;
  lf.lfCharSet := DEFAULT_CHARSET;
  Move(RichFont.szFaceName, lf.lfFaceName, SizeOf(lf.lfFaceName));

  cf.lStructSize := SizeOf(cf);
  cf.hwndOwner   := hMain;
  cf.lpLogFont   := @lf;
  cf.Flags       := CF_SCREENFONTS_F or CF_INITTOLOGFONTSTRUCT_F;
  if not ChooseFontW(@cf) then Exit;

  RichFont.dwEffects := 0;
  if lf.lfWeight >= 700 then RichFont.dwEffects := RichFont.dwEffects or CFE_BOLD;
  if lf.lfItalic <> 0   then RichFont.dwEffects := RichFont.dwEffects or CFE_ITALIC;
  RichFont.yHeight := cf.iPointSize * 2;   // twips = 1/10 pt * 2
  Move(lf.lfFaceName, RichFont.szFaceName, SizeOf(lf.lfFaceName));
  ApplyCharFormat;
{$IFDEF FEAT_LINENUMBERS}
  LnInvalidate;
{$ENDIF}
end;

procedure SetZoom(pct: Integer);
begin
  if pct < 10 then pct := 10;
  if pct > 500 then pct := 500;
  if pct = 100 then EdMsg(EM_SETZOOM, 0, 0)
  else EdMsg(EM_SETZOOM, pct, 100);
  UpdateStatus;
{$IFDEF FEAT_LINENUMBERS}
  LnInvalidate;
{$ENDIF}
end;

{ ======================= Find / Replace ======================= }

procedure InitFR;
begin
  FillChar(fr, SizeOf(fr), 0);
  fr.lStructSize      := SizeOf(fr);
  fr.lpstrFindWhat    := @FindWhat[0];
  fr.wFindWhatLen     := Length(FindWhat);
  fr.lpstrReplaceWith := @ReplaceWith[0];
  fr.wReplaceWithLen  := Length(ReplaceWith);
  fr.Flags            := FR_DOWN;
end;

// селекцията (ако е на един ред) става текст за търсене
procedure SeedFindFromSelection;
var
  cr: TCharRange;
  buf: array[0..255] of WideChar;
  i: Integer;
begin
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  if (cr.cpMax <= cr.cpMin) or (cr.cpMax - cr.cpMin >= 255) then Exit;
  FillChar(buf, SizeOf(buf), 0);
  EdMsg(EM_GETSELTEXT, 0, LPARAM(@buf[0]));
  for i := 0 to 254 do
    if (buf[i] = #13) or (buf[i] = #10) then Exit
    else if buf[i] = #0 then Break;
  Move(buf, FindWhat, SizeOf(FindWhat));
end;

function DoFind(down, wrap, silent: Boolean): Boolean;
var
  cr: TCharRange;
  ft: TFindTextExW;
  fl: DWORD;
  pos: LRESULT;
begin
  Result := False;
  if FindWhat[0] = #0 then Exit;
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  fl := fr.Flags and (FR_MATCHCASE or FR_WHOLEWORD);   // whole word вече работи
  ft.lpstrText := @FindWhat[0];
  if down then
  begin
    fl := fl or FR_DOWN;
    ft.chrg.cpMin := cr.cpMax;        // от края на селекцията надолу
    ft.chrg.cpMax := -1;
  end
  else
  begin
    ft.chrg.cpMin := cr.cpMin;        // от началото на селекцията нагоре
    ft.chrg.cpMax := 0;
  end;
  pos := EdMsg(EM_FINDTEXTEXW, fl, LPARAM(@ft));
  if (pos = -1) and wrap then         // wrap-around
  begin
    if down then begin ft.chrg.cpMin := 0; ft.chrg.cpMax := -1; end
    else begin ft.chrg.cpMin := TextLenInternal; ft.chrg.cpMax := 0; end;
    pos := EdMsg(EM_FINDTEXTEXW, fl, LPARAM(@ft));
  end;
  if pos = -1 then
  begin
    if not silent then
      MsgBox('Cannot find "' + UnicodeString(PWideChar(@FindWhat[0])) + '"',
             MB_OK or MB_ICONINFORMATION);
    Exit;
  end;
  EdMsg(EM_EXSETSEL, 0, LPARAM(@ft.chrgText));
  EdMsg(EM_SCROLLCARET, 0, 0);
  Result := True;
end;

// дали текущата селекция е точно търсеният текст
function SelectionMatches: Boolean;
var
  cr: TCharRange;
  ft: TFindTextExW;
begin
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  Result := False;
  if cr.cpMax <= cr.cpMin then Exit;
  ft.chrg := cr;
  ft.lpstrText := @FindWhat[0];
  if EdMsg(EM_FINDTEXTEXW, FR_DOWN or (fr.Flags and (FR_MATCHCASE or FR_WHOLEWORD)),
           LPARAM(@ft)) <> cr.cpMin then Exit;
  Result := ft.chrgText.cpMax = cr.cpMax;
end;

procedure DoReplaceOne;
begin
  // заменя само ако селекцията наистина е съвпадение (1.0 заменяше
  // каквото и да е маркирано)
  if SelectionMatches then
    EdMsg(EM_REPLACESEL, WPARAM(True), LPARAM(@ReplaceWith[0]));
  DoFind(True, True, False);
end;

procedure DoReplaceAll;
var
  cr: TCharRange;
  n: Integer;
begin
  n := 0;
  cr.cpMin := 0; cr.cpMax := 0;       // от началото
  EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  SendMessageW(hEdit, WM_SETREDRAW, 0, 0);
  while DoFind(True, False, True) do
  begin
    EdMsg(EM_REPLACESEL, WPARAM(True), LPARAM(@ReplaceWith[0]));
    Inc(n);
  end;
  SendMessageW(hEdit, WM_SETREDRAW, 1, 0);
  InvalidateRect(hEdit, nil, True);
  MsgBox('Replaced ' + IStr(n) + ' occurrence(s).', MB_OK or MB_ICONINFORMATION);
end;

procedure OnFindReplaceMsg;
begin
  if (fr.Flags and FR_DIALOGTERM) <> 0 then begin hFindDlg := 0; Exit; end;
  if (fr.Flags and FR_REPLACEALL) <> 0 then begin DoReplaceAll; Exit; end;
  if (fr.Flags and FR_REPLACE)    <> 0 then begin DoReplaceOne; Exit; end;
  DoFind(fFindIsReplace or ((fr.Flags and FR_DOWN) <> 0), True, False);
end;

procedure OpenFindDlg(replace: Boolean);
begin
  if hFindDlg <> 0 then
  begin
    if fFindIsReplace = replace then begin SetFocus(hFindDlg); Exit; end;
    DestroyWindow(hFindDlg);
    hFindDlg := 0;
  end;
  SeedFindFromSelection;
  // пазим опциите между отварянията, махаме само еднократните флагове
  fr.Flags := fr.Flags and (FR_DOWN or FR_MATCHCASE or FR_WHOLEWORD);
  fr.hwndOwner := hMain;
  fFindIsReplace := replace;
  if replace then hFindDlg := ReplaceTextW(@fr)
  else hFindDlg := FindTextW(@fr);
end;

procedure CmdFindNext(down: Boolean);
begin
  if FindWhat[0] = #0 then OpenFindDlg(False)
  else DoFind(down, True, False);
end;

{ ======================= печат ======================= }

procedure PageSetup;
var
  psd: TPageSetupDlgW;
begin
  FillChar(psd, SizeOf(psd), 0);
  psd.lStructSize := SizeOf(psd);
  psd.hwndOwner   := hMain;
  psd.hDevMode    := gDevMode;
  psd.hDevNames   := gDevNames;
  psd.Flags       := PSD_MARGINS or PSD_INHUNDREDTHSOFMILLIMETERS;
  psd.rtMargin    := gMargins;
  if PageSetupDlgW(@psd) then
  begin
    gMargins  := psd.rtMargin;        // 1.0 изхвърляше резултата
    gDevMode  := psd.hDevMode;
    gDevNames := psd.hDevNames;
  end;
end;

procedure PrintDoc;
var
  pd: TPrintDlgW;
  di: DOCINFOW;
  fmt: TFormatRange;
  cr: TCharRange;
  dc: HDC;
  dpiX, dpiY, offX, offY, physW, physH, resW, resH: Integer;
  rcMargin, rcText: TRect;
  cur, endPos, next, start: LongInt;
  docName, dateStr, t: UnicodeString;
  hHdrFont: HFONT;
  oldF: HGDIOBJ;
  fontPx, hdrTw, pages, pageNo, xl, xr, yt, yb: Integer;
  withHdr: Boolean;
  st: TSystemTime;
  dbuf: array[0..63] of WideChar;

  function TwX(px: Integer): Integer; begin Result := MulDiv(px, 1440, dpiX); end;
  function TwY(px: Integer): Integer; begin Result := MulDiv(px, 1440, dpiY); end;
  function MmTw(mm100: Integer): Integer; begin Result := MulDiv(mm100, 1440, 2540); end;

begin
  FillChar(pd, SizeOf(pd), 0);
  pd.lStructSize := SizeOf(pd);
  pd.hwndOwner   := hMain;
  pd.hDevMode    := gDevMode;
  pd.hDevNames   := gDevNames;
  pd.nCopies     := 1;
  pd.Flags       := PD_RETURNDC_F or PD_NOPAGENUMS_F;
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  if cr.cpMax <= cr.cpMin then pd.Flags := pd.Flags or PD_NOSELECTION_F;
  if not PrintDlgW(@pd) then Exit;
  gDevMode  := pd.hDevMode;
  gDevNames := pd.hDevNames;
  dc := pd.hDC;
  if dc = 0 then Exit;

  dpiX  := GetDeviceCaps(dc, LOGPIXELSX);
  dpiY  := GetDeviceCaps(dc, LOGPIXELSY);
  offX  := GetDeviceCaps(dc, PHYSICALOFFSETX);
  offY  := GetDeviceCaps(dc, PHYSICALOFFSETY);
  physW := GetDeviceCaps(dc, PHYSICALWIDTH);
  physH := GetDeviceCaps(dc, PHYSICALHEIGHT);
  resW  := GetDeviceCaps(dc, HORZRES);
  resH  := GetDeviceCaps(dc, VERTRES);

  // полетата от Page Setup, в twips, спрямо печатаемата област
  rcMargin.Left   := MmTw(gMargins.Left) - TwX(offX);
  rcMargin.Top    := MmTw(gMargins.Top) - TwY(offY);
  rcMargin.Right  := TwX(physW - offX) - MmTw(gMargins.Right);
  rcMargin.Bottom := TwY(physH - offY) - MmTw(gMargins.Bottom);
  if rcMargin.Left < 0 then rcMargin.Left := 0;
  if rcMargin.Top < 0 then rcMargin.Top := 0;
  if rcMargin.Right > TwX(resW) then rcMargin.Right := TwX(resW);
  if rcMargin.Bottom > TwY(resH) then rcMargin.Bottom := TwY(resH);

  if (pd.Flags and PD_SELECTION_F) <> 0 then
  begin cur := cr.cpMin; endPos := cr.cpMax; end
  else
  begin cur := 0; endPos := TextLenInternal; end;
  start := cur;

  // колонтитули: име на файла и дата горе, "Page N of M" долу
  fontPx := MulDiv(9, dpiY, 72);
  hdrTw := TwY(fontPx * 2);
  rcText := rcMargin;
  Inc(rcText.Top, hdrTw);
  Dec(rcText.Bottom, hdrTw);
  withHdr := rcText.Bottom - rcText.Top > TwY(fontPx * 6);
  if not withHdr then rcText := rcMargin;

  // първо преброяваме страниците (EM_FORMATRANGE без рисуване)
  pages := 0;
  repeat
    FillChar(fmt, SizeOf(fmt), 0);
    fmt.hdc := dc; fmt.hdcTarget := dc;
    fmt.rc := rcText;
    fmt.rcPage.Right := TwX(resW); fmt.rcPage.Bottom := TwY(resH);
    fmt.chrg.cpMin := cur; fmt.chrg.cpMax := endPos;
    next := EdMsg(EM_FORMATRANGE, 0, LPARAM(@fmt));
    Inc(pages);
    if next <= cur then Break;
    cur := next;
  until cur >= endPos;
  EdMsg(EM_FORMATRANGE, 0, 0);
  cur := start;

  GetLocalTime(@st);
  GetDateFormatW(LOCALE_USER_DEFAULT, DATE_SHORTDATE, @st, nil, @dbuf[0], 64);
  dateStr := PWideChar(@dbuf[0]);
  hHdrFont := CreateFontW(-fontPx, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET,
             OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY,
             DEFAULT_PITCH, 'Segoe UI');
  xl := MulDiv(rcMargin.Left, dpiX, 1440);
  xr := MulDiv(rcMargin.Right, dpiX, 1440);
  yt := MulDiv(rcMargin.Top, dpiY, 1440);
  yb := MulDiv(rcMargin.Bottom, dpiY, 1440) - fontPx;
  pageNo := 0;
  // 1.0 ползваше WM_GETTEXTLENGTH (броi CRLF за 2) -> позицията никога не
  // стигаше края и принтерът вадеше празни страници до безкрай

  docName := DocTitle;
  FillChar(di, SizeOf(di), 0);
  di.cbSize      := SizeOf(di);
  di.lpszDocName := PWideChar(docName);
  if StartDocW(dc, @di) <= 0 then
  begin
    DeleteDC(dc);
    MsgBox('Cannot start printing.', MB_OK or MB_ICONERROR);
    Exit;
  end;

  repeat
    if StartPage(dc) <= 0 then Break;
    FillChar(fmt, SizeOf(fmt), 0);
    fmt.hdc := dc;
    fmt.hdcTarget := dc;
    fmt.rc := rcText;                 // EM_FORMATRANGE променя rc -> всеки път наново
    fmt.rcPage.Right := TwX(resW);
    fmt.rcPage.Bottom := TwY(resH);
    fmt.chrg.cpMin := cur;
    fmt.chrg.cpMax := endPos;
    next := EdMsg(EM_FORMATRANGE, WPARAM(True), LPARAM(@fmt));
    Inc(pageNo);
    if withHdr then
    begin
      oldF := SelectObject(dc, hHdrFont);
      SetBkMode(dc, TRANSPARENT);
      SetTextColor(dc, 0);
      SetTextAlign(dc, TA_LEFT or TA_TOP);
      TextOutW(dc, xl, yt, PWideChar(docName), Length(docName));
      SetTextAlign(dc, TA_RIGHT or TA_TOP);
      TextOutW(dc, xr, yt, PWideChar(dateStr), Length(dateStr));
      t := 'Page ' + IStr(pageNo) + ' of ' + IStr(pages);
      SetTextAlign(dc, TA_CENTER or TA_TOP);
      TextOutW(dc, (xl + xr) div 2, yb, PWideChar(t), Length(t));
      SelectObject(dc, oldF);
    end;
    EndPage(dc);
    if next <= cur then Break;        // предпазител срещу зацикляне
    cur := next;
  until cur >= endPos;

  EdMsg(EM_FORMATRANGE, 0, 0);        // flush formatting cache
  EndDoc(dc);
  DeleteObject(hHdrFont);
  DeleteDC(dc);
end;

{ ======================= Go To ======================= }

var
  GoTmpl: array[0..127] of DWORD;     // DWORD-подравнен буфер за шаблона

{ Шаблонът се сглобява в runtime - подравняването се смята автоматично,
  вместо на ръка като в 1.0 }
function BuildGoToTemplate: Pointer;
var
  p: PWord;
  procedure W(x: Word); begin p^ := x; Inc(p); end;
  procedure D(x: DWORD); begin W(x and $FFFF); W(x shr 16); end;
  procedure Str_(const t: UnicodeString);
  var i: Integer;
  begin
    for i := 1 to Length(t) do W(Word(t[i]));
    W(0);
  end;
  procedure Align4; begin if (PtrUInt(p) and 3) <> 0 then W(0); end;
  procedure Item(style: DWORD; x, y, cx, cy: SmallInt; id, atom: Word;
    const title: UnicodeString);
  begin
    Align4;
    D(style); D(0);
    W(Word(x)); W(Word(y)); W(Word(cx)); W(Word(cy));
    W(id);
    W($FFFF); W(atom);
    Str_(title);
    W(0);                             // creation data
  end;
begin
  FillChar(GoTmpl, SizeOf(GoTmpl), 0);
  p := @GoTmpl[0];
  D(DS_MODALFRAME or DS_CENTER or DS_SETFONT or WS_POPUP or WS_CAPTION or WS_SYSMENU);
  D(0);
  W(4);                               // items
  W(0); W(0); W(160); W(56);
  W(0); W(0);                         // menu, class
  Str_('Go To Line');
  W(9); Str_('Segoe UI');             // DS_SETFONT
  Item(WS_CHILD or WS_VISIBLE, 7, 7, 146, 9, $FFFF, $0082, '&Line number:');
  Item(WS_CHILD or WS_VISIBLE or WS_BORDER or ES_NUMBER or WS_TABSTOP,
       7, 18, 146, 12, IDC_GOEDIT, $0081, '');
  Item(WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON or WS_TABSTOP,
       49, 36, 50, 14, IDOK, $0080, 'OK');
  Item(WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON or WS_TABSTOP,
       103, 36, 50, 14, IDCANCEL, $0080, 'Cancel');
  Result := @GoTmpl[0];
end;

function GoToProc(hDlg: HWND; uMsg: UINT; wParam: WPARAM;
                  lParam: LPARAM): PtrInt; stdcall;
var
  trans: WINBOOL;
  n: UINT;
begin
  Result := 1;
  case uMsg of
    WM_INITDIALOG:
      begin                           // попълва текущия ред
        SetDlgItemInt(hDlg, IDC_GOEDIT, lParam, False);
        SendDlgItemMessageW(hDlg, IDC_GOEDIT, EM_SETSEL, 0, -1);
        SetFocus(GetDlgItem(hDlg, IDC_GOEDIT));
        Exit(0);
      end;
    WM_COMMAND:
      case LoWrd(wParam) of
        IDOK:
          begin
            trans := False;
            n := GetDlgItemInt(hDlg, IDC_GOEDIT, trans, False);
            if (not trans) or (n = 0) or (LongInt(n) > gLineCount) then
            begin
              MessageBoxW(hDlg, 'The line number is beyond the total number of lines',
                          'TinyRetroPad - Go To Line', MB_OK or MB_ICONWARNING);
              Exit;
            end;
            EndDialog(hDlg, n);
            Exit;
          end;
        IDCANCEL: begin EndDialog(hDlg, 0); Exit; end;
      end;
  end;
  Result := 0;
end;

procedure GoToDlg;
var
  line, idx: LongInt;
  cr: TCharRange;
begin
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  gLineCount := EdMsg(EM_GETLINECOUNT, 0, 0);
  line := DialogBoxIndirectParamW(hInstApp, BuildGoToTemplate, hMain,
            @GoToProc, EdMsg(EM_EXLINEFROMCHAR, 0, cr.cpMax) + 1);
  if line <= 0 then Exit;             // cancel
  idx := EdMsg(EM_LINEINDEX, line - 1, 0);
  if idx = -1 then Exit;
  cr.cpMin := idx; cr.cpMax := idx;
  EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  EdMsg(EM_SCROLLCARET, 0, 0);
  SetFocus(hEdit);
end;

{ ======================= външни промени / recovery ======================= }

procedure CheckExternalChange;
var
  d: TFileAttrData;
  q: UnicodeString;
  cr: TCharRange;
  fn: UnicodeString;
begin
  if fChecking or (gFile = '') or not gHaveStamp then Exit;
  if not ReadStamp(gFile, d) then Exit;        // изтрит/недостъпен - мълчим
  if not StampChanged(d, gStamp) then Exit;
  gStamp := d;                                 // питаме веднъж за промяна
  fChecking := True;
  try
    q := gFile + #13#10#13#10'This file has been modified by another program.'#13#10;
    if fDirty then q := q + 'Reload it and lose your unsaved changes?'
    else q := q + 'Do you want to reload it?';
    if MsgBox(q, MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
      EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
      fn := gFile;                    // копие - LoadFile презаписва gFile
      if LoadFile(fn) then
      begin
        EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
        EdMsg(EM_SCROLLCARET, 0, 0);
      end;
    end;
  finally
    fChecking := False;
  end;
end;

function RecoveryRestore: Boolean;
var
  fd: TWin32FindDataW;
  hf, h: THandle;
  dir, fn, s, head, path: UnicodeString;
  size, got: DWORD;
  buf: PByte;
  enc: TEncoding;
  p, e, l: Integer;
  q: UnicodeString;
begin
  Result := False;
  dir := RecoveryDir;
  hf := FindFirstFileW(PWideChar(dir + '\recovery-*.trp'), fd);
  if hf = INVALID_HANDLE_VALUE then Exit;
  repeat
    fn := dir + '\' + UnicodeString(PWideChar(@fd.cFileName[0]));
    if SameFile(fn, gRecFile) then Continue;
    // заключен = другата инстанция е жива
    h := CreateFileW(PWideChar(fn), GENERIC_READ, 0, nil, OPEN_EXISTING, 0, 0);
    if h = INVALID_HANDLE_VALUE then Continue;
    s := '';
    size := GetFileSize(h, nil);
    if (size > 2) and (size < MAX_FILESIZE) then
    begin
      GetMem(buf, size);
      got := 0;
      if not ReadFile(h, buf^, size, got, nil) then got := 0;
      DecodeBytes(buf, got, s, enc);
      FreeMem(buf);
    end;
    CloseHandle(h);

    p := Pos(#10, s);
    if (p < 12) or (Copy(s, 1, 7) <> 'TRPAD1'#9) or (s[9] <> #9) or (s[11] <> #9) then
    begin
      DeleteFileW(PWideChar(fn));     // празен (чисто записан) или чужд файл
      Continue;
    end;
    head := Copy(s, 1, p - 1);
    Delete(s, 1, p);
    e := Ord(head[8]) - Ord('0');
    l := Ord(head[10]) - Ord('0');
    path := Copy(head, 12, MaxInt);

    q := 'TinyRetroPad was not closed properly.'#13#10#13#10'Restore the unsaved text';
    if path <> '' then q := q + ' of'#13#10 + path;
    q := q + '?';
    if MsgBox(q, MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
      fLoading := True;
      SendMessageW(hEdit, WM_SETTEXT, 0, LPARAM(PWideChar(s)));
      ApplyCharFormat;
      EdMsg(EM_EMPTYUNDOBUFFER, 0, 0);
      fLoading := False;
      gFile := path;
      if (e >= 0) and (e <= Ord(High(TEncoding))) then gEnc := TEncoding(e);
      if (l >= 0) and (l <= Ord(High(TEol))) then gEol := TEol(l);
      fDirty := True;                 // още не е записан
      gRecPending := True;
      TakeStamp;
      ApplyTitle;
      SyncMenus;
      UpdateStatus;
      ScheduleStats;
      Result := True;
    end;
    DeleteFileW(PWideChar(fn));
    if Result then Break;
  until not FindNextFileW(hf, fd);
  Windows.FindClose(hf);
end;

{ ======================= главни / малки букви ======================= }

procedure ChangeCase(mode: Integer);    // 0 UPPER, 1 lower, 2 Title Case
var
  cr: TCharRange;
  s: UnicodeString;
  i: Integer;
begin
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  if cr.cpMax <= cr.cpMin then begin MessageBeep(MB_OK); Exit; end;
  s := GetRange(cr.cpMin, cr.cpMax);
  if s = '' then Exit;
  UniqueString(s);
  CharLowerBuffW(PWideChar(s), Length(s));        // съобразено с езика
  case mode of
    0: CharUpperBuffW(PWideChar(s), Length(s));
    2: for i := 1 to Length(s) do
         if IsCharAlphaW(s[i]) and ((i = 1) or not (IsCharAlphaNumericW(s[i - 1]) or
            (s[i - 1] = '''') or (s[i - 1] = #$2019))) then
           CharUpperBuffW(@s[i], 1);
  end;
  ReplaceRange(cr.cpMin, cr.cpMax, s, True);
end;

{ ======================= транслитерация ======================= }

const
  // а..я -> латиница (Закон за транслитерацията, 2009)
  LatOfCyr: array[0..31] of UnicodeString = (
    'a', 'b', 'v', 'g', 'd', 'e', 'zh', 'z', 'i', 'y', 'k', 'l', 'm', 'n', 'o', 'p', 'r', 's', 't', 'u', 'f', 'h', 'ts', 'ch', 'sh', 'sht', 'a', 'y', 'y', 'e', 'yu', 'ya');
  LatSeq: array[0..32] of UnicodeString = (
    'sht', 'zh', 'ts', 'ch', 'sh', 'yu', 'ya', 'a', 'b', 'v', 'g', 'd', 'e', 'z', 'i', 'y', 'k', 'l', 'm', 'n', 'o', 'p', 'r', 's', 't', 'u', 'f', 'h', 'w', 'x', 'q', 'c', 'j');
  CyrSeq: array[0..32] of UnicodeString = (
    #$0449, #$0436, #$0446, #$0447, #$0448, #$044E, #$044F, #$0430, #$0431, #$0432, #$0433, #$0434, #$0435, #$0437, #$0438, #$0439, #$043A, #$043B, #$043C, #$043D, #$043E, #$043F, #$0440, #$0441, #$0442, #$0443, #$0444, #$0445, #$0432, #$043A#$0441, #$043A, #$0446, #$0434#$0436);
  CyrIA: UnicodeString = #$0438#$044F;
  CyrBulgaria: UnicodeString = #$0431#$044A#$043B#$0433#$0430#$0440#$0438#$044F;  // българия

function IsUpperCyr(c: WideChar): Boolean; inline;
begin
  Result := ((Ord(c) >= $0410) and (Ord(c) <= $042F)) or
            ((Ord(c) >= $0400) and (Ord(c) <= $040F));
end;

function IsAsciiLetter(c: WideChar): Boolean; inline;
begin
  Result := ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z'));
end;

function IsAsciiUpper(c: WideChar): Boolean; inline;
begin
  Result := (c >= 'A') and (c <= 'Z');
end;

function AsciiLower(const s: UnicodeString): UnicodeString;
var
  i: Integer;
begin
  Result := s;
  UniqueString(Result);
  for i := 1 to Length(Result) do
    if IsAsciiUpper(Result[i]) then Result[i] := WideChar(Ord(Result[i]) + 32);
end;

function UpperFirst(const s: UnicodeString; all: Boolean): UnicodeString;
begin
  Result := s;
  UniqueString(Result);
  if Result = '' then Exit;
  if all then CharUpperBuffW(PWideChar(Result), Length(Result))
  else CharUpperBuffW(PWideChar(Result), 1);
end;

function LowerStr(const s: UnicodeString): UnicodeString;
begin
  Result := s;
  UniqueString(Result);
  if Result <> '' then CharLowerBuffW(PWideChar(Result), Length(Result));
end;

function IsWordEnd(const s: UnicodeString; i: Integer): Boolean; inline;
begin                                 // след позиция i няма буква
  Result := (i >= Length(s)) or not IsCharAlphaW(s[i + 1]);
end;

// "Щастие" -> "Shtastie", "ЩАСТИЕ" -> "SHTASTIE", "България" -> "Bulgaria"
function ToLatin(const s: UnicodeString): UnicodeString;
var
  i, n, idx: Integer;
  c: WideChar;
  t: UnicodeString;
  up, allCaps: Boolean;
begin
  Result := '';
  n := Length(s);
  i := 1;
  while i <= n do
  begin
    c := s[i];
    idx := -1;
    if (Ord(c) >= $0430) and (Ord(c) <= $044F) then idx := Ord(c) - $0430
    else if (Ord(c) >= $0410) and (Ord(c) <= $042F) then idx := Ord(c) - $0410;
    if (c = #$045D) or (c = #$040D) then idx := 8;     // ѝ -> i
    if idx < 0 then
    begin
      Result := Result + c;
      Inc(i);
      Continue;
    end;
    up := IsUpperCyr(c) or (c = #$040D);
    // изключение по закона: "България" -> "Bulgaria" (а не "Balgaria")
    if (idx = 1) and ((i = 1) or not IsCharAlphaW(s[i - 1])) and (i + 7 <= n) and
       IsWordEnd(s, i + 7) and (LowerStr(Copy(s, i, 8)) = CyrBulgaria) then
    begin
      t := 'Bulgaria';
      if IsUpperCyr(s[i + 1]) then t := 'BULGARIA'
      else if not up then t := 'bulgaria';
      Result := Result + t;
      Inc(i, 8);
      Continue;
    end;
    // -ия в края на дума -> -ia
    if (idx = 8) and (i < n) and ((s[i + 1] = #$044F) or (s[i + 1] = #$042F)) and
       IsWordEnd(s, i + 1) and (i > 1) and IsCharAlphaW(s[i - 1]) then
    begin
      if up then Result := Result + 'I' else Result := Result + 'i';
      if s[i + 1] = #$042F then Result := Result + 'A' else Result := Result + 'a';
      Inc(i, 2);
      Continue;
    end;
    t := LatOfCyr[idx];
    if up then
    begin
      allCaps := ((i < n) and IsUpperCyr(s[i + 1])) or ((i > 1) and IsUpperCyr(s[i - 1]));
      t := UpperFirst(t, allCaps);
    end;
    Result := Result + t;
    Inc(i);
  end;
end;

// обратното е нееднозначно (a -> а, не ъ), но върши работа
function ToCyrillic(const s: UnicodeString): UnicodeString;
var
  i, n, k, L: Integer;
  c: WideChar;
  t, src: UnicodeString;
  allCaps: Boolean;
begin
  Result := '';
  n := Length(s);
  i := 1;
  while i <= n do
  begin
    c := s[i];
    if not IsAsciiLetter(c) then
    begin
      Result := Result + c;
      Inc(i);
      Continue;
    end;
    t := '';
    L := 1;
    if (i < n) and (AsciiLower(Copy(s, i, 2)) = 'ia') and IsWordEnd(s, i + 1) and
       (i > 1) and IsCharAlphaW(s[i - 1]) then
    begin
      t := CyrIA; L := 2;
    end
    else
      for k := 0 to High(LatSeq) do
      begin
        L := Length(LatSeq[k]);
        if (i + L - 1 <= n) and (AsciiLower(Copy(s, i, L)) = LatSeq[k]) then
        begin
          t := CyrSeq[k];
          Break;
        end;
      end;
    if t = '' then begin t := c; L := 1; end;
    src := Copy(s, i, L);
    if IsAsciiUpper(c) then
    begin
      allCaps := ((L > 1) and IsAsciiUpper(src[L])) or
                 ((L = 1) and (((i < n) and IsAsciiUpper(s[i + 1])) or
                               ((i > 1) and IsAsciiUpper(s[i - 1]))));
      t := UpperFirst(t, allCaps);
    end;
    Result := Result + t;
    Inc(i, L);
  end;
end;

// маркираното, или целият документ
procedure Transliterate(latin: Boolean);
var
  cr: TCharRange;
  a, b: LongInt;
  s, t: UnicodeString;
  sel: Boolean;
begin
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  sel := cr.cpMax > cr.cpMin;
  if sel then begin a := cr.cpMin; b := cr.cpMax; end
  else begin a := 0; b := TextLenInternal; end;
  s := GetRange(a, b);
  if latin then t := ToLatin(s) else t := ToCyrillic(s);
  if t = s then Exit;
  ReplaceRange(a, b, t, sel);
  if not sel then
  begin                               // курсорът да не скача в края
    cr.cpMax := cr.cpMin;
    EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
    EdMsg(EM_SCROLLCARET, 0, 0);
  end;
end;

{ ======================= инструменти за редове ======================= }

type
  TStrArr = array of UnicodeString;

function IsBreak(c: WideChar): Boolean; inline;
begin
  Result := (c = #13) or (c = #10);
end;

procedure SplitLines(const s: UnicodeString; out L: TStrArr);
var
  t: UnicodeString;
  f: TEol;
  i, n, start: Integer;
begin
  t := ConvertEol(s, eolLF, nil, f);
  n := 1;
  for i := 1 to Length(t) do if t[i] = #10 then Inc(n);
  SetLength(L, n);
  n := 0;
  start := 1;
  for i := 1 to Length(t) + 1 do
    if (i > Length(t)) or (t[i] = #10) then
    begin
      L[n] := Copy(t, start, i - start);
      Inc(n);
      start := i + 1;
    end;
end;

function CmpLines(const x, y: UnicodeString): Integer;
begin
  Result := CompareStringW(LOCALE_USER_DEFAULT, NORM_IGNORECASE,
    PWideChar(x), Length(x), PWideChar(y), Length(y)) - 2;
end;

procedure MergeSort(var A: TStrArr; desc: Boolean);
var
  tmp: TStrArr;

  procedure Sort(lo, hi: Integer);
  var
    mid, i, j, k, c: Integer;
  begin
    if hi - lo < 1 then Exit;
    mid := (lo + hi) div 2;
    Sort(lo, mid);
    Sort(mid + 1, hi);
    i := lo; j := mid + 1; k := lo;
    while (i <= mid) and (j <= hi) do
    begin
      c := CmpLines(A[i], A[j]);
      if desc then c := -c;
      if c <= 0 then begin tmp[k] := A[i]; Inc(i); end   // стабилно
      else begin tmp[k] := A[j]; Inc(j); end;
      Inc(k);
    end;
    while i <= mid do begin tmp[k] := A[i]; Inc(i); Inc(k); end;
    while j <= hi do begin tmp[k] := A[j]; Inc(j); Inc(k); end;
    for k := lo to hi do A[k] := tmp[k];
  end;

begin
  SetLength(tmp, Length(A));
  Sort(0, High(A));
end;

{$PUSH}{$Q-}{$R-}                     // FNV хешът разчита на препълване
function HashStr(const s: UnicodeString): DWORD;
var
  i: Integer;
begin
  Result := 2166136261;
  for i := 1 to Length(s) do
    Result := (Result xor Ord(s[i])) * 16777619;
end;
{$POP}

// премахва повторенията, пази първото срещане и реда; връща броя махнати
function Dedup(var A: TStrArr): Integer;
var
  table: array of Integer;
  cap, i, n, h: Integer;
  dup: Boolean;
begin
  cap := 16;
  while cap < Length(A) * 2 do cap := cap * 2;
  SetLength(table, cap);
  for i := 0 to cap - 1 do table[i] := -1;
  n := 0;
  for i := 0 to High(A) do
  begin
    h := HashStr(A[i]) and DWORD(cap - 1);
    dup := False;
    while table[h] >= 0 do
    begin
      if A[table[h]] = A[i] then begin dup := True; Break; end;
      h := (h + 1) and (cap - 1);
    end;
    if dup then Continue;
    A[n] := A[i];
    table[h] := n;
    Inc(n);
  end;
  Result := Length(A) - n;
  SetLength(A, n);
end;

procedure LinesOp(op: Integer);         // 0 сорт ↑, 1 сорт ↓, 2 дубликати, 3 trim
var
  cr: TCharRange;
  a, b, total: LongInt;
  full, sub, joined, orig: UnicodeString;
  L: TStrArr;
  i, k, removed: Integer;
  trailing, sel: Boolean;
begin
  total := TextLenInternal;
  full := GetRange(0, total);
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  sel := (cr.cpMax > cr.cpMin) and (Length(full) = total);
  if sel then
  begin                               // разширяваме до цели редове
    a := cr.cpMin; b := cr.cpMax;
    if (b > a) and IsBreak(full[b]) then Dec(b);
    while (a > 0) and not IsBreak(full[a]) do Dec(a);
    while (b < total) and not IsBreak(full[b + 1]) do Inc(b);
    sub := Copy(full, a + 1, b - a);
  end
  else
  begin
    a := 0; b := total;
    sub := full;
  end;
  trailing := (sub <> '') and IsBreak(sub[Length(sub)]);
  orig := sub;
  if trailing then SetLength(sub, Length(sub) - 1);

  SplitLines(sub, L);
  removed := 0;
  case op of
    0: MergeSort(L, False);
    1: MergeSort(L, True);
    2: removed := Dedup(L);
    3: for i := 0 to High(L) do
       begin
         k := Length(L[i]);
         while (k > 0) and ((L[i][k] = ' ') or (L[i][k] = #9)) do Dec(k);
         SetLength(L[i], k);
       end;
  end;

  joined := '';
  for i := 0 to High(L) do
  begin
    if i > 0 then joined := joined + #13;
    joined := joined + L[i];
  end;
  if trailing then joined := joined + #13;
  if joined <> orig then
    ReplaceRange(a, b, joined, sel);
  if op = 2 then
    MsgBox('Removed ' + IStr(removed) + ' duplicate line(s).', MB_OK or MB_ICONINFORMATION);
end;

{ ======================= четене на глас (SAPI) ======================= }

function HasCyrillic(const s: UnicodeString): Boolean;
var
  i: Integer;
begin
  for i := 1 to Length(s) do
    if (Ord(s[i]) >= $0400) and (Ord(s[i]) <= $04FF) then Exit(True);
  Result := False;
end;

const
  RateNames: array[0..3] of UnicodeString = ('&Slow', '&Normal', '&Fast', '&Very Fast');
  RateValues: array[0..3] of LongInt = (-3, 0, 3, 6);
  VoiceRoots: array[0..1] of UnicodeString = (
    'SOFTWARE\Microsoft\Speech\Voices\Tokens',            // класически SAPI
    'SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens');   // гласовете от Settings

function HexToInt(const s: UnicodeString): Integer;
var
  i, d: Integer;
begin
  Result := 0;
  for i := 1 to Length(s) do
  begin
    case s[i] of
      '0'..'9': d := Ord(s[i]) - Ord('0');
      'a'..'f': d := Ord(s[i]) - Ord('a') + 10;
      'A'..'F': d := Ord(s[i]) - Ord('A') + 10;
    else
      Break;                          // "402;409" -> 402
    end;
    Result := Result * 16 + d;
  end;
end;

{ Четем гласовете директно от registry - и класическите SAPI, и OneCore
  (тези, които Settings -> Speech -> Add voices инсталира). OneCore
  гласовете SAPI сам не ги показва, но ги ползва, ако му дадем token id. }
procedure EnumVoices;
var
  r, i: Integer;
  root, k, ka: HKEY;
  name: array[0..255] of WideChar;
  len: DWORD;
  v: TVoiceInfo;
  idx: DWORD;
begin
  SetLength(gVoices, 0);
  for r := 0 to High(VoiceRoots) do
  begin
    if RegOpenKeyExW(HKEY_LOCAL_MACHINE, PWideChar(VoiceRoots[r]), 0,
                     KEY_READ or KEY_WOW64_64KEY_F, root) <> 0 then Continue;
    idx := 0;
    while Length(gVoices) < MAX_VOICES do
    begin
      len := Length(name);
      if RegEnumKeyExW(root, idx, @name[0], @len, nil, nil, nil, nil) <> 0 then Break;
      Inc(idx);
      v.Id := 'HKEY_LOCAL_MACHINE\' + VoiceRoots[r] + '\' + UnicodeString(PWideChar(@name[0]));
      v.Name := '';
      v.Lang := 0;
      if RegOpenKeyExW(root, @name[0], 0, KEY_READ or KEY_WOW64_64KEY_F, k) = 0 then
      begin
        v.Name := RegGetStr(k, '');
        if RegOpenKeyExW(k, 'Attributes', 0, KEY_READ or KEY_WOW64_64KEY_F, ka) = 0 then
        begin
          v.Lang := HexToInt(RegGetStr(ka, 'Language'));
          RegCloseKey(ka);
        end;
        RegCloseKey(k);
      end;
      if v.Name = '' then v.Name := PWideChar(@name[0]);
      // един и същ глас и в двете места -> показваме го веднъж
      for i := 0 to High(gVoices) do
        if SameFile(gVoices[i].Name, v.Name) then begin v.Name := ''; Break; end;
      if v.Name = '' then Continue;
      SetLength(gVoices, Length(gVoices) + 1);
      gVoices[High(gVoices)] := v;
    end;
    RegCloseKey(root);
  end;
end;

procedure BuildVoiceMenu(hParent: HMENU);
var
  i: Integer;
begin
  gVoiceMenu := CreatePopupMenu;
  Item(gVoiceMenu, IDM_VOICE_AUTO, '&Automatic (by language)');
  Sep(gVoiceMenu);
  if Length(gVoices) = 0 then
    AppendMenuW(gVoiceMenu, MF_STRING or MF_GRAYED, 0, '(no voices installed)')
  else
    for i := 0 to High(gVoices) do
      Item(gVoiceMenu, IDM_VOICE_FIRST + i, EscapeAmp(gVoices[i].Name));
  Sep(gVoiceMenu);
  for i := 0 to High(RateNames) do
    Item(gVoiceMenu, IDM_RATE_FIRST + i, RateNames[i] + ' Speed');
  Sep(gVoiceMenu);
  Item(gVoiceMenu, IDM_SPEAK_HILITE, '&Highlight Spoken Words');
  Item(gVoiceMenu, IDM_SPEAK_REMIND, 'Speak &Reminders');
  Popup(hParent, gVoiceMenu, 'Read Aloud &Voice');
end;

function VoiceIndex(const id: UnicodeString): Integer;
var
  i: Integer;
begin
  for i := 0 to High(gVoices) do
    if SameFile(gVoices[i].Id, id) then Exit(i);
  Result := -1;
end;

procedure SyncVoiceMenu;
var
  sel: Integer;
begin
  if gVoiceMenu = 0 then Exit;
  sel := VoiceIndex(gVoiceSel);
  if sel < 0 then sel := IDM_VOICE_AUTO else sel := IDM_VOICE_FIRST + sel;
  CheckMenuRadioItem(gVoiceMenu, IDM_VOICE_AUTO, IDM_VOICE_LAST, sel, MF_BYCOMMAND);
  CheckMenuRadioItem(gVoiceMenu, IDM_RATE_FIRST, IDM_RATE_LAST,
    IDM_RATE_FIRST + gRateIdx, MF_BYCOMMAND);
  if fSpeakHilite then
    CheckMenuItem(gVoiceMenu, IDM_SPEAK_HILITE, MF_BYCOMMAND or MF_CHECKED)
  else
    CheckMenuItem(gVoiceMenu, IDM_SPEAK_HILITE, MF_BYCOMMAND or MF_UNCHECKED);
  if fRemindSpeak then
    CheckMenuItem(gVoiceMenu, IDM_SPEAK_REMIND, MF_BYCOMMAND or MF_CHECKED)
  else
    CheckMenuItem(gVoiceMenu, IDM_SPEAK_REMIND, MF_BYCOMMAND or MF_UNCHECKED);
end;

// кой глас за този текст: избраният, или автоматично по езика
function PickVoice(const text: UnicodeString): Integer;
var
  i: Integer;
begin
  Result := VoiceIndex(gVoiceSel);
  if Result >= 0 then Exit;
  if HasCyrillic(text) then
  begin
    for i := 0 to High(gVoices) do
      if gVoices[i].Lang = LANG_BG then Exit(i);
    if not gBgHintShown then
    begin
      gBgHintShown := True;
      MsgBox('No Bulgarian voice is installed, so the text will be read by ' +
             'the default voice.'#13#10#13#10'To add one: Settings -> Time & language -> ' +
             'Speech -> Manage voices -> Add voices -> Bulgarian.',
             MB_OK or MB_ICONINFORMATION);
    end;
  end;
  Result := -1;                       // default глас на системата
end;

procedure ApplyVoice(idx: Integer);
var
  tok: ISpObjectToken;
begin
  if (idx >= 0) and
     (CoCreateInstance(CLSID_SpObjectToken, nil, CLSCTX_ALL, IID_ISpObjectToken, tok) = 0) and
     (tok.SetId(nil, PWideChar(gVoices[idx].Id), False) = 0) and
     (gVoice.SetVoice(Pointer(tok)) = 0) then
    Exit;
  gVoice.SetVoice(nil);               // nil = системният default
end;

// край на четенето: връщаме селекцията, ако сме я местили
procedure SpeechDone(restoreSel: Boolean);
begin
  if not gSpeaking then Exit;
  gSpeaking := False;
  gSpeakStream := 0;
  if restoreSel and gSpeakToEnd then ClearReadPos;   // прочетено до края -> забравяме
  if restoreSel and fSpeakHilite then
  begin
    EdMsg(EM_EXSETSEL, 0, LPARAM(@gSpeakSel));
    EdMsg(EM_SCROLLCARET, 0, 0);
  end;
  ScheduleStats;
end;

procedure SpeechStop(restoreSel: Boolean);
begin
  if gVoice <> nil then gVoice.Speak(nil, SPF_PURGEBEFORESPEAK, nil);
  SpeechDone(restoreSel);
end;

// Ctrl+R по време на четене: спираме и оставяме курсора на последната
// изговорена дума -> следващото Ctrl+R продължава оттам (и след рестарт)
procedure SpeechPause;
var
  r: TCharRange;
begin
  if gVoice <> nil then gVoice.Speak(nil, SPF_PURGEBEFORESPEAK, nil);
  if gLastWordPos < 0 then
  begin                               // още нито една дума - само връщаме селекцията
    gSpeakToEnd := False;
    SpeechDone(True);
    Exit;
  end;
  gSpeaking := False;
  gSpeakStream := 0;
  r.cpMin := gLastWordPos; r.cpMax := gLastWordPos;
  EdMsg(EM_EXSETSEL, 0, LPARAM(@r));
  EdMsg(EM_SCROLLCARET, 0, 0);
  SaveReadPos(gLastWordPos);
  gStatusNote := 'Paused - Ctrl+R continues from here';
  ScheduleStats;
end;

// SAPI ни праща WM_APP_SPEECH; изваждаме натрупаните събития
procedure OnSpeechEvents;
var
  ev: TSpEvent;
  got: ULONG;
  r: TCharRange;
begin
  if gVoice = nil then Exit;
  repeat
    got := 0;
    FillChar(ev, SizeOf(ev), 0);
    gVoice.GetEvents(1, @ev, @got);
    if got = 0 then Break;
    if (not gSpeaking) or (ev.ulStreamNum <> gSpeakStream) then Continue;
    case ev.eEventId of
      SPEI_WORD_BOUNDARY:
        begin
          r.cpMin := gSpeakBase + LongInt(ev.lp);
          r.cpMax := r.cpMin + LongInt(ev.wp);
          gLastWordPos := r.cpMin;
          if fSpeakHilite then
          begin
            EdMsg(EM_EXSETSEL, 0, LPARAM(@r));
            EdMsg(EM_SCROLLCARET, 0, 0);
          end;
        end;
      SPEI_END_INPUT_STREAM:
        SpeechDone(True);
    end;
  until False;
end;

procedure CmdSpeak;
var
  cr: TCharRange;
  s: UnicodeString;
  mask: QWord;
begin
  if gVoice = nil then
  begin
    CoInitialize(nil);
    if CoCreateInstance(CLSID_SpVoice, nil, CLSCTX_ALL, IID_ISpVoice, gVoice) <> 0 then
    begin
      gVoice := nil;
      MsgBox('Speech (SAPI) is not available on this system.', MB_OK or MB_ICONWARNING);
      Exit;
    end;
    // събития за всяка дума и за края - като съобщения към прозореца
    mask := (QWord(1) shl SPEI_WORD_BOUNDARY) or (QWord(1) shl SPEI_END_INPUT_STREAM) or
            SPFEI_FLAGCHECK;
    gVoice.SetInterest(mask, mask);
    gVoice.SetNotifyWindowMessage(hMain, WM_APP_SPEECH, 0, 0);
  end
  else if gSpeaking or (gVoice.WaitUntilDone(0) = 1) then  // още говори -> стоп
  begin
    SpeechPause;
    Exit;
  end;

  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  if cr.cpMax > cr.cpMin then s := GetRange(cr.cpMin, cr.cpMax)
  else s := GetRange(cr.cpMin, TextLenInternal);   // от курсора до края
  if s = '' then Exit;
  gSpeakBase := cr.cpMin;
  gSpeakSel := cr;
  gSpeakToEnd := cr.cpMax <= cr.cpMin;
  gLastWordPos := -1;
  ApplyVoice(PickVoice(s));
  gVoice.SetRate(RateValues[gRateIdx]);
  gSpeakStream := 0;
  gSpeaking := True;
  if gVoice.Speak(PWideChar(s), SPF_ASYNC or SPF_PURGEBEFORESPEAK or SPF_IS_NOT_XML,
                  @gSpeakStream) <> 0 then
    gSpeaking := False;
end;

{ ======================= правопис ======================= }

procedure ApplySpell;
var
  o: LRESULT;
begin
  o := EdMsg(EM_GETLANGOPTIONS, 0, 0);
  if fSpell then
  begin
    EdMsg(EM_SETEDITSTYLE, SES_USECTF or SES_CTFALLOWPROOFING,
                           SES_USECTF or SES_CTFALLOWPROOFING);
    o := o or IMF_SPELLCHECKING;
  end
  else
    o := o and not LRESULT(IMF_SPELLCHECKING);
  EdMsg(EM_SETLANGOPTIONS, 0, o);
end;

{ ======================= помощни за низове ======================= }

function TrimW(const s: UnicodeString): UnicodeString;
var
  a, b: Integer;
begin
  a := 1; b := Length(s);
  while (a <= b) and ((s[a] = ' ') or (s[a] = #9)) do Inc(a);
  while (b >= a) and ((s[b] = ' ') or (s[b] = #9)) do Dec(b);
  Result := Copy(s, a, b - a + 1);
end;

{ ======================= грешна подредба ======================= }

{ "ghbdtn" -> "привет" и обратно. Не ползваме таблица, а реалните
  инсталирани подредби: за всеки символ VkKeyScanEx казва кой клавиш
  го дава в едната подредба, а ToUnicodeEx - какво дава същият клавиш
  в другата. Така работи за фонетична, БДС, руска и т.н. }

function IsCyrLayout(h: HKL): Boolean;
begin
  case PtrUInt(h) and $3FF of        // primary language id
    $02, $19, $22, $23, $2F: Result := True;   // bg, ru, uk, be, mk
  else
    Result := False;
  end;
end;

function FindLayouts(out lat, cyr: HKL): Boolean;
var
  list: array[0..31] of HKL;
  n, i: Integer;
  cur: HKL;
begin
  lat := 0; cyr := 0;
  cur := GetKeyboardLayout(0);
  if IsCyrLayout(cur) then cyr := cur else lat := cur;
  n := GetKeyboardLayoutList(Length(list), @list[0]);
  for i := 0 to n - 1 do
    if IsCyrLayout(list[i]) then
    begin
      if cyr = 0 then cyr := list[i];
    end
    else if lat = 0 then lat := list[i];
  if lat = 0 then lat := LoadKeyboardLayoutW('00000409', KLF_NOTELLSHELL);
  Result := (lat <> 0) and (cyr <> 0);
end;

function MapKey(c: WideChar; src, dst: HKL; out r: WideChar): Boolean;
var
  vk: SmallInt;
  ks: array[0..255] of Byte;
  buf: array[0..7] of WideChar;
  n: Integer;
  sc: UINT;
begin
  Result := False;
  vk := VkKeyScanExW(c, src);
  if (vk = -1) or ((vk and $600) = $200) then Exit;   // няма го / само с Ctrl
  FillChar(ks, SizeOf(ks), 0);
  if (vk and $100) <> 0 then ks[VK_SHIFT] := $80;
  if (vk and $200) <> 0 then ks[VK_CONTROL] := $80;
  if (vk and $400) <> 0 then ks[VK_MENU] := $80;
  sc := MapVirtualKeyExW(vk and $FF, 0, dst);
  n := ToUnicodeEx(vk and $FF, sc, @ks[0], @buf[0], Length(buf), 4, dst);
  if n < 0 then                       // мъртъв клавиш - изчистваме състоянието
    ToUnicodeEx(vk and $FF, sc, @ks[0], @buf[0], Length(buf), 4, dst)
  else if (n = 1) and (buf[0] >= ' ') then
  begin
    r := buf[0];
    Result := True;
  end;
end;

function IsCyrChar(c: WideChar): Boolean; inline;
begin
  Result := (Ord(c) >= $0400) and (Ord(c) <= $04FF);
end;

procedure CmdFixLayout;
var
  cr: TCharRange;
  a, b, i: LongInt;
  s, t, line: UnicodeString;
  lat, cyr, src, dst: HKL;
  nLat, nCyr: Integer;
  r: WideChar;
  sel: Boolean;
begin
  if not FindLayouts(lat, cyr) then
  begin
    MsgBox('No Cyrillic keyboard layout is installed.', MB_OK or MB_ICONWARNING);
    Exit;
  end;
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  sel := cr.cpMax > cr.cpMin;
  if sel then
  begin
    a := cr.cpMin; b := cr.cpMax;
    s := GetRange(a, b);
  end
  else
  begin                               // последната "дума" преди курсора
    b := cr.cpMin;
    a := b - 256;
    if a < 0 then a := 0;
    line := GetRange(a, b);
    i := Length(line);
    while (i > 0) and ((line[i] = ' ') or (line[i] = #9)) do Dec(i);
    b := a + i;                       // без интервалите накрая
    while (i > 0) and not ((line[i] = ' ') or (line[i] = #9) or IsBreak(line[i])) do Dec(i);
    s := Copy(line, i + 1, b - a - i);
    a := b - Length(s);
  end;
  if s = '' then begin MessageBeep(MB_OK); Exit; end;

  nLat := 0; nCyr := 0;
  for i := 1 to Length(s) do
    if IsAsciiLetter(s[i]) then Inc(nLat)
    else if IsCyrChar(s[i]) then Inc(nCyr);
  if nCyr > nLat then begin src := cyr; dst := lat; end
  else begin src := lat; dst := cyr; end;

  t := s;
  UniqueString(t);
  for i := 1 to Length(t) do
    if (t[i] > ' ') and MapKey(t[i], src, dst, r) then t[i] := r;
  if t = s then begin MessageBeep(MB_OK); Exit; end;

  ReplaceRange(a, b, t, sel);
  if not sel then
  begin                               // курсорът - където си беше
    cr.cpMin := cr.cpMin + (Length(t) - Length(s));
    cr.cpMax := cr.cpMin;
    EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  end;
  ActivateKeyboardLayout(dst, 0);     // и продължаваш да пишеш на правилния език
end;

{ ======================= калкулатор в текста ======================= }

var
  cS: UnicodeString;                  // израз
  cP: Integer;                        // позиция
  cErr, cComma: Boolean;

function CPeek: WideChar;
begin
  while (cP <= Length(cS)) and (cS[cP] = ' ') do Inc(cP);
  if cP <= Length(cS) then Result := cS[cP] else Result := #0;
end;

function CExpr: Double; forward;
function CUnary: Double; forward;

function CNumber: Double;
var
  t: ShortString;
  code: Integer;
  c: WideChar;
begin
  t := '';
  while (cP <= Length(cS)) and (Length(t) < 60) do
  begin
    c := cS[cP];
    if (c >= '0') and (c <= '9') then t := t + AnsiChar(Ord(c))
    else if (c = '.') or (c = ',') then
    begin
      if c = ',' then cComma := True;
      t := t + '.';
    end
    else Break;
    Inc(cP);
  end;
  Result := 0;
  Val(t, Result, code);
  if (t = '') or (t = '.') or (code <> 0) then cErr := True;
end;

function CPrimary: Double;
var
  c: WideChar;
  id: UnicodeString;
begin
  Result := 0;
  c := CPeek;
  if c = '(' then
  begin
    Inc(cP);
    Result := CExpr;
    if CPeek = ')' then Inc(cP) else cErr := True;
  end
  else if ((c >= '0') and (c <= '9')) or (c = '.') or (c = ',') then
    Result := CNumber
  else if IsAsciiLetter(c) then
  begin
    id := '';
    while (cP <= Length(cS)) and IsAsciiLetter(cS[cP]) do
    begin
      id := id + cS[cP];
      Inc(cP);
    end;
    id := AsciiLower(id);
    if id = 'pi' then Result := Pi
    else if (id = 'sqrt') and (CPeek = '(') then Result := Sqrt(CPrimary())
    else cErr := True;
  end
  else
    cErr := True;
  while CPeek = '%' do                // 15% = 0.15, т.е. 200*15% = 30
  begin
    Inc(cP);
    Result := Result / 100;
  end;
end;

function IntPow(x: Double; n: Integer): Double;
var
  neg: Boolean;
begin
  neg := n < 0;
  n := Abs(n);
  Result := 1;
  while n > 0 do
  begin
    if Odd(n) then Result := Result * x;
    x := x * x;
    n := n shr 1;
  end;
  if neg then Result := 1 / Result;
end;

function CPower: Double;              // ^ е дясно-асоциативно, 2^-1 работи
var
  e: Double;
begin
  Result := CPrimary;
  if CPeek = '^' then
  begin
    Inc(cP);
    e := CUnary;
    if (Frac(e) = 0) and (Abs(e) <= 1024) then
    begin                             // цяла степен - и за отрицателна основа
      Result := IntPow(Result, Round(e));
    end
    else if Result > 0 then Result := Exp(e * Ln(Result))
    else cErr := True;
  end;
end;

function CUnary: Double;              // -2^2 = -4, както е прието
begin
  case CPeek of
    '-': begin Inc(cP); Result := -CUnary(); end;
    '+': begin Inc(cP); Result := CUnary(); end;
  else
    Result := CPower;
  end;
end;

function CTerm: Double;
var
  c: WideChar;
  d: Double;
begin
  Result := CUnary;
  while not cErr do
  begin
    c := CPeek;
    if (c = '*') or (c = #$00D7) then begin Inc(cP); Result := Result * CUnary; end
    else if (c = '/') or (c = #$00F7) or (c = ':') then
    begin
      Inc(cP);
      d := CUnary;
      if d = 0 then cErr := True else Result := Result / d;
    end
    else Break;
  end;
end;

function CExpr: Double;
var
  c: WideChar;
begin
  Result := CTerm;
  while not cErr do
  begin
    c := CPeek;
    if c = '+' then begin Inc(cP); Result := Result + CTerm; end
    else if c = '-' then begin Inc(cP); Result := Result - CTerm; end
    else Break;
  end;
end;

function HasOperator(const s: UnicodeString): Boolean;
var
  i: Integer;
begin
  for i := 2 to Length(s) do          // водещ минус не се брои
    case s[i] of
      '+', '-', '*', '/', ':', '^', '%', '(', #$00D7, #$00F7: Exit(True);
    end;
  Result := (Pos('sqrt', AsciiLower(s)) > 0) or (Pos('pi', AsciiLower(s)) > 0);
end;

function Evaluate(const s: UnicodeString; out v: Double): Boolean;
var
{$IFDEF CPUX86_64}
  old: DWord;
{$ELSE}
  old: Word;
{$ENDIF}
begin
  Result := False;
  v := 0;
  if (TrimW(s) = '') or not HasOperator(TrimW(s)) then Exit;
  cS := s; cP := 1; cErr := False; cComma := False;
  // маскираме FPU изключенията: 1/0, overflow и т.н. дават Inf/NaN
  // вместо runtime error (нямаме SysUtils за try/except)
{$IFDEF CPUX86_64}
  old := GetMXCSR;
  SetMXCSR(old or $1F80);
{$ELSE}
  old := Get8087CW;
  Set8087CW(old or $3F);
{$ENDIF}
  v := CExpr;
  if CPeek <> #0 then cErr := True;
{$IFDEF CPUX86_64}
  SetMXCSR(old);
{$ELSE}
  asm fnclex end;
  Set8087CW(old);
{$ENDIF}
  Result := (not cErr) and (v = v) and (Abs(v) <= 1.0e300);
end;

function FmtNum(x: Double; comma: Boolean): UnicodeString;
var
  t: ShortString;
  i: Integer;
begin
  if (Abs(x) >= 1e15) or ((x <> 0) and (Abs(x) < 1e-9)) then
    Str(x, t)                         // научен запис за крайностите
  else
  begin
    Str(x:0:10, t);                   // 10 знака скриват 0.1+0.2=0.30000000000000004
    if Pos('.', t) > 0 then
    begin
      i := Length(t);
      while t[i] = '0' do Dec(i);
      if t[i] = '.' then Dec(i);
      SetLength(t, i);
    end;
    if t = '-0' then t := '0';
  end;
  Result := UnicodeString(TrimW(UnicodeString(t)));
  if comma then
    for i := 1 to Length(Result) do
      if Result[i] = '.' then Result[i] := ',';
end;

function IsCalcChar(c: WideChar): Boolean;
begin
  case c of
    '0'..'9', '.', ',', '+', '-', '*', '/', '^', '%', '(', ')', #$00D7, #$00F7:
      Result := True;
  else
    Result := IsAsciiLetter(c);
  end;
end;

procedure CmdCalc;
var
  cr: TCharRange;
  a, ins, i: LongInt;
  s, line, ins_t: UnicodeString;
  v: Double;
  ok, endsEq, sel: Boolean;
begin
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  sel := cr.cpMax > cr.cpMin;
  ins := cr.cpMax;
  if sel then
    line := GetRange(cr.cpMin, cr.cpMax)
  else
  begin                               // текстът от началото на реда до курсора
    a := cr.cpMin - 512;
    if a < 0 then a := 0;
    line := GetRange(a, cr.cpMin);
    for i := Length(line) downto 1 do
      if IsBreak(line[i]) then begin Delete(line, 1, i); Break; end;
  end;
  s := TrimW(line);
  endsEq := (s <> '') and (s[Length(s)] = '=');
  if endsEq then s := TrimW(Copy(s, 1, Length(s) - 1));

  ok := False;
  if sel then ok := Evaluate(s, v)
  else
    // най-дългата завършваща част на реда, която е валиден израз:
    // "Цена: 1250*0,2+15" -> "1250*0,2+15"
    // (започваме само на граница - иначе "10^400" би дал "0^400" = 0)
    for i := 1 to Length(s) do
      if (s[i] <> ' ') and ((i = 1) or not IsCalcChar(s[i - 1])) and
         Evaluate(Copy(s, i, MaxInt), v) then
      begin
        ok := True;
        Break;
      end;
  if not ok then
  begin
    MessageBeep(MB_ICONASTERISK);
    SetStatusText(0, '  No arithmetic expression before the cursor');
    Exit;
  end;

  ins_t := FmtNum(v, cComma);
  if endsEq then
  begin
    if (line <> '') and (line[Length(line)] <> ' ') then ins_t := ' ' + ins_t;
  end
  else
    ins_t := ' = ' + ins_t;
  ReplaceRange(ins, ins, ins_t, False);
end;

{ ======================= auto-indent ======================= }

// Enter -> нов ред със същия отстъп (интервали/табове) като текущия
function DoAutoIndent: Boolean;
var
  cr: TCharRange;
  a: LongInt;
  line, ind: UnicodeString;
  i: Integer;
begin
  Result := False;
  if not fAutoIndent then Exit;
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  a := cr.cpMin - 4096;
  if a < 0 then a := 0;
  line := GetRange(a, cr.cpMin);
  for i := Length(line) downto 1 do
    if IsBreak(line[i]) then begin Delete(line, 1, i); Break; end;
  i := 1;
  while (i <= Length(line)) and ((line[i] = ' ') or (line[i] = #9)) do Inc(i);
  ind := Copy(line, 1, i - 1);
  if ind = '' then Exit;              // няма отстъп - RichEdit си знае работата
  EdMsg(EM_REPLACESEL, WPARAM(True), LPARAM(PWideChar(UnicodeString(#13) + ind)));
  EdMsg(EM_SCROLLCARET, 0, 0);
  Result := True;
end;

{ ======================= Ctrl+Enter: изпълни реда ======================= }

{ Редът под курсора се пуска през "cmd.exe /d /s /c", stdout+stderr идват
  през pipe в отделна нишка и се вмъкват под реда, докато командата
  работи. Esc убива целия job (cmd + всичко, което е пуснал). }

const
  RUN_MAX_OUTPUT = 16 * 1024 * 1024;

function RunReader(param: Pointer): PtrInt;
var
  buf: array[0..4095] of Byte;
  got, code, newCap: DWORD;
  p: PByte;
  post: Boolean;
begin
  got := 0;
  while ReadFile(gRunRead, buf, SizeOf(buf), got, nil) and (got > 0) do
  begin
    EnterCriticalSection(gRunCS);
    if gRunBufLen + got > gRunBufCap then
    begin
      newCap := (gRunBufLen + got) * 2;
      if gRunBuf = nil then p := HeapAlloc(GetProcessHeap, 0, newCap)
      else p := HeapReAlloc(GetProcessHeap, 0, gRunBuf, newCap);
      if p <> nil then begin gRunBuf := p; gRunBufCap := newCap; end;
    end;
    if gRunBufLen + got <= gRunBufCap then
    begin
      Move(buf, (gRunBuf + gRunBufLen)^, got);
      Inc(gRunBufLen, got);
    end;
    post := not gRunNotified;
    gRunNotified := True;
    LeaveCriticalSection(gRunCS);
    if post then PostMessageW(hMain, WM_APP_RUNOUT, 0, 0);
    got := 0;
  end;
  WaitForSingleObject(gRunProc, INFINITE);
  code := 0;
  GetExitCodeProcess(gRunProc, code);
  PostMessageW(hMain, WM_APP_RUNDONE, code, 0);
  Result := 0;
end;

function DirOf(const fn: UnicodeString): UnicodeString;
var
  i: Integer;
begin
  i := Length(fn);
  while (i > 0) and (fn[i] <> '\') and (fn[i] <> '/') do Dec(i);
  Result := Copy(fn, 1, i - 1);
  if (Length(Result) = 2) and (Result[2] = ':') then Result := Result + '\';
end;

function DirExists(const d: UnicodeString): Boolean;
var
  a: DWORD;
begin
  a := GetFileAttributesW(PWideChar(d));
  Result := (a <> $FFFFFFFF) and ((a and FILE_ATTRIBUTE_DIRECTORY) <> 0);
end;

function CurrentRunDir: UnicodeString;
var
  buf: array[0..MAX_PATHBUF-1] of WideChar;
begin
  if (gRunDir <> '') and DirExists(gRunDir) then Exit(gRunDir);
  if gFile <> '' then
  begin
    Result := DirOf(gFile);
    if DirExists(Result) then Exit;
  end;
  GetCurrentDirectoryW(MAX_PATHBUF, @buf[0]);
  Result := PWideChar(@buf[0]);
end;

// вмъква изход на gRunPos (редакторът е read-only, докато върви командата)
procedure RunInsert(const t: UnicodeString);
var
  cr: TCharRange;
  s: UnicodeString;
  i, o: Integer;
  f: TEol;
begin
  if t = '' then Exit;
  // всички нови редове -> CR (вътрешният формат на RichEdit), без
  // контролни символи и ANSI escape последователности
  s := ConvertEol(t, eolCR, nil, f);
  o := 0;
  i := 1;
  while i <= Length(s) do
  begin
    if s[i] = #27 then
    begin                             // ESC [ ... буква
      Inc(i);
      if (i <= Length(s)) and (s[i] = '[') then
      begin
        Inc(i);
        while (i <= Length(s)) and not (((s[i] >= 'A') and (s[i] <= 'Z')) or
              ((s[i] >= 'a') and (s[i] <= 'z'))) do Inc(i);
      end;
      Inc(i);
      Continue;
    end;
    if (s[i] >= ' ') or (s[i] = #9) or (s[i] = #13) then
    begin
      Inc(o);
      s[o] := s[i];
    end;
    Inc(i);
  end;
  SetLength(s, o);
  if s = '' then Exit;

  EdMsg(EM_SETREADONLY, 0, 0);
  cr.cpMin := gRunPos; cr.cpMax := gRunPos;
  EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  EdMsg(EM_REPLACESEL, WPARAM(True), LPARAM(PWideChar(s)));
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  gRunPos := cr.cpMax;                // курсорът е точно след вмъкнатото
  EdMsg(EM_SCROLLCARET, 0, 0);
  if gRunning then EdMsg(EM_SETREADONLY, 1, 0);
  gRunEndsWithBreak := s[Length(s)] = #13;
end;

{ cmd /u пише вградените си команди (dir, echo, set...) като UTF-16LE,
  а външните програми (ping, git...) - като байтове (UTF-8 след chcp 65001).
  За латиница и кирилица в UTF-16LE старшите байтове (нечетните позиции)
  са 00..05, а в UTF-8/ASCII такива байтове практически няма. }
function LooksUtf16(n: Integer): Boolean;
var
  i, pairs, lowOdd, lowEven: Integer;
begin
  pairs := n div 2;
  Result := False;
  if pairs < 1 then Exit;
  lowOdd := 0; lowEven := 0;
  for i := 0 to pairs - 1 do
  begin
    // старши байт 00..05 = латиница/кирилица в UTF-16; в UTF-8 такива няма
    if gRunPend[2 * i + 1] <= $05 then Inc(lowOdd);
    // контролни символи като младши байт - но CR/LF/TAB са нормални
    // (cmd пише новия ред отделно: "0D 00 0A 00")
    if (gRunPend[2 * i] < $20) and not (gRunPend[2 * i] in [9, 10, 13]) then Inc(lowEven);
  end;
  Result := (lowOdd * 10 >= pairs * 6) and (lowEven * 2 < pairs);
end;

// CRLF често идва разделен в две парчета (cmd пише текста и новия ред
// с отделни WriteFile) - задържаме крайния CR, за да не стане празен ред
procedure RunEmit(s: UnicodeString; final: Boolean);
begin
  if gRunPendCR then
  begin
    s := #13 + s;
    gRunPendCR := False;
  end;
  if (not final) and (s <> '') and (s[Length(s)] = #13) then
  begin
    SetLength(s, Length(s) - 1);
    gRunPendCR := True;
  end;
  RunInsert(s);
end;

// декодира натрупаните байтове: UTF-16LE (cmd /u), UTF-8, иначе OEM (cp866)
procedure RunFlush(final: Boolean);
var
  n, keep, i, need: Integer;
  s: UnicodeString;
  b: Byte;
begin
  n := Length(gRunPend);
  if n = 0 then
  begin
    if final then RunEmit('', True);
    Exit;
  end;
  if (n >= 2) and LooksUtf16(n) then
  begin
    keep := 0;
    if Odd(n) and not final then keep := 1;     // половин символ - чака следващото парче
    SetLength(s, (n - keep) div 2);
    if Length(s) > 0 then Move(gRunPend[0], s[1], Length(s) * 2);
    RunEmit(s, final);
    if keep > 0 then gRunPend[0] := gRunPend[n - 1];
    SetLength(gRunPend, keep);
    Exit;
  end;
  keep := 0;
  if not final then
  begin                               // не режем UTF-8 символ по средата
    i := n - 1;
    while (i >= 0) and (i >= n - 4) and ((gRunPend[i] and $C0) = $80) do Dec(i);
    if (i >= 0) and (gRunPend[i] >= $C0) then
    begin
      b := gRunPend[i];
      if b >= $F0 then need := 4 else if b >= $E0 then need := 3 else need := 2;
      if n - i < need then keep := n - i;
    end;
  end;
  if not MbToWide(CP_UTF8, MB_ERR_INVALID_CHARS, PAnsiChar(@gRunPend[0]), n - keep, s) then
    MbToWide(GetOEMCP, 0, PAnsiChar(@gRunPend[0]), n - keep, s);
  RunEmit(s, final);
  if keep > 0 then
    Move(gRunPend[n - keep], gRunPend[0], keep);
  SetLength(gRunPend, keep);
end;

procedure RunOutput;
var
  old: Integer;
  n: DWORD;
begin
  EnterCriticalSection(gRunCS);
  n := gRunBufLen;
  old := Length(gRunPend);
  if (n > 0) and (gRunTotal + n <= RUN_MAX_OUTPUT) then
  begin
    SetLength(gRunPend, old + Integer(n));
    Move(gRunBuf^, gRunPend[old], n);
  end;
  gRunBufLen := 0;
  gRunNotified := False;
  LeaveCriticalSection(gRunCS);
  if n = 0 then Exit;
  if gRunTotal + n > RUN_MAX_OUTPUT then
  begin
    if not gRunStopped then
    begin
      gRunStopped := True;
      TerminateJobObject(gRunJob, 1);
      RunFlush(True);
      RunInsert('[output too large - stopped]'#13);
    end;
    Exit;
  end;
  Inc(gRunTotal, n);
  RunFlush(False);
end;

procedure RunDone(code: DWORD);
var
  cr: TCharRange;
begin
  RunOutput;                          // каквото е останало в буфера
  RunFlush(True);
  if not gRunEndsWithBreak then RunInsert(#13);
  if gRunStopped then RunInsert('[stopped]'#13)
  else if code <> 0 then RunInsert('[exit code ' + IStr(code) + ']'#13);
  gRunning := False;
  EdMsg(EM_SETREADONLY, 0, 0);
  CloseHandle(gRunRead);   gRunRead := 0;
  CloseHandle(gRunProc);   gRunProc := 0;
  CloseHandle(gRunJob);    gRunJob := 0;
  CloseHandle(gRunThreadH); gRunThreadH := 0;
  if gRunTempFile <> '' then
  begin
    DeleteFileW(PWideChar(gRunTempFile));
    gRunTempFile := '';
  end;
  cr.cpMin := gRunPos; cr.cpMax := gRunPos;    // курсорът - на нов ред след изхода
  EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  EdMsg(EM_SCROLLCARET, 0, 0);
  ScheduleStats;
end;

procedure RunStop;
begin
  if not gRunning then Exit;
  gRunStopped := True;
  TerminateJobObject(gRunJob, 1);   // нишката ще види EOF и ще прати RUNDONE
end;

// "cd", "cd папка", "cd /d D:\x", "D:" се обработват тук: една команда
// cmd /c не може да смени папката за следващите
function RunBuiltinCd(const cmd: UnicodeString): Boolean;
var
  lc, arg, base, target: UnicodeString;
  buf: array[0..MAX_PATHBUF-1] of WideChar;
begin
  Result := False;
  lc := AsciiLower(cmd);
  if (Length(cmd) = 2) and (cmd[2] = ':') and IsAsciiLetter(cmd[1]) then
    arg := cmd + '\'
  else if (lc = 'cd') or (lc = 'chdir') then
    arg := ''
  else if (Copy(lc, 1, 3) = 'cd ') or (Copy(lc, 1, 3) = 'cd\') or
          (Copy(lc, 1, 3) = 'cd.') or (Copy(lc, 1, 3) = 'cd/') then
    arg := TrimW(Copy(cmd, 3, MaxInt))
  else
    Exit;
  Result := True;
  if AsciiLower(Copy(arg, 1, 3)) = '/d ' then arg := TrimW(Copy(arg, 4, MaxInt));
  if (Length(arg) >= 2) and (arg[1] = '"') and (arg[Length(arg)] = '"') then
    arg := Copy(arg, 2, Length(arg) - 2);
  base := CurrentRunDir;
  if arg = '' then
  begin
    RunInsert(base + #13);
    Exit;
  end;
  // относителен път спрямо текущата работна папка
  if (Length(arg) >= 2) and ((arg[2] = ':') or ((arg[1] = '\') and (arg[2] = '\'))) then
    target := arg
  else if arg[1] = '\' then
    target := Copy(base, 1, 2) + arg
  else
    target := base + '\' + arg;
  if GetFullPathNameW(PWideChar(target), MAX_PATHBUF, @buf[0], nil) > 0 then
    target := PWideChar(@buf[0]);
  if (Length(target) > 3) and (target[Length(target)] = '\') then
    SetLength(target, Length(target) - 1);
  if DirExists(target) then
  begin
    gRunDir := target;
    RunInsert(target + #13);
  end
  else
    RunInsert('The system cannot find the path specified.'#13);
end;

// текущият ред (абзац): текст и позиции [a, b) - независимо къде е курсорът
function CurrentLine(out a, b: LongInt): UnicodeString;
var
  cr: TCharRange;
  total: LongInt;
  line: UnicodeString;
  i: Integer;
begin
  EdMsg(EM_EXGETSEL, 0, LPARAM(@cr));
  total := TextLenInternal;
  a := cr.cpMin - 4096;
  if a < 0 then a := 0;
  line := GetRange(a, cr.cpMin);
  i := Length(line);
  while (i > 0) and not IsBreak(line[i]) do Dec(i);
  a := cr.cpMin - (Length(line) - i);
  b := cr.cpMin;
  if b + 4096 < total then line := GetRange(b, b + 4096)
  else line := GetRange(b, total);
  i := 1;
  while (i <= Length(line)) and not IsBreak(line[i]) do Inc(i);
  b := b + i - 1;
  if b > total then b := total;
  Result := GetRange(a, b);
end;

// изходът отива на новия ред под ред [.., b): ако след него вече има
// ред, вмъкваме преди него; ако е последният ред - добавяме нов ред
procedure RunPrepareOutput(b: LongInt);
begin
  gRunEndsWithBreak := True;
  if b < TextLenInternal then gRunPos := b + 1
  else
  begin
    gRunPos := b;
    RunInsert(#13);
  end;
end;

procedure RunCaretToOutput;
var
  cr: TCharRange;
begin
  cr.cpMin := gRunPos; cr.cpMax := gRunPos;
  EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  EdMsg(EM_SCROLLCARET, 0, 0);
end;

// пуска "cmd /c <cmd>" с изход към gRunPos
function RunStart(const cmd: UnicodeString): Boolean;
var
  cmdLine, dir: UnicodeString;
  sa: TSecurityAttributes;
  si: TStartupInfoW;
  pi: TProcessInformation;
  hWrite, hNul: THandle;
  tid: TThreadID;
begin
  Result := False;
  // stdout+stderr -> pipe; stdin -> NUL (команда, която чака вход, не виси)
  FillChar(sa, SizeOf(sa), 0);
  sa.nLength := SizeOf(sa);
  sa.bInheritHandle := True;
  if not CreatePipe(gRunRead, hWrite, @sa, 0) then Exit;
  SetHandleInformation(gRunRead, HANDLE_FLAG_INHERIT, 0);
  hNul := CreateFileW('NUL', GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE,
                      @sa, OPEN_EXISTING, 0, 0);

  FillChar(si, SizeOf(si), 0);
  si.cb := SizeOf(si);
  si.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  si.wShowWindow := SW_HIDE;
  si.hStdInput := hNul;
  si.hStdOutput := hWrite;
  si.hStdError := hWrite;
  // /u: вградените команди на cmd пишат UTF-16 (иначе "г." в датите на dir
  // става "?."); chcp 65001: външните програми пишат UTF-8
  cmdLine := 'cmd.exe /u /d /s /c "chcp 65001>nul & ' + cmd + '"';
  UniqueString(cmdLine);
  dir := CurrentRunDir;
  FillChar(pi, SizeOf(pi), 0);
  if not CreateProcessW(nil, PWideChar(cmdLine), nil, nil, True,
           CREATE_NO_WINDOW_F or CREATE_SUSPENDED, nil, PWideChar(dir), @si, @pi) then
  begin
    CloseHandle(hWrite); CloseHandle(hNul); CloseHandle(gRunRead); gRunRead := 0;
    RunInsert('[cannot start cmd.exe]'#13);
    Exit;
  end;
  CloseHandle(hWrite);                // иначе ReadFile никога няма да види EOF
  CloseHandle(hNul);
  gRunJob := CreateJobObjectW(nil, nil);
  if gRunJob <> 0 then AssignProcessToJobObject(gRunJob, pi.hProcess);
  ResumeThread(pi.hThread);
  CloseHandle(pi.hThread);
  gRunProc := pi.hProcess;

  gRunCmd := cmd;
  gRunning := True;
  gRunStopped := False;
  gRunTotal := 0;
  gRunPendCR := False;
  SetLength(gRunPend, 0);
  EdMsg(EM_SETREADONLY, 1, 0);
  ScheduleStats;
  gRunThreadH := THandle(BeginThread(@RunReader, nil, tid));
  Result := True;
end;

{ ======================= планер: @-редове -> Task Scheduler ======================= }

{ Синтаксис (български и английски, редът на думите е свободен):
    @ 18:30 Обади се на Иван              днес (или утре, ако часът е минал)
    @ утре 09:00 backup.bat               tomorrow
    @ 15.10 10:00 / 15.10.2026 / 2026-10-15
    @ пт 17:00 Плати сметката             най-близкия петък, веднъж
    @ всеки ден 08:00 git pull            daily / ежедневно
    @ всеки пн,ср 10:00 Среща             every mon,wed
    @ след 20 мин Извади пицата           in 20 min / след 2 ч
  Текст -> напомняне (trpad /remind), програма/скрипт -> изпълнява се.
  ">" отпред винаги значи команда. }

const
  // ключови думи за @-редовете (всичко се сравнява с малки букви)
  KwEvery: array[0..4] of UnicodeString = (
    #$0432#$0441#$0435#$043A#$0438, #$0432#$0441#$044F#$043A#$0430, #$0432#$0441#$044F#$043A#$043E, 'every', 'each');
  KwDaily: array[0..3] of UnicodeString = (
    #$0435#$0436#$0435#$0434#$043D#$0435#$0432#$043D#$043E, #$0432#$0441#$0435#$043A#$0438#$0434#$043D#$0435#$0432#$043D#$043E, 'daily', 'everyday');
  KwDay: array[0..2] of UnicodeString = (
    #$0434#$0435#$043D, #$0434#$0435#$043D#$0430, 'day');
  KwToday: array[0..1] of UnicodeString = (
    #$0434#$043D#$0435#$0441, 'today');
  KwTomorrow: array[0..1] of UnicodeString = (
    #$0443#$0442#$0440#$0435, 'tomorrow');
  KwDayAfter: array[0..0] of UnicodeString = (
    #$0432#$0434#$0440#$0443#$0433#$0438#$0434#$0435#$043D);
  KwIn: array[0..1] of UnicodeString = (
    #$0441#$043B#$0435#$0434, 'in');
  KwFiller: array[0..6] of UnicodeString = (
    #$0432, #$0432#$044A#$0432, #$043D#$0430, 'at', 'on', #$0433'.', #$0433);
  KwMin: array[0..8] of UnicodeString = (
    #$043C#$0438#$043D, #$043C#$0438#$043D'.', #$043C#$0438#$043D#$0443#$0442#$0430, #$043C#$0438#$043D#$0443#$0442#$0438, 'min', 'mins', 'minute', 'minutes', 'm');
  KwHour: array[0..9] of UnicodeString = (
    #$0447, #$0447'.', #$0447#$0430#$0441, #$0447#$0430#$0441#$0430, #$0447#$0430#$0441#$043E#$0432#$0435, 'h', 'hr', 'hrs', 'hour', 'hours');
  KwWd0: array[0..4] of UnicodeString = (
    #$043F#$043D, #$043F#$043E#$043D, #$043F#$043E#$043D#$0435#$0434#$0435#$043B#$043D#$0438#$043A, 'mon', 'monday');
  KwWd1: array[0..5] of UnicodeString = (
    #$0432#$0442, #$0432#$0442#$043E, #$0432#$0442#$043E#$0440#$043D#$0438#$043A, 'tue', 'tues', 'tuesday');
  KwWd2: array[0..4] of UnicodeString = (
    #$0441#$0440, #$0441#$0440#$044F, #$0441#$0440#$044F#$0434#$0430, 'wed', 'wednesday');
  KwWd3: array[0..6] of UnicodeString = (
    #$0447#$0442, #$0447#$0435#$0442, #$0447#$0435#$0442#$0432#$044A#$0440#$0442#$044A#$043A, 'thu', 'thur', 'thurs', 'thursday');
  KwWd4: array[0..4] of UnicodeString = (
    #$043F#$0442, #$043F#$0435#$0442, #$043F#$0435#$0442#$044A#$043A, 'fri', 'friday');
  KwWd5: array[0..4] of UnicodeString = (
    #$0441#$0431, #$0441#$044A#$0431, #$0441#$044A#$0431#$043E#$0442#$0430, 'sat', 'saturday');
  KwWd6: array[0..4] of UnicodeString = (
    #$043D#$0434, #$043D#$0435#$0434, #$043D#$0435#$0434#$0435#$043B#$044F, 'sun', 'sunday');
  DayXml: array[0..6] of UnicodeString = ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');
  DayShort: array[0..6] of UnicodeString = ('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun');
  Arrow: UnicodeString = #$2192;

type
  TDT = record
    y, mo, d, h, mi: Integer;
  end;

  TSched = record
    kind: Integer;                    // 0 веднъж, 1 всеки ден, 2 всяка седмица
    days: array[0..6] of Boolean;     // пн..нд
    nDays: Integer;
    when: TDT;                        // начало
    rest: UnicodeString;              // какво да се направи
    isCmd: Boolean;
    cmd: UnicodeString;
  end;

const
  SK_ONCE = 0; SK_DAILY = 1; SK_WEEKLY = 2;

function InList(const t: UnicodeString; const L: array of UnicodeString): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(L) do
    if L[i] = t then Exit(True);
  Result := False;
end;

function WeekdayOf(const t: UnicodeString): Integer;
begin
  if InList(t, KwWd0) then Exit(0);
  if InList(t, KwWd1) then Exit(1);
  if InList(t, KwWd2) then Exit(2);
  if InList(t, KwWd3) then Exit(3);
  if InList(t, KwWd4) then Exit(4);
  if InList(t, KwWd5) then Exit(5);
  if InList(t, KwWd6) then Exit(6);
  Result := -1;
end;

function DTToFT(const t: TDT): Int64;
var
  st: TSystemTime;
  ft: TFileTime;
begin
  FillChar(st, SizeOf(st), 0);
  st.wYear := t.y; st.wMonth := t.mo; st.wDay := t.d;
  st.wHour := t.h; st.wMinute := t.mi;
  if not SystemTimeToFileTime(@st, @ft) then Exit(-1);
  Result := Int64(ft.dwHighDateTime) shl 32 or ft.dwLowDateTime;
end;

function FTToDT(v: Int64; out dow: Integer): TDT;
var
  st: TSystemTime;
  ft: TFileTime;
begin
  ft.dwLowDateTime := DWORD(v and $FFFFFFFF);
  ft.dwHighDateTime := DWORD(v shr 32);
  FileTimeToSystemTime(@ft, @st);
  Result.y := st.wYear; Result.mo := st.wMonth; Result.d := st.wDay;
  Result.h := st.wHour; Result.mi := st.wMinute;
  dow := (st.wDayOfWeek + 6) mod 7;   // 0 = понеделник
end;

function NowDT: TDT;
var
  st: TSystemTime;
begin
  GetLocalTime(@st);
  Result.y := st.wYear; Result.mo := st.wMonth; Result.d := st.wDay;
  Result.h := st.wHour; Result.mi := st.wMinute;
end;

function AddMinutes(const t: TDT; m: Int64): TDT;
var
  dow: Integer;
begin
  Result := FTToDT(DTToFT(t) + m * 600000000, dow);
end;

function DowOf(const t: TDT): Integer;
begin
  FTToDT(DTToFT(t), Result);
end;

function ValidDT(const t: TDT): Boolean;
var
  r: TDT;
  dow: Integer;
  v: Int64;
begin
  v := DTToFT(t);
  if v < 0 then Exit(False);
  r := FTToDT(v, dow);
  Result := (r.y = t.y) and (r.mo = t.mo) and (r.d = t.d);
end;

function Pad(n, w: Integer): UnicodeString;
begin
  Result := IStr(n);
  while Length(Result) < w do Result := '0' + Result;
end;

function IsoDT(const t: TDT): UnicodeString;
begin
  Result := Pad(t.y, 4) + '-' + Pad(t.mo, 2) + '-' + Pad(t.d, 2) + 'T' +
            Pad(t.h, 2) + ':' + Pad(t.mi, 2) + ':00';
end;

function ShowDT(const t: TDT): UnicodeString;
begin
  Result := Pad(t.d, 2) + '.' + Pad(t.mo, 2) + '.' + Pad(t.y, 4) + ' ' +
            Pad(t.h, 2) + ':' + Pad(t.mi, 2);
end;

function ParseInt(const s: UnicodeString; out v: Integer): Boolean;
var
  i: Integer;
begin
  v := 0;
  Result := (s <> '') and (Length(s) <= 6);
  if not Result then Exit;
  for i := 1 to Length(s) do
    if (s[i] >= '0') and (s[i] <= '9') then v := v * 10 + Ord(s[i]) - Ord('0')
    else Exit(False);
end;

// "18:30", "9:05"
function ParseTime(const t: UnicodeString; out h, m: Integer): Boolean;
var
  p: Integer;
begin
  p := Pos(':', t);
  Result := (p > 1) and ParseInt(Copy(t, 1, p - 1), h) and
            ParseInt(Copy(t, p + 1, MaxInt), m) and (Length(t) - p = 2) and
            (h <= 23) and (m <= 59);
end;

// "15.10", "15.10.2026", "15.10.26", "2026-10-15"
function ParseDate(const t: UnicodeString; out d: TDT): Boolean;
var
  p1, p2, a, b, c: Integer;
  s: UnicodeString;
begin
  Result := False;
  d := NowDT;
  s := t;
  if (s <> '') and (s[Length(s)] = '.') then SetLength(s, Length(s) - 1);
  p1 := Pos('-', s);
  if p1 = 5 then
  begin                               // ISO
    p2 := Pos('-', Copy(s, 6, MaxInt)) + 5;
    if (p2 <= 5) or not ParseInt(Copy(s, 1, 4), a) or
       not ParseInt(Copy(s, 6, p2 - 6), b) or not ParseInt(Copy(s, p2 + 1, MaxInt), c) then Exit;
    d.y := a; d.mo := b; d.d := c;
  end
  else
  begin
    p1 := Pos('.', s);
    if p1 < 2 then Exit;
    p2 := Pos('.', Copy(s, p1 + 1, MaxInt));
    if not ParseInt(Copy(s, 1, p1 - 1), a) then Exit;
    if p2 = 0 then
    begin
      if not ParseInt(Copy(s, p1 + 1, MaxInt), b) then Exit;
      c := d.y;
    end
    else
    begin
      p2 := p2 + p1;
      if not ParseInt(Copy(s, p1 + 1, p2 - p1 - 1), b) or
         not ParseInt(Copy(s, p2 + 1, MaxInt), c) then Exit;
      if c < 100 then c := c + 2000;
    end;
    d.d := a; d.mo := b; d.y := c;
  end;
  d.h := 0; d.mi := 0;
  Result := ValidDT(d);
end;

// "20", "20мин", "2ч" -> число + единица (минути)
function ParseRelative(const t1, t2: UnicodeString; out mins: Integer; out used: Integer): Boolean;
var
  i, n: Integer;
  num, unitW: UnicodeString;
begin
  Result := False;
  used := 1;
  i := 1;
  while (i <= Length(t1)) and (t1[i] >= '0') and (t1[i] <= '9') do Inc(i);
  num := Copy(t1, 1, i - 1);
  unitW := Copy(t1, i, MaxInt);
  if unitW = '' then
  begin
    unitW := t2;
    used := 2;
  end;
  if not ParseInt(num, n) or (n = 0) then Exit;
  if InList(unitW, KwMin) then mins := n
  else if InList(unitW, KwHour) then mins := n * 60
  else Exit;
  Result := True;
end;

// програма ли е първата дума? (.bat/.exe/..., или се намира в PATH)
function LooksLikeCommand(const rest: UnicodeString; out cmd: UnicodeString): Boolean;
var
  w, ext: UnicodeString;
  i: Integer;
  buf: array[0..MAX_PATHBUF-1] of WideChar;
begin
  cmd := rest;
  if (rest <> '') and (rest[1] = '>') then
  begin
    cmd := TrimW(Copy(rest, 2, MaxInt));
    Exit(True);
  end;
  if (rest <> '') and (rest[1] = '"') then
  begin
    i := Pos('"', Copy(rest, 2, MaxInt));
    if i = 0 then w := Copy(rest, 2, MaxInt) else w := Copy(rest, 2, i - 1);
  end
  else
  begin
    i := Pos(' ', rest);
    if i = 0 then w := rest else w := Copy(rest, 1, i - 1);
  end;
  ext := '';
  i := Length(w);
  while (i > 0) and (w[i] <> '.') and (w[i] <> '\') do Dec(i);
  if (i > 0) and (w[i] = '.') then ext := AsciiLower(Copy(w, i, MaxInt));
  if ext = '.ps1' then
  begin
    cmd := 'powershell -NoProfile -ExecutionPolicy Bypass -File ' + rest;
    Exit(True);
  end;
  if (ext = '.bat') or (ext = '.cmd') or (ext = '.exe') or (ext = '.com') or
     (ext = '.py') or (ext = '.vbs') or (ext = '.js') then Exit(True);
  if FileExists(CurrentRunDir + '\' + w) then Exit(True);
  Result := (SearchPathW(nil, PWideChar(w), '.exe', MAX_PATHBUF, @buf[0], nil) > 0) or
            (SearchPathW(nil, PWideChar(w), '.com', MAX_PATHBUF, @buf[0], nil) > 0) or
            (SearchPathW(nil, PWideChar(w), '.bat', MAX_PATHBUF, @buf[0], nil) > 0) or
            (SearchPathW(nil, PWideChar(w), '.cmd', MAX_PATHBUF, @buf[0], nil) > 0);
end;

function IsScheduleLine(const line: UnicodeString): Boolean;
var
  s: UnicodeString;
begin
  s := TrimW(line);
  Result := (Length(s) >= 2) and (s[1] = '@') and ((s[2] = ' ') or (s[2] = #9));
end;

function ParseSchedule(const line: UnicodeString; out S: TSched; out err: UnicodeString): Boolean;
var
  src, tok, low, nxt: UnicodeString;
  p, q, n, h, m, wd, rel, used, i: Integer;
  every, hasTime, hasDate, hasRel: Boolean;
  dt, now_: TDT;
  parts: UnicodeString;

  function NextTok(var pos: Integer): UnicodeString;
  var
    st: Integer;
  begin
    while (pos <= Length(src)) and ((src[pos] = ' ') or (src[pos] = #9)) do Inc(pos);
    st := pos;
    while (pos <= Length(src)) and (src[pos] <> ' ') and (src[pos] <> #9) do Inc(pos);
    Result := Copy(src, st, pos - st);
  end;

  // списък от дни "пн,ср,пт" -> True, ако всичко е ден от седмицата
  function TakeDays(const t: UnicodeString): Boolean;
  var
    k, st, d: Integer;
    one: UnicodeString;
    tmp: array[0..6] of Boolean;
    cnt: Integer;
  begin
    Result := False;
    FillChar(tmp, SizeOf(tmp), 0);
    cnt := 0;
    st := 1;
    for k := 1 to Length(t) + 1 do
      if (k > Length(t)) or (t[k] = ',') then
      begin
        one := Copy(t, st, k - st);
        st := k + 1;
        if one = '' then Continue;
        d := WeekdayOf(one);
        if d < 0 then Exit;
        if not tmp[d] then Inc(cnt);
        tmp[d] := True;
      end;
    if cnt = 0 then Exit;
    for k := 0 to 6 do
      if tmp[k] then S.days[k] := True;
    S.nDays := 0;
    for k := 0 to 6 do if S.days[k] then Inc(S.nDays);
    Result := True;
  end;

begin
  Result := False;
  err := '';
  FillChar(S.days, SizeOf(S.days), 0);
  S.nDays := 0;
  S.kind := SK_ONCE;
  S.rest := '';
  S.isCmd := False;
  S.cmd := '';
  src := TrimW(line);
  every := False; hasTime := False; hasDate := False; hasRel := False;
  h := 0; m := 0; rel := 0;
  now_ := NowDT;
  dt := now_;
  p := 2;                             // след "@"
  while True do
  begin
    q := p;
    tok := NextTok(p);
    if tok = '' then Break;
    low := LowerStr(tok);
    if InList(low, KwFiller) then Continue;
    if InList(low, KwEvery) then begin every := True; Continue; end;
    if InList(low, KwDaily) or (every and InList(low, KwDay)) then
    begin
      S.kind := SK_DAILY;
      Continue;
    end;
    if InList(low, KwToday) then begin dt := now_; hasDate := True; Continue; end;
    if InList(low, KwTomorrow) then begin dt := AddMinutes(now_, 24 * 60); hasDate := True; Continue; end;
    if InList(low, KwDayAfter) then begin dt := AddMinutes(now_, 48 * 60); hasDate := True; Continue; end;
    if InList(low, KwIn) then
    begin
      i := p;
      nxt := LowerStr(NextTok(i));
      n := i;
      if ParseRelative(nxt, LowerStr(NextTok(n)), rel, used) then
      begin
        hasRel := True;
        if used = 2 then p := n else p := i;
        Continue;
      end;
    end;
    if (not hasTime) and ParseTime(low, h, m) then begin hasTime := True; Continue; end;
    if (not hasDate) and ParseDate(low, dt) then begin hasDate := True; Continue; end;
    if TakeDays(low) then Continue;
    // нищо от горното -> оттук започва текстът/командата
    S.rest := TrimW(Copy(src, q, MaxInt));
    Break;
  end;

  if S.rest = '' then begin err := 'nothing to do - add a text or a command after the time'; Exit; end;
  if hasRel then
  begin
    S.kind := SK_ONCE;
    S.when := AddMinutes(now_, rel);
  end
  else
  begin
    if not hasTime then begin err := 'missing time (HH:MM)'; Exit; end;
    if every and (S.nDays > 0) then S.kind := SK_WEEKLY;
    if (S.kind = SK_ONCE) and (S.nDays > 1) then S.kind := SK_WEEKLY;
    S.when := now_;
    if hasDate then S.when := dt;
    S.when.h := h; S.when.mi := m;
    if (S.kind = SK_ONCE) and (S.nDays = 1) and not hasDate then
    begin                             // "пт 17:00" -> най-близкия петък
      wd := 0;
      while not S.days[wd] do Inc(wd);
      i := 0;
      while (DowOf(S.when) <> wd) or
            ((i = 0) and (DTToFT(S.when) <= DTToFT(now_))) do
      begin
        S.when := AddMinutes(S.when, 24 * 60);
        Inc(i);
        if i > 8 then Break;
      end;
    end
    else if (S.kind = SK_ONCE) and not hasDate and (DTToFT(S.when) <= DTToFT(now_)) then
      S.when := AddMinutes(S.when, 24 * 60);   // часът мина -> утре
    if (S.kind = SK_ONCE) and (DTToFT(S.when) <= DTToFT(now_)) then
    begin
      err := 'that time is already in the past';
      Exit;
    end;
  end;
  S.isCmd := LooksLikeCommand(S.rest, S.cmd);
  Result := True;
end;

function XmlEsc(const s: UnicodeString): UnicodeString;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    case s[i] of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
    else
      Result := Result + s[i];
    end;
end;

function TaskSlug(const s: UnicodeString): UnicodeString;
var
  t: UnicodeString;
  i: Integer;
  c: WideChar;
begin
  t := AsciiLower(ToLatin(s));
  Result := '';
  for i := 1 to Length(t) do
  begin
    c := t[i];
    if ((c >= 'a') and (c <= 'z')) or ((c >= '0') and (c <= '9')) then Result := Result + c
    else if (Result <> '') and (Result[Length(Result)] <> '-') then Result := Result + '-';
    if Length(Result) >= 32 then Break;
  end;
  while (Result <> '') and (Result[Length(Result)] = '-') do SetLength(Result, Length(Result) - 1);
  if Result = '' then Result := 'task';
end;

function ExePath: UnicodeString;
var
  buf: array[0..MAX_PATHBUF-1] of WideChar;
begin
  GetModuleFileNameW(0, @buf[0], MAX_PATHBUF);
  Result := PWideChar(@buf[0]);
end;

function BuildTaskXml(const S: TSched): UnicodeString;
var
  trig, act, settings, endB, txt: UnicodeString;
  i, dow: Integer;
  e: TDT;
begin
  // triggerBaseType е xs:sequence с Enabled ПРЕДИ StartBoundary - затова
  // изобщо не пишем Enabled (подразбира се true)
  case S.kind of
    SK_DAILY:
      trig := '<CalendarTrigger><StartBoundary>' + IsoDT(S.when) + '</StartBoundary>' +
              '<ScheduleByDay><DaysInterval>1</DaysInterval>' +
              '</ScheduleByDay></CalendarTrigger>';
    SK_WEEKLY:
      begin
        trig := '<CalendarTrigger><StartBoundary>' + IsoDT(S.when) + '</StartBoundary>' +
                '<ScheduleByWeek><DaysOfWeek>';
        for i := 0 to 6 do
          if S.days[i] then trig := trig + '<' + DayXml[i] + ' />';
        trig := trig + '</DaysOfWeek><WeeksInterval>1</WeeksInterval></ScheduleByWeek></CalendarTrigger>';
      end;
  else
    begin                             // веднъж; след това задачата се самоизтрива
      e := FTToDT(DTToFT(S.when) + Int64(24) * 60 * 600000000, dow);
      endB := IsoDT(e);
      trig := '<TimeTrigger><StartBoundary>' + IsoDT(S.when) + '</StartBoundary>' +
              '<EndBoundary>' + endB + '</EndBoundary></TimeTrigger>';
    end;
  end;

  if S.isCmd then
    act := '<Exec><Command>cmd.exe</Command><Arguments>' + XmlEsc('/d /c ' + S.cmd) +
           '</Arguments><WorkingDirectory>' + XmlEsc(CurrentRunDir) +
           '</WorkingDirectory></Exec>'
  else
  begin
    txt := S.rest;
    for i := 1 to Length(txt) do if txt[i] = '"' then txt[i] := '''';
    act := '<Exec><Command>' + XmlEsc(ExePath) + '</Command><Arguments>' +
           XmlEsc('/remind "' + txt + '"') + '</Arguments></Exec>';
  end;

  settings := '<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>' +
              '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>' +
              '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>' +
              '<StartWhenAvailable>true</StartWhenAvailable>' +
              '<Enabled>true</Enabled>' +
              '<ExecutionTimeLimit>PT72H</ExecutionTimeLimit>';
  if S.kind = SK_ONCE then
    settings := settings + '<DeleteExpiredTaskAfter>PT0S</DeleteExpiredTaskAfter>';

  Result := '<?xml version="1.0" encoding="UTF-16"?>'#13#10 +
    '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">'#13#10 +
    '<RegistrationInfo><Description>' + XmlEsc('TinyRetroPad: ' + S.rest) +
    '</Description></RegistrationInfo>'#13#10 +
    '<Triggers>' + trig + '</Triggers>'#13#10 +
    '<Principals><Principal id="Author"><LogonType>InteractiveToken</LogonType>' +
    '<RunLevel>LeastPrivilege</RunLevel></Principal></Principals>'#13#10 +
    '<Settings>' + settings + '</Settings>'#13#10 +
    '<Actions Context="Author">' + act + '</Actions>'#13#10 +
    '</Task>'#13#10;
end;

function DescribeSchedule(const S: TSched): UnicodeString;
var
  i: Integer;
  d: UnicodeString;
begin
  case S.kind of
    SK_DAILY:  Result := 'every day at ' + Pad(S.when.h, 2) + ':' + Pad(S.when.mi, 2);
    SK_WEEKLY:
      begin
        d := '';
        for i := 0 to 6 do
          if S.days[i] then
          begin
            if d <> '' then d := d + ', ';
            d := d + DayShort[i];
          end;
        Result := 'every ' + d + ' at ' + Pad(S.when.h, 2) + ':' + Pad(S.when.mi, 2);
      end;
  else
    Result := 'once, ' + DayShort[DowOf(S.when)] + ' ' + ShowDT(S.when);
  end;
  if S.isCmd then Result := Result + '  - command: ' + S.cmd
  else Result := Result + '  - reminder';
end;

procedure CmdScheduleLine(const line: UnicodeString; b: LongInt);
var
  S: TSched;
  err, xml, tmp, name, dry: UnicodeString;
  data: TBytes;
  lossy: Boolean;
  h: THandle;
  w: DWORD;
  buf: array[0..MAX_PATHBUF-1] of WideChar;
  nw: TDT;
begin
  RunPrepareOutput(b);
  if not ParseSchedule(line, S, err) then
  begin
    RunInsert('[schedule: ' + err + ']'#13);
    RunCaretToOutput;
    Exit;
  end;
  xml := BuildTaskXml(S);
  // TRPAD_SCHED_DRYRUN=1 -> само показва XML-а, без да създава задача (за тестове)
  FillChar(buf, SizeOf(buf), 0);
  GetEnvironmentVariableW('TRPAD_SCHED_DRYRUN', @buf[0], 8);
  dry := PWideChar(@buf[0]);
  GetTempPathW(MAX_PATHBUF, @buf[0]);
  tmp := UnicodeString(PWideChar(@buf[0])) + 'trpad_task_' + IStr(GetTickCount) + '.xml';
  if dry <> '' then data := EncodeText(xml, encUTF8, lossy)
  else data := EncodeText(xml, encUTF16LE, lossy);   // schtasks иска UTF-16
  h := CreateFileW(PWideChar(tmp), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_TEMPORARY, 0);
  if h = INVALID_HANDLE_VALUE then
  begin
    RunInsert('[schedule: cannot write temp file]'#13);
    Exit;
  end;
  w := 0;
  WriteFile(h, data[0], Length(data), w, nil);
  CloseHandle(h);
  gRunTempFile := tmp;

  nw := NowDT;
  name := '\TinyRetroPad\' + TaskSlug(S.rest) + '-' + Pad(nw.y, 4) + Pad(nw.mo, 2) +
          Pad(nw.d, 2) + '-' + Pad(nw.h, 2) + Pad(nw.mi, 2) + Pad(GetTickCount mod 100, 2);
  RunInsert(Arrow + ' ' + DescribeSchedule(S) + #13);
  if dry <> '' then
    RunStart('type "' + tmp + '"')
  else
    RunStart('schtasks /create /tn "' + name + '" /xml "' + tmp + '" /f');
end;

procedure CmdListTasks;
var
  cr: TCharRange;
  total: LongInt;
  t: UnicodeString;
begin
  if gRunning then begin MessageBeep(MB_OK); Exit; end;
  total := TextLenInternal;
  t := 'schtasks /query /tn \TinyRetroPad\ /fo LIST';
  if (total > 0) and not IsBreak(GetRange(total - 1, total)[1]) then t := #13 + t;
  cr.cpMin := total; cr.cpMax := total;
  EdMsg(EM_EXSETSEL, 0, LPARAM(@cr));
  EdMsg(EM_REPLACESEL, WPARAM(True), LPARAM(PWideChar(t)));
  RunPrepareOutput(TextLenInternal);
  RunStart('schtasks /query /tn \TinyRetroPad\ /fo LIST');
end;

procedure CmdDeleteTask;
var
  a, b: LongInt;
  line, name: UnicodeString;
  p: Integer;
begin
  if gRunning then begin MessageBeep(MB_OK); Exit; end;
  line := CurrentLine(a, b);
  p := Pos('\TinyRetroPad\', line);
  if p = 0 then
  begin
    MsgBox('Put the cursor on a line with a task name (\TinyRetroPad\...),'#13#10 +
           'for example in the output of Tools -> Scheduled Tasks.', MB_OK or MB_ICONINFORMATION);
    Exit;
  end;
  name := TrimW(Copy(line, p, MaxInt));
  p := Pos(' ', name);
  if p > 0 then SetLength(name, p - 1);
  if MsgBox('Delete the scheduled task'#13#10 + name + ' ?', MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
  RunPrepareOutput(b);
  RunStart('schtasks /delete /tn "' + name + '" /f');
end;

procedure CmdScheduleHelp;
begin
  MessageBoxW(hMain,
    'Write a line that starts with "@ " and press Ctrl+Enter on it:'#13#10#13#10 +
    '@ 18:30 Call Ivan                   today (tomorrow if 18:30 has passed)'#13#10 +
    '@ tomorrow 09:00 backup.bat'#13#10 +
    '@ 15.10 10:00 Dentist             also 15.10.2026 or 2026-10-15'#13#10 +
    '@ fri 17:00 Pay the bill           the next Friday, once'#13#10 +
    '@ every day 08:00 git pull'#13#10 +
    '@ every mon,wed 10:00 Meeting'#13#10 +
    '@ in 20 min Take out the pizza'#13#10#13#10 +
    'Bulgarian works too: днес, утре, вдругиден, пн..нд, всеки ден, всеки пн,'#13#10 +
    'след 20 мин, след 2 ч.'#13#10#13#10 +
    'Plain text = reminder (a message box, read aloud if enabled).'#13#10 +
    'A program, script or command in PATH = it is run at that time.'#13#10 +
    'Start with ">" to force a command.'#13#10#13#10 +
    'Tasks live in Task Scheduler under \TinyRetroPad\ and run even when'#13#10 +
    'TinyRetroPad is closed. One-time tasks delete themselves afterwards.',
    'TinyRetroPad - Scheduling', MB_OK or MB_ICONINFORMATION);
end;

{ ======================= Ctrl+Enter ======================= }

procedure CmdRunLine;
var
  a, b: LongInt;
  line, cmd: UnicodeString;
begin
  if gRunning then begin MessageBeep(MB_OK); Exit; end;
  line := CurrentLine(a, b);
  cmd := TrimW(line);
  if cmd = '' then begin MessageBeep(MB_OK); Exit; end;
  if IsScheduleLine(cmd) then
  begin
    CmdScheduleLine(cmd, b);
    Exit;
  end;
  RunPrepareOutput(b);
  if RunBuiltinCd(cmd) then
  begin
    RunCaretToOutput;
    Exit;
  end;
  if RunStart(cmd) then
    gStatusNote := 'Running: ' + cmd + '   (Esc stops)';
end;

{ ======================= /remind ======================= }

// стартиран от Task Scheduler: показва напомнянето (и го чете на глас)
procedure ShowReminder(const text: UnicodeString);
var
  nw: TDT;
begin
  MessageBeep(MB_ICONINFORMATION);
  if fRemindSpeak then
  begin
    CoInitialize(nil);
    if CoCreateInstance(CLSID_SpVoice, nil, CLSCTX_ALL, IID_ISpVoice, gVoice) = 0 then
    begin
      gBgHintShown := True;           // без допълнителни прозорци
      ApplyVoice(PickVoice(text));
      gVoice.SetRate(RateValues[gRateIdx]);
      gVoice.Speak(PWideChar(text), SPF_ASYNC or SPF_IS_NOT_XML, nil);
    end
    else
      gVoice := nil;
  end;
  nw := NowDT;
  MessageBoxW(0, PWideChar(text),
    PWideChar('TinyRetroPad - Reminder ' + Pad(nw.h, 2) + ':' + Pad(nw.mi, 2)),
    MB_OK or MB_ICONINFORMATION or MB_SYSTEMMODAL or MB_SETFOREGROUND or MB_TOPMOST);
  if gVoice <> nil then gVoice.Speak(nil, SPF_PURGEBEFORESPEAK, nil);
  gVoice := nil;
end;

{ ======================= менюта ======================= }

procedure ShowContextMenu(x, y: Integer);
var
  hCtx: HMENU;
begin
  hCtx := CreatePopupMenu;
  Item(hCtx, IDM_EDIT_UNDO,   '&Undo');
  Item(hCtx, IDM_EDIT_REDO,   '&Redo');
  Sep(hCtx);
  Item(hCtx, IDM_EDIT_CUT,    'Cu&t');
  Item(hCtx, IDM_EDIT_COPY,   '&Copy');
  Item(hCtx, IDM_EDIT_PASTE,  '&Paste');
  Item(hCtx, IDM_EDIT_DELETE, 'De&lete');
  Sep(hCtx);
  Item(hCtx, IDM_EDIT_SELALL, 'Select &All');
  Sep(hCtx);
  Item(hCtx, IDM_EDIT_SPEAK,  'Read Al&oud / Stop');
  UpdateEditMenu(hCtx);
  TrackPopupMenu(hCtx, 0, x, y, 0, hMain, nil);
  DestroyMenu(hCtx);
end;

procedure CreateNotepadMenus(hWnd: HWND);
var
  hBar, hPop, hSub: HMENU;
  e: TEncoding;
  l: TEol;
begin
  hBar := CreateMenu;
  if hBar = 0 then Exit;

  // File
  hPop := CreatePopupMenu;
  Item(hPop, IDM_FILE_NEW,       '&New'#9'Ctrl+N');
  Item(hPop, IDM_FILE_OPEN,      '&Open...'#9'Ctrl+O');
  Item(hPop, IDM_SAVE,           '&Save'#9'Ctrl+S');
  Item(hPop, IDM_FILE_SAVEAS,    'Save &As...'#9'Ctrl+Shift+S');
  Sep(hPop);
  gMruMenu := CreatePopupMenu;
  Popup(hPop, gMruMenu, 'Recent &Files');
  MruRebuild;
  Sep(hPop);
  Item(hPop, IDM_FILE_PAGESETUP, 'Page Set&up...');
  Item(hPop, IDM_FILE_PRINT,     '&Print...'#9'Ctrl+P');
  Sep(hPop);
  Item(hPop, IDM_FILE_EXIT,      'E&xit');
  Popup(hBar, hPop, '&File');

  // Edit
  hPop := CreatePopupMenu;
  Item(hPop, IDM_EDIT_UNDO,     '&Undo'#9'Ctrl+Z');
  Item(hPop, IDM_EDIT_REDO,     '&Redo'#9'Ctrl+Y');
  Sep(hPop);
  Item(hPop, IDM_EDIT_CUT,      'Cu&t'#9'Ctrl+X');
  Item(hPop, IDM_EDIT_COPY,     '&Copy'#9'Ctrl+C');
  Item(hPop, IDM_EDIT_PASTE,    '&Paste'#9'Ctrl+V');
  Item(hPop, IDM_EDIT_DELETE,   'De&lete'#9'Del');
  Sep(hPop);
  Item(hPop, IDM_EDIT_FIND,     '&Find...'#9'Ctrl+F');
  Item(hPop, IDM_EDIT_FINDNEXT, 'Find &Next'#9'F3');
  Item(hPop, IDM_EDIT_FINDPREV, 'Find Pre&vious'#9'Shift+F3');
  Item(hPop, IDM_EDIT_REPLACE,  '&Replace...'#9'Ctrl+H');
  Item(hPop, IDM_EDIT_GOTO,     '&Go To...'#9'Ctrl+G');
  Sep(hPop);
  hSub := CreatePopupMenu;
  Item(hSub, IDM_LINES_SORTASC,  'Sort &Ascending');
  Item(hSub, IDM_LINES_SORTDESC, 'Sort &Descending');
  Item(hSub, IDM_LINES_DEDUP,    'Remove D&uplicate Lines');
  Item(hSub, IDM_LINES_TRIM,     '&Trim Trailing Whitespace');
  Popup(hPop, hSub, 'L&ines');
  Sep(hPop);
  Item(hPop, IDM_EDIT_SELALL,   'Select &All'#9'Ctrl+A');
  Item(hPop, IDM_EDIT_TIME,     'Time/&Date'#9'F5');
  Item(hPop, IDM_EDIT_CALC,     'Ca&lculate'#9'F9');
  Item(hPop, IDM_EDIT_FIXLAYOUT, 'Fi&x Keyboard Layout'#9'Ctrl+Shift+K');

  Sep(hPop);
  Item(hPop, IDM_EDIT_SPEAK,    'Read Al&oud / Stop'#9'Ctrl+R');
  Popup(hBar, hPop, '&Edit');

  // Format
  hPop := CreatePopupMenu;
  Item(hPop, IDM_FMT_WRAP, '&Word Wrap');
  Item(hPop, IDM_FMT_FONT, '&Font...');
  Item(hPop, IDM_FMT_SPELL, '&Spell Checking');
  Item(hPop, IDM_FMT_AUTOINDENT, '&Auto Indent');
  Sep(hPop);
  hSub := CreatePopupMenu;
  Item(hSub, IDM_FMT_UPPER, '&UPPERCASE'#9'Ctrl+Shift+U');
  Item(hSub, IDM_FMT_LOWER, '&lowercase'#9'Ctrl+U');
  Item(hSub, IDM_FMT_TITLE, '&Title Case');
  Popup(hPop, hSub, 'Change &Case');
  hSub := CreatePopupMenu;
  Item(hSub, IDM_FMT_TOLATIN, '&Cyrillic -> Latin');
  Item(hSub, IDM_FMT_TOCYR,   '&Latin -> Cyrillic');
  Popup(hPop, hSub, 'T&ransliterate');
  Popup(hBar, hPop, 'F&ormat');

  // View
  hPop := CreatePopupMenu;
  hSub := CreatePopupMenu;
  Item(hSub, IDM_VIEW_ZOOMIN,    'Zoom &In'#9'Ctrl+Plus');
  Item(hSub, IDM_VIEW_ZOOMOUT,   'Zoom &Out'#9'Ctrl+Minus');
  Item(hSub, IDM_VIEW_ZOOMRESET, '&Restore Default Zoom'#9'Ctrl+0');
  Popup(hPop, hSub, '&Zoom');
  Item(hPop, IDM_VIEW_STATUS, '&Status Bar');
  BuildVoiceMenu(hPop);
{$IFDEF FEAT_LINENUMBERS}
  Item(hPop, IDM_VIEW_LINENUM, 'Line &Numbers');
{$ENDIF}
{$IFDEF FEAT_DARKMODE}
  Item(hPop, IDM_VIEW_DARK, 'Dark &Mode');
{$ENDIF}
  Popup(hBar, hPop, '&View');

  // Encoding (нова) - важи за следващия Save
  hPop := CreatePopupMenu;
  for e := Low(TEncoding) to High(TEncoding) do
    Item(hPop, IDM_ENC_FIRST + Ord(e), EncNames[e]);
  Sep(hPop);
  for l := Low(TEol) to High(TEol) do
    Item(hPop, IDM_EOL_FIRST + Ord(l), EolNames[l]);
  Popup(hBar, hPop, 'E&ncoding');

  // Tools
  hPop := CreatePopupMenu;
  Item(hPop, IDM_EDIT_RUNLINE,  '&Run Line'#9'Ctrl+Enter');
  Item(hPop, IDM_EDIT_RUNSTOP,  '&Stop Command'#9'Esc');
  Sep(hPop);
  Item(hPop, IDM_TOOLS_TASKS,   'Scheduled &Tasks');
  Item(hPop, IDM_TOOLS_DELTASK, '&Delete Task on This Line');
  Item(hPop, IDM_TOOLS_SCHEDHELP, 'How to &Schedule...');
  Popup(hBar, hPop, '&Tools');

  // Help
  hPop := CreatePopupMenu;
  Item(hPop, IDM_HELP_VIEWHELP, '&View Help');
  Sep(hPop);
  Item(hPop, IDM_HELP_ABOUT,    '&About TinyRetroPad');
  Popup(hBar, hPop, '&Help');

  SetMenu(hWnd, hBar);
end;

const
  AccelTable: array[0..23] of TAccelEntry = (
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('N'); cmd: IDM_FILE_NEW),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('O'); cmd: IDM_FILE_OPEN),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('S'); cmd: IDM_SAVE),
    (fVirt: FVIRTKEY or FCONTROL or FSHIFT; key: Ord('S'); cmd: IDM_FILE_SAVEAS),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('P'); cmd: IDM_FILE_PRINT),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('F'); cmd: IDM_EDIT_FIND),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('H'); cmd: IDM_EDIT_REPLACE),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('G'); cmd: IDM_EDIT_GOTO),
    (fVirt: FVIRTKEY;                      key: VK_F3;    cmd: IDM_EDIT_FINDNEXT),
    (fVirt: FVIRTKEY or FSHIFT;            key: VK_F3;    cmd: IDM_EDIT_FINDPREV),
    (fVirt: FVIRTKEY;                      key: VK_F5;    cmd: IDM_EDIT_TIME),
    (fVirt: FVIRTKEY or FCONTROL;          key: VK_OEM_PLUS_K;  cmd: IDM_VIEW_ZOOMIN),
    (fVirt: FVIRTKEY or FCONTROL;          key: VK_ADD;         cmd: IDM_VIEW_ZOOMIN),
    (fVirt: FVIRTKEY or FCONTROL;          key: VK_OEM_MINUS_K; cmd: IDM_VIEW_ZOOMOUT),
    (fVirt: FVIRTKEY or FCONTROL;          key: VK_SUBTRACT;    cmd: IDM_VIEW_ZOOMOUT),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('0');       cmd: IDM_VIEW_ZOOMRESET),
    (fVirt: FVIRTKEY or FCONTROL;          key: VK_NUMPAD0;     cmd: IDM_VIEW_ZOOMRESET),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('Y');       cmd: IDM_EDIT_REDO),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('U');       cmd: IDM_FMT_LOWER),
    (fVirt: FVIRTKEY or FCONTROL or FSHIFT; key: Ord('U');      cmd: IDM_FMT_UPPER),
    (fVirt: FVIRTKEY or FCONTROL;          key: Ord('R');       cmd: IDM_EDIT_SPEAK),
    (fVirt: FVIRTKEY;                      key: VK_F9;          cmd: IDM_EDIT_CALC),
    (fVirt: FVIRTKEY or FCONTROL or FSHIFT; key: Ord('K');      cmd: IDM_EDIT_FIXLAYOUT),
    (fVirt: FVIRTKEY;                      key: VK_PAUSE;       cmd: IDM_EDIT_FIXLAYOUT)
  );

{ ======================= настройки (registry) ======================= }

procedure LoadSettings;
var
  k: HKEY;
  f: TCharFormatW;
  z: DWORD;
  i, n: Integer;
  t: UnicodeString;
begin
  if RegOpenKeyExW(HKEY_CURRENT_USER, RegKey, 0, KEY_READ, k) <> 0 then Exit;
  if RegGetBin(k, 'Font', @f, SizeOf(f)) and (f.cbSize = SizeOf(f)) and
     (f.yHeight > 0) then
    RichFont := f;
  fWrap   := RegGetBool(k, 'WordWrap', fWrap);
  fStatus := RegGetBool(k, 'StatusBar', fStatus);
{$IFDEF FEAT_LINENUMBERS}
  fLineNum := RegGetBool(k, 'LineNumbers', fLineNum);
{$ENDIF}
{$IFDEF FEAT_DARKMODE}
  fDark := RegGetBool(k, 'DarkMode', fDark);
{$ENDIF}
  if RegGetBin(k, 'Zoom', @z, SizeOf(z)) and (z >= 10) and (z <= 500) then
    gStartZoom := z;
  RegGetBin(k, 'Margins', @gMargins, SizeOf(gMargins));
  gHavePlacement := RegGetBin(k, 'Placement', @gPlacement, SizeOf(gPlacement)) and
                    (gPlacement.length = SizeOf(gPlacement));
  fSpell := RegGetBool(k, 'SpellCheck', fSpell);
  fAutoIndent := RegGetBool(k, 'AutoIndent', fAutoIndent);
  gVoiceSel := RegGetStr(k, 'Voice');
  if RegGetBin(k, 'SpeechRate', @z, SizeOf(z)) and (z <= 3) then gRateIdx := z;
  fSpeakHilite := RegGetBool(k, 'SpeechHighlight', fSpeakHilite);
  fRemindSpeak := RegGetBool(k, 'SpeakReminders', fRemindSpeak);
  n := 0;
  for i := 0 to MRU_MAX - 1 do
  begin
    t := RegGetStr(k, 'Recent' + IStr(i));
    if t <> '' then begin gMru[n] := t; Inc(n); end;
  end;
  RegCloseKey(k);
end;

procedure SaveSettings;
var
  k: HKEY;
  wp: TWindowPlacement;
  i: Integer;
begin
  if RegCreateKeyExW(HKEY_CURRENT_USER, RegKey, 0, nil, 0, KEY_WRITE, nil,
                     k, nil) <> 0 then Exit;
  RegPutBin(k, 'Font', @RichFont, SizeOf(RichFont));
  RegPutDW(k, 'WordWrap', Ord(fWrap));
  RegPutDW(k, 'StatusBar', Ord(fStatus));
{$IFDEF FEAT_LINENUMBERS}
  RegPutDW(k, 'LineNumbers', Ord(fLineNum));
{$ENDIF}
{$IFDEF FEAT_DARKMODE}
  RegPutDW(k, 'DarkMode', Ord(fDark));
{$ENDIF}
  RegPutDW(k, 'Zoom', CurZoom);
  RegPutBin(k, 'Margins', @gMargins, SizeOf(gMargins));
  FillChar(wp, SizeOf(wp), 0);
  wp.length := SizeOf(wp);
  if GetWindowPlacement(hMain, @wp) then
    RegPutBin(k, 'Placement', @wp, SizeOf(wp));
  RegPutDW(k, 'SpellCheck', Ord(fSpell));
  RegPutDW(k, 'AutoIndent', Ord(fAutoIndent));
  RegPutStr(k, 'Voice', gVoiceSel);
  RegPutDW(k, 'SpeechRate', gRateIdx);
  RegPutDW(k, 'SpeechHighlight', Ord(fSpeakHilite));
  RegPutDW(k, 'SpeakReminders', Ord(fRemindSpeak));
  for i := 0 to MRU_MAX - 1 do
    RegPutStr(k, 'Recent' + IStr(i), gMru[i]);
  RegCloseKey(k);
end;

{ ======================= window procedure ======================= }

function DropFileName(hDrop: THandle): UnicodeString;
var
  buf: array[0..MAX_PATHBUF-1] of WideChar;
begin
  Result := '';
  if DragQueryFileW(hDrop, 0, @buf[0], MAX_PATHBUF) > 0 then
    Result := PWideChar(@buf[0]);
end;

function MainWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM;
                 lParam: LPARAM): LRESULT; stdcall;
var
  w, h, cmd, gx: Integer;
  pf: PMsgFilterRec;
  rc: TRect;
  pt: TPoint;
  cr: TCharRange;
begin
  Result := 0;

{$IFDEF FEAT_LINENUMBERS}
  if (uMsg = WM_PAINT) and fLineNum then
  begin
    PaintGutter(hWnd);
    Exit;
  end;
{$ENDIF}

  case uMsg of
    WM_CREATE:
      begin
        // RICHEDIT50W в plain-text режим; размер 0,0 - WM_SIZE ще го нагласи
        hEdit := CreateWindowExW(0, EditClass, nil,
                   WS_CHILD or WS_VISIBLE or ES_LEFT or ES_MULTILINE or
                   ES_AUTOVSCROLL or ES_NOHIDESEL or WS_VSCROLL or WS_HSCROLL,
                   0, 0, 0, 0, hWnd, 0, 0, nil);
        // plain text: Paste от браузър вече не вкарва форматиране и картинки
        EdMsg(EM_SETTEXTMODE, TM_PLAINTEXT or TM_MULTILEVELUNDO or TM_MULTICODEPAGE, 0);
        EdMsg(EM_SETEVENTMASK, 0,
              ENM_CHANGE or ENM_MOUSEEVENTS or ENM_SELCHANGE or ENM_UPDATE or
              ENM_SCROLL or ENM_DROPFILES);
        EdMsg(EM_EXLIMITTEXT, 0, $7FFFFFFE);    // вдигни лимита
        DragAcceptFiles(hEdit, True);
        DragAcceptFiles(hWnd, True);
        // Save в системното меню
        AppendMenuW(GetSystemMenu(hWnd, False), MF_STRING, IDM_SAVE, 'Save');
        CreateNotepadMenus(hWnd);
        // истински status bar
        hStatus := CreateWindowExW(0, 'msctls_statusbar32', nil,
                     WS_CHILD or WS_VISIBLE or SBARS_SIZEGRIP,
                     0, 0, 0, 0, hWnd, 0, hInstApp, nil);
      end;

    WM_SETFOCUS:
      SetFocus(hEdit);                // 1.0: фокусът не беше в редактора

    WM_SYSCOMMAND:
      begin
        if wParam = IDM_SAVE then CmdSave
        else Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
      end;

    WM_INITMENUPOPUP:
      UpdateEditMenu(HMENU(wParam));

    WM_COMMAND:
      begin
        if lParam = PtrInt(hEdit) then  // нотификации от редактора
        begin
          case HiWrd(wParam) of
            EN_CHANGE:
              if not fLoading then
              begin
                if gSpeaking then SpeechStop(False);   // текстът се промени -> позициите вече не важат
                gRecPending := True;
                ScheduleStats;
                if not fDirty then begin fDirty := True; ApplyTitle; end;
              end;
            EN_UPDATE:
              begin
                if fStatus and (CurZoom <> gZoom) then UpdateStatus;  // Ctrl+колелце
{$IFDEF FEAT_LINENUMBERS}
                LnInvalidate;
{$ENDIF}
              end;
{$IFDEF FEAT_LINENUMBERS}
            EN_VSCROLL: LnInvalidate;
{$ENDIF}
          end;
          Exit;
        end;
        cmd := LoWrd(wParam);
        case cmd of
          IDM_FILE_NEW:
            if MaybeSaveChanges then NewFile;
          IDM_FILE_OPEN:
            if MaybeSaveChanges then
            begin
              gDropFile := '';
              if PickFile(False, gDropFile) then LoadFile(gDropFile);
            end;
          IDM_SAVE:           CmdSave;
          IDM_FILE_SAVEAS:    CmdSaveAs;
          IDM_FILE_PRINT:     PrintDoc;
          IDM_FILE_PAGESETUP: PageSetup;
          IDM_FILE_EXIT:      SendMessageW(hWnd, WM_CLOSE, 0, 0);
          IDM_EDIT_UNDO:   EdMsg(EM_UNDO, 0, 0);
          IDM_EDIT_REDO:   EdMsg(EM_REDO, 0, 0);
          IDM_EDIT_CUT:    EdMsg(WM_CUT, 0, 0);
          IDM_EDIT_COPY:   EdMsg(WM_COPY, 0, 0);
          IDM_EDIT_PASTE:  EdMsg(WM_PASTE, 0, 0);
          IDM_EDIT_DELETE: EdMsg(WM_CLEAR, 0, 0);
          IDM_EDIT_SELALL:
            begin
              SetFocus(hEdit);
              EdMsg(EM_SETSEL, 0, -1);
            end;
          IDM_EDIT_TIME:
            begin
              SetFocus(hEdit);
              InsertTimeDate;
            end;
          IDM_EDIT_FIND:     OpenFindDlg(False);
          IDM_EDIT_FINDNEXT: CmdFindNext(True);
          IDM_EDIT_FINDPREV: CmdFindNext(False);
          IDM_EDIT_REPLACE:  OpenFindDlg(True);
          IDM_EDIT_GOTO:     GoToDlg;
          IDM_FMT_WRAP:
            begin
              fWrap := not fWrap;
              ApplyWrap;
              SyncMenus;
            end;
          IDM_FMT_FONT:      ChooseFontDlg;
          IDM_FMT_SPELL:
            begin
              fSpell := not fSpell;
              ApplySpell;
              SyncMenus;
            end;
          IDM_FMT_UPPER:     ChangeCase(0);
          IDM_FMT_LOWER:     ChangeCase(1);
          IDM_FMT_TITLE:     ChangeCase(2);
          IDM_FMT_TOLATIN:   Transliterate(True);
          IDM_FMT_TOCYR:     Transliterate(False);
          IDM_LINES_SORTASC:  LinesOp(0);
          IDM_LINES_SORTDESC: LinesOp(1);
          IDM_LINES_DEDUP:    LinesOp(2);
          IDM_LINES_TRIM:     LinesOp(3);
          IDM_EDIT_SPEAK:     CmdSpeak;
          IDM_EDIT_CALC:      CmdCalc;
          IDM_EDIT_FIXLAYOUT: CmdFixLayout;
          IDM_EDIT_RUNLINE:   CmdRunLine;
          IDM_EDIT_RUNSTOP:   RunStop;
          IDM_TOOLS_TASKS:    CmdListTasks;
          IDM_TOOLS_DELTASK:  CmdDeleteTask;
          IDM_TOOLS_SCHEDHELP: CmdScheduleHelp;
          IDM_SPEAK_REMIND:
            begin
              fRemindSpeak := not fRemindSpeak;
              SyncVoiceMenu;
            end;
          IDM_FMT_AUTOINDENT:
            begin
              fAutoIndent := not fAutoIndent;
              SyncMenus;
            end;
          IDM_VOICE_AUTO:
            begin
              gVoiceSel := '';
              SyncVoiceMenu;
            end;
          IDM_VOICE_FIRST..IDM_VOICE_LAST:
            if cmd - IDM_VOICE_FIRST <= High(gVoices) then
            begin
              gVoiceSel := gVoices[cmd - IDM_VOICE_FIRST].Id;
              SyncVoiceMenu;
            end;
          IDM_SPEAK_HILITE:
            begin
              fSpeakHilite := not fSpeakHilite;
              SyncVoiceMenu;
            end;
          IDM_RATE_FIRST..IDM_RATE_LAST:
            begin
              gRateIdx := cmd - IDM_RATE_FIRST;
              if gVoice <> nil then gVoice.SetRate(RateValues[gRateIdx]);
              SyncVoiceMenu;
            end;
          IDM_MRU_FIRST..IDM_MRU_LAST:
            begin
              w := cmd - IDM_MRU_FIRST;
              if gMru[w] = '' then Exit;
              gDropFile := gMru[w];   // копие: MruAdd ще размести масива
              if FileExists(gDropFile) then OpenPath(gDropFile)
              else
              begin
                MsgBox('Cannot find file:'#13#10 + gMru[w], MB_OK or MB_ICONWARNING);
                MruRemove(w);
              end;
            end;
          IDM_MRU_CLEAR:
            begin
              for w := 0 to MRU_MAX - 1 do gMru[w] := '';
              MruRebuild;
            end;
          IDM_VIEW_ZOOMIN:   SetZoom((CurZoom div 10 + 1) * 10);
          IDM_VIEW_ZOOMOUT:  SetZoom(((CurZoom + 9) div 10 - 1) * 10);
          IDM_VIEW_ZOOMRESET: SetZoom(100);
          IDM_VIEW_STATUS:
            begin
              fStatus := not fStatus;
              if fStatus then ShowWindow(hStatus, SW_SHOW)
              else ShowWindow(hStatus, SW_HIDE);
              RelayoutClient;
              UpdateStatus;
              ScheduleStats;
              SyncMenus;
            end;
{$IFDEF FEAT_LINENUMBERS}
          IDM_VIEW_LINENUM:
            begin
              fLineNum := not fLineNum;
              RelayoutClient;
              InvalidateRect(hWnd, nil, True);
              SyncMenus;
            end;
{$ENDIF}
{$IFDEF FEAT_DARKMODE}
          IDM_VIEW_DARK:
            begin
              fDark := not fDark;
              ApplyDark;
              SyncMenus;
            end;
{$ENDIF}
          IDM_ENC_FIRST..IDM_ENC_LAST:
            if TEncoding(cmd - IDM_ENC_FIRST) <> gEnc then
            begin
              gEnc := TEncoding(cmd - IDM_ENC_FIRST);
              if not fDirty then begin fDirty := True; ApplyTitle; end;
              SyncMenus;
              UpdateStatus;
            end;
          IDM_EOL_FIRST..IDM_EOL_LAST:
            if TEol(cmd - IDM_EOL_FIRST) <> gEol then
            begin
              gEol := TEol(cmd - IDM_EOL_FIRST);
              if not fDirty then begin fDirty := True; ApplyTitle; end;
              SyncMenus;
              UpdateStatus;
            end;
          IDM_HELP_ABOUT:
            MessageBoxW(hWnd, AboutText, AppName, MB_OK or MB_ICONINFORMATION);
          IDM_HELP_VIEWHELP:
            ShellExecuteW(0, 'open', HelpUrl, nil, nil, SW_SHOWNORMAL);
        end;
      end;

    WM_NOTIFY:
      begin
        pf := PMsgFilterRec(lParam);
        if pf^.nmhdr.hwndFrom = hEdit then
          case pf^.nmhdr.code of
            EN_SELCHANGE:
              begin
                UpdateStatus;
                if not gSpeaking then ScheduleStats;   // без мигане при караоке
              end;
            EN_MSGFILTER:
              if pf^.msg = WM_RBUTTONUP then
              begin
                GetCursorPos(@pt);
                ShowContextMenu(pt.X, pt.Y);
                Exit(1);
              end;
            EN_DROPFILES:
              begin
                // HDROP-ът е на RichEdit-а - само четем името и отлагаме
                gDropFile := DropFileName(PEnDropFilesRec(lParam)^.hDrop);
                if gDropFile <> '' then PostMessageW(hWnd, WM_APP_OPENDROP, 0, 0);
                Exit(0);              // 0 = RichEdit да не вмъква нищо
              end;
          end;
      end;

    WM_CONTEXTMENU:                   // Shift+F10 / клавиш Menu
      begin
        if (LoWrd(lParam) = $FFFF) and (HiWrd(lParam) = $FFFF) then
        begin
          EdMsg(EM_EXGETSEL, 0, PtrInt(@cr));
          EdMsg(EM_POSFROMCHAR, PtrUInt(@pt), cr.cpMax);
          ClientToScreen(hEdit, @pt);
        end
        else
        begin
          pt.X := SmallInt(LoWrd(lParam));
          pt.Y := SmallInt(HiWrd(lParam));
        end;
        ShowContextMenu(pt.X, pt.Y);
      end;

    WM_DROPFILES:                     // пуснат върху рамката/status bar-а
      begin
        gDropFile := DropFileName(THandle(wParam));
        DragFinish(THandle(wParam));
        if gDropFile <> '' then PostMessageW(hWnd, WM_APP_OPENDROP, 0, 0);
      end;

    WM_APP_OPENDROP:
      begin
        SetForegroundWindow(hWnd);
        OpenPath(gDropFile);
      end;

    WM_SIZE:
      begin
        w := LoWrd(lParam);
        h := HiWrd(lParam);
        if (hStatus <> 0) and fStatus then
        begin
          SendMessageW(hStatus, WM_SIZE, 0, 0);
          GetWindowRect(hStatus, @rc);
          Dec(h, rc.Bottom - rc.Top);
          LayoutStatusParts(w);
        end;
        gx := 0;
{$IFDEF FEAT_LINENUMBERS}
        gx := GutterW;
        LnInvalidate;
{$ENDIF}
        SetWindowPos(hEdit, 0, gx, 0, w - gx, h, SWP_NOZORDER);
      end;

    WM_TIMER:
      case wParam of
        TIMER_STATS:
          begin
            KillTimer(hWnd, TIMER_STATS);
            UpdateWordStats;
          end;
        TIMER_AUTOSAVE:
          RecoverySnapshot;
      end;

    WM_ACTIVATEAPP:                   // връщане към програмата -> файлът променен ли е?
      if wParam <> 0 then PostMessageW(hWnd, WM_APP_CHECKFILE, 0, 0);

    WM_APP_CHECKFILE:
      CheckExternalChange;

    WM_APP_SPEECH:
      OnSpeechEvents;

    WM_APP_RUNOUT:
      RunOutput;

    WM_APP_RUNDONE:
      RunDone(DWORD(wParam));

    WM_CLOSE:                         // 1.0: X затваряше без да пита!
      if MaybeSaveChanges then DestroyWindow(hWnd);

    WM_QUERYENDSESSION:
      Result := Ord(MaybeSaveChanges);

    WM_DESTROY:
      begin
        KillTimer(hWnd, TIMER_AUTOSAVE);
        SaveSettings;
        RecoveryClose;                // чист изход -> няма какво да се възстановява
        if gRunning then TerminateJobObject(gRunJob, 1);
        if gSpeaking and (gLastWordPos >= 0) then SaveReadPos(gLastWordPos);
        if gVoice <> nil then gVoice.Speak(nil, SPF_PURGEBEFORESPEAK, nil);
        gVoice := nil;
        PostQuitMessage(0);
      end;

  else
    if (uFindMsg <> 0) and (uMsg = uFindMsg) then
      OnFindReplaceMsg                // FINDMSGSTRING нотификация
    else
      Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
  end;
end;

{ ======================= main ======================= }

const
  DefaultFace: UnicodeString = 'Consolas';

var
  wc: TWndClassW;
  msg: TMsg;
  dc: HDC;
  startFile: UnicodeString;

begin
  hInstApp := GetModuleHandleW(nil);
  LoadLibraryW(RichDll);                       // модерният Rich Edit
  InitCommonControls;
  uFindMsg := RegisterWindowMessageW('commdlg_FindReplace');
  InitFR;
  InitializeCriticalSection(gRunCS);

  dc := GetDC(0);
  gDpi := GetDeviceCaps(dc, LOGPIXELSY);
  ReleaseDC(0, dc);

  // default шрифт: Consolas 11pt (1.0: Courier, без размер)
  FillChar(RichFont, SizeOf(RichFont), 0);
  RichFont.cbSize := SizeOf(RichFont);
  RichFont.dwMask := CFM_FACE or CFM_SIZE;
  RichFont.yHeight := 220;
  Move(DefaultFace[1], RichFont.szFaceName, Length(DefaultFace) * 2);
  LoadSettings;
  EnumVoices;

  // "trpad /remind текст" - пуснат от Task Scheduler: само напомняне
  startFile := ParseStartupFile;
  if (AsciiLower(Copy(startFile, 1, 8)) = '/remind ') or (AsciiLower(startFile) = '/remind') then
  begin
    startFile := TrimW(Copy(startFile, 9, MaxInt));
    if (Length(startFile) >= 2) and (startFile[1] = '"') and
       (startFile[Length(startFile)] = '"') then
      startFile := Copy(startFile, 2, Length(startFile) - 2);
    if startFile = '' then startFile := 'Reminder';
    ShowReminder(startFile);
    ExitProcess(0);
  end;

  FillChar(wc, SizeOf(wc), 0);
  wc.lpfnWndProc   := @MainWndProc;
  wc.hInstance     := hInstApp;
  wc.hCursor       := LoadCursorW(0, PWideChar(PtrUInt(32512)));   // IDC_ARROW
  wc.hIcon         := LoadIconW(0, PWideChar(PtrUInt(32512)));     // IDI_APPLICATION
  wc.hbrBackground := HBRUSH(COLOR_BTNFACE + 1);
  wc.lpszClassName := ClassName;
  RegisterClassW(@wc);

  hMain := CreateWindowExW(0, ClassName, ClassName, WS_OVERLAPPEDWINDOW,
             CW_USEDEFAULT, CW_USEDEFAULT, S(WindowWidth), S(WindowHeight),
             0, 0, hInstApp, nil);
  if hMain = 0 then ExitProcess(0);

  gAccel := CreateAcceleratorTableW(@AccelTable[0], Length(AccelTable));

  // възстановяване на настройките
  if gStartZoom <> 100 then EdMsg(EM_SETZOOM, gStartZoom, 100);
  ApplyWrap;
  if not fStatus then ShowWindow(hStatus, SW_HIDE);
{$IFDEF FEAT_DARKMODE}
  if fDark then ApplyDark else
{$ENDIF}
  ApplyCharFormat;
  if fSpell then ApplySpell;
  SyncMenus;

  // позиция на прозореца - само ако е върху съществуващ монитор
  if gHavePlacement and
     (MonitorFromRect(@gPlacement.rcNormalPosition, 0) <> 0) then
  begin
    if gPlacement.showCmd = SW_SHOWMINIMIZED then
      gPlacement.showCmd := SW_SHOWNORMAL;
    SetWindowPlacement(hMain, @gPlacement);
  end
  else
    ShowWindow(hMain, SW_SHOWDEFAULT);
  RelayoutClient;

  startFile := ParseStartupFile;
  fLoading := False;
  if not RecoveryRestore then         // първо: има ли текст за спасяване?
  begin
    if startFile <> '' then
    begin
      if FileExists(startFile) then LoadFile(startFile)
      else gFile := FullPath(startFile);   // нов файл - ще се създаде при Save
    end;
    fDirty := False;
  end;
  ApplyTitle;
  UpdateStatus;
  ScheduleStats;
  SetTimer(hMain, TIMER_AUTOSAVE, AUTOSAVE_MS, nil);
  SetFocus(hEdit);

  while GetMessageW(@msg, 0, 0, 0) do
  begin
    // активният modeless Find/Replace си обработва клавишите
    if (hFindDlg <> 0) and IsDialogMessageW(hFindDlg, @msg) then Continue;
    if TranslateAcceleratorW(hMain, gAccel, @msg) <> 0 then Continue;
    // Ctrl+Enter = изпълни реда; Esc = спри командата
    if (msg.message = WM_KEYDOWN) and (msg.hwnd = hEdit) and
       (msg.wParam = VK_RETURN) and (GetKeyState(VK_CONTROL) < 0) and
       (GetKeyState(VK_MENU) >= 0) then
    begin
      CmdRunLine;
      Continue;
    end;
    if gRunning and (msg.message = WM_KEYDOWN) and (msg.wParam = VK_ESCAPE) then
    begin
      RunStop;
      Continue;
    end;
    // auto-indent: Enter се обработва преди TranslateMessage -> няма WM_CHAR
    if (msg.message = WM_KEYDOWN) and (msg.hwnd = hEdit) and
       (msg.wParam = VK_RETURN) and (GetKeyState(VK_CONTROL) >= 0) and
       (GetKeyState(VK_MENU) >= 0) and DoAutoIndent then Continue;
    TranslateMessage(msg);
    DispatchMessageW(msg);
  end;

  DestroyAcceleratorTable(gAccel);
  ExitProcess(msg.wParam);
end.
