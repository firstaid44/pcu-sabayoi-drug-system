<#
  EA Live Dashboard  (log-only)  v6.0
  v6.0: อัปเดตหน้าจอแบบไม่โหลดหน้าใหม่ (live.js + DOM morph) -> ไม่กระพริบ ไม่เลื่อนกลับบนสุด
  อ่าน log ของ MT5 อย่างเดียว  ไม่แตะ EA  ไม่แตะ MT5  ไม่ส่งคำสั่งเทรดใดๆ
  สร้างไฟล์ dashboard.html แล้ววนสร้างใหม่ทุก ๆ N วินาที
#>
[CmdletBinding()]
param(
  [string]$DataDir  = "$env:APPDATA\MetaQuotes\Terminal\3EFD9CBD5D42C604C5FB210C49B55791",
  [string]$OutFile  = '',
  [int]   $Interval = 5,
  [double]$ContractSize = 100.0,   # XAUUSD 1 lot = 100 oz -> 0.02 lot = 2 USD ต่อการวิ่งราคา 1.00
  [int]   $DayStartHour = 6,       # วันเทรดของ EA เริ่ม 06:00 เวลาไทย (= เที่ยงคืนเวลาเซิร์ฟเวอร์)
  [int]   $NotifySeconds = 90,     # ป้ายแจ้งเตือนเปิด/ปิดไม้ ค้างบนจอกี่วินาที
  # ฟอนต์: plex (แนะนำ) | prompt | anuphan | noto | sarabun | kanit | niramit (ต้องติดตั้งในเครื่อง)
  [ValidateSet('plex','prompt','anuphan','noto','sarabun','kanit','niramit')]
  [string]$Font = 'plex',
  [string]$Account = '',           # เลขบัญชีที่จะโชว์บนหัวหน้า Home (เว้นว่าง = ใช้จาก PosExport ถ้ามี)
  [switch]$Once
)

$ErrorActionPreference = 'Continue'

# หาโฟลเดอร์ของสคริปต์เอง (PowerShell บางรุ่นไม่ตั้ง $PSScriptRoot ตอน bind พารามิเตอร์)
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = Split-Path -Parent $PSCommandPath -ErrorAction SilentlyContinue }
if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue }
if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = (Get-Location).Path }
if ([string]::IsNullOrWhiteSpace($OutFile))   { $OutFile = Join-Path $ScriptDir 'dashboard.html' }
if ([string]::IsNullOrWhiteSpace($DataDir))   { $DataDir = "$env:APPDATA\MetaQuotes\Terminal\3EFD9CBD5D42C604C5FB210C49B55791" }
if (-not (Test-Path -LiteralPath $DataDir)) {
  Write-Host "ไม่พบโฟลเดอร์ข้อมูลของ MT5: $DataDir" -ForegroundColor Red
  Write-Host 'สั่งใหม่โดยระบุเอง เช่น:  .\build-dashboard.ps1 -DataDir C:\...\Terminal\<รหัสโฟลเดอร์>' -ForegroundColor Yellow
  return
}
$IC = [Globalization.CultureInfo]::InvariantCulture

# ---------- ฟอนต์ ----------
$FontMap = @{
  'plex'    = @{ q='family=IBM+Plex+Sans+Thai:wght@400;500;600;700'; f='"IBM Plex Sans Thai","IBM Plex Sans"'; n='IBM Plex Sans Thai' }
  'prompt'  = @{ q='family=Prompt:wght@300;400;500;600;700';         f='"Prompt"';            n='Prompt' }
  'anuphan' = @{ q='family=Anuphan:wght@400;500;600;700';            f='"Anuphan"';           n='Anuphan' }
  'noto'    = @{ q='family=Noto+Sans+Thai:wght@400;500;600;700';     f='"Noto Sans Thai"';    n='Noto Sans Thai' }
  'sarabun' = @{ q='family=Sarabun:wght@400;500;600;700';            f='"Sarabun"';           n='Sarabun' }
  'kanit'   = @{ q='family=Kanit:wght@300;400;500;600;700';          f='"Kanit"';             n='Kanit' }
  'niramit' = @{ q='';  f='"TH Niramit AS","TH Niramit","TH SarabunPSK","TH Sarabun New"';    n='TH Niramit (ฟอนต์ในเครื่อง)' }
}
$FontPick  = $FontMap[$Font]
$FontStack = $FontPick.f + ',"Leelawadee UI","Segoe UI","Noto Sans Thai",Tahoma,sans-serif'

