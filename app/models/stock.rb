require 'csv'
require 'open-uri'

class Stock < ActiveRecord::Base

  def self.generate_snapshot
    puts "Creating new snapshot"
    @stocks = []
    import_finviz(@stocks)
    import_evebitda(@stocks)
    import_buyback_yield(@stocks)
    # compute_rank(data)
    return @stocks
  end

  def self.import_finviz(processed_stocks)
    puts "Importing data from finviz"
    # not using f=cap_smallover since it filters market caps over 300M instead of 200M
    # r = requests.get('http://finviz.com/export.ashx?v=152', cookies={"screenerUrl": "screener.ashx?v=152&f=cap_smallover&ft=4", "customTable": "0,1,2,6,7,10,11,13,14,45,65"})
    # r = requests.get('http://finviz.com/export.ashx?v=152', cookies={"screenerUrl": "screener.ashx?v=152&ft=4", "customTable": "0,1,2,6,7,10,11,13,14,45,65"})

    begin
      url = 'http://finviz.com/export.ashx?v=152&ft=4&c=0,1,2,3,4,5,6,7,10,11,13,14,45,65'
      response = HTTParty.get(url)
      response = CSV.parse(response)

      keys = response.delete_at(0).collect { |k| k.parameterize.underscore.to_sym }
      response = response.map {|a| Hash[ keys.zip(a) ] }

      response.each do |row|
        # Field labels
        # [:no, :ticker, :company, :sector, :industry, :country, :market_cap, :p_e, :price]
        puts row[:ticker]
        if row[:market_cap].to_f < 200
          puts "Market Cap too small: #{row[:market_cap]}"
        else
          processed_stocks << {
            ticker:                 row[:ticker],
            company:                row[:company],
            sector:                 row[:sector],
            industry:               row[:industry],
            country:                row[:country],
            market_cap:             row[:market_cap],
            p_e:                    row[:p_e].to_f,
            p_s:                    row[:p_s].to_f,
            p_b:                    row[:p_b].to_f,
            p_free_cash_flow:       row[:p_free_cash_flow].to_f,
            dividend_yield:         row[:dividend_yield].to_s.chop!.to_f,
            performance_half_year:  row[:performance_half_year].to_s.chop!.to_f,
            price:                  row[:price].to_f
          }
        end      
      end
      puts "Finviz data imported"
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
    end
  end

  def self.import_single_buyback_yield(stock)
    done = false
    while done == false
      begin
        puts stock[:ticker]
        return if stock[:market_cap].blank?
        query = "http://finance.yahoo.com/q/cf?s=#{stock[:ticker]}&ql=1"
        puts query
        response = HTTParty.get(query)
        html = Nokogiri::HTML(response)

        # Repair html
        table = html.css('table.yfnc_tabledata1')[0]
        return unless table

        table = html.css("table")[0]
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
          puts "BB: #{stock[:bb]}"
          done = true
        end
      rescue Exception => e
        puts e.message
        puts e.backtrace.inspect

        puts "Trying again in 1 sec"
        sleep 1
      end
    end
  end

  def self.import_buyback_yield(data)
    puts "Importing Buyback Yield"
    threads = []
    data.each do |stock|
      thread = Thread.new do 
        import_single_buyback_yield(stock)
      end
      threads << thread
    end
    threads.each { |t| t.join }
    puts "Completed Buyback Yield" 
  end

  # http://query.yahooapis.com/v1/public/yql?q=select%20symbol,%20EnterpriseValueEBITDA.content%20from%20yahoo.finance.keystats%20where%20symbol%20in%20(%22TSLA%22,%22MSFT%22,%22APPL%22,%22SCTY%22)&env=store://datatables.org/alltableswithkeys&format=json
  def self.import_evebitda(data)
    puts "Importing EV/EBITDA"
    
    batch_size = 100
    data.each_slice(batch_size) do |group|
      tickers = group.collect {|g| g[:ticker]}
      puts "Tickers: #{tickers.join(", ")}"

      tickers = tickers.map { |s| "'#{s}'" }.join(', ')
      query = "select symbol, EnterpriseValueEBITDA.content from yahoo.finance.keystats where symbol in (#{tickers})"
      env = "store://datatables.org/alltableswithkeys"
      format = "json"
      url = URI::encode("http://query.yahooapis.com/v1/public/yql?q=#{query}&env=#{env}&format=#{format}")
      response = HTTParty.get(url)
      stats = response["query"]["results"]["stats"]

      puts stats.count
      unless stats.blank?
        stats.each do |row|
          puts row["symbol"]
          if row["EnterpriseValueEBITDA"] != "N/A"
            puts "EVEBITDA: #{row["EnterpriseValueEBITDA"]}"
            stock = data.find {|stock| stock[:ticker] == row["symbol"] }
            stock[:evebitda] = row["EnterpriseValueEBITDA"].to_f
          end
        end
      else
        puts "No stats."
      end
    end
    puts "EV/EBITDA imported"
  end

  def compute_rank(data, step=0)
    compute_perank(data) if step == 0
    compute_psrank(data) if step <=1
    compute_pbrank(data) if step <=2
    compute_pfcfrank(data) if step <=3
    compute_bby(data) if step <=4
    compute_shy(data) if step <=5
    compute_shyrank(data) if step <=6
    compute_evebitdarank(data) if step <=7
    set_mediums(data) if step <=8
    compute_stockrank(data) if step <=9
    compute_overallrank(data) if step <=10
    puts "Rank Computed!"
  end

  # def compute_somerank(data, key, origkey=None, reverse=True, filterpositive=False):
  #   print "Computing " + key + " rank"
  #   if not origkey:
  #     origkey = key
  #     i = 0
  #     value = None
  #     stocks = sorted([stock for stock in data.values() if origkey in stock and (not filterpositive or stock[origkey] >= 0)], key=lambda k: k[origkey], reverse=reverse)
  #     amt = len(stocks)
  #     for stock in stocks:
  #         print stock["Ticker"]
  #         if stock[origkey] != value:
  #             last_rank = i
  #             value = stock[origkey]
  #         stock[key+"Rank"] = Decimal(last_rank)/amt*100
  #         print key+"Rank: " + str(stock[key+"Rank"])
  #         i +=1
  #       enmd
  #     print "Computed " + key + " Rank"
  # end

  # OLD
  # def compute_somerank(data, key, origkey=None, reverse=True, filterpositive=False):
  #     print "Computing " + key + " rank"
  #     if not origkey:
  #         origkey = key
  #     i = 0
  #     value = None
  #     stocks = sorted([stock for stock in data.values() if origkey in stock and (not filterpositive or stock[origkey] >= 0)], key=lambda k: k[origkey], reverse=reverse)
  #     amt = len(stocks)
  #     for stock in stocks:
  #         print stock["Ticker"]
  #         if stock[origkey] != value:
  #             last_rank = i
  #             value = stock[origkey]
  #         stock[key+"Rank"] = Decimal(last_rank)/amt*100
  #         print key+"Rank: " + str(stock[key+"Rank"])
  #         i +=1
  #     print "Computed " + key + " Rank"
end