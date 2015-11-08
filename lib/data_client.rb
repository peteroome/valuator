require "httparty"

class DataClient
  def intialize
    @url = "http://finviz.com/export.ashx?v=152&ft=4&c=0,1,2,3,4,5,6,7,10,11,13,14,45,65"
  end

  # not using f=cap_smallover since it filters market caps over 300M instead of 200M
  # r = requests.get('http://finviz.com/export.ashx?v=152', cookies={"screenerUrl": "screener.ashx?v=152&f=cap_smallover&ft=4", "customTable": "0,1,2,6,7,10,11,13,14,45,65"})
  # r = requests.get('http://finviz.com/export.ashx?v=152', cookies={"screenerUrl": "screener.ashx?v=152&ft=4", "customTable": "0,1,2,6,7,10,11,13,14,45,65"})
  def query
    response = HTTParty.get(@url)

    if response.code == 200
      CSV.parse(response)
    else
      raise "DataClient.new.query: #{response.code} #{response.body}"
    end
  end
end