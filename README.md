# EA Dashboard (MT5 · XAUUSD) — หน้าจอติดตาม EA แบบสด อ่านจาก log อย่างเดียว

แดชบอร์ดหน้าจอโทรศัพท์ (portrait) สำหรับติดตาม Expert Advisor 2 ตัวบน MetaTrader 5
(ตัวอย่างในโปรเจกต์นี้คือ **ScalperEA** และ **GridTrader** บน XAUUSD)
โดย **อ่านไฟล์ log ของ MT5 อย่างเดียว** — ไม่แตะ EA ไม่ส่งคำสั่งเทรด ไม่แก้ค่าใดๆ ในบัญชี

> Mobile-first dashboard for two MT5 Expert Advisors. Log-only: it never sends orders
> or modifies anything in the terminal. Live floating P/L comes from a tiny read-only indicator.

## หน้าจอ

| แท็บ | แสดงอะไร |
|---|---|
| **Home** | กำไร/ขาดทุนที่ปิดแล้ววันนี้ · ไม้ที่ถืออยู่ (SL→TP bar + กำไรลอยสด) · กราฟกำไรสะสม 2 เส้น · log Expert เฉพาะที่สำคัญ |
| **Summary** | โดนัทชนะ/แพ้ · แยกต่อ EA (สี Scalper น้ำเงิน / Grid ส้ม) พร้อม sparkline · ประวัติไม้ที่ปิดแล้ว คลิกดูรายละเอียดได้ |
| **Notify** | การ์ดเปิด/ปิดไม้ + เหตุการณ์สำคัญ (guard, ล็อก, เพดาน, ปิดขาดทุน ฯลฯ) · toast + เสียงเตือน (เปิด/ปิดได้) |
| **ระบบ** | สถานะบัญชีสด (balance/equity/margin) จาก PosExport · heartbeat ของ EA · log เต็ม |

## ส่วนประกอบ

```
EA-Dashboard/
├── build-dashboard.ps1   # ตัวสร้าง: อ่าน log → dashboard.html + live.js ทุก N วินาที (PowerShell 5.1+)
├── START-DASHBOARD.cmd   # ดับเบิลคลิกเพื่อรัน (เลือกฟอนต์ได้ในไฟล์นี้)
├── PosExport.mq5         # indicator อ่านอย่างเดียว: เขียนไม้ที่ถือ + balance/equity ลง MQL5\Files\ea_positions.csv ทุก 1 วิ
├── CHANGELOG.md
└── README.md
```

### วิธีทำงาน (v6.0)

```
MT5 ─ Logs\yyyyMMdd.log (Journal)  ─┐
MT5 ─ MQL5\Logs\yyyyMMdd.log (Experts) ─┼─► build-dashboard.ps1 ─► dashboard.html  (เปิดครั้งแรก)
PosExport.mq5 ─ MQL5\Files\ea_positions.csv ─┘                     └► live.js        (หน้าเว็บดึงทุก N วิ)
```

- **dashboard.html** โหลดครั้งเดียว มี CSS/JS ครบในไฟล์เดียว
- **live.js** ถูกเขียนใหม่ทุก N วินาที หน้าเว็บโหลดผ่าน `<script>` (ใช้ได้ทั้ง `file://` และ http)
  แล้วทำ **DOM morph** — เทียบเวอร์ชันก่อน/หลัง แทนที่เฉพาะกิ่งที่เปลี่ยน
  → ไม่กระพริบ, ตำแหน่งเลื่อนคงเดิม, แท็บ/ตัวกรอง/แถวที่กางอยู่ไม่หาย
- ทุกอย่างเป็นเวลาไทย (เซิร์ฟเวอร์ = ไทย − 6) วันเทรดเริ่ม 06:00

## ติดตั้ง

