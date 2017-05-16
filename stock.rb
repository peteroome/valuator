class Stock
  attr_reader :ticker,
              :data,
              :market_cap,
              :pe,
              :ps,
              :pb,
              :p_fcf,
              :dividend_yield,
              :perf_half,
              :price

  def initialize(ticker, data = {})
    @ticker = ticker.to_sym
    @data = data
  end

  # Returns the market cap
  #
  # @return [Integer]
  def market_cap
    @market_cap ||= case @data.market_cap[-1]
      when "B"
        then @data.market_cap.to_f * 1_000_000_000
      when "M"
        then @data.market_cap.to_f * 1_000_000
      else
        @data.market_cap.to_f
      end
  end

  # Returns the p/e
  #
  # @return [Integer]
  def pe
    @pe ||= @data.p_e.to_f
  end

  # Returns the p/s
  #
  # @return [Integer]
  def ps
    @ps ||= @data.p_s.to_f
  end

  # Returns the p/b
  #
  # @return [Integer]
  def pb
    @pb ||= @data.p_b.to_f
  end

  # Returns the p/fcf
  #
  # @return [Integer]
  def p_fcf
    @p_fcf ||= @data.p_fcf.to_f
  end

  # Returns the dividend_yield
  #
  # @return [Integer]
  def dividend_yield
    @dividend_yield ||= @data.dividend.to_s.gsub("%", "").to_f
  end

  # Returns the performance_half_year
  #
  # @return [Integer]
  def perf_half
    @perf_half ||= @data.perf_half.to_s.gsub("%", "").to_f
  end

  # Returns the price
  #
  # @return [Integer]
  def price
    @price ||= @data.price.to_f
  end

  # Returns the buyback yield
  #
  # @return [Integer]
  def buyback_yield
    @price ||= @data.price.to_f
  end

  # def single_buy_back_yield
  #   # Repair html
  #   table = html.css('table.yfnc_tabledata1')[0]
  #   return unless table
  #
  #   sale = 0
  #   rows = table.css("tr")
  #
  #   rows.each do |tr|
  #     title = tr.css("td")[0].text.squeeze.strip
  #     if title == "Sale Purchase of Stock"
  #       data = tr.css("td")
  #       data.each do |data|
  #         val = data.text.strip
  #         val = val.gsub("(", "-")
  #         val = val.gsub(",", "")
  #         val = val.gsub(")", "")
  #         val = val.gsub("&nbsp;", "")
  #         val = val.gsub("\n", "")
  #         val = val.gsub("\t", "")
  #         val = val.gsub("\\n", "")
  #         val = val.gsub(" ", "")
  #
  #         return if val == "-"
  #         sale += val.to_i*1000
  #       end
  #     end
  #
  #     stock[:bb] = -sale
  #     done = true
  #   end
  # end
  #
  # def process_evebitda
  #   query = "select symbol, EnterpriseValueEBITDA.content from yahoo.finance.keystats where symbol in (#{tickers})"
  #   env = "store://datatables.org/alltableswithkeys"
  #   url = URI::encode("http://query.yahooapis.com/v1/public/yql?q=#{query}&env=#{env}&format=json")
  #
  #   response = HTTParty.get(url)
  #   stats = response["query"]["results"]["stats"]
  #
  #   unless stats.blank?
  #     stats.each do |row|
  #       if row["EnterpriseValueEBITDA"] != "N/A"
  #         stock = data.find {|stock| stock[:ticker] == row["symbol"] }
  #         stock[:evebitda] = row["EnterpriseValueEBITDA"].to_f
  #       end
  #     end
  #   end
  # end
end
