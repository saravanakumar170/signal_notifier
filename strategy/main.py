import yfinance as yf
import pandas as pd
from datetime import datetime, timedelta
from firebase_admin import credentials, initialize_app, firestore
import os
import json
import pytz
import requests

# Initialize Firebase Admin with credentials from environment variable
# For Codemagic: Set environment variable FIREBASE_SERVICE_ACCOUNT with JSON content
firebase_creds_json = os.environ.get('FIREBASE_SERVICE_ACCOUNT')

if firebase_creds_json:
    # Parse JSON from environment variable
    cred_dict = json.loads(firebase_creds_json)
    cred = credentials.Certificate(cred_dict)
else:
    # Fallback to file (for local testing)
    cred = credentials.Certificate('firebase-key.json')

initialize_app(cred)
db = firestore.client()

# Cache for holidays (to avoid repeated API calls)
_holiday_cache = None
_holiday_cache_year = None

def get_nse_holidays():
    """
    Fetch NSE holidays dynamically from API.
    Uses pandas_market_calendars for accurate NSE holiday data.
    Falls back to manual list if API fails.
    """
    global _holiday_cache, _holiday_cache_year
    
    current_year = datetime.now().year
    
    # Return cached holidays if already fetched for this year
    if _holiday_cache and _holiday_cache_year == current_year:
        return _holiday_cache
    
    try:
        # Try to get holidays from NSE calendar API
        import pandas_market_calendars as mcal
        
        # Get NSE calendar
        nse = mcal.get_calendar('NSE')
        
        # Get holidays for current year
        start_date = f'{current_year}-01-01'
        end_date = f'{current_year}-12-31'
        
        schedule = nse.schedule(start_date=start_date, end_date=end_date)
        
        # Get all trading days
        trading_days = set(schedule.index.date)
        
        # Get all days in the year
        all_days = pd.date_range(start=start_date, end=end_date, freq='D')
        
        # Holidays are weekdays that are not trading days
        holidays = []
        for day in all_days:
            if day.weekday() < 5 and day.date() not in trading_days:  # Weekday but not trading
                holidays.append(day.date())
        
        _holiday_cache = holidays
        _holiday_cache_year = current_year
        
        print(f"✅ Loaded {len(holidays)} NSE holidays for {current_year} from API")
        return holidays
        
    except Exception as e:
        print(f"⚠️  Could not fetch holidays from API: {e}")
        print("Using fallback holiday list for 2026")
        
        # Fallback: Manual list for 2026 (in case API fails)
        fallback_holidays = [
            datetime(2026, 1, 26).date(),   # Republic Day
            datetime(2026, 3, 14).date(),   # Holi
            datetime(2026, 3, 30).date(),   # Ram Navami
            datetime(2026, 4, 2).date(),    # Mahavir Jayanti
            datetime(2026, 4, 3).date(),    # Good Friday
            datetime(2026, 4, 14).date(),   # Dr. Ambedkar Jayanti
            datetime(2026, 5, 1).date(),    # Maharashtra Day
            datetime(2026, 8, 15).date(),   # Independence Day
            datetime(2026, 8, 27).date(),   # Ganesh Chaturthi
            datetime(2026, 10, 2).date(),   # Gandhi Jayanti
            datetime(2026, 10, 21).date(),  # Dussehra
            datetime(2026, 11, 9).date(),   # Diwali
            datetime(2026, 11, 10).date(),  # Diwali (Balipratipada)
            datetime(2026, 11, 24).date(),  # Guru Nanak Jayanti
        ]
        
        return fallback_holidays

def is_market_open():
    """
    Check if Indian stock market is currently open.
    Returns True if market is open, False otherwise.
    """
    # Get current time in IST
    ist = pytz.timezone('Asia/Kolkata')
    now = datetime.now(ist)
    
    # Check if today is a weekend (Saturday=5, Sunday=6)
    if now.weekday() >= 5:
        print(f"⏸️  Market closed: Weekend ({now.strftime('%A')})")
        return False
    
    # Check if today is a market holiday
    holidays = get_nse_holidays()
    today_date = now.date()
    
    if today_date in holidays:
        print(f"⏸️  Market closed: Holiday ({now.strftime('%B %d, %Y')})")
        return False
    
    # Check if current time is within market hours (9:17 AM - 3:30 PM IST)
    market_open_time = now.replace(hour=9, minute=17, second=0, microsecond=0)
    market_close_time = now.replace(hour=15, minute=30, second=0, microsecond=0)
    
    if now < market_open_time or now > market_close_time:
        print(f"⏸️  Outside market hours: {now.strftime('%I:%M %p IST')}")
        return False
    
    return True

