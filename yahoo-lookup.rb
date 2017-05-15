class YahooLookup
  def initialize(symbol)
    @query = "http://finance.yahoo.com/q/cf?s=#{stock[:ticker]}&ql=1"
    response = HTTParty.get(query)
    html = Nokogiri::HTML(response)
  end

  def query
  end

  def single_buy_back_yield
    # Repair html
    table = html.css('table.yfnc_tabledata1')[0]
    return unless table

    sale = 0
    rows = table.css("tr")

    rows.each do |tr|
      title = tr.css("td")[0].text.squeeze.strip
      if title == "Sale Purchase of Stock"
        data = tr.css("td")
        data.each do |data|
          val = data.text.strip
          val = val.gsub("(", "-")
          val = val.gsub(",", "")
          val = val.gsub(")", "")
          val = val.gsub("&nbsp;", "")
          val = val.gsub("\n", "")
          val = val.gsub("\t", "")
          val = val.gsub("\\n", "")
          val = val.gsub(" ", "")

          return if val == "-"
          sale += val.to_i*1000
        end
      end

      stock[:bb] = -sale
      done = true
    end
  end

  def process_evebitda
    query = "select symbol, EnterpriseValueEBITDA.content from yahoo.finance.keystats where symbol in (#{tickers})"
    env = "store://datatables.org/alltableswithkeys"
    url = URI::encode("http://query.yahooapis.com/v1/public/yql?q=#{query}&env=#{env}&format=json")

    response = HTTParty.get(url)
    stats = response["query"]["results"]["stats"]

    unless stats.blank?
      stats.each do |row|
        if row["EnterpriseValueEBITDA"] != "N/A"
          stock = data.find {|stock| stock[:ticker] == row["symbol"] }
          stock[:evebitda] = row["EnterpriseValueEBITDA"].to_f
        end
      end
    end
  end
end
