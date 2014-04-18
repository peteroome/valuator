require 'csv'
require 'open-uri'

class Stock < ActiveRecord::Base

  def self.generate_snapshot_to_csv
    @stocks = []
    generate_snapshot(@stocks)
    to_csv(@stocks)
  end

  def self.generate_snapshot(data)
    puts "Creating new snapshot"
    import_finviz(data)
    import_evebitda(data)
    import_buyback_yield(data)
    compute_rank(data)
    puts data[0..10]
    return data
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

  def self.compute_rank(data, step = 0)
    compute_perank(data)
    # compute_psrank(data)
    # compute_pbrank(data)
    # compute_pfcfrank(data)
    # compute_bby(data)
    # compute_shy(data)
    # compute_shyrank(data)
    # compute_evebitdarank(data)
    # set_mediums(data)
    # compute_stockrank(data)
    # compute_overallrank(data)
    puts "Rank Computed!"
  end

  def self.compute_somerank(data, key, origkey = nil, reverse = true, filterpositive = false)
    puts "Computing #{key} rank"
    if origkey.nil?
      origkey = key
      i = 0
      value = nil
    
      puts "#{stock[origkey]}"
      puts "#{key} Blank: #{stock[origkey].blank?}"
      puts "filterpositive: #{filterpositive}"

      data = data.reject {|stock| stock[origkey].blank? && (filterpositive == false || stock[origkey] >= 0)}
      data = data.sort {|x,y| y[origkey] <=> x[origkey] }
      data.reverse if reverse == true

      amount = data.length
      puts "Amount: #{amount}"
      data.each do |stock|
        puts stock[:ticker]
        if stock[origkey] != value
          last_rank = i
          value = stock[origkey]
        end
        new_key = "#{key.to_s}_rank".parameterize.underscore.to_sym
        stock[new_key] = (last_rank.to_f/amount)*100
        puts "#{new_key}: #{stock[new_key]}"
        i +=1
      end
    end
    puts "Computed #{key} rank"
  end

  def self.compute_perank(data)
    compute_somerank(data, :pe)
  end

  def self.compute_psrank(data)
    compute_somerank(data, :ps)
  end

  def self.compute_pbrank(data)
    compute_somerank(data, :pb)
  end

  def self.compute_pfcfrank(data)
    compute_somerank(data, :pfcf, :p_free_cash_flow)
  end

  def self.compute_bby(data)
    puts "Computing BBY"
    data = data.reject {|stock| stock[:bb].blank? && stock[:market_cap].blank?}
    data.each do |stock|
      puts stock[:ticker]
      stock[:bby] = -stock[:bb].to_f/(stock[:market_cap].to_f*1000000)*100
      puts "BBY: #{stock[:bby]}"
    end
    puts "Done computing BBY"
  end

  def self.compute_shy(data)
    puts "Computing SHY"
    data.each do |stock|
      puts stock[:ticker]
      stock[:shy] = 0
      puts "DY: #{stock[:dividend_yield]}"
      puts "BBY: #{stock[:bby]}"

      unless stock[:dividend_yield].blank?
        stock[:shy] += stock[:dividend_yield].to_f
      end

      unless stock[:bby].blank?
        stock[:shy] += stock[:bby].to_f
      end

      puts "SHY: #{stock["SHY"]}"
    end
    puts "Done computing SHY"
  end

  def self.compute_shyrank(data)
    compute_somerank(data, :shy, reverse = false)
  end

  def self.compute_evebitdarank(data)
    compute_somerank(data, :evebitda, filterpositive = true)
  end

  def self.set_mediums(data)
    puts "Setting Mediums"
    data.each do |stock|
      [:pe, :ps, :pb, :pfcf, :evebitda].each do |key|
        key_rank = "#{key.to_s}_rank".parameterize.underscore.to_sym
        unless stock[key_rank].blank?
          stock[key_rank] = 50
        end

        if !stock[:evebitda].blank? && stock[:evebitda] < 0
          stock[:evebitda_rank] = 50
        end
      end
    end
    puts "Done setting Mediums"
  end

  def self.compute_stockrank(data)
    puts "Computing stock rank"
    data.each do |stock|
      puts stock[:ticker]
      ranks = [stock[:pe_rank], stock[:ps_rank], stock[:pbr_rank], stock[:pfcf_rank], stock[:shy_rank], stock[:evebitda_rank]].map(&:to_f)

      # Sum ranks
      stock[:rank] = ranks.inject(:+)
      puts "Rank: #{stock[:rank]}"
    end
  end

  def self.compute_overallrank(data)
    puts "Computing Overall rank"
    compute_somerank(data, :ovr, origkey = :rank, reverse = false)
  end

  def self.to_csv(data)
    column_names = data.first.keys
    file =  CSV.generate do |csv|
      csv << column_names
      data.each do |stock|
        csv << stock.values
      end
    end
    File.write('./csvs/stocks.csv', file)
  end
end