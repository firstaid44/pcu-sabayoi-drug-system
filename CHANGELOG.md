# Changelog

## v6.0 — 2026-09-10
- **อัปเดตหน้าจอโดยไม่โหลดหน้าใหม่**: ตัวสร้างเขียน `live.js` คู่กับ `dashboard.html`
  หน้าเว็บดึง `live.js` ทุก N วินาทีผ่าน `<script>` แล้ว DOM-morph เฉพาะส่วนที่เปลี่ยน
- แก้ **หน้าจอกระพริบ** และ **เลื่อนกลับไปบนสุด** ทุกครั้งที่อัปเดต (ตัว scroll จริงคือ `.phone` ไม่ใช่ window)
- แท็บ / ตัวกรอง / แถวที่กางอยู่ / ปุ่มดูเพิ่ม คงสถานะเดิมหลังอัปเดต (event delegation + re-apply)
- title ของแท็บเบราว์เซอร์ และเสียงเตือน อัปเดตตามข้อมูลใหม่โดยไม่ต้องโหลดหน้า
- `<noscript>` fallback ยังใช้ meta refresh ได้เมื่อปิด JavaScript

## v5.0
- ข้อมูลสดจากแท็บ Trade ผ่าน indicator `PosExport.mq5` (`ea_positions.csv`): กำไรลอย / balance / equity / margin
- การ์ดไม้ที่ถือแบบกะทัดรัด มีแถบ SL→TP และจุดราคาปัจจุบัน
- หน้าจอ 4 แท็บแนวตั้ง (Home / Summary / Notify / ระบบ) ตามเทมเพลต Gradient Dark Mode
- แยกสี/สถิติต่อ EA, คลิกดูรายละเอียดไม้, log Expert สด + heartbeat, toast + เสียงเตือน
- เลือกฟอนต์ไทยได้ (IBM Plex Sans Thai เป็นค่าเริ่มต้น)

## v1.0
- อ่าน Journal + Experts log, จับคู่ไม้เปิด/ปิดด้วยราคาเข้าโดยนัย, สรุปกำไรวัน, meta refresh ทุก 5 วิ