1. คัดลอกโฟลเดอร์นี้ไปไว้ที่ไหนก็ได้ เช่น `%APPDATA%\MetaQuotes\Terminal\EA-Dashboard\`
2. แก้ `-DataDir` ให้ชี้โฟลเดอร์ข้อมูลของ MT5 ของคุณ (ค่าเริ่มต้นอยู่บนสุดของ `build-dashboard.ps1`)
   หาได้จาก MT5 → File → Open Data Folder
3. (ทางเลือก แต่แนะนำ) **PosExport**: คัดลอก `PosExport.mq5` ไปที่ `MQL5\Indicators\` → เปิด MetaEditor กด F7 →
   ใน MT5 กด Refresh ที่ Navigator → ลาก PosExport ลงกราฟใดก็ได้ (ไม่จำเป็นต้องเป็นกราฟที่ EA อยู่ — มันอ่านทั้งบัญชี)
   ถ้าไม่ใส่ แดชบอร์ดยังใช้ได้ แต่ไม่มีกำไรลอย/equity แบบสด
4. ดับเบิลคลิก `START-DASHBOARD.cmd` — จะเปิด `dashboard.html` ในเบราว์เซอร์ให้เอง

### พารามิเตอร์

```powershell
.\build-dashboard.ps1 -DataDir "C:\...\Terminal\<id>" -Interval 5 -Font plex -DayStartHour 6 -NotifySeconds 90
```

| พารามิเตอร์ | ค่าเริ่มต้น | ความหมาย |
|---|---|---|
| `-DataDir` | โฟลเดอร์ MT5 ในเครื่องผู้เขียน | โฟลเดอร์ข้อมูล MT5 (มี `Logs\` และ `MQL5\`) |
| `-OutFile` | `dashboard.html` ข้างสคริปต์ | ไฟล์ผลลัพธ์ (`live.js` จะอยู่โฟลเดอร์เดียวกัน) |
| `-Interval` | 5 | วินาทีต่อรอบสร้างใหม่ = ความถี่ที่หน้าเว็บอัปเดต |
| `-ContractSize` | 100 | ขนาดสัญญา (XAUUSD 1 lot = 100 oz) |
| `-DayStartHour` | 6 | ชั่วโมงเริ่มวันเทรด (เวลาไทย) |
| `-NotifySeconds` | 90 | toast เปิด/ปิดไม้ค้างบนจอกี่วินาที |
| `-Font` | plex | plex · prompt · anuphan · noto · sarabun · kanit · niramit (ฟอนต์ในเครื่อง) |
| `-Once` | – | สร้างครั้งเดียวแล้วออก (ไว้ทดสอบ) |

## การแยกว่าไม้ไหนเป็นของ EA ตัวไหน

Journal ของ MT5 ไม่บันทึก magic number แต่บันทึกคอมเมนต์ตอนส่งคำสั่ง
(`placed for execution (SCLP|B|1)` / `(GT|S|g1)`) แดชบอร์ดจับคู่ไม้เปิดกับดีลปิดด้วย **ราคาเข้าโดยนัย**
`entry = close ∓ profit / (lot × ContractSize)` จึงนับไม้ที่ **ปิดด้วยมือ/มือถือ** (magic = 0) ได้ถูกต้อง
ซึ่งต่างจากป้ายบนกราฟของ EA ที่กรองด้วย magic number

ถ้า EA ของคุณใช้คอมเมนต์อื่น แก้ที่ regex ใน `Get-Model` (`SCLP|GT`) และชื่อ EA ใน `$eaList`

## รูปแบบไฟล์ ea_positions.csv (จาก PosExport)

```
ACC;login;balance;equity;margin;free;marginLevel;profit;currency;serverTime;localTime;N
POS;ticket;magic;symbol;dir;lot;open;sl;tp;current;profit;swap;openTime;comment
```

เขียนลง `.tmp` แล้ว `FileMove` ทับ → ผู้อ่านไม่เจอไฟล์เขียนครึ่งเดียว

## ข้อจำกัด / สิ่งที่ตั้งใจให้เป็นแบบนี้

- อ่านอย่างเดียว 100% — ไม่มีฟังก์ชันสั่งเทรด และจะไม่มี
- ไม่ต้องใช้เว็บเซิร์ฟเวอร์ (เปิดจาก `file://` ได้) ถ้าจะดูจากโทรศัพท์ ให้แชร์โฟลเดอร์หรือรัน static server ง่ายๆ ชี้ที่โฟลเดอร์นี้
- log ของ MT5 หมุนไฟล์ตอนเที่ยงคืน แต่วันเทรดเริ่ม 06:00 สคริปต์จึงอ่าน 2 ไฟล์ต่อวันเสมอ
- ตัวเลขทั้งหมดเป็นข้อมูลเชิงกลไกและเลขคณิต **ไม่ใช่คำแนะนำการลงทุน**

## เครื่องมือที่ใช้

PowerShell 5.1 (Windows) หรือ PowerShell 7 · เบราว์เซอร์ที่รองรับ ES5 · MQL5 (สำหรับ PosExport)
ไม่มี dependency ภายนอก (Google Fonts ใช้เมื่อเลือกฟอนต์เว็บ ไม่มีก็ fallback เป็นฟอนต์ระบบ)

## License

MIT — ดู `LICENSE`
