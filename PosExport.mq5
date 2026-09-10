//+------------------------------------------------------------------+
//|  PosExport.mq5  -  ส่งออกไม้ที่ถืออยู่ (แท็บ Trade) เป็นไฟล์ CSV   |
//|  เป็น "อินดิเคเตอร์" ไม่ใช่ EA  จึงลากใส่กราฟที่มี EA รันอยู่ได้    |
//|  ไม่ส่งคำสั่งเทรดใดๆ  อ่านอย่างเดียว                                |
//+------------------------------------------------------------------+
#property copyright "EA Dashboard"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

input int    InpUpdateMs = 1000;                 // อัปเดตทุกกี่มิลลิวินาที
input string InpFileName = "ea_positions.csv";   // ไฟล์ปลายทางใน MQL5\Files\

string g_tmp = "ea_positions.tmp";

//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME, "PosExport");
   int ms = InpUpdateMs; if(ms < 200) ms = 200;
   EventSetMillisecondTimer(ms);
   WriteSnapshot();
   Print("[PosExport] เริ่มทำงาน - เขียน ", InpFileName, " ทุก ", ms, " ms");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   Print("[PosExport] หยุดทำงาน (reason ", reason, ")");
  }
//+------------------------------------------------------------------+
void OnTimer() { WriteSnapshot(); }
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   return(rates_total);
  }
//+------------------------------------------------------------------+
string Esc(string s)
  {
   StringReplace(s, ";", ",");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return s;
  }
//+------------------------------------------------------------------+
void WriteSnapshot()
  {
   int h = FileOpen(g_tmp, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;

   FileWriteString(h, "ACC;" +
      IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))                 + ";" +
      DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)               + ";" +
      DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2)                + ";" +
      DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),2)                + ";" +
      DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2)           + ";" +
      DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),2)          + ";" +
      DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT),2)                + ";" +
      AccountInfoString(ACCOUNT_CURRENCY)                                + ";" +
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)                + ";" +
      TimeToString(TimeLocal(),   TIME_DATE|TIME_SECONDS)                + ";" +
      IntegerToString(PositionsTotal())                                  + "\r\n");

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(!PositionSelectByTicket(tk)) continue;

      string  sym  = PositionGetString(POSITION_SYMBOL);
      long    type = PositionGetInteger(POSITION_TYPE);
      string  dir  = (type == POSITION_TYPE_BUY ? "BUY" : "SELL");
      double  cur  = PositionGetDouble(POSITION_PRICE_CURRENT);
      int     dg   = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      if(dg <= 0) dg = 2;

      FileWriteString(h, "POS;" +
         IntegerToString((long)tk)                                          + ";" +
         IntegerToString(PositionGetInteger(POSITION_MAGIC))                + ";" +
         Esc(sym)                                                           + ";" +
         dir                                                                + ";" +
         DoubleToString(PositionGetDouble(POSITION_VOLUME),2)               + ";" +
         DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),dg)          + ";" +
         DoubleToString(PositionGetDouble(POSITION_SL),dg)                  + ";" +
         DoubleToString(PositionGetDouble(POSITION_TP),dg)                  + ";" +
         DoubleToString(cur,dg)                                             + ";" +
         DoubleToString(PositionGetDouble(POSITION_PROFIT),2)               + ";" +
         DoubleToString(PositionGetDouble(POSITION_SWAP),2)                 + ";" +
         TimeToString((datetime)PositionGetInteger(POSITION_TIME), TIME_DATE|TIME_SECONDS) + ";" +
         Esc(PositionGetString(POSITION_COMMENT))                           + "\r\n");
     }

   FileClose(h);
   FileMove(g_tmp, 0, InpFileName, FILE_REWRITE);
  }
//+------------------------------------------------------------------+
