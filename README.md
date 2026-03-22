# 💊 ระบบบริหารจัดการคลังยา — PCU สะบ้าย้อย

ระบบจัดการคลังยาสำหรับหน่วยบริการปฐมภูมิ (PCU) สะบ้าย้อย อำเภอสะบ้าย้อย จังหวัดสงขลา  
พัฒนาด้วย Vanilla HTML/CSS/JS — ใช้งานได้ทันทีบน Browser ไม่ต้องติดตั้ง

---

## 🌐 เปิดใช้งาน

> **GitHub Pages:** `https://USERNAME.github.io/pcu-sabayoi-drug-system/`

---

## 📁 โครงสร้างไฟล์

```
pcu-sabayoi-drug-system/
├── index.html                ← หน้า Landing — เชื่อมทุกระบบ
├── barcode_scanner.html      ← สแกนบาร์โค้ดด้วยกล้องมือถือ
├── tmt_sync_tool.html        ← จับคู่รหัสยา PCU กับมาตรฐาน TMT
└── README.md
```

---

## 🔧 ฟีเจอร์แต่ละหน้า

### 📷 Barcode Scanner (`barcode_scanner.html`)
- เปิดกล้องมือถือสแกนบาร์โค้ดอัตโนมัติ
- รองรับ **EAN-13, Code 128, QR Code, GS1-128**
- แปลข้อมูล GS1 → LOT, วันหมดอายุ, จำนวน อัตโนมัติ
- ค้นหายาจากฐานข้อมูล 118 รายการของ PCU สะบ้าย้อย
- บันทึกประวัติสแกนใน localStorage
- รองรับปุ่มไฟฉาย + กลับกล้อง

### 🔬 TMT Sync Tool (`tmt_sync_tool.html`)
- จับคู่รหัสยา PCU กับ **รหัสมาตรฐาน TMT** (Thai Medicines Terminology)
- Auto-map ยา 118 รายการอัตโนมัติ
- ค้นหาและแก้ไข TMT Code ได้ทุกรายการ
- Export เป็น CSV (UTF-8 BOM, เปิด Excel ได้ทันที)
- บันทึกการแก้ไขใน localStorage

---

## 🛠️ เทคโนโลยี

| ส่วน | เทคโนโลยี |
|------|-----------|
| Frontend | HTML5, CSS3, Vanilla JavaScript |
| Barcode scanning | [jsQR v1.4.0](https://github.com/cozmo/jsQR) |
| ฟอนต์ | IBM Plex Sans Thai + IBM Plex Mono |
| ข้อมูลยามาตรฐาน | TMT (สมสท. — สำนักพัฒนามาตรฐานระบบข้อมูลสุขภาพไทย) |
| Hosting | GitHub Pages |

---

## 📱 รองรับ

- ✅ Android Chrome
- ✅ iOS Safari
- ✅ Desktop Chrome / Edge / Firefox
- ✅ ไม่ต้องติดตั้ง App ใดๆ

---

## 🚀 วิธีนำไปใช้งาน

1. Fork หรือ Clone repository นี้
2. เปิด **Settings → Pages** → เลือก branch `main`
3. รอ 1–2 นาที จะได้ URL พร้อมใช้งาน

---

## 📋 ฐานข้อมูลยา

ระบบมียา **118 รายการ** ครอบคลุมกลุ่ม:

| กลุ่ม | ตัวอย่าง |
|-------|---------|
| Antibiotic | Amoxicillin, Norfloxacin, Metronidazole |
| Antihypertensive | Amlodipine, Losartan, Enalapril |
| Antidiabetic | Metformin, Glipizide, Pioglitazone |
| Analgesic / NSAID | Paracetamol, Ibuprofen, Diclofenac |
| Supplement | Folic acid, Ferrous fumarate, Calcium |
| และอื่นๆ | Corticosteroid, GI, Bronchodilator... |

---

## 👥 ผู้พัฒนา

**PCU สะบ้าย้อย** — หน่วยบริการปฐมภูมิ  
อำเภอสะบ้าย้อย จังหวัดสงขลา

---

*พัฒนาเพื่อการใช้งานจริงในระบบสาธารณสุขชุมชน*
