require 'csv'

class Stock < ActiveRecord::Base

  def self.generate_snapshot
    print "Creating new snapshot"
    @stocks = []
    import_finviz(@stocks)
    # import_evebitda(data)
    # import_buyback_yield(data, True)
    # compute_rank(data)
    return @stocks
  end

  def self.import_finviz(processed_stocks)
    print "Importing data from finviz"
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
end