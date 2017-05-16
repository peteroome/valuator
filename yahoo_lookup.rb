require 'httparty'
require 'nokogiri'

class YahooLookup
  attr_reader :ticker, :query, :response

  def initialize(ticker)
    @ticker ||= ticker
    @query ||= "http://finance.yahoo.com/q/cf?s=#{@ticker}&ql=1"
  end

  def response
    @response ||= HTTParty.get(@query)
  end

  def html_response
    Nokogiri::HTML(@response)
  end
end
