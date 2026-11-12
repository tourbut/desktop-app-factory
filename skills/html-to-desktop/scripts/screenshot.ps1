# 앱 exe 를 띄워 창을 PNG 로 찍는다. 추가 설치 없이 Windows 기본 .NET(System.Drawing)과 user32 만 쓴다.
# 사용: powershell -ExecutionPolicy Bypass -File screenshot.ps1 -Exe <앱.exe> -Png <저장경로.png> [-WaitSec 4] [-Keep]
# -Keep 이 없으면 찍은 뒤 앱을 종료한다.
param(
  [Parameter(Mandatory)][string]$Exe,
  [Parameter(Mandatory)][string]$Png,
  [int]$WaitSec = 4,
  [switch]$Keep
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8 # 없으면 Bash 등 다른 셸을 거칠 때 한글 출력이 깨진다
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Win {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
}
'@
[Win]::SetProcessDPIAware() | Out-Null # 없으면 고DPI 화면에서 창 일부만 찍힌다

$p = Start-Process -FilePath (Resolve-Path $Exe).Path -PassThru
try {
  $deadline = (Get-Date).AddSeconds(30)
  do { Start-Sleep -Milliseconds 300; $p.Refresh() } until ($p.MainWindowHandle -ne 0 -or $p.HasExited -or (Get-Date) -gt $deadline)
  if ($p.MainWindowHandle -eq 0) { throw '앱 창을 찾지 못했다 (바로 종료됐거나 30초 안에 뜨지 않음).' }
  Start-Sleep -Seconds $WaitSec # WebView2 가 페이지를 그릴 시간

  $r = New-Object Win+RECT
  [Win]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
  $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $hdc = $g.GetHdc()
  # 2 = PW_RENDERFULLCONTENT: 다른 창에 가려져 있어도 WebView2(DirectComposition) 내용까지 찍는다.
  $ok = [Win]::PrintWindow($p.MainWindowHandle, $hdc, 2)
  $g.ReleaseHdc($hdc); $g.Dispose()
  if (-not $ok) { throw 'PrintWindow 실패' }
  # 창 사각형에는 보이지 않는 크기 조절 테두리가 포함돼 검게 찍힌다. 보이는 영역(DWMWA_EXTENDED_FRAME_BOUNDS=9)만 잘라낸다.
  $v = New-Object Win+RECT
  if ([Win]::DwmGetWindowAttribute($p.MainWindowHandle, 9, [ref]$v, 16) -eq 0) {
    $crop = New-Object System.Drawing.Rectangle ($v.L - $r.L), ($v.T - $r.T), ($v.R - $v.L), ($v.B - $v.T)
    $full = $bmp; $bmp = $full.Clone($crop, $full.PixelFormat); $full.Dispose()
  }
  $bmp.Save([IO.Path]::GetFullPath($Png), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  Write-Host "OK: $Png (pid=$($p.Id))"
} finally {
  if (-not $Keep -and -not $p.HasExited) { Stop-Process -Id $p.Id }
}