def run_trading_strategy():
    """
    Nifty trading strategy that runs every 2 minutes during market hours.
    Writes signal to Firestore: BUY, SELL, or NO ENTRY
    """
    
    # Check if market is open
    if not is_market_open():
        print("Skipping execution - market is closed")
        return {"signal": "MARKET_CLOSED", "reason": "Market is closed"}
    
    ticker = "^NSEI"
    try:
        data = yf.download(ticker, period="3mo", interval="1d", progress=False, auto_adjust=False)
    except Exception as e:
        print(f"Error downloading data: {e}")
        return {"signal": "NO ENTRY", "error": str(e)}

    if isinstance(data.columns, pd.MultiIndex):
        data.columns = data.columns.get_level_values(0)

    if len(data) < 20:
        print("Error: Not enough data fetched to calculate indicators.")
        return {"signal": "NO ENTRY", "error": "Insufficient data"}

    data.dropna(inplace=True)

    required_cols = ['Close', 'High', 'Low']
    for col in required_cols:
        if col not in data.columns:
            print(f"Error: Column '{col}' missing from data.")
            return {"signal": "NO ENTRY", "error": f"Missing column: {col}"}

    # CALCULATE STOCHASTICS (14, 3, 3)
    k_period = 14
    d_period = 3

    data['Low_14'] = data['Low'].rolling(window=k_period).min()
    data['High_14'] = data['High'].rolling(window=k_period).max()
    data['%K'] = 100 * ((data['Close'] - data['Low_14']) / (data['High_14'] - data['Low_14']))
    data['%D'] = data['%K'].rolling(window=d_period).mean()

    current_stoch = data['%K'].iloc[-1]
    previous_stoch = data['%K'].iloc[-2]
    current_price = data['Close'].iloc[-1]

    # CALCULATE RENKO BRICKS
    brick_size = 20
    bricks = []
    last_brick_price = data['Close'].iloc[0]

    for index, row in data.iterrows():
        price = row['Close']
        diff = price - last_brick_price

        if diff > 0:
            num_bricks = int(diff // brick_size)
            if num_bricks > 0:
                for _ in range(num_bricks):
                    bricks.append(1)  # Green Brick
                    last_brick_price += brick_size
        elif diff < 0:
            num_bricks = int(abs(diff) // brick_size)
            if num_bricks > 0:
                for _ in range(num_bricks):
                    bricks.append(-1)  # Red Brick
                    last_brick_price -= brick_size

    if len(bricks) < 3:
        print("Not enough movement to form Renko bricks yet.")
        return {"signal": "NO ENTRY", "error": "Insufficient bricks"}

    last_3_bricks = bricks[-3:]
    three_green = all(b == 1 for b in last_3_bricks)
    three_red = all(b == -1 for b in last_3_bricks)

    # TRADING LOGIC
    stoch_crossed_above_20 = previous_stoch <= 20 and current_stoch > 20
    is_buy_signal = three_green and (stoch_crossed_above_20 or (current_stoch > 20 and current_stoch < 40))

    stoch_crossed_below_80 = previous_stoch >= 80 and current_stoch < 80
    is_sell_signal = three_red and (stoch_crossed_below_80 or (current_stoch < 80 and current_stoch > 60))

    # DETERMINE SIGNAL
    if is_buy_signal:
        signal = "BUY"
        reason = "3 Green Renko Bricks & Stochastics rising from oversold"
    elif is_sell_signal:
        signal = "SELL"
        reason = "3 Red Renko Bricks & Stochastics falling from overbought"
    else:
        signal = "NO ENTRY"
        reason = "Market ranging or setup not complete"

    # Log the decision
    print(f"\n{'='*50}")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Nifty Price: {current_price:.2f}")
    print(f"Stochastics: {current_stoch:.2f} (Previous: {previous_stoch:.2f})")
    print(f"Renko: {'3 Green' if three_green else '3 Red' if three_red else 'Mixed'}")
    print(f"SIGNAL: {signal}")
    print(f"Reason: {reason}")
    print(f"{'='*50}\n")

    # Write to Firestore
    try:
        # Get the last signal from Firestore to avoid duplicates
        signals_ref = db.collection('signals')
        last_signal_query = signals_ref.order_by('timestamp', direction=firestore.Query.DESCENDING).limit(1).get()
        
        last_signal_type = None
        if len(last_signal_query) > 0:
            last_signal_type = last_signal_query[0].to_dict().get('type')
        
        # Only write if signal changed
        if signal != last_signal_type:
            signals_ref.add({
                'type': signal,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'source': 'github_actions',
                'price': float(current_price),
                'stochastics': float(current_stoch),
                'reason': reason
            })
            print(f"✅ Signal written to Firestore: {signal}")
        else:
            print(f"⏭️  Signal unchanged ({signal}), skipping write")
            
    except Exception as e:
        print(f"Error writing to Firestore: {e}")
        return {"signal": signal, "error": str(e)}

    return {
        "signal": signal,
        "price": float(current_price),
        "stochastics": float(current_stoch),
        "reason": reason
    }

if __name__ == "__main__":
    try:
        result = run_trading_strategy()
        print(f"\nFinal Result: {result}")
    except Exception as e:
        print(f"An error occurred: {e}")
