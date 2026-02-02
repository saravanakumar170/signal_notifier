import yfinance as yf
import pandas as pd
from datetime import datetime
from firebase_admin import credentials, initialize_app, firestore
import os
import json
import pytz

# -----------------------------
# Firebase Initialization
# -----------------------------
firebase_creds_json = os.environ.get('FIREBASE_SERVICE_ACCOUNT')

if firebase_creds_json:
    cred_dict = json.loads(firebase_creds_json)
    cred = credentials.Certificate(cred_dict)
else:
    cred = credentials.Certificate('firebase-key.json')  # local testing only

initialize_app(cred)
db = firestore.client()

# -----------------------------
# Holiday Cache
# -----------------------------
_holiday_cache = None
_holiday_cache_year = None

def get_nse_holidays():
    global _holiday_cache, _holiday_cache_year
    current_year = datetime.now().year

    if _holiday_cache and _holiday_cache_year == current_year:
        return _holiday_cache

    try:
        import pandas_market_calendars as mcal
        nse = mcal.get_calendar('NSE')

        start_date = f'{current_year}-01-01'
        end_date = f'{current_year}-12-31'

        schedule = nse.schedule(start_date=start_date, end_date=end_date)
        trading_days = set(schedule.index.date)

        all_days = pd.date_range(start=start_date, end=end_date, freq='D')

        holidays = []
        for day in all_days:
            if day.weekday() < 5 and day.date() not in trading_days:
                holidays.append(day.date())

        _holiday_cache = holidays
        _holiday_cache_year = current_year
        return holidays

    except Exception:
        return [
            datetime(2026, 1, 26).date(),
            datetime(2026, 3, 14).date(),
            datetime(2026, 3, 30).date(),
            datetime(2026, 4, 2).date(),
            datetime(2026, 4, 3).date(),
            datetime(2026, 4, 14).date(),
            datetime(2026, 5, 1).date(),
            datetime(2026, 8, 15).date(),
            datetime(2026, 8, 27).date(),
            datetime(2026, 10, 2).date(),
            datetime(2026, 10, 21).date(),
            datetime(2026, 11, 9).date(),
            datetime(2026, 11, 10).date(),
            datetime(2026, 11, 24).date(),
        ]

def is_market_open():
    ist = pytz.timezone('Asia/Kolkata')
    now = datetime.now(ist)

    if now.weekday() >= 5:
        return False

    if now.date() in get_nse_holidays():
        return False

    open_time = now.replace(hour=9, minute=17, second=0)
    close_time = now.replace(hour=15, minute=30, second=0)

    return open_time <= now <= close_time

# -----------------------------
# Trading Strategy
# -----------------------------
def run_trading_strategy():

    # 🔴 DEFAULT SIGNAL (IMPORTANT)
    signal = "NO ENTRY"
    reason = "Market closed or no setup"
    current_price = 0.0
    current_stoch = 0.0

    if is_market_open():
        ticker = "^NSEI"
        data = yf.download(ticker, period="3mo", interval="1d", progress=False)

        if isinstance(data.columns, pd.MultiIndex):
            data.columns = data.columns.get_level_values(0)

        data.dropna(inplace=True)

        if len(data) >= 20:
            data['Low_14'] = data['Low'].rolling(14).min()
            data['High_14'] = data['High'].rolling(14).max()
            data['%K'] = 100 * ((data['Close'] - data['Low_14']) /
                                (data['High_14'] - data['Low_14']))

            current_stoch = data['%K'].iloc[-1]
            previous_stoch = data['%K'].iloc[-2]
            current_price = data['Close'].iloc[-1]

            # Renko
            brick_size = 20
            bricks = []
            last_price = data['Close'].iloc[0]

            for price in data['Close']:
                diff = price - last_price
                bricks += [1] * int(diff // brick_size)
                bricks += [-1] * int(abs(diff) // brick_size if diff < 0 else 0)
                last_price += int(diff // brick_size) * brick_size

            if len(bricks) >= 3:
                last3 = bricks[-3:]
                three_green = all(b == 1 for b in last3)
                three_red = all(b == -1 for b in last3)

                buy = three_green and previous_stoch <= 20 and current_stoch > 20
                sell = three_red and previous_stoch >= 80 and current_stoch < 80

                if buy:
                    signal = "BUY"
                    reason = "Renko bullish + Stoch up"
                elif sell:
                    signal = "SELL"
                    reason = "Renko bearish + Stoch down"
                else:
                    signal = "NO ENTRY"
                    reason = "Setup not complete"

    # -----------------------------
    # LOG OUTPUT
    # -----------------------------
    print("=" * 50)
    print(f"Time: {datetime.now()}")
    print(f"Signal: {signal}")
    print(f"Reason: {reason}")
    print("=" * 50)

    # -----------------------------
    # FIREBASE WRITE (NO DUPLICATES)
    # -----------------------------
    try:
        signals_ref = db.collection('signals')
        last = signals_ref.order_by(
            'timestamp',
            direction=firestore.Query.DESCENDING
        ).limit(1).get()

        last_signal = last[0].to_dict()['type'] if last else None

        if signal != last_signal:
            signals_ref.add({
                "type": signal,
                "timestamp": firestore.SERVER_TIMESTAMP,
                "price": current_price,
                "stochastics": current_stoch,
                "reason": reason,
                "source": "github_actions"
            })
            print(f"✅ Firebase updated: {signal}")
        else:
            print("⏭️ Same signal – skipped")

    except Exception as e:
        print("🔥 Firebase error:", e)

    return signal

# -----------------------------
# MAIN
# -----------------------------
if __name__ == "__main__":
    run_trading_strategy()
