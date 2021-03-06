//+------------------------------------------------------------------+
//|                                                 SetupDaPaula.mq5 |
//|                                       Copyright 2019, Paulo Féra |
//|                      https://www.youtube.com/watch?v=laCU3m1m6Bk |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2019, Paulo Féra"
#property description "Este robô opera utilizando o setup da paula desenvolvido pelo Rodrigo Cohen."
#property link        "https://www.youtube.com/watch?v=laCU3m1m6Bk"
#property version     "1.00"
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <lib_cisnewbar.mqh>

#define EXPERT_MAGIC 636988;   // MagicNumber of the expert

input double stopLoss = 150; //Pontos de stop loss
input double bollingerBandSize = 300; //Tamanho mínimo da banda de bollinger
input double contracts = 2; //Quantidade de contratos

MqlRates priceInfo[];
MqlTick tick;
CisNewBar current_chart;
double upperBand[];
double lowerBand[];
int bollingerBandsDefinition;
string entry = "";
bool inTrade = false;

int OnInit()
{
   ArraySetAsSeries(priceInfo, true);
   ArraySetAsSeries(upperBand, true);
   ArraySetAsSeries(lowerBand, true);

   bollingerBandsDefinition = iBands(_Symbol, _Period, 20, 0, 2, PRICE_CLOSE);
   if (bollingerBandsDefinition == INVALID_HANDLE)
   {
      Print("Erro ao criar a banda de bollinger. Erro: ", GetLastError());
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

void OnTick()
{
   if (CopyRates(_Symbol, _Period, 0, 3, priceInfo) < 0)
   {
      Alert("Erro ao obter informações de MqlRates: ", GetLastError());
      return;
   }
   
   if (!SymbolInfoTick(_Symbol, tick))
   {
      Alert("Erro ao obter informações de preços: ", GetLastError());
      return;
   }
   
   if (CopyBuffer(bollingerBandsDefinition, 1, 0, 2, upperBand) < 0)
   {
      Alert("Erro ao obter informações da bande de bollinger: ", GetLastError());
      return;
   }
   
   if (CopyBuffer(bollingerBandsDefinition, 2, 0, 2, lowerBand) < 0)
   {
      Alert("Erro ao obter informações da bande de bollinger: ", GetLastError());
      return;
   }
   
   int period_seconds = PeriodSeconds(_Period);                         // Number of seconds in current chart period
   datetime new_time = TimeCurrent() / period_seconds * period_seconds; // Time of bar opening on current chart
   if(current_chart.isNewBar(new_time)) OnNewBar();                     // When new bar appears - launch the NewBar event handler
}


void OnNewBar()
{
   string log = "";
   inTrade = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (PositionGetSymbol(i) == _Symbol)
      {
         inTrade = true;
         break;
      }
   }
   
   log = log + "inTrade: " + inTrade;
   log = log + "Bollinger band size: " + (upperBand[0] - lowerBand[0]);
   
   if ((upperBand[0] - lowerBand[0]) >= bollingerBandSize)
   {
      if (entry == "sell" && !inTrade && priceInfo[1].close < upperBand[1] && priceInfo[1].close > lowerBand[1])
      {
         log = log + "Dentro: " + entry + "\n";
   
         double sl = GetPriceNormalized(tick.bid + stopLoss * _Point);
         double tp = GetPriceNormalized(lowerBand[0]);
         log = log + "sl: " + sl + "\n";
         log = log + "tp: " + tp + "\n";
         
         MqlTradeRequest request = {0};
         MqlTradeResult result = {0};
   
         request.action = TRADE_ACTION_DEAL;
         request.symbol = Symbol();
         request.volume = contracts;
         request.type = ORDER_TYPE_SELL;
         request.price = GetPriceNormalized(tick.bid);
         request.magic = EXPERT_MAGIC;
         request.type_filling = ORDER_FILLING_RETURN;
         request.sl = sl;
         request.tp = tp;
   
         //--- send the request
         if(!OrderSend(request, result))
            PrintFormat("OrderSend error %d", GetLastError());
         
         entry = "";
      }
      else if (entry == "buy" && !inTrade && priceInfo[1].close < upperBand[1] && priceInfo[1].close > lowerBand[1])
      {
         log = log + "Dentro: " + entry + "\n";
         
         double sl = GetPriceNormalized(tick.ask - stopLoss * _Point);
         double tp = GetPriceNormalized(upperBand[0]);
   
         log = log + "sl: " + sl + "\n";
         log = log + "tp: " + tp + "\n";
         
         MqlTradeRequest request = {0};
         MqlTradeResult result = {0};
   
         request.action = TRADE_ACTION_DEAL;
         request.symbol = Symbol();
         request.volume = contracts;
         request.type = ORDER_TYPE_BUY;
         request.price = GetPriceNormalized(tick.ask);
         request.magic = EXPERT_MAGIC;
         request.type_filling = ORDER_FILLING_RETURN;
         request.sl = sl;
         request.tp = tp;
   
         //--- send the request
         if(!OrderSend(request, result))
            PrintFormat("OrderSend error %d", GetLastError());
         
         entry = "";
      }
   }
   
   //Check if current bar and last bar are of same day
   if (TimeToString(priceInfo[0].time, TIME_DATE) != TimeToString(priceInfo[1].time, TIME_DATE)) return;

   if (priceInfo[1].close > upperBand[1])
      entry = "sell";
   else if (priceInfo[1].close < lowerBand[1])
      entry = "buy";
   
   log = log + "Fora: " + entry + "\n";

   log = log + "priceInfo[0].close: " + priceInfo[0].close + "\n" +
               "priceInfo[1].close: " + priceInfo[1].close + "\n" +
               "priceInfo[2].close: " + priceInfo[2].close + "\n" +
               "upperBand[0]: " + upperBand[0] + "\n" +
               "lowerBand[0]: " + lowerBand[0] + "\n";
               "upperBand[1]: " + upperBand[1] + "\n" +
               "lowerBand[1]: " + lowerBand[1] + "\n";

   Comment(log);
}

double GetPriceNormalized(double price)
{
   return MathRound(price * 0.1) * 10;
}
//+------------------------------------------------------------------+
