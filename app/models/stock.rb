require 'csv'

class Stock < ActiveRecord::Base

  def self.generate_snapshot
    puts "Creating new snapshot"
    @stocks = []
    import_finviz(@stocks)
    # import_evebitda(data)
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
    threads= []
    data.each do |stock|
      thread = Thread.new do 
        import_single_buyback_yield(stock)
      end
      threads << thread
    end
    threads.each { |t| t.join }
    puts "Completed Buyback Yield" 
  end


  # OLD
  # def import_buyback_yield(data, parallel=False):
  #     print "Importing Buyback Yield"
  #     if parallel:
  #         pool = multiprocessing.Pool(4)
  #         pool.map(import_single_buyback_yield, data.values())
  #     else:
  #         for stock in data:
  #             stock = data[stock]
  #             import_single_buyback_yield(stock)
  #     print "Completed Buyback Yield" 

  # def import_single_buyback_yield(stock):
  #     done = False
  #     while not done:
  #         try:
  #             print stock["Ticker"]
  #             if not stock["MarketCap"]: break
  #             query = "http://finance.yahoo.com/q/cf?s="+stock["Ticker"]+"&ql=1"
  #             print query
  #             r = requests.get(query, timeout=5)
  #             html = r.text
  #             # Repair html
  #             html = html.replace('<div id="yucs-contextual_shortcuts"data-property="finance"data-languagetag="en-us"data-status="active"data-spaceid=""data-cobrand="standard">', '<div id="yucs-contextual_shortcuts" data-property="finance" data-languagetag="en-us" data-status="active" data-spaceid="" data-cobrand="standard">')
  #             html = re.sub(r'(?<!\=)"">', '">', html)
  #             soup = BeautifulSoup(html)
  #             #with open("html.html", "w") as f:
  #             #    f.write(html)
  #             #with open("file.html", "w") as f:
  #             #    f.write(soup.prettify())
  #             table = soup.find("table", {"class": "yfnc_tabledata1"})
  #             if not table: break
  #             table = table.find("table")
  #             if not table: break
  #             sale = 0
  #             for tr in table.findAll("tr"):
  #                 title = tr.td.renderContents().strip()
  #                 if title == "Sale Purchase of Stock":
  #                     for td in tr.findAll("td")[1:]:
  #                         val = td.renderContents().strip()
  #                         val = val.replace("(", "-")
  #                         val = val.replace(",", "")
  #                         val = val.replace(")", "")
  #                         val = val.replace("&nbsp;", "")
  #                         val = val.replace("\n", "")
  #                         val = val.replace("\t", "")
  #                         val = val.replace("\\n", "")
  #                         val = val.replace(" ", "")
  #                         if val == "-": continue
  #                         sale += int(val)*1000
  #             stock["BB"] = -sale
  #             print "BB: "+str(stock["BB"])
  #             done = True
  #             #print "done!"
  #         except Exception as e:
  #             print e
  #             print "Trying again in 1 sec"
  #             time.sleep(1)

  # def import_evebitda(data)
  #   puts "Importing EV/EBITDA"
  #   y = yql.Public()
  #   step=100
  #   tickers = data.keys
  #   tickers.each do |ticker|

  #   for i in range(0,len(tickers),step):
  #       print "From " + tickers[i] + " to " + tickers[min(i+step,len(tickers))-1]
  #       nquery = 'select symbol, EnterpriseValueEBITDA.content from yahoo.finance.keystats where symbol in ({0})'.format('"'+('","'.join(tickers[i:i+step-1])+'"'))
  #       ebitdas = y.execute(nquery, env="http://www.datatables.org/alltables.env")
  #       if ebitdas.results:
  #           for row in ebitdas.results["stats"]:
  #               print row["symbol"]
  #               if "EnterpriseValueEBITDA" in row and row["EnterpriseValueEBITDA"] and row["EnterpriseValueEBITDA"] != "N/A":
  #                   print "EVEBITDA: " + row["EnterpriseValueEBITDA"]
  #                   data[row["symbol"]]["EVEBITDA"] = row["EnterpriseValueEBITDA"]
  #       else:
  #           pass
  #           print "No results"
  #   print "EV/EBITDA imported"
  # end

  # OLD
  # def import_evebitda(data):
  #   print "Importing EV/EBITDA"
  #   y = yql.Public()
  #   step=100
  #   tickers = data.keys()
  #   for i in range(0,len(tickers),step):
  #       print "From " + tickers[i] + " to " + tickers[min(i+step,len(tickers))-1]
  #       nquery = 'select symbol, EnterpriseValueEBITDA.content from yahoo.finance.keystats where symbol in ({0})'.format('"'+('","'.join(tickers[i:i+step-1])+'"'))
  #       ebitdas = y.execute(nquery, env="http://www.datatables.org/alltables.env")
  #       if ebitdas.results:
  #           for row in ebitdas.results["stats"]:
  #               print row["symbol"]
  #               if "EnterpriseValueEBITDA" in row and row["EnterpriseValueEBITDA"] and row["EnterpriseValueEBITDA"] != "N/A":
  #                   print "EVEBITDA: " + row["EnterpriseValueEBITDA"]
  #                   data[row["symbol"]]["EVEBITDA"] = row["EnterpriseValueEBITDA"]
  #       else:
  #           pass
  #           print "No results"
  #   print "EV/EBITDA imported"
end