require 'csv'

class Stock < ActiveRecord::Base

  def generate_snapshot(data)
    print "Creating new snapshot"
    import_finviz(data)
    # import_evebitda(data)
    # import_buyback_yield(data, True)
    # compute_rank(data)
    return data
  end

  def import_finviz(processed_data):
    print "Importing data from finviz"
    # not using f=cap_smallover since it filters market caps over 300M instead of 200M
    # r = requests.get('http://finviz.com/export.ashx?v=152', cookies={"screenerUrl": "screener.ashx?v=152&f=cap_smallover&ft=4", "customTable": "0,1,2,6,7,10,11,13,14,45,65"})
    # r = requests.get('http://finviz.com/export.ashx?v=152', cookies={"screenerUrl": "screener.ashx?v=152&ft=4", "customTable": "0,1,2,6,7,10,11,13,14,45,65"})
    url = 'http://finviz.com/export.ashx?v=152'
    response = HTTParty.get(url)
    response = CSV.parse(response)

    keys = response.first
    response = response.map {|a| Hash[ keys.zip(a) ] }

    tickers = []
    response.each do |row|
      # Field labels
      # ["No.", "Ticker", "Company", "Sector", "Industry", "Country", "Market Cap", "P/E", "Price", "Change", "Volume"]
      unless row = response.first
        tickers << {
          ticker: row["Ticker"]
          company:
          sector:
          industry:
          country:
          market_cap:
          pe:
          ps:
          pb:
          pfreecashflow:
          dividendyield:
          performancehalfyear:
          price:
        }
      end
    end

    # OLD
    
    data = csv_to_dicts(r.text)
    tickers = []
    for row in data:
      try:
        stock = {}
        if row["Ticker"]:
            stock["Ticker"] = row["Ticker"]
        print stock["Ticker"]
        if "Importing " + row["Company"]:
            stock["Company"] = row["Company"]
        # Ignore companies with market cap below 200M
        if not "Market Cap" in row or row["Market Cap"] == "":
            continue
        market_cap = Decimal(row["Market Cap"])
        if market_cap < 200:
            print "Market Cap too small: "+ row["Market Cap"]
            continue
        stock["MarketCap"] = row["Market Cap"]
        if row["P/E"]:
            stock["PE"] = row["P/E"]
        if row["P/S"]:
            stock["PS"] = row["P/S"]
        if row["P/B"]:
            stock["PB"] = row["P/B"]
        if row["P/Free Cash Flow"]:
            stock["PFreeCashFlow"] = row["P/Free Cash Flow"]
        if row["Dividend Yield"]:
            stock["DividendYield"] = row["Dividend Yield"][:-1]
        if row["Performance (Half Year)"]:
            stock["PerformanceHalfYear"] = row["Performance (Half Year)"][:-1]
        if row["Price"]:
            stock["Price"] = row["Price"]
        processed_data[stock["Ticker"]] = stock
    except Exception as e:
      print e
      #pdb.set_trace()
    print "Finviz data imported"
  end

end