# ---------- helpers ----------
function Read-LogLines([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  try {
    $fs = [System.IO.File]::Open($path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
    $sr = New-Object System.IO.StreamReader($fs,[System.Text.Encoding]::Unicode)
    $txt = $sr.ReadToEnd(); $sr.Dispose(); $fs.Dispose()
    return ($txt -split "`r?`n")
  } catch { return @() }
}
function D([string]$s) { try { [double]::Parse($s,$IC) } catch { 0.0 } }
function F2([double]$v) { $v.ToString('F2',$IC) }
function JEsc([string]$s) {
  if ($null -eq $s) { return '' }
  $s.Replace('\','\\').Replace('"','\"').Replace('<','\u003c')
}
function Enc([string]$s) {
  if ($null -eq $s) { return '' }
  $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

# แปลง log 1 ไฟล์ (1 วัน) เป็น object
function Parse-LogFile([string]$path,[datetime]$day) {
  $out = New-Object System.Collections.ArrayList
  foreach ($ln in (Read-LogLines $path)) {
    if ([string]::IsNullOrWhiteSpace($ln)) { continue }
    $p = $ln.Split("`t")
    if ($p.Length -lt 5) { continue }
    $tm = $p[2]
    if ($tm.Length -lt 8) { continue }
    try {
      $t = $day.Date.AddHours([int]$tm.Substring(0,2)).AddMinutes([int]$tm.Substring(3,2)).AddSeconds([double]::Parse($tm.Substring(6),$IC))
    } catch { continue }
    [void]$out.Add([pscustomobject]@{
      T   = $t
      Src = $p[3]
      Msg = ($p[4..($p.Length-1)] -join "`t")
    })
  }
  return $out
}

# ---------- กฎจัดระดับความสำคัญของข้อความ log ----------
$SevRules = @(
  @{ p='\[ACCOUNT GUARD\]';            s='critical'; l='เพดานบัญชี' },
  @{ p='\[BASKET CUT\]';               s='critical'; l='ตัดตะกร้า'   },
  @{ p='auto trading disabled';        s='critical'; l='Algo ปิดอยู่' },
  @{ p='\[OPEN FAIL\]';                s='critical'; l='เปิดไม้ไม่สำเร็จ' },
  @{ p='หยุดทำงาน \(reason';           s='critical'; l='EA ถูกถอด/คอมไพล์' },
  @{ p='\[WARN\]';                     s='serious';  l='คำเตือน' },
  @{ p='\[ปิดขาดทุน\]';                s='serious';  l='ปิดขาดทุน' },
  @{ p='หยุดเทรด|ล็อกดาวน์|\[ห้ามเทรด\]|\[พัก\]'; s='warning'; l='พัก/ล็อก' },
  @{ p='\[RESUME\]';                   s='good';     l='กลับมาเทรด' },
  @{ p='\[ล็อกกำไร\]|ล็อกกำไร';        s='good';     l='ล็อกกำไร' },
  @{ p='\[TRAIL\]';                    s='info';     l='เลื่อน SL' },
  @{ p='\[OPEN\]';                     s='info';     l='เปิดไม้' },
  @{ p='\[SKIP\]';                     s='info';     l='ข้ามสัญญาณ' },
  @{ p='\[SIGNAL\]';    s='info'; l='สัญญาณ' },
  @{ p='\[NOTIFY\]';    s='info'; l='แจ้งเตือน' },
  @{ p='\[ตรวจสภาพ\]';  s='beat'; l='หายใจ' }
)
function Get-Sev([string]$m) {
  foreach ($ru in $SevRules) { if ($m -match $ru.p) { return @{ s=$ru.s; l=$ru.l } } }
  return @{ s='none'; l='' }
}

# ---------- อ่านไม้ที่ถืออยู่แบบสด จาก PosExport.mq5 ----------
function Get-LivePositions([string]$DataDir) {
  $f = Join-Path $DataDir 'MQL5\Files\ea_positions.csv'
  $res = [pscustomobject]@{ Ok=$false; Age=999999; Acc=$null; Pos=@() }
  if (-not (Test-Path -LiteralPath $f)) { return $res }
  try {
    $fs = [System.IO.File]::Open($f,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
    $sr = New-Object System.IO.StreamReader($fs,[System.Text.Encoding]::Default)
    $txt = $sr.ReadToEnd(); $sr.Dispose(); $fs.Dispose()
  } catch { return $res }
  $res.Age = [int]((Get-Date) - (Get-Item -LiteralPath $f).LastWriteTime).TotalSeconds
  $pos = New-Object System.Collections.ArrayList
  foreach ($ln in ($txt -split "`r?`n")) {
    if ([string]::IsNullOrWhiteSpace($ln)) { continue }
    $c = $ln.Split(';')
    if ($c[0] -eq 'ACC' -and $c.Length -ge 11) {
      $res.Acc = [pscustomobject]@{
        Login=$c[1]; Balance=(D $c[2]); Equity=(D $c[3]); Margin=(D $c[4]); Free=(D $c[5])
        Level=(D $c[6]); Profit=(D $c[7]); Cur=$c[8]; SrvTime=$c[9]; LocTime=$c[10]; N=[int](D $c[11])
      }
      $res.Ok = $true
    }
    elseif ($c[0] -eq 'POS' -and $c.Length -ge 13) {
      $mg = $c[2]
      $nm = 'มือ/อื่นๆ'
      if ($mg -eq '77401') { $nm = 'ScalperEA' } elseif ($mg -eq '77301') { $nm = 'GridTrader' }
      [void]$pos.Add([pscustomobject]@{
        Ticket=$c[1]; Magic=$mg; EA=$nm; Sym=$c[3]; Dir=$c[4]; Lot=(D $c[5])
        Open=(D $c[6]); SL=(D $c[7]); TP=(D $c[8]); Cur=(D $c[9])
        Profit=(D $c[10]); Swap=(D $c[11]); OpenT=$c[12]; Comment=$(if ($c.Length -ge 14) { $c[13] } else { '' })
      })
    }
  }
  $res.Pos = @($pos)
  return $res
}

function Get-Model {
  param([string]$DataDir,[double]$ContractSize,[int]$DayStartHour)

  $now = Get-Date
  $dayStart = $now.Date.AddHours($DayStartHour)
  if ($now -lt $dayStart) { $dayStart = $dayStart.AddDays(-1) }

  # อ่านไฟล์ log ตั้งแต่วันที่ dayStart ถึงวันนี้ (ไฟล์ log ตัดที่เที่ยงคืนเวลาไทย)
  $days = @()
  $d = $dayStart.Date
  while ($d -le $now.Date) { $days += $d; $d = $d.AddDays(1) }

  $J = New-Object System.Collections.ArrayList   # Journal / Trades
  $E = New-Object System.Collections.ArrayList   # Experts
  foreach ($dd in $days) {
    $stamp = $dd.ToString('yyyyMMdd')
    foreach ($r in (Parse-LogFile (Join-Path $DataDir "Logs\$stamp.log") $dd))      { [void]$J.Add($r) }
    foreach ($r in (Parse-LogFile (Join-Path $DataDir "MQL5\Logs\$stamp.log") $dd)) { [void]$E.Add($r) }
  }

  $lastLog = $null
  if ($J.Count -gt 0 -or $E.Count -gt 0) {
    $all = @()
    if ($J.Count) { $all += $J[$J.Count-1].T }
    if ($E.Count) { $all += $E[$E.Count-1].T }
    $lastLog = ($all | Sort-Object)[-1]
  }

  # ---------- 1) deal ทั้งหมดจาก Trades ----------
  $deals = New-Object System.Collections.ArrayList
  $byDeal = @{}
  $reDeal = [regex]'deal #(\d+) (buy|sell) ([\d.]+) (\S+) at ([\d.]+) done \(based on order #(\d+)\)'
  foreach ($r in $J) {
    if ($r.Src -ne 'Trades') { continue }
    $m = $reDeal.Match($r.Msg); if (-not $m.Success) { continue }
    $o = [pscustomobject]@{
      Id=$m.Groups[1].Value; T=$r.T; Dir=$m.Groups[2].Value; Lot=(D $m.Groups[3].Value)
      Sym=$m.Groups[4].Value; Price=(D $m.Groups[5].Value); Order=$m.Groups[6].Value
      Profit=$null; Reason=''; EA='?'; Note=''; SL=0.0; TP=0.0
    }
    [void]$deals.Add($o); $byDeal[$o.Id] = $o
  }

  # ---------- 2) กำไร/ขาดทุน + เหตุผลปิด จาก Notifications ----------
  $reProfit = [regex]"deal #(\d+) (?:buy|sell) [\d.]+ \S+ at [\d.]+ done, profit: (-?[\d.]+) USD"
  $reReason = [regex]'added order #(\d+) .*?due (stop loss|take profit)'
  $reCloseBy= [regex]'close by [\d.]+ \S+ at [\d.]+, #(\d+) by #(\d+)'
  $reasonByOrder = @{}
  $closeByPairs  = New-Object System.Collections.ArrayList
  foreach ($r in $J) {
    if ($r.Src -ne 'Notifications') { continue }
    $m = $reProfit.Match($r.Msg)
    if ($m.Success -and $byDeal.ContainsKey($m.Groups[1].Value)) { $byDeal[$m.Groups[1].Value].Profit = (D $m.Groups[2].Value) }
    $m2 = $reReason.Match($r.Msg)
    if ($m2.Success) { $reasonByOrder[$m2.Groups[1].Value] = $m2.Groups[2].Value }
    $m3 = $reCloseBy.Match($r.Msg)
    if ($m3.Success) { [void]$closeByPairs.Add([pscustomobject]@{ T=$r.T; A=$m3.Groups[1].Value; B=$m3.Groups[2].Value }) }
  }
  foreach ($o in $deals) { if ($reasonByOrder.ContainsKey($o.Order)) { $o.Reason = $reasonByOrder[$o.Order] } }

  # ---------- 2b) SL/TP ปัจจุบันของแต่ละ ticket (จากบรรทัด modify) ----------
  $slNow = @{}; $tpNow = @{}
  $reMod = [regex]'modify #(\d+) .*?-> sl: ([\d.]+), tp: ([\d.]+)'
  foreach ($r in $J) {
    if ($r.Src -ne 'Trades') { continue }
    $m = $reMod.Match($r.Msg); if (-not $m.Success) { continue }
    $slNow[$m.Groups[1].Value] = (D $m.Groups[2].Value)
    $tpNow[$m.Groups[1].Value] = (D $m.Groups[3].Value)
  }

  # ---------- 3) ระบุเจ้าของไม้ (SCLP=ScalperEA, GT=GridTrader) ----------
  $tags = New-Object System.Collections.ArrayList
  $reTag = [regex]'placed for execution \(([A-Za-z]+)\|'
  foreach ($r in $J) {
    if ($r.Src -ne 'Trades') { continue }
    $m = $reTag.Match($r.Msg); if ($m.Success) {
      $nm = if ($m.Groups[1].Value -eq 'SCLP') { 'ScalperEA' } elseif ($m.Groups[1].Value -eq 'GT') { 'GridTrader' } else { $m.Groups[1].Value }
      [void]$tags.Add([pscustomobject]@{ T=$r.T; EA=$nm })
    }
  }
  $exOpens = New-Object System.Collections.ArrayList
  $reExOpen = [regex]'\[OPEN\] (BUY|SELL)'
  foreach ($r in $E) {
    $m = $reExOpen.Match($r.Msg); if ($m.Success) {
      [void]$exOpens.Add([pscustomobject]@{ T=$r.T; EA=($r.Src -split ' ')[0]; Dir=$m.Groups[1].Value.ToLower(); Msg=$r.Msg })
    }
  }
  function Find-OpenMsg($o) {
    foreach ($x in $exOpens) { if ([math]::Abs(($o.T-$x.T).TotalSeconds) -le 15 -and $x.Dir -eq $o.Dir) { return $x.Msg } }
    return ''
  }
  function Find-CloseMsg($t, $ea) {
    foreach ($r in $E) {
      if ($r.T -lt $t.AddSeconds(-30) -or $r.T -gt $t.AddSeconds(45)) { continue }
      if ((($r.Src -split ' ')[0]) -ne $ea) { continue }
      if ($r.Msg -match '\[ปิดขาดทุน\]|\[ล็อกกำไร\]|\[BASKET CUT\]|\[ACCOUNT GUARD\]|\[TRAIL\]|\[ปิด|ตัดขาดทุน|ปิดไม้') { return $r.Msg }
    }
    return ''
  }
  function Resolve-EA($o) {
    $best=$null; $bestGap=99
    foreach ($t in $tags) { $g=($o.T-$t.T).TotalSeconds; if ($g -ge 0 -and $g -le 8 -and $g -lt $bestGap) { $bestGap=$g; $best=$t.EA } }
    if ($best) { return $best }
    foreach ($x in $exOpens) { if ([math]::Abs(($o.T-$x.T).TotalSeconds) -le 15 -and $x.Dir -eq $o.Dir) { return $x.EA } }
    return 'ปิด/เปิดเอง'
  }

  # ---------- 4) จับคู่ไม้ปิด กับ ไม้เปิด (ใช้ราคาเข้าที่คำนวณย้อนจากกำไร) ----------
  $openList = New-Object System.Collections.ArrayList
  $closed   = New-Object System.Collections.ArrayList
  foreach ($o in ($deals | Sort-Object T)) {
    if ($null -eq $o.Profit) {
      $o.EA = (Resolve-EA $o)
      $o.Note = (Find-OpenMsg $o)
      [void]$openList.Add($o)
      continue
    }
    $usdPer1 = $o.Lot * $ContractSize          # USD ต่อการวิ่งราคา 1.00
    if ($usdPer1 -le 0) { $usdPer1 = 2.0 }
    $entry = if ($o.Dir -eq 'buy') { $o.Price + $o.Profit/$usdPer1 } else { $o.Price - $o.Profit/$usdPer1 }
    $want  = if ($o.Dir -eq 'buy') { 'sell' } else { 'buy' }
    $cand  = @($openList | Where-Object { $_.Dir -eq $want -and [math]::Abs($_.Lot-$o.Lot) -lt 1e-9 })
    if ($cand.Count -gt 0) {
      $pick = $cand | Sort-Object { [math]::Abs($_.Price-$entry) } | Select-Object -First 1
      for ($k=0; $k -lt $openList.Count; $k++) { if ($openList[$k].Id -eq $pick.Id) { $openList.RemoveAt($k); break } }
      [void]$closed.Add([pscustomobject]@{
        EA=$pick.EA; Dir=$pick.Dir; Lot=$pick.Lot
        OpenT=$pick.T; OpenP=$pick.Price; CloseT=$o.T; CloseP=$o.Price
        Profit=$o.Profit; Reason=$o.Reason; Order=$pick.Order
        Note=$pick.Note; CNote=(Find-CloseMsg $o.T $pick.EA)
      })
    } else {
      [void]$closed.Add([pscustomobject]@{
        EA='ไม่ทราบ'; Dir=$want; Lot=$o.Lot
        OpenT=$null; OpenP=0.0; CloseT=$o.T; CloseP=$o.Price
        Profit=$o.Profit; Reason=$o.Reason; Order=$o.Order
        Note=''; CNote=''
      })
    }
  }
  # ปิดแบบ Close By : อีกขาหนึ่งถูกปิดไปด้วย แต่ไม่มี notification กำไร
  foreach ($pr in $closeByPairs) {
    foreach ($ordId in @($pr.A,$pr.B)) {
      $left = @($openList | Where-Object { $_.Order -eq $ordId })
      foreach ($l in $left) {
        for ($k=0; $k -lt $openList.Count; $k++) { if ($openList[$k].Id -eq $l.Id) { $openList.RemoveAt($k); break } }
        [void]$closed.Add([pscustomobject]@{
          EA=$l.EA; Dir=$l.Dir; Lot=$l.Lot
          OpenT=$l.T; OpenP=$l.Price; CloseT=$pr.T; CloseP=$l.Price
          Profit=0.0; Reason='close by'; Order=$l.Order
          Note=$l.Note; CNote=''
        })
      }
    }
  }

  # กรองเฉพาะวันเทรดปัจจุบัน (เริ่ม 06:00 เวลาไทย)
  $closedToday = @($closed | Where-Object { $_.CloseT -ge $dayStart } | Sort-Object CloseT)
  $openNow     = @($openList | Sort-Object T)
  $reST = [regex]'SL=([\d.]+) TP=([\d.]+)'
  foreach ($o in $openNow) {
    $mm = $reST.Match($o.Note)
    if ($mm.Success) { $o.SL = (D $mm.Groups[1].Value); $o.TP = (D $mm.Groups[2].Value) }
    if ($slNow.ContainsKey($o.Order)) { $o.SL = $slNow[$o.Order] }
    if ($tpNow.ContainsKey($o.Order)) { $o.TP = $tpNow[$o.Order] }
  }

  # ---------- 5) เหตุการณ์ / เตือนภัย ----------
  $events = New-Object System.Collections.ArrayList
  foreach ($r in $E) {
    if ($r.T -lt $dayStart) { continue }
    $sv = Get-Sev $r.Msg
    if ($sv.s -eq 'none' -or $sv.s -eq 'beat') { continue }
    [void]$events.Add([pscustomobject]@{ T=$r.T; EA=(($r.Src -split ' ')[0]); Sev=$sv.s; Tag=$sv.l; Msg=$r.Msg })
  }
  $events = @($events | Sort-Object T)

  # ---------- 6) สถานะล่าสุด ----------
  # ชีพจรของ EA แต่ละตัว = บรรทัด log ล่าสุดที่มันเขียน
  $hb = @{}
  foreach ($r in $E) {
    if ($r.Src -notmatch '\(') { continue }   # เอาเฉพาะ EA ที่รันบนกราฟ ไม่เอาบรรทัดระบบ
    $nm = ($r.Src -split ' ')[0]
    if ([string]::IsNullOrWhiteSpace($nm)) { continue }
    if ($hb.ContainsKey($nm)) {
      $hb[$nm].T = $r.T; $hb[$nm].Msg = $r.Msg
      if ($r.T -ge $dayStart) { $hb[$nm].N = $hb[$nm].N + 1 }
    } else {
      $n0 = 0; if ($r.T -ge $dayStart) { $n0 = 1 }
      $hb[$nm] = [pscustomobject]@{ EA=$nm; T=$r.T; Msg=$r.Msg; N=$n0 }
    }
  }

  # log ดิบของแท็บ Experts (300 บรรทัดล่าสุดของวันเทรดนี้)
  $tailAll = New-Object System.Collections.ArrayList
  foreach ($r in $E) {
    if ($r.T -lt $dayStart) { continue }
    $sv = Get-Sev $r.Msg
    [void]$tailAll.Add([pscustomobject]@{ T=$r.T; EA=(($r.Src -split ' ')[0]); Sev=$sv.s; Msg=$r.Msg })
  }
  $tailCount = $tailAll.Count
  $tail = @($tailAll | Select-Object -Last 300)
  $scalperHold = $null
  for ($i=$E.Count-1; $i -ge 0; $i--) {
    if ($E[$i].Msg -match 'ไม้ถือ=(\d+)') { $scalperHold = [int]$Matches[1]; break }
  }
  $lockState = 'ปกติ'
  for ($i=$E.Count-1; $i -ge 0; $i--) {
    $m = $E[$i].Msg
    if ($m -match '\[RESUME\]|ครบเวลาล็อกดาวน์') { $lockState='ปกติ'; break }
    if ($m -match 'หยุดเทรด|ล็อกดาวน์|ถึงเพดาน')  { $lockState='LOCK'; break }
  }

  [pscustomobject]@{
    Now=$now; DayStart=$dayStart; LastLog=$lastLog
    Closed=$closedToday; Open=$openNow; Events=$events
    ScalperHold=$scalperHold; Lock=$lockState; Heartbeat=$hb
    Tail=$tail; TailCount=$tailCount
    Live=(Get-LivePositions $DataDir)
  }
}

# ---------- HTML (มือถือแนวตั้ง 4 หน้าจอ ธีม Gradient Dark) ----------
$CSS = @'
:root{
  --bg:#0E1120; --card:#171B2E; --card2:#1E2438; --card3:#232B44;
  --line:#272F4A; --ink:#FFFFFF; --ink2:#AEB6D4; --muted:#737CA2;
  --acc:#3C78FC; --acc2:#4A8CFF; --cyan:#9CE4FC;
  --good:#12C46A; --bad:#F0424E; --warn:#FFC24D; --serious:#FF8A5B;
  --ea1:#4A8CFF; --ea2:#D95926; --ea2l:#F08A5B;
}
*{box-sizing:border-box}
html{background:#080A12;overflow-x:hidden}
body{margin:0;background:#080A12;color:var(--ink);
  font:16px/1.5 var(--ff);
  -webkit-font-smoothing:antialiased;display:flex;justify-content:center;overflow-x:hidden}
.phone{width:100%;max-width:440px;background:var(--bg);position:relative;overflow-x:hidden;
  padding:0 0 84px;min-height:100vh}
@media(min-width:520px){
  body{padding:22px 0}
  .phone{border-radius:32px;min-height:calc(100vh - 44px);box-shadow:0 24px 70px rgba(0,0,0,.65)}
  .tabbar{border-radius:0 0 32px 32px}
}

/* top bar */
.top{position:sticky;top:0;z-index:30;background:var(--bg);display:flex;align-items:center;
  gap:10px;padding:16px 18px 10px}
.av{width:40px;height:40px;border-radius:50%;flex:none;
  background:linear-gradient(150deg,#BFE9FF,var(--acc));display:grid;place-items:center;
  font-weight:700;color:#0E1120;font-size:15px}
.top .ttl{flex:1;font-size:17.5px;font-weight:600}
.iconbtn{width:38px;height:38px;border-radius:50%;border:1px solid var(--line);background:var(--card);
  color:var(--ink2);display:grid;place-items:center;cursor:pointer;font-size:17.5px;flex:none;padding:0}
.iconbtn:active{background:var(--card3)}

.screen{display:none;padding:2px 18px 10px}
.screen.on{display:block}
h3.st{font-size:13px;font-weight:600;color:var(--muted);letter-spacing:.09em;text-transform:uppercase;
  margin:22px 0 10px}
h3.st:first-child{margin-top:8px}
.pgttl{text-align:center;font-size:22px;font-weight:700;letter-spacing:.16em;margin:2px 0 16px}

/* greeting + hero */
.hi{font-size:23px;font-weight:700;margin:6px 0 2px}
.hisub{font-size:13.5px;color:var(--muted);line-height:1.6;margin-bottom:14px}
.heroRow{display:flex;align-items:flex-end;gap:12px;margin-bottom:6px}
.big{font-size:38px;font-weight:700;letter-spacing:-.03em;line-height:1.05;font-variant-numeric:tabular-nums}
.big .cur{font-size:22px;font-weight:600;color:var(--muted);margin-right:3px;vertical-align:.3em}
.deltaBox{margin-left:auto;text-align:right}
.deltaBox .d1{font-size:14.5px;font-weight:600}
.deltaBox .d2{height:9px;border-radius:99px;margin-top:5px;background:linear-gradient(90deg,var(--cyan),var(--acc));width:74px}
.pos{color:var(--good)} .neg{color:var(--bad)}

/* generic card */
.c{background:var(--card2);border-radius:18px;padding:14px 16px}
.c+.c{margin-top:10px}
.k{font-size:13px;color:var(--muted)}
.chip{display:inline-flex;align-items:center;gap:5px;border-radius:99px;padding:3px 10px;font-size:13px;font-weight:600}
.chip.up{background:rgba(18,196,106,.15);color:var(--good)}
.chip.dn{background:rgba(240,66,78,.15);color:var(--bad)}
.chip.nt{background:var(--card3);color:var(--ink2)}
.ea{display:inline-block;font-size:11.5px;padding:2px 9px;border-radius:99px;font-weight:600;white-space:nowrap;
  background:var(--card3);color:var(--ink2)}
.ea-s{background:rgba(74,140,255,.18);color:var(--ea1)}
.ea-g{background:rgba(217,89,38,.22);color:var(--ea2l)}
.muted{color:var(--muted)}
.empty{color:var(--muted);font-size:14px;padding:10px 0;text-align:center}

/* open position card (compact) */
.oplist{display:grid;grid-template-columns:repeat(auto-fill,minmax(168px,1fr));gap:7px}
.op{background:var(--card2);border-radius:12px;padding:8px 10px 9px;position:relative;overflow:hidden}
.op:before{content:"";position:absolute;left:0;top:0;bottom:0;width:3px;background:var(--ea1)}
.op.g:before{background:var(--ea2)}
.op.m:before{background:var(--muted)}
.oph{display:flex;align-items:center;gap:5px}
.oph .sp{flex:1}
.opp{font-size:15.5px;font-weight:700;font-variant-numeric:tabular-nums;margin-left:auto;line-height:1.2}
.oprow{font-size:12.5px;color:var(--muted);font-variant-numeric:tabular-nums;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.oprow b{color:var(--ink);font-weight:600}
.opbar{position:relative;display:flex;height:5px;border-radius:99px;margin:7px 0 5px;background:var(--card3)}
.opbar i{display:block;height:100%}
.opbar i:first-of-type{border-radius:99px 0 0 99px}
.opbar i:last-of-type{border-radius:0 99px 99px 0}
.opmk{position:absolute;top:-3.5px;width:3px;height:12px;border-radius:2px;background:#fff;
  box-shadow:0 0 6px rgba(255,255,255,.6);margin-left:-1.5px}
.opft{display:flex;justify-content:space-between;gap:6px;font-size:11.5px;font-variant-numeric:tabular-nums;white-space:nowrap}
.livedot{display:inline-block;width:7px;height:7px;border-radius:50%;background:var(--good);
  margin-right:5px;animation:pulse 1.8s ease-out infinite;color:rgba(18,196,106,.45)}
.livewarn{color:var(--warn)}
/* chart panel */
.panel{background:var(--card2);border-radius:20px;padding:14px 14px 6px}
.tabs{display:flex;gap:6px;justify-content:flex-end;margin-bottom:6px}
.tab{font:inherit;font-size:12px;cursor:pointer;border:1px solid var(--line);background:transparent;
  color:var(--muted);border-radius:9px;padding:4px 11px}
.tab.on{background:var(--acc);border-color:var(--acc);color:#fff;font-weight:600}
.io{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:12px}
.iobox{background:var(--card2);border-radius:16px;padding:12px 14px}
.iobox .kk{font-size:11px;letter-spacing:.09em;color:var(--muted);text-transform:uppercase}
.iobox .vv{font-size:19.5px;font-weight:700;margin-top:3px;font-variant-numeric:tabular-nums}

/* donut */
.gwrap{display:flex;flex-direction:column;align-items:center;margin:4px 0 6px}
.ring{width:230px;height:230px}
.ringc{fill:var(--ink);font-weight:700;font-size:40px}
.rings{fill:var(--muted);font-size:13px}

/* list rows */
.lrow{display:flex;align-items:center;gap:11px;background:var(--card2);border-radius:16px;
  padding:13px 15px;margin-bottom:10px}
.lrow .nm{flex:1;min-width:0}
.lrow .nm b{display:block;font-size:15px;font-weight:600}
.lrow .nm span{font-size:12px;color:var(--muted)}
.lrow .amt{font-size:17.5px;font-weight:700;font-variant-numeric:tabular-nums;white-space:nowrap}
.spk{flex:none}

/* trade rows */
.tr{background:var(--card2);border-radius:15px;padding:11px 14px;margin-bottom:8px;cursor:pointer}
.tr.fr{box-shadow:inset 3px 0 0 var(--good)}
.tr.fl{box-shadow:inset 3px 0 0 var(--bad)}
.trh{display:flex;align-items:center;gap:9px}
.trh .t1{font-size:14.5px;font-weight:600}
.trh .t2{font-size:12px;color:var(--muted)}
.trh .sp{flex:1}
.trh .am{font-size:17px;font-weight:700;font-variant-numeric:tabular-nums}
.det{display:none;margin-top:10px;border-top:1px solid var(--line);padding-top:10px;font-size:13px;
  color:var(--ink2);line-height:1.75}
.det.on{display:block}
.dg{display:grid;grid-template-columns:1fr 1fr;gap:3px 12px}
.dg span{color:var(--muted)}
.raw{display:block;margin-top:8px;background:var(--bg);border-radius:10px;padding:9px 11px;
  font-size:12px;word-break:break-word;color:var(--ink2)}
.nb{display:inline-block;font-size:10px;font-weight:700;padding:2px 6px;border-radius:5px;
  color:#0E1120;vertical-align:middle;letter-spacing:.04em}
.nb-w{background:var(--good)} .nb-l{background:var(--bad);color:#fff} .nb-o{background:var(--acc2);color:#fff}

/* log list */
.lg{list-style:none;margin:0;padding:0}
.lg li{display:flex;gap:9px;align-items:flex-start;padding:9px 0;border-bottom:1px solid rgba(255,255,255,.05);
  font-size:13px;color:var(--ink2);line-height:1.55}
.lg li:last-child{border-bottom:none}
.lg .tm{color:var(--muted);flex:none;font-variant-numeric:tabular-nums}
.dot{display:inline-block;width:6px;height:6px;border-radius:50%;margin-top:6px;flex:none}
.s-critical{background:var(--bad)} .s-serious{background:var(--serious)}
.s-warning{background:var(--warn)} .s-good{background:var(--good)} .s-info{background:var(--muted)}
.more{font:inherit;font-size:13px;cursor:pointer;background:var(--card2);color:var(--ink2);
  border:1px solid var(--line);border-radius:10px;padding:7px 14px;margin-top:10px;width:100%}

/* notify cards */
.nf{display:flex;gap:11px;background:var(--card2);border-radius:15px;padding:11px 14px;margin-bottom:8px;
  border-left:4px solid var(--muted)}
.nf.win{border-left-color:var(--good)} .nf.loss{border-left-color:var(--bad)}
.nf.open{border-left-color:var(--acc2)}
.nf.critical{border-left-color:var(--bad)} .nf.serious{border-left-color:var(--serious)}
.nf.warning{border-left-color:var(--warn)} .nf.good{border-left-color:var(--good)}
.nf .ico{font-size:16px;line-height:1.5}
.nf .bd{flex:1;min-width:0}
.nf .bd b{display:block;font-size:14.5px;font-weight:600}
.nf .bd span{font-size:12px;color:var(--muted);word-break:break-word}
.nf .tt{font-size:11.5px;color:var(--muted);white-space:nowrap}

/* heartbeat pills */
.pills{display:flex;flex-direction:column;gap:8px;margin-bottom:4px}
.pill{display:flex;align-items:center;gap:9px;background:var(--card2);border-radius:14px;
  padding:11px 14px;font-size:13px;color:var(--ink2)}
.pill b{font-weight:600;color:var(--ink);font-size:14px}
.beat{width:9px;height:9px;border-radius:50%;flex:none}
.beat.alive{background:var(--good);color:rgba(18,196,106,.45);animation:pulse 1.8s ease-out infinite}
.beat.late{background:var(--warn);color:rgba(255,194,77,.45);animation:pulse 1.8s ease-out infinite}
.beat.dead{background:var(--bad)}
@keyframes pulse{0%{box-shadow:0 0 0 0 currentColor;opacity:1}70%{box-shadow:0 0 0 8px transparent;opacity:.7}100%{box-shadow:0 0 0 0 transparent;opacity:1}}

/* tab bar */
.tabbar{position:fixed;bottom:0;left:0;right:0;margin:0 auto;width:100%;max-width:440px;
  background:rgba(14,17,32,.95);border-top:1px solid var(--line);display:grid;
  grid-template-columns:repeat(4,1fr);padding:9px 0 11px;z-index:50}
.nv{background:none;border:0;cursor:pointer;color:var(--muted);display:flex;flex-direction:column;
  align-items:center;gap:3px;font:inherit;font-size:11px;padding:4px 0;position:relative}
.nv svg{width:23px;height:23px;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}
.nv.on{color:var(--ink)}
.nv .bdg{position:absolute;top:0;right:50%;margin-right:-20px;background:var(--bad);color:#fff;
  font-size:10px;font-weight:700;border-radius:99px;padding:1px 5px;min-width:15px}

/* toasts */
.toasts:empty{display:none}
.toasts{position:fixed;bottom:88px;left:0;right:0;margin:0 auto;width:100%;max-width:440px;
  z-index:60;display:flex;flex-direction:column;gap:8px;padding:0 14px}
.toast{display:flex;gap:11px;align-items:flex-start;background:var(--card2);
  border:1px solid var(--line);border-left:5px solid var(--muted);border-radius:15px;
  padding:11px 15px;box-shadow:0 12px 34px rgba(0,0,0,.6)}
.toast .ti{font-size:17.5px;animation:blink 1.6s ease-in-out infinite}
.toast b{font-size:14.5px;font-weight:600;color:var(--ink)}
.toast .ts{font-size:12px;color:var(--muted)}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.35}}
@media (prefers-reduced-motion:reduce){.toast .ti,.beat{animation:none!important}}
.tw-win{border-left-color:var(--good)}  .tw-win .ti{color:var(--good)}
.tw-loss{border-left-color:var(--bad)}  .tw-loss .ti{color:var(--bad)}
.tw-open{border-left-color:var(--acc2)} .tw-open .ti{color:var(--acc2)}
.foot{color:var(--muted);font-size:12px;margin-top:16px;line-height:1.8}
.foot b{color:var(--ink2)}
svg text{font-family:var(--ff)}
'@

function Build-Html($M) {
  $sb  = New-Object System.Text.StringBuilder   # เนื้อหา (.phone) - ส่วนที่ live.js ส่งไปอัปเดต
  $sbH = New-Object System.Text.StringBuilder   # head/css - โหลดครั้งเดียว
  function A([string]$s)  { [void]$sb.AppendLine($s) }
  function AH([string]$s) { [void]$sbH.AppendLine($s) }

  $closed = $M.Closed
  $tot = 0.0; $gross = 0.0; $lossSum = 0.0
  foreach ($c in $closed) {
    $tot += $c.Profit
    if ($c.Profit -ge 0) { $gross += $c.Profit } else { $lossSum += $c.Profit }
  }
  $wins = @($closed | Where-Object { $_.Profit -gt 0 }).Count
  $wr = 0; if ($closed.Count -gt 0) { $wr = [math]::Round(100.0*$wins/$closed.Count) }
  $stale = $false
  if ($M.LastLog) { $stale = ((Get-Date) - $M.LastLog).TotalMinutes -gt 8 }

  # ----- ข้อมูลสด จาก PosExport (แท็บ Trade) -----
  $LV = $M.Live
  $liveOk = ($LV -and $LV.Ok -and $LV.Age -le 45)
  $float = 0.0
  $posShow = @()
  if ($liveOk) {
    foreach ($q in $LV.Pos) { $float += $q.Profit + $q.Swap }
    $posShow = @($LV.Pos)
  } else {
    $posShow = @($M.Open)
  }
  $netAll = $tot + $float

  # ----- แจ้งเตือน -----
  $cut = (Get-Date).AddSeconds(-1 * $NotifySeconds)
  $alerts = New-Object System.Collections.ArrayList
  foreach ($c in @($closed | Where-Object { $_.CloseT -ge $cut })) {
    $kind = 'win'; $icon = '&#9650;'
    if ($c.Profit -lt 0) { $kind = 'loss'; $icon = '&#9660;' }
    [void]$alerts.Add([pscustomobject]@{
      T=$c.CloseT; Kind=$kind; Icon=$icon
      Head=('ปิดไม้ ' + $c.Dir.ToUpper() + '  ' + $(if ($c.Profit -ge 0) {'+'} else {''}) + (F2 $c.Profit) + ' USD')
      Sub=($c.EA + ' &middot; ' + (F2 $c.OpenP) + ' &rarr; ' + (F2 $c.CloseP) + ' &middot; ' + $c.CloseT.ToString('HH:mm:ss'))
      Id=('c' + $c.Order + '_' + $c.CloseT.ToString('HHmmss')); P=$c.Profit })
  }
  foreach ($o in @($M.Open | Where-Object { $_.T -ge $cut })) {
    [void]$alerts.Add([pscustomobject]@{
      T=$o.T; Kind='open'; Icon='&#9658;'
      Head=('เปิดไม้ ' + $o.Dir.ToUpper() + '  ' + $o.Lot.ToString('0.00',$IC) + ' lot')
      Sub=($o.EA + ' &middot; @ ' + (F2 $o.Price) + ' &middot; ' + $o.T.ToString('HH:mm:ss'))
      Id=('o' + $o.Order); P=0.0 })
  }
  $alerts = @($alerts | Sort-Object T -Descending | Select-Object -First 4)

  # ----- per EA -----
  $per = @{}
  $eaList = @('ScalperEA','GridTrader')
  foreach ($ea in $eaList) {
    $ss = @($closed | Where-Object { $_.EA -eq $ea })
    $pp = 0.0; foreach ($x in $ss) { $pp += $x.Profit }
    $ww = @($ss | Where-Object { $_.Profit -gt 0 }).Count
    $wrx = 0; if ($ss.Count -gt 0) { $wrx = [math]::Round(100.0*$ww/$ss.Count) }
    $per[$ea] = @{ n=$ss.Count; w=$ww; l=($ss.Count-$ww); p=$pp; wr=$wrx; list=$ss }
  }

  # ----- เหตุการณ์สำคัญ (ใช้ทั้งหน้า Home และ Notify) -----
  $keyEv = @($M.Events | Where-Object { $_.Sev -eq 'critical' -or $_.Sev -eq 'serious' -or $_.Sev -eq 'warning' -or $_.Sev -eq 'good' -or $_.Tag -eq 'เปิดไม้' })

  # ================= head =================
  AH '<meta charset="utf-8">'
  AH ('<noscript><meta http-equiv="refresh" content="' + $Interval + '"></noscript>')
  AH '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
  $ttl = (F2 $tot) + ' USD - EA XAUUSD'
  if ($alerts.Count -gt 0) {
    $a0 = $alerts[0]
    if ($a0.Kind -eq 'open')    { $ttl = '(*) เปิดไม้ใหม่ - ' + $ttl }
    elseif ($a0.Kind -eq 'win') { $ttl = '[+] ' + (F2 $a0.P) + ' - ' + $ttl }
    else                        { $ttl = '[-] ' + (F2 $a0.P) + ' - ' + $ttl }
  }
  AH ('<title>' + (Enc $ttl) + '</title>')
  if ($FontPick.q -ne '') {
    AH '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
    AH ('<link href="https://fonts.googleapis.com/css2?' + $FontPick.q + '&display=swap" rel="stylesheet">')
  }
  AH ('<style>:root{--ff:' + $FontStack + '}</style>')
  AH ('<style>' + $CSS + '</style>')
  A '<div class="phone">'

  # ================= top bar =================
  A '<div class="top"><div class="av">KO</div><div class="ttl" id="pgname">Home</div>'
  A '<button class="iconbtn" id="sndbtn" type="button" title="เสียงเตือน">&#128276;</button></div>'

  # =========================================================
  # SCREEN 1 : HOME
  # =========================================================
  A '<div class="screen" id="sc-home" data-name="Home">'
  A '<div class="hi">สวัสดี, Ko!</div>'
  $lastTxt = '-'; if ($M.LastLog) { $lastTxt = $M.LastLog.ToString('HH:mm:ss') }
  $staleTxt = ''; if ($stale) { $staleTxt = ' <span style="color:var(--bad);font-weight:600">(log ไม่ขยับ)</span>' }
  $accLine = ''
  if ($liveOk -and $LV.Acc) {
    $accLine = '<br><span class="livedot"></span>สด &middot; ทุน ' + (F2 $LV.Acc.Balance) + ' &middot; equity ' + (F2 $LV.Acc.Equity) +
               ' &middot; อัปเดต ' + $LV.Age + ' วิที่แล้ว'
  } elseif ($LV -and $LV.Ok) {
    $accLine = '<br><span class="livewarn">ข้อมูลสดหยุดอัปเดต ' + $LV.Age + ' วินาที &mdash; PosExport อาจถูกถอดออกจากกราฟ</span>'
  } else {
    $accLine = '<br><span class="livewarn">ยังไม่มีข้อมูลสด &mdash; ต้องลาก PosExport ใส่กราฟก่อน (ดูหน้า ระบบ)</span>'
  }
  $accNo = $Account
  if ([string]::IsNullOrWhiteSpace($accNo) -and $liveOk -and $LV.Acc -and $LV.Acc.Login) { $accNo = [string]$LV.Acc.Login }
  $accTxt = ''; if (-not [string]::IsNullOrWhiteSpace($accNo)) { $accTxt = ' &middot; บัญชี ' + (Enc $accNo) }
  A ('<div class="hisub">XAUUSD' + $accTxt + '<br>วันเทรด ' + $M.DayStart.ToString('dd/MM HH:mm') +
     ' &rarr; ' + $M.Now.ToString('HH:mm:ss') + ' &middot; log ล่าสุด ' + $lastTxt + $staleTxt + $accLine + '</div>')

  # ---- (1) กำไร/ขาดทุน ----
  A '<h3 class="st">กำไร / ขาดทุน ที่ปิดแล้ววันนี้</h3>'
  $tcls = 'pos'; if ($tot -lt 0) { $tcls = 'neg' }
  A '<div class="heroRow">'
  A ('<div class="big ' + $tcls + '"><span class="cur">$</span>' + (F2 $tot) + '</div>')
  A ('<div class="deltaBox"><div class="d1 ' + $tcls + '">' + $closed.Count + ' ไม้ &middot; ชนะ ' + $wr + '%</div><div class="d2"></div></div>')
  A '</div>'
  A '<div class="io">'
  A ('<div class="iobox"><div class="kk">กำไรรวม</div><div class="vv pos">+' + (F2 $gross) + ' <span style="font-size:11px;color:var(--muted)">USD</span></div></div>')
  A ('<div class="iobox"><div class="kk">ขาดทุนรวม</div><div class="vv neg">' + (F2 $lossSum) + ' <span style="font-size:11px;color:var(--muted)">USD</span></div></div>')
  A '</div>'
  if ($liveOk) {
    $fcls = 'pos'; $fsg = '+'
    if ($float -lt 0) { $fcls = 'neg'; $fsg = '' }
    $ncls = 'pos'; $nsg = '+'
    if ($netAll -lt 0) { $ncls = 'neg'; $nsg = '' }
    A '<div class="io">'
    A ('<div class="iobox"><div class="kk"><span class="livedot"></span>กำไรลอย (ยังไม่ปิด)</div><div class="vv ' + $fcls + '">' + $fsg + (F2 $float) + ' <span style="font-size:11px;color:var(--muted)">USD</span></div></div>')
    A ('<div class="iobox"><div class="kk">รวมสุทธิวันนี้</div><div class="vv ' + $ncls + '">' + $nsg + (F2 $netAll) + ' <span style="font-size:11px;color:var(--muted)">USD</span></div></div>')
    A '</div>'
  }

  # ---- (2) ไม้ที่ถืออยู่ + TP/SL (การ์ดเล็ก, กำไรสด) ----
  $hdSuffix = ''
  if ($liveOk) { $hdSuffix = ' &middot; <span class="livedot"></span>สด' }
  A ('<h3 class="st">ไม้ที่ถืออยู่ &middot; ' + $posShow.Count + ' ไม้' + $hdSuffix + '</h3>')
  if ($posShow.Count -eq 0) {
    A '<div class="c empty">ไม่มีไม้ค้าง</div>'
  } else {
    A '<div class="oplist">'
    foreach ($q in $posShow) {
      $gg = ''; $eac = 'ea ea-s'; $shortEA = 'Scalper'
      if ($q.EA -eq 'GridTrader') { $gg = ' g'; $eac = 'ea ea-g'; $shortEA = 'Grid' }
      elseif ($q.EA -ne 'ScalperEA') { $gg = ' m'; $eac = 'ea'; $shortEA = 'มือ' }

      if ($liveOk) {
        $entry = $q.Open; $curP = $q.Cur; $sl = $q.SL; $tp = $q.TP
        $pnl = $q.Profit + $q.Swap; $lot = $q.Lot; $tk = $q.Ticket
        $isBuy = ($q.Dir -eq 'BUY'); $dirTxt = $q.Dir
      } else {
        $entry = $q.Price; $curP = 0.0; $sl = $q.SL; $tp = $q.TP
        $pnl = $null; $lot = $q.Lot; $tk = $q.Order
        $isBuy = ($q.Dir -eq 'buy'); $dirTxt = $q.Dir.ToUpper()
      }
      $tk4 = [string]$tk; if ($tk4.Length -gt 4) { $tk4 = $tk4.Substring($tk4.Length-4) }
      $slTxt = '-'; if ($sl -gt 0) { $slTxt = (F2 $sl) }
      $tpTxt = '-'; if ($tp -gt 0) { $tpTxt = (F2 $tp) }

      # แถบ SL -> TP + ขีดบอกราคาปัจจุบัน
      $wSL = 50.0; $mkHtml = ''
      if ($sl -gt 0 -and $tp -gt 0) {
        $lo = $sl; $hi = $tp
        if (-not $isBuy) { $lo = $tp; $hi = $sl }
        $rng = $hi - $lo
        if ($rng -gt 0) {
          $ePct = 100.0*($entry-$lo)/$rng
          if ($isBuy) { $wSL = $ePct } else { $wSL = 100.0 - $ePct }
          if ($liveOk -and $curP -gt 0) {
            $cPct = 100.0*($curP-$lo)/$rng
            if (-not $isBuy) { $cPct = 100.0 - $cPct }
            if ($cPct -lt 0) { $cPct = 0 }
            if ($cPct -gt 100) { $cPct = 100 }
            $mkHtml = '<span class="opmk" style="left:' + [math]::Round($cPct,1) + '%"></span>'
          }
        }
      }
      if ($wSL -lt 0) { $wSL = 0 }
      if ($wSL -gt 100) { $wSL = 100 }
      $wTP = 100.0 - $wSL
      $noST = ($sl -le 0 -and $tp -le 0)

      A ('<div class="op' + $gg + '" title="ticket ' + $tk + '">')
      $pnlHtml = '<span class="opp k" style="font-size:12px">&mdash;</span>'
      if ($null -ne $pnl) {
        $pc = 'pos'; $ps2 = '+'
        if ($pnl -lt 0) { $pc = 'neg'; $ps2 = '' }
        $pnlHtml = '<span class="opp ' + $pc + '">' + $ps2 + (F2 $pnl) + '</span>'
      }
      A ('<div class="oph"><span class="' + $eac + '">' + $dirTxt + '</span><span class="k">' + $shortEA + '</span>' + $pnlHtml + '</div>')
      if ($liveOk -and $curP -gt 0) {
        A ('<div class="oprow">' + $lot.ToString('0.00',$IC) + ' &middot; <b>' + (F2 $entry) + '</b> &rarr; <b>' + (F2 $curP) + '</b></div>')
      } else {
        A ('<div class="oprow">' + $lot.ToString('0.00',$IC) + ' &middot; เข้า <b>' + (F2 $entry) + '</b></div>')
      }
      if ($noST) {
        A '<div class="opbar"><i style="background:var(--card3);width:100%"></i></div>'
        A ('<div class="opft"><span class="k">ไม่ได้ตั้ง SL / TP</span><span class="k">#' + $tk4 + '</span></div>')
      } else {
        A ('<div class="opbar"><i style="background:var(--bad);width:' + [math]::Round($wSL,1) + '%"></i>' +
           '<i style="background:var(--good);width:' + [math]::Round($wTP,1) + '%"></i>' + $mkHtml + '</div>')
        A ('<div class="opft"><span class="neg">SL ' + $slTxt + '</span><span class="pos">TP ' + $tpTxt + '</span></div>')
      }
      A '</div>'
    }
    A '</div>'
  }

  # ---- (3) กราฟ ----
  A '<h3 class="st">กำไรสะสมของวัน</h3>'
  A '<div class="panel">'
  A '<div class="tabs"><button class="tab ctab" data-c="BOTH" type="button">ทั้งคู่</button>'
  A '<button class="tab ctab" data-c="ScalperEA" type="button">Scalper</button>'
  A '<button class="tab ctab" data-c="GridTrader" type="button">Grid</button></div>'
  if ($closed.Count -eq 0) {
    A '<div class="empty" style="padding:36px 0">ยังไม่มีไม้ปิดในวันเทรดนี้</div>'
  } else {
    $W=400; $H=210; $L=34; $R=66; $Tp=14; $B=24
    $pw=$W-$L-$R; $ph=$H-$Tp-$B
    $x0=$M.DayStart; $x1=$M.Now
    $lastClose=($closed | Select-Object -Last 1).CloseT
    if ($lastClose -gt $x1) { $x1=$lastClose }
    if ($x1 -le $x0) { $x1=$x0.AddHours(1) }
    $span=($x1-$x0).TotalSeconds
    $series = @{}
    foreach ($ea in $eaList) {
      $lst = New-Object System.Collections.ArrayList
      [void]$lst.Add([pscustomobject]@{T=$x0;V=0.0;P=0.0;F=1})
      $cc = 0.0
      foreach ($c in $closed) { if ($c.EA -eq $ea) { $cc += $c.Profit; [void]$lst.Add([pscustomobject]@{T=$c.CloseT;V=$cc;P=$c.Profit;F=0}) } }
      $series[$ea] = @($lst)
    }
    $allV = @()
    foreach ($ea in $eaList) { foreach ($p in $series[$ea]) { $allV += $p.V } }
    $vmax=($allV | Measure-Object -Maximum).Maximum
    $vmin=($allV | Measure-Object -Minimum).Minimum
    if ($vmax -lt 0) { $vmax = 0 }
    if ($vmin -gt 0) { $vmin = 0 }
    $pad=[math]::Max(([math]::Abs($vmax-$vmin))*0.18, 5)
    $ymax=$vmax+$pad; $ymin=$vmin-$pad
    $sx={ param($t) $L + $pw * ([math]::Min([math]::Max((($t-$x0).TotalSeconds/$span),0),1)) }
    $sy={ param($v) $Tp + $ph * (($ymax-$v)/($ymax-$ymin)) }
    $svg = New-Object System.Text.StringBuilder
    [void]$svg.Append("<svg viewBox=""0 0 $W $H"" width=""100%"" role=""img"" aria-label=""กำไรสะสมของวัน แยกตามระบบ"">")
    for ($i=0;$i -le 3;$i++) {
      $v=$ymin+($ymax-$ymin)*$i/3.0; $y=[math]::Round((& $sy $v),1)
      [void]$svg.Append("<line x1=""$L"" x2=""$($L+$pw)"" y1=""$y"" y2=""$y"" stroke=""#242B44"" stroke-width=""1""/>")
      [void]$svg.Append("<text x=""$($L-6)"" y=""$($y+3.5)"" text-anchor=""end"" fill=""#737CA2"" font-size=""10.5"">$([math]::Round($v,0))</text>")
    }
    $yz=[math]::Round((& $sy 0.0),1)
    [void]$svg.Append("<line x1=""$L"" x2=""$($L+$pw)"" y1=""$yz"" y2=""$yz"" stroke=""#39415F"" stroke-width=""1.2"" stroke-dasharray=""3 3""/>")
    $tk=$x0
    while ($tk -le $x1) {
      $x=[math]::Round((& $sx $tk),1)
      [void]$svg.Append("<text x=""$x"" y=""$($H-7)"" text-anchor=""middle"" fill=""#737CA2"" font-size=""10.5"">$($tk.ToString('HH:mm'))</text>")
      $tk=$tk.AddHours(3)
    }
    $cols = @{ 'ScalperEA'='#4A8CFF'; 'GridTrader'='#D95926' }
    foreach ($ea in $eaList) {
      $ps = $series[$ea]
      if ($ps.Count -lt 2) { continue }
      [void]$svg.Append("<g class=""ser"" data-s=""$ea"">")
      $dp=@(); foreach ($p in $ps) { $dp += ("$([math]::Round((& $sx $p.T),1)),$([math]::Round((& $sy $p.V),1))") }
      [void]$svg.Append("<polyline fill=""none"" stroke=""$($cols[$ea])"" stroke-width=""2.4"" stroke-linejoin=""round"" stroke-linecap=""round"" points=""$($dp -join ' ')""/>")
      foreach ($p in $ps) {
        if ($p.F -eq 1) { continue }
        $cx=[math]::Round((& $sx $p.T),1); $cy=[math]::Round((& $sy $p.V),1)
        $sg=''; if ($p.P -ge 0) { $sg='+' }
        $ttip = "$($p.T.ToString('HH:mm')) $ea $sg$(F2 $p.P) USD | สะสม $(F2 $p.V)"
        [void]$svg.Append("<circle cx=""$cx"" cy=""$cy"" r=""3"" fill=""#1E2438"" stroke=""$($cols[$ea])"" stroke-width=""1.8""><title>$(Enc $ttip)</title></circle>")
      }
      $lp=$ps[$ps.Count-1]
      $lx=[math]::Round((& $sx $lp.T),1); $ly=[math]::Round((& $sy $lp.V),1)
      [void]$svg.Append("<circle cx=""$lx"" cy=""$ly"" r=""10"" fill=""$($cols[$ea])"" opacity="".22""/>")
      [void]$svg.Append("<circle cx=""$lx"" cy=""$ly"" r=""5"" fill=""#FFFFFF""/>")
      $nm2 = 'S'; if ($ea -eq 'GridTrader') { $nm2 = 'G' }
      [void]$svg.Append("<text x=""$($lx+9)"" y=""$($ly+3.5)"" fill=""$($cols[$ea])"" font-size=""11.5"" font-weight=""600"">$nm2 $(F2 $lp.V)</text>")
      [void]$svg.Append("</g>")
    }
    [void]$svg.Append("</svg>")
    A $svg.ToString()
  }
  A '</div>'

  # ---- (4) Log Expert สด เฉพาะที่สำคัญ ----
  A '<h3 class="st">Log Expert สด &middot; เฉพาะที่สำคัญ</h3>'
  A '<div class="c"><ul class="lg" id="homelog">'
  $keyShow = @($keyEv | Select-Object -Last 30)
  if ($keyShow.Count -eq 0) { A '<li><span class="muted">ยังไม่มีเหตุการณ์สำคัญ</span></li>' }
  for ($i=$keyShow.Count-1; $i -ge 0; $i--) {
    $tl = $keyShow[$i]
    $eac6 = 'ea'; if ($tl.EA -eq 'ScalperEA') { $eac6='ea ea-s' } elseif ($tl.EA -eq 'GridTrader') { $eac6='ea ea-g' }
    $hid = ''; if (($keyShow.Count-1-$i) -ge 6) { $hid = ' style="display:none" data-extra="1"' }
    A ('<li' + $hid + '><span class="dot s-' + $tl.Sev + '"></span><span class="tm">' + $tl.T.ToString('HH:mm:ss') + '</span>' +
       '<span><span class="' + $eac6 + '">' + (Enc $tl.EA) + '</span> ' + (Enc $tl.Msg) + '</span></li>')
  }
  A '</ul>'
  if ($keyShow.Count -gt 6) { A '<button class="more" type="button" data-more="homelog">ดูเพิ่ม</button>' }
  A '</div>'
  A '</div>'

  # =========================================================
  # SCREEN 2 : SUMMARIES
  # =========================================================
  A '<div class="screen" id="sc-sum" data-name="Summaries">'
  A '<div class="pgttl">SUMMARIES</div>'
  A '<div class="tabs" style="justify-content:center;margin-bottom:12px">'
  A '<button class="tab stab" data-s="ALL" type="button">ทั้งหมด</button>'
  A '<button class="tab stab" data-s="ScalperEA" type="button">Scalper</button>'
  A '<button class="tab stab" data-s="GridTrader" type="button">Grid</button></div>'

  # ---- (1) อัตราชนะ : วงแหวน 3 แบบ ----
  $gsets = @(
    @{ id='ALL';        n=$closed.Count;         w=$wins;             wr=$wr;                 lbl='ทั้งสองระบบ' },
    @{ id='ScalperEA';  n=$per['ScalperEA'].n;   w=$per['ScalperEA'].w; wr=$per['ScalperEA'].wr; lbl='ScalperEA' },
    @{ id='GridTrader'; n=$per['GridTrader'].n;  w=$per['GridTrader'].w; wr=$per['GridTrader'].wr; lbl='GridTrader' }
  )
  foreach ($gs in $gsets) {
    A ('<div class="gwrap gset" data-g="' + $gs.id + '" style="display:none">')
    $rr=86.0; $circ=2*[math]::PI*$rr
    $frac=[math]::Min([math]::Max($gs.wr/100.0,0),1)
    $dash=[math]::Round($circ*$frac,1); $rest=[math]::Round($circ-$dash,1)
    $angg=(-90.0+360.0*$frac)*[math]::PI/180.0
    $exx=[math]::Round(110+$rr*[math]::Cos($angg),1); $eyy=[math]::Round(110+$rr*[math]::Sin($angg),1)
    $gid = 'rg' + $gs.id
    $g = New-Object System.Text.StringBuilder
    [void]$g.Append("<svg class=""ring"" viewBox=""0 0 220 220"" role=""img"" aria-label=""อัตราชนะ $($gs.lbl)"">")
    [void]$g.Append("<defs><linearGradient id=""$gid"" x1=""0"" y1=""1"" x2=""1"" y2=""0""><stop offset=""0"" stop-color=""#9CE4FC""/><stop offset=""1"" stop-color=""#2E6CFC""/></linearGradient></defs>")
    [void]$g.Append('<circle cx="110" cy="110" r="86" fill="none" stroke="#232B44" stroke-width="14"/>')
    [void]$g.Append("<circle cx=""110"" cy=""110"" r=""86"" fill=""none"" stroke=""url(#$gid)"" stroke-width=""14"" stroke-linecap=""round"" stroke-dasharray=""$dash $rest"" transform=""rotate(-90 110 110)""/>")
    [void]$g.Append('<circle cx="110" cy="24" r="6" fill="#FFFFFF"/>')
    [void]$g.Append("<circle cx=""$exx"" cy=""$eyy"" r=""6"" fill=""#FFFFFF""/>")
    [void]$g.Append("<text class=""ringc"" x=""110"" y=""114"" text-anchor=""middle"">$($gs.wr)<tspan font-size=""22"">%</tspan></text>")
    [void]$g.Append("<text class=""rings"" x=""110"" y=""136"" text-anchor=""middle"">ชนะ $($gs.w) จาก $($gs.n) ไม้</text>")
    [void]$g.Append('</svg>')
    A $g.ToString()
    A '</div>'
  }

  # ---- (2) ผลการเทรดของ EA ----
  A '<h3 class="st">ผลการเทรดของ EA</h3>'
  foreach ($ea in $eaList) {
    $pv = $per[$ea]
    $cls2 = 'pos'; $chp = 'chip up'; $arrow = '&#9650;'
    if ($pv.p -lt 0) { $cls2 = 'neg'; $chp = 'chip dn'; $arrow = '&#9660;' }
    $eac7 = 'ea ea-s'; $col = '#4A8CFF'
    if ($ea -eq 'GridTrader') { $eac7 = 'ea ea-g'; $col = '#D95926' }
    # sparkline
    $spk = ''
    $sl2 = $pv.list
    if ($sl2.Count -gt 0) {
      $cc2 = 0.0; $vs = @(0.0)
      foreach ($x in $sl2) { $cc2 += $x.Profit; $vs += $cc2 }
      $mx = ($vs | Measure-Object -Maximum).Maximum; $mn = ($vs | Measure-Object -Minimum).Minimum
      if ($mx -eq $mn) { $mx = $mn + 1 }
      $pt = @()
      for ($i=0; $i -lt $vs.Count; $i++) {
        $xx = [math]::Round(74.0*$i/[math]::Max(1,($vs.Count-1)),1)
        $yy = [math]::Round(26.0 - 22.0*(($vs[$i]-$mn)/($mx-$mn)) - 2,1)
        $pt += "$xx,$yy"
      }
      $spk = "<svg class=""spk"" width=""76"" height=""30"" viewBox=""0 0 76 30""><polyline fill=""none"" stroke=""$col"" stroke-width=""1.8"" stroke-linejoin=""round"" stroke-linecap=""round"" points=""$($pt -join ' ')""/><circle cx=""$([math]::Round(74.0,1))"" cy=""$([math]::Round(26.0 - 22.0*(($vs[$vs.Count-1]-$mn)/($mx-$mn)) - 2,1))"" r=""2.6"" fill=""$col""/></svg>"
    }
    A ('<div class="lrow"><span class="' + $eac7 + '">' + $ea.Substring(0,1) + '</span>' +
       '<div class="nm"><b>' + (Enc $ea) + '</b><span>' + $pv.n + ' ไม้ &middot; ชนะ ' + $pv.w + ' &middot; แพ้ ' + $pv.l + ' (' + $pv.wr + '%)</span></div>' +
       $spk +
       '<span class="amt ' + $cls2 + '">' + (F2 $pv.p) + '</span></div>')
  }
  $lockCls = 'chip up'; if ($M.Lock -eq 'LOCK') { $lockCls = 'chip dn' }
  A ('<div class="lrow"><span class="ea">i</span><div class="nm"><b>สถานะระบบ</b><span>ถืออยู่ ' + $M.Open.Count +
     ' ไม้ &middot; กำไรรวม +' + (F2 $gross) + ' / ขาดทุน ' + (F2 $lossSum) + '</span></div>' +
     '<span class="' + $lockCls + '">' + $M.Lock + '</span></div>')

  # ---- (3) ประวัติไม้ที่ปิดแล้ว ----
  A ('<h3 class="st">ประวัติไม้ที่ปิดแล้ว &middot; <span id="histn">' + $closed.Count + '</span> ไม้</h3>')
  if ($closed.Count -eq 0) {
    A '<div class="c empty">ยังไม่มีไม้ปิด</div>'
  } else {
    $cumEA = @{ 'ScalperEA'=0.0; 'GridTrader'=0.0 }
    $cumAll = 0.0
    $rowsH = New-Object System.Collections.ArrayList
    foreach ($c in $closed) {
      $cumAll += $c.Profit
      if ($cumEA.ContainsKey($c.EA)) { $cumEA[$c.EA] = $cumEA[$c.EA] + $c.Profit }
      $rs = switch -Regex ($c.Reason) {
        'stop loss'   { if ($c.Profit -ge 0) { 'SL ที่เลื่อนแล้ว' } else { 'ชน SL' }; break }
        'take profit' { 'ชน TP'; break }
        'close by'    { 'หักกลบไม้'; break }
        default       { 'ปิดด้วยคำสั่ง' }
      }
      $hold = '-'; if ($c.OpenT) { $hold = [string][int](($c.CloseT-$c.OpenT).TotalMinutes) + ' นาที' }
      $cl = 'pos'; $sg2 = '+'
      if ($c.Profit -lt 0) { $cl = 'neg'; $sg2 = '' }
      $frc = ''
      if ($c.CloseT -ge $cut) { $frc = ' fr'; if ($c.Profit -lt 0) { $frc = ' fl' } }
      $eac8 = 'ea ea-s'; if ($c.EA -eq 'GridTrader') { $eac8 = 'ea ea-g' }
      $rid = 'h' + $c.Order + '_' + $c.CloseT.ToString('HHmmss')
      $opT = '-'; if ($c.OpenT) { $opT = $c.OpenT.ToString('HH:mm:ss') }
      $det = '<div class="det" data-det="' + $rid + '"><div class="dg">' +
        '<div><span>เปิด</span> ' + $opT + ' @ ' + (F2 $c.OpenP) + '</div>' +
        '<div><span>ปิด</span> ' + $c.CloseT.ToString('HH:mm:ss') + ' @ ' + (F2 $c.CloseP) + '</div>' +
        '<div><span>ล็อต</span> ' + $c.Lot.ToString('0.00',$IC) + '</div>' +
        '<div><span>ถือ</span> ' + $hold + '</div>' +
        '<div><span>ระยะราคา</span> ' + (F2 ([math]::Abs($c.CloseP-$c.OpenP))) + '</div>' +
        '<div><span>ticket</span> ' + $c.Order + '</div>' +
        '<div><span>สะสมของ EA</span> <b class="' + $(if ($cumEA[$c.EA] -ge 0) {'pos'} else {'neg'}) + '">' + (F2 $cumEA[$c.EA]) + '</b></div>' +
        '<div><span>สะสมรวม</span> <b class="' + $(if ($cumAll -ge 0) {'pos'} else {'neg'}) + '">' + (F2 $cumAll) + '</b></div>' +
        '</div>'
      if ($c.Note -ne '')  { $det += '<span class="raw">ตอนเข้า: ' + (Enc $c.Note) + '</span>' }
      if ($c.CNote -ne '') { $det += '<span class="raw">ตอนปิด: ' + (Enc $c.CNote) + '</span>' }
      $det += '</div>'
      $nbd = ''
      if ($c.CloseT -ge $cut) { $nbd = ' <span class="nb nb-w">ใหม่</span>'; if ($c.Profit -lt 0) { $nbd = ' <span class="nb nb-l">ใหม่</span>' } }
      [void]$rowsH.Add('<div class="tr hrow' + $frc + '" data-row="' + $rid + '" data-ea="' + (Enc $c.EA) + '">' +
        '<div class="trh"><span class="' + $eac8 + '">' + $c.Dir.ToUpper() + '</span>' +
        '<div><div class="t1">' + (F2 $c.OpenP) + ' &rarr; ' + (F2 $c.CloseP) + $nbd + '</div>' +
        '<div class="t2">' + $c.CloseT.ToString('HH:mm:ss') + ' &middot; ' + $rs + '</div></div>' +
        '<span class="sp"></span><span class="am ' + $cl + '">' + $sg2 + (F2 $c.Profit) + '</span></div>' + $det + '</div>')
    }
    for ($i=$rowsH.Count-1; $i -ge 0; $i--) { A $rowsH[$i] }
  }
  A '</div>'

  # =========================================================
  # SCREEN 3 : NOTIFY
  # =========================================================
  A '<div class="screen" id="sc-not" data-name="Notify">'
  A '<div class="pgttl">NOTIFY</div>'

  # ---- (1) History การเทรด ----
  A '<h3 class="st">History การเทรด</h3>'
  $hist = New-Object System.Collections.ArrayList
  foreach ($c in $closed) {
    $kd = 'win'; $ico = '&#9650;'; $sg3 = '+'
    if ($c.Profit -lt 0) { $kd = 'loss'; $ico = '&#9660;'; $sg3 = '' }
    [void]$hist.Add([pscustomobject]@{ T=$c.CloseT; K=$kd; I=$ico
      H=('ปิดไม้ ' + $c.Dir.ToUpper() + ' ' + $sg3 + (F2 $c.Profit) + ' USD')
      S=($c.EA + ' &middot; ' + (F2 $c.OpenP) + ' &rarr; ' + (F2 $c.CloseP)) })
  }
  foreach ($o in $M.Open) {
    [void]$hist.Add([pscustomobject]@{ T=$o.T; K='open'; I='&#9658;'
      H=('เปิดไม้ ' + $o.Dir.ToUpper() + ' ' + $o.Lot.ToString('0.00',$IC) + ' lot')
      S=($o.EA + ' &middot; @ ' + (F2 $o.Price) + ' &middot; SL ' + $(if ($o.SL -gt 0) { (F2 $o.SL) } else { '-' }) + ' / TP ' + $(if ($o.TP -gt 0) { (F2 $o.TP) } else { '-' })) })
  }
  $hist = @($hist | Sort-Object T -Descending)
  if ($hist.Count -eq 0) {
    A '<div class="c empty">ยังไม่มีรายการเทรดวันนี้</div>'
  } else {
    foreach ($x in $hist) {
      A ('<div class="nf ' + $x.K + '"><span class="ico">' + $x.I + '</span><div class="bd"><b>' + $x.H + '</b><span>' + $x.S + '</span></div>' +
         '<span class="tt">' + $x.T.ToString('HH:mm:ss') + '</span></div>')
    }
  }

  # ---- (2) Expert เฉพาะที่สำคัญ ----
  A '<h3 class="st">Expert เฉพาะเหตุการณ์สำคัญ</h3>'
  $critN = @($keyEv | Where-Object { $_.Sev -eq 'critical' }).Count
  A ('<div class="k" style="margin-bottom:9px">' + $keyEv.Count + ' เหตุการณ์ &middot; ร้ายแรง ' + $critN + ' &middot; กรองเฉพาะ เปิด-ปิดไม้ / หยุดเทรด / ห้ามเทรด / เพดานขาดทุน-กำไร</div>')
  if ($keyEv.Count -eq 0) {
    A '<div class="c empty">ยังไม่มีเหตุการณ์สำคัญ</div>'
  } else {
    $kshow = @($keyEv | Select-Object -Last 60)
    for ($i=$kshow.Count-1; $i -ge 0; $i--) {
      $e3 = $kshow[$i]
      $eac9 = 'ea'; if ($e3.EA -eq 'ScalperEA') { $eac9='ea ea-s' } elseif ($e3.EA -eq 'GridTrader') { $eac9='ea ea-g' }
      A ('<div class="nf ' + $e3.Sev + '"><span class="ico"><span class="dot s-' + $e3.Sev + '" style="margin-top:5px"></span></span>' +
         '<div class="bd"><b>' + (Enc $e3.Tag) + ' <span class="' + $eac9 + '">' + (Enc $e3.EA) + '</span></b>' +
         '<span>' + (Enc $e3.Msg) + '</span></div><span class="tt">' + $e3.T.ToString('HH:mm:ss') + '</span></div>')
    }
  }
  A '</div>'

  # =========================================================
  # SCREEN 4 : SYSTEM / FULL LOG
  # =========================================================
  A '<div class="screen" id="sc-sys" data-name="ระบบ">'
  A '<div class="pgttl">SYSTEM</div>'
  A '<h3 class="st">ข้อมูลสดจากแท็บ Trade</h3>'
  if ($liveOk -and $LV.Acc) {
    $ac = $LV.Acc
    A ('<div class="pill"><span class="beat alive"></span><b>PosExport ทำงานอยู่</b><span class="muted">อัปเดต ' + $LV.Age + ' วินาทีที่แล้ว &middot; ' + $LV.Pos.Count + ' ไม้</span></div>')
    A '<div class="io" style="margin-top:9px">'
    A ('<div class="iobox"><div class="kk">Balance</div><div class="vv">' + (F2 $ac.Balance) + '</div></div>')
    A ('<div class="iobox"><div class="kk">Equity</div><div class="vv">' + (F2 $ac.Equity) + '</div></div>')
    A '</div><div class="io">'
    A ('<div class="iobox"><div class="kk">Margin ที่ใช้</div><div class="vv">' + (F2 $ac.Margin) + '</div></div>')
    A ('<div class="iobox"><div class="kk">Margin Level</div><div class="vv">' + (F2 $ac.Level) + '%</div></div>')
    A '</div>'
    A ('<div class="k" style="margin-top:8px">เวลาเซิร์ฟเวอร์ ' + (Enc $ac.SrvTime) + ' &middot; บัญชี ' + (Enc $ac.Login) + ' ' + (Enc $ac.Cur) + '</div>')
  } else {
    A '<div class="c"><div style="font-size:13px;line-height:1.9">'
    A '<b class="livewarn">ยังไม่ได้เปิดข้อมูลสด</b><br>'
    A 'วิธีเปิด (ทำครั้งเดียว ไม่ต้องปิด MT5 ไม่ต้องแตะ EA):<br>'
    A '1. คัดลอก <b>PosExport.mq5</b> ไปที่ MQL5\Indicators\<br>'
    A '2. เปิด MetaEditor กด F7 คอมไพล์<br>'
    A '3. ใน MT5 ที่ Navigator &rarr; Indicators ลาก <b>PosExport</b> ใส่กราฟไหนก็ได้ (ใส่ทับกราฟที่มี EA รันอยู่ได้ ไม่ชนกัน)<br>'
    A '<span class="k">อินดิเคเตอร์ตัวนี้อ่านอย่างเดียว ไม่ส่งคำสั่งเทรด ไม่ยุ่งกับ EA และไม่เกี่ยวกับปุ่ม Algo Trading</span>'
    A '</div></div>'
  }
  A '<h3 class="st">ชีพจร EA</h3>'
  $expSec = @{ 'ScalperEA'=300; 'GridTrader'=900 }
  $order = @('ScalperEA','GridTrader')
  foreach ($k in ($M.Heartbeat.Keys | Sort-Object)) { if ($order -notcontains $k) { $order += $k } }
  A '<div class="pills">'
  foreach ($nm in $order) {
    if (-not $M.Heartbeat.ContainsKey($nm)) {
      A ('<div class="pill"><span class="beat dead"></span><b>' + (Enc $nm) + '</b> <span class="muted">ไม่มี log ในวันเทรดนี้</span></div>')
      continue
    }
    $h = $M.Heartbeat[$nm]
    $sec = [int](((Get-Date) - $h.T).TotalSeconds); if ($sec -lt 0) { $sec = 0 }
    $ex = 600; if ($expSec.ContainsKey($nm)) { $ex = $expSec[$nm] }
    $st = 'alive'; $lbl = 'หายใจอยู่'
    if ($sec -gt $ex*3) { $st='dead'; $lbl='เงียบผิดปกติ' }
    elseif ($sec -gt $ex*1.5) { $st='late'; $lbl='ช้ากว่าปกติ' }
    $ago = ''
    if ($sec -lt 60) { $ago = "$sec วินาที" }
    elseif ($sec -lt 3600) { $ago = "$([int]($sec/60)) นาที" }
    else { $ago = "$([int]($sec/3600)) ชม. $([int](($sec%3600)/60)) นาที" }
    A ('<div class="pill"><span class="beat ' + $st + '"></span><b>' + (Enc $nm) + '</b>' +
       '<span class="muted">' + $lbl + ' &middot; ' + $h.T.ToString('HH:mm:ss') + ' (' + $ago + 'ที่แล้ว) &middot; ' + $h.N + ' บรรทัด</span></div>')
  }
  A '</div>'

  A ('<h3 class="st">Log แท็บ Experts ทั้งหมด &middot; ' + $M.TailCount + ' บรรทัดวันนี้</h3>')
  A '<div class="c"><ul class="lg" id="fulllog">'
  if ($M.Tail.Count -eq 0) { A '<li><span class="muted">ยังไม่มี log</span></li>' }
  for ($i=$M.Tail.Count-1; $i -ge 0; $i--) {
    $tl = $M.Tail[$i]
    $sv = $tl.Sev; if ($sv -eq 'none' -or $sv -eq 'beat') { $sv = 'info' }
    $eacA = 'ea'; if ($tl.EA -eq 'ScalperEA') { $eacA='ea ea-s' } elseif ($tl.EA -eq 'GridTrader') { $eacA='ea ea-g' }
    $hid2 = ''; if (($M.Tail.Count-1-$i) -ge 25) { $hid2 = ' style="display:none" data-extra="1"' }
    A ('<li' + $hid2 + '><span class="dot s-' + $sv + '"></span><span class="tm">' + $tl.T.ToString('HH:mm:ss') + '</span>' +
       '<span><span class="' + $eacA + '">' + (Enc $tl.EA) + '</span> ' + (Enc $tl.Msg) + '</span></li>')
  }
  A '</ul>'
  if ($M.Tail.Count -gt 25) { A '<button class="more" type="button" data-more="fulllog">ดูเพิ่ม</button>' }
  A '</div>'
  A ('<div class="foot">อ่านจาก log ของ MT5 อย่างเดียว ไม่มีการส่งคำสั่งเทรดหรือแก้ค่าใดๆ<br>' +
     'v6.0 หน้าจออัปเดตทุก ' + $Interval + ' วินาทีผ่าน live.js โดยไม่โหลดหน้าใหม่ (ไม่กระพริบ ตำแหน่งเลื่อนคงเดิม)<br>' +
     '<b>ไม่มีกำไรลอยแบบเรียลไทม์</b> ไม่มี equity/balance ปัจจุบัน และไม่มี ATR/ADX สด &mdash; ตัวเลขขยับเมื่อ EA เขียน log (ทุกแท่ง M5/M15) หรือมีไม้ปิด<br>' +
     'ไม้ที่ปิดเองด้วยมือ/มือถือ ถูกนับในหน้านี้ (ต่างจากป้ายบนกราฟของ EA ที่กรองด้วย magic number)<br>' +
     'เวลาไทย &middot; เซิร์ฟเวอร์ = ไทย &minus; 6 &middot; วันเทรดเริ่ม 06:00<br>' +
     'เป็นข้อมูลเชิงกลไกและเลขคณิต ไม่ใช่คำแนะนำการลงทุน การตัดสินใจเป็นของคุณ</div>')
  A '</div>'

  # ================= toasts =================
  A '<div class="toasts">'
  foreach ($a in $alerts) {
    A ('<div class="toast tw-' + $a.Kind + '"><span class="ti">' + $a.Icon + '</span>' +
       '<span><b>' + $a.Head + '</b><br><span class="ts">' + $a.Sub + '</span></span></div>')
  }
  A '</div>'

  # ================= tab bar =================
  $nCrit = @($M.Events | Where-Object { $_.Sev -eq 'critical' }).Count
  $bdg = ''
  if ($nCrit -gt 0) { $bdg = '<span class="bdg">' + $nCrit + '</span>' }
  A '<nav class="tabbar">'
  A '<button class="nv" data-go="sc-home" type="button"><svg viewBox="0 0 24 24"><path d="M3 10.2 12 3l9 7.2V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>Home</button>'
  A '<button class="nv" data-go="sc-sum" type="button"><svg viewBox="0 0 24 24"><rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/></svg>Summary</button>'
  A ('<button class="nv" data-go="sc-not" type="button"><svg viewBox="0 0 24 24"><path d="M18 15v-4a6 6 0 1 0-12 0v4l-2 3h16z"/><path d="M10 21h4"/></svg>Notify' + $bdg + '</button>')
  A '<button class="nv" data-go="sc-sys" type="button"><svg viewBox="0 0 24 24"><circle cx="8" cy="8" r="3.2"/><circle cx="16" cy="8" r="3.2"/><circle cx="8" cy="16" r="3.2"/><circle cx="16" cy="16" r="3.2"/></svg>ระบบ</button>'
  A '</nav>'
  A '</div>'

  # ---------------- interactive (v6.0: ไม่โหลดหน้าใหม่, อัปเดตเฉพาะส่วนที่เปลี่ยน) ----------------
  $jsA = @()
  foreach ($a in $alerts) { $jsA += ('{id:"' + (JEsc $a.Id) + '",k:"' + $a.Kind + '"}') }
  $alertsJs = ($jsA -join ',')
  $sbS = New-Object System.Text.StringBuilder
  function AJ([string]$s) { [void]$sbS.AppendLine($s) }
  AJ '<script>(function(){'
  AJ ('var POLL_MS=' + ([math]::Max(1,$Interval)*1000) + ',LIVE_FILE="live.js";')
  AJ 'var K="eadash3",ST={p:"sc-home",c:"BOTH",s:"ALL",o:{},m:{},sc:{}};'
  AJ 'try{var _p=JSON.parse(sessionStorage.getItem(K)||"{}");for(var _k in _p)ST[_k]=_p[_k]}catch(e){}'
  AJ 'function save(){try{sessionStorage.setItem(K,JSON.stringify(ST))}catch(e){}}'
  AJ 'function qa(s,root){return Array.prototype.slice.call((root||document).querySelectorAll(s))}'
  AJ 'function getY(){var ph=document.querySelector(".phone");return (ph?ph.scrollTop:0)+window.scrollY}'
  AJ 'function setY(y){var ph=document.querySelector(".phone");if(ph&&ph.scrollHeight>ph.clientHeight){ph.scrollTop=y;window.scrollTo(0,0)}else{window.scrollTo(0,y)}}'
  # --- state appliers (เรียกซ้ำได้หลังทุกการอัปเดต) ---
  AJ 'function goPage(id,scrollTop){ST.p=id;qa(".screen").forEach(function(el){el.className=(el.id===id)?"screen on":"screen"});'
  AJ 'qa(".nv").forEach(function(b){b.className=(b.getAttribute("data-go")===id)?"nv on":"nv"});'
  AJ 'var cur=document.getElementById(id);var t=document.getElementById("pgname");'
  AJ 'if(cur&&t)t.textContent=cur.getAttribute("data-name");save();if(scrollTop)setY(0)}'
  AJ 'function applyC(){qa(".ctab").forEach(function(b){b.className=(b.getAttribute("data-c")===ST.c)?"tab ctab on":"tab ctab"});'
  AJ 'qa("g.ser").forEach(function(g){var s=g.getAttribute("data-s");g.style.display=(ST.c==="BOTH"||ST.c===s)?"":"none"})}'
  AJ 'function applyS(){qa(".stab").forEach(function(b){b.className=(b.getAttribute("data-s")===ST.s)?"tab stab on":"tab stab"});'
  AJ 'qa(".gset").forEach(function(g){g.style.display=(g.getAttribute("data-g")===ST.s)?"":"none"});'
  AJ 'var n=0;qa(".hrow").forEach(function(r){var ok=(ST.s==="ALL"||r.getAttribute("data-ea")===ST.s);'
  AJ 'r.style.display=ok?"":"none";if(ok)n++});'
  AJ 'var hn=document.getElementById("histn");if(hn)hn.textContent=n}'
  AJ 'function applyO(){qa(".hrow").forEach(function(r){var id=r.getAttribute("data-row");'
  AJ 'var d=r.querySelector(".det");if(d)d.className=ST.o[id]?"det on":"det"})}'
  AJ 'function applyM(){qa("[data-more]").forEach(function(b){var id=b.getAttribute("data-more"),on=ST.m[id];'
  AJ 'var ul=document.getElementById(id);if(!ul)return;var ex=ul.querySelectorAll("[data-extra]");'
  AJ 'for(var i=0;i<ex.length;i++)ex[i].style.display=on?"":"none";'
  AJ 'b.textContent=on?"ย่อกลับ":("ดูเพิ่ม ("+ex.length+" บรรทัด)")})}'
  AJ 'function applyAll(){goPage(ST.p,false);applyC();applyS();applyO();applyM()}'
  # --- event delegation: ผูกครั้งเดียว ใช้ได้แม้ DOM ถูกแทนที่ ---
  AJ 'document.addEventListener("click",function(ev){var t=ev.target;'
  AJ 'function up(sel){var n=t;while(n&&n!==document){if(n.matches&&n.matches(sel))return n;n=n.parentNode}return null}'
  AJ 'var b;'
  AJ 'if((b=up(".nv"))){goPage(b.getAttribute("data-go"),true);return}'
  AJ 'if((b=up(".ctab"))){ST.c=b.getAttribute("data-c");save();applyC();return}'
  AJ 'if((b=up(".stab"))){ST.s=b.getAttribute("data-s");save();applyS();return}'
  AJ 'if((b=up("[data-more]"))){var id=b.getAttribute("data-more");ST.m[id]=ST.m[id]?0:1;save();applyM();return}'
  AJ 'if((b=up(".hrow"))){var rid=b.getAttribute("data-row");ST.o[rid]=ST.o[rid]?0:1;save();applyO();return}'
  AJ '},false);'
  # --- DOM morph: เทียบ "เวอร์ชันก่อน" กับ "เวอร์ชันใหม่" แล้วแทนที่เฉพาะกิ่งที่เปลี่ยน ---
  AJ 'var ROOT=document.querySelector(".phone");var PREV=ROOT.cloneNode(true);'
  AJ 'function morph(live,prev,next){'
  AJ 'if(prev.outerHTML===next.outerHTML)return;'
  AJ 'var lc=live.children,pc=prev.children,nc=next.children;'
  AJ 'var same=(pc.length===nc.length&&lc.length===pc.length&&pc.length>0);'
  AJ 'if(same){for(var i=0;i<pc.length;i++){if(pc[i].tagName!==nc[i].tagName||lc[i].tagName!==pc[i].tagName){same=false;break}}}'
  AJ 'if(!same){live.parentNode.replaceChild(next.cloneNode(true),live);return}'
  AJ 'var pa=prev.attributes,na=next.attributes,attrDiff=(pa.length!==na.length);'
  AJ 'if(!attrDiff){for(var j=0;j<na.length;j++){if(prev.getAttribute(na[j].name)!==na[j].value){attrDiff=true;break}}}'
  AJ 'if(attrDiff){for(var k=0;k<na.length;k++)live.setAttribute(na[k].name,na[k].value);'
  AJ 'for(var q=live.attributes.length-1;q>=0;q--){var an=live.attributes[q].name;if(!next.hasAttribute(an)&&an!=="style")live.removeAttribute(an)}}'
  AJ 'var ptxt=[],ntxt=[];for(var a=0;a<prev.childNodes.length;a++){if(prev.childNodes[a].nodeType===3)ptxt.push(prev.childNodes[a].nodeValue)}'
  AJ 'for(var c=0;c<next.childNodes.length;c++){if(next.childNodes[c].nodeType===3)ntxt.push(next.childNodes[c].nodeValue)}'
  AJ 'if(ptxt.join("")!==ntxt.join("")){live.innerHTML=next.innerHTML;return}'
  AJ 'var L=Array.prototype.slice.call(lc),P=Array.prototype.slice.call(pc),N=Array.prototype.slice.call(nc);'
  AJ 'for(var m=0;m<N.length;m++)morph(L[m],P[m],N[m])}'
  # --- รับข้อมูลใหม่ ---
  AJ 'function applyLive(D){if(!D||!D.html)return;var sy=getY();'
  AJ 'var box=document.createElement("div");box.innerHTML=D.html;var next=box.querySelector(".phone");if(!next)return;'
  AJ 'try{morph(ROOT,PREV,next)}catch(e){ROOT.parentNode.replaceChild(next.cloneNode(true),ROOT)}'
  AJ 'ROOT=document.querySelector(".phone");PREV=next;'
  AJ 'if(D.title)document.title=D.title;'
  AJ 'applyAll();try{setY(sy)}catch(e){}playAlerts(D.alerts||[])}'
  AJ 'var lastTs="";function poll(){var s=document.createElement("script");s.src=LIVE_FILE+"?"+Date.now();'
  AJ 's.onload=function(){s.parentNode.removeChild(s);var D=window.__EADASH;if(D&&D.ts!==lastTs){lastTs=D.ts;applyLive(D)}};'
  AJ 's.onerror=function(){s.parentNode.removeChild(s)};document.head.appendChild(s)}'
  # --- sound ---
  AJ 'var ON=false;try{ON=localStorage.getItem("ea_snd")==="1"}catch(e){}'
  AJ 'function paint(){var b=document.getElementById("sndbtn");if(b){b.innerHTML=ON?"&#128276;":"&#128277;";b.style.color=ON?"#12C46A":"";b.title=ON?"เสียงเตือน: เปิด":"เสียงเตือน: ปิด"}}'
  AJ 'function tone(k){try{var C=window.AudioContext||window.webkitAudioContext;if(!C)return;var c=new C();'
  AJ 'var f=(k==="win")?[680,1020]:((k==="loss")?[520,330]:[760,760]);'
  AJ 'f.forEach(function(hz,i){var o=c.createOscillator(),g=c.createGain();o.type="sine";o.frequency.value=hz;'
  AJ 'var t0=c.currentTime+i*0.19;g.gain.setValueAtTime(0.0001,t0);g.gain.exponentialRampToValueAtTime(0.2,t0+0.02);'
  AJ 'g.gain.exponentialRampToValueAtTime(0.0001,t0+0.17);o.connect(g);g.connect(c.destination);o.start(t0);o.stop(t0+0.19)});}catch(e){}}'
  AJ 'document.addEventListener("click",function(ev){var n=ev.target;while(n&&n!==document){if(n.id==="sndbtn"){ON=!ON;try{localStorage.setItem("ea_snd",ON?"1":"0")}catch(e){}paint();if(ON)tone("win");return}n=n.parentNode}},false);'
  AJ 'function playAlerts(A){paint();if(!ON||!A.length)return;var seen={};try{seen=JSON.parse(sessionStorage.getItem("ea_played")||"{}")}catch(e){}'
  AJ 'var fresh=null;A.forEach(function(a){if(!seen[a.id]){seen[a.id]=1;fresh=a}});'
  AJ 'try{sessionStorage.setItem("ea_played",JSON.stringify(seen))}catch(e){}'
  AJ 'if(fresh)tone(fresh.k)}'
  # --- start ---
  AJ 'applyAll();try{setY((ST.sc||{})[ST.p]||0)}catch(e){}'
  AJ ('playAlerts([' + $alertsJs + ']);')
  AJ 'setInterval(function(){ST.sc=ST.sc||{};ST.sc[ST.p]=getY();save()},400);'
  AJ 'window.addEventListener("beforeunload",function(){ST.sc=ST.sc||{};ST.sc[ST.p]=getY();save()});'
  AJ 'setInterval(poll,POLL_MS);'
  AJ '})();</script>'

  $body = $sb.ToString()
  return @{
    Html   = ($sbH.ToString() + $body + $sbS.ToString())
    Body   = $body
    Title  = $ttl
    Alerts = $alertsJs
  }
}
# ---------- main loop ----------
Write-Host "EA Dashboard - อ่าน log จาก: $DataDir"
Write-Host "เขียนไฟล์: $OutFile   (รีเฟรชทุก $Interval วินาที)"
Write-Host "กด Ctrl+C เพื่อหยุด" -ForegroundColor Yellow
$first = $true
while ($true) {
  try {
    $M = Get-Model -DataDir $DataDir -ContractSize $ContractSize -DayStartHour $DayStartHour
    $R = Build-Html $M
    $utf8 = New-Object System.Text.UTF8Encoding($true)
    # 1) live.js - หน้าเว็บที่เปิดค้างไว้ดึงไฟล์นี้ทุก $Interval วิ แล้วอัปเดตเฉพาะส่วนที่เปลี่ยน (ไม่โหลดหน้าใหม่)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
    $liveJs = 'window.__EADASH={ts:' + ($ts | ConvertTo-Json -Compress) + ',title:' + ($R.Title | ConvertTo-Json -Compress) +
              ',alerts:[' + $R.Alerts + '],html:' + ($R.Body | ConvertTo-Json -Compress) + '};'
    $liveFile = Join-Path (Split-Path -Parent $OutFile) 'live.js'
    [System.IO.File]::WriteAllText("$liveFile.tmp",$liveJs,$utf8)
    Move-Item -LiteralPath "$liveFile.tmp" -Destination $liveFile -Force
    # 2) dashboard.html - สำหรับเปิดครั้งแรก / เปิดใหม่
    $tmp = "$OutFile.tmp"
    [System.IO.File]::WriteAllText($tmp,$R.Html,$utf8)
    Move-Item -LiteralPath $tmp -Destination $OutFile -Force
    $t = (Get-Date).ToString('HH:mm:ss')
    Write-Host "[$t] ปิดแล้ว $($M.Closed.Count) ไม้ / ถืออยู่ $($M.Open.Count) ไม้ / เหตุการณ์ $($M.Events.Count)"
    if ($first) { Start-Process $OutFile; $first = $false }
  } catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
  }
  if ($Once) { break }
  Start-Sleep -Seconds $Interval
}
