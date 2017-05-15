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


end
