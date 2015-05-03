# Notes
# List of all US companies:
# http://www.nasdaq.com/screening/companies-by-name.aspx?letter=0&exchange=nasdaq&render=download
# exchange param can be: nasdaq, nyse etc
#
# Stockmapper
# http://prototypes.stockmapper.com/NYXtrac.html
#
# Yahoo Finance Info
# http://www.jarloo.com/yahoo_finance/
#
# Tradier
# https://developer.tradier.com/documentation/markets/fundamentals/get-ratios
#
# Quandl - Historical data
# https://www.quandl.com/data/WIKI?keyword=&page=1
#
# Quantopian - Algo-trading
# https://www.quantopian.com/algorithms

require 'rubygems'
require 'active_support'
# require 'active_support/inflector'
require 'active_support/core_ext'
require 'httparty'
require 'nokogiri'
require 'csv'
require 'open-uri'
require 'fileutils'
require 'ruby-progressbar'
require 'thread/pool'
require 'builder'

def generate_snapshot(data)
  import_finviz(data)
  import_evebitda(data, true)
  import_buyback_yield(data, true)
  compute_rank(data)
  return data
end

def import_finviz(processed_stocks)
  # Original request:
  # http://finviz.com/export.ashx?v=152&ft=4&c=0,1,2,3,4,5,6,7,10,11,13,14,45,65
  #
  # The URL is not using `f=cap_smallover` 
  # since it filters market caps over 300M instead of 200M.
  # Need to double check data for market cap size > 200M.
  #
  # Data feed:
  # https://www.kimonolabs.com/api/57h4b1oq?apikey=0c8d49caa3f0d6c3b3c35d9d0d872cc7

  # Paginate through results
  #
  response = get_finviz_stocks

  # Convert market caps to real numbers
  response.map { |s| 
    if s["market_cap"][-1] == "B"
      s["market_cap"] = s["market_cap"].to_f * 1_000_000_000
    elsif s["market_cap"][-1] == "M"
      s["market_cap"] = s["market_cap"].to_f * 1_000_000
    else
      s["market_cap"] = s["market_cap"].to_f
    end
  }

  # Only those over 200M Market Cap
  response = response.delete_if { |s| s["market_cap"] < 200_000_000 }

  response.each do |row|
    # Field labels
    # [:no, :ticker, :company, :sector, :industry, :country, :market_cap, :p_e, :price]
    processed_stocks << {
      ticker:                row["symbol"]["text"],
      company:               row["company"],
      sector:                row["sector"],
      industry:              row["industry"],
      country:               row["country"],
      market_cap:            row["market_cap"],
      pe:                    row["p/e"].to_f,
      ps:                    row["p/s"].to_f,
      pb:                    row["p/b"].to_f,
      p_free_cash_flow:      row["p/fcf"].to_f,
      dividend_yield:        row["dividend"].to_s.gsub("%", "").to_f,
      performance_half_year: row["perf_half"].to_s.gsub("%", "").to_f,
      price:                 row["price"].to_f
    }
  end
  puts "Finviz data imported (#{processed_stocks.count} stocks)"
end

def get_finviz_stocks(current_page = 0, results = [])
  url = "https://kimonolabs.com/api/57h4b1oq?apikey=0c8d49caa3f0d6c3b3c35d9d0d872cc7&kimoffset=#{current_page}"
  puts "URL: #{url}"
  response = HTTParty.get(url)
  response = JSON.parse(response.body)
  puts "COUNT: #{response["count"]}"
  if response["count"] > 0
    response["results"]["collection1"].each do |stock|
      results << stock
    end
    get_finviz_stocks(current_page + 2500, results)
  end  
  return results
end

def import_single_buyback_yield(stock)
  done = false
  while done == false
    query = "http://finance.yahoo.com/q/cf?s=#{stock[:ticker]}&ql=1"
    response = HTTParty.get(query)
    html = Nokogiri::HTML(response)

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
end

def import_buyback_yield(data, threaded = true)
  puts "\n"
  progress_bar = ProgressBar.create(title: "Importing Buyback Yield", starting_at: 0, total: data.count)

  if threaded
    pool = Thread.pool(30)
    data.each do |stock|
      pool.process {
        progress_bar.increment
        import_single_buyback_yield(stock)
      }
    end
    pool.shutdown
  else
    data.each do |stock|
      progress_bar.increment
      import_single_buyback_yield(stock)
    end
  end
end

def process_evebitda_batch(data, batch)
  tickers = batch.collect {|g| g[:ticker]}
  tickers = tickers.map { |s| "'#{s}'" }.join(', ')

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

# http://query.yahooapis.com/v1/public/yql?q=select%20symbol,%20EnterpriseValueEBITDA.content%20from%20yahoo.finance.keystats%20where%20symbol%20in%20(%22TSLA%22,%22MSFT%22,%22APPL%22,%22SCTY%22)&env=store://datatables.org/alltableswithkeys&format=json
def import_evebitda(data, threaded = true, batch_size = 100)
  progress_bar = ProgressBar.create(title: "Importing EV/EBITDA Data", starting_at: 0, total: data.count)

  pool = Thread.pool(10) if threaded

  data.each_slice(batch_size) do |batch|
    if threaded
      pool.process {
        progress_bar.progress += batch_size
        process_evebitda_batch(data, batch)
      }
    else
      process_evebitda_batch(data, batch)
      progress_bar.progress += batch_size
    end
  end

  pool.shutdown if threaded
end

def compute_rank(data, step = 0)
  compute_somerank(data, :pe)
  compute_somerank(data, :ps)
  compute_somerank(data, :pb)
  compute_somerank(data, :pfcf, :p_free_cash_flow)
  compute_bby(data)
  compute_shy(data)
  compute_somerank(data, :shy, nil, false)
  compute_somerank(data, :evebitda, nil, true, true)
  set_mediums(data)
  compute_stockrank(data)
  compute_somerank(data, :ovr, :rank, false)
end

# `reverse = true` means that low values get a high rank
def compute_somerank(data, key, origkey = nil, reverse = true, filterpositive = false)
  origkey = key if origkey.nil?

  # reject nil values
  data = data.reject {|stock| stock[origkey].blank? and (filterpositive or stock[origkey] < 0)}
  data = data.sort_by! { |k| k[origkey] }
  data.reverse! if reverse == true

  amount = data.length
  progress_bar = ProgressBar.create(title: "Computing #{key.upcase} Rank", starting_at: 0, total: data.count)

  i = 0
  data.each do |stock|
    last_rank = i unless stock[origkey].blank?
    new_key = "#{key.to_s}_rank".parameterize.underscore.to_sym
    stock[new_key] = (last_rank.to_f / amount.to_f)*100
    i += 1
    progress_bar.increment
  end
end

def compute_bby(data)
  progress_bar = ProgressBar.create(title: "Computing BBY", starting_at: 0, total: data.count)

  data = data.reject {|stock| stock[:bb].blank?}
  data.each do |stock|
    stock[:bby] = -((stock[:bb].to_f/stock[:market_cap])*100)
    progress_bar.increment
  end
end

def compute_shy(data)
  progress_bar = ProgressBar.create(title: "Computing SHY", starting_at: 0, total: data.count)

  data.each do |stock|
    stock[:shy] = 0

    unless stock[:dividend_yield].blank?
      stock[:shy] += stock[:dividend_yield].to_f
    end

    unless stock[:bby].blank?
      stock[:shy] += stock[:bby].to_f
    end

    progress_bar.increment
  end
end

def set_mediums(data)
  progress_bar = ProgressBar.create(title: "Setting Mediums", starting_at: 0, total: data.count)

  data.each do |stock|
    [:pe, :ps, :pb, :pfcf, :shy, :evebitda].each do |key|
      key_rank = "#{key.to_s}_rank".parameterize.underscore.to_sym
      if stock[key_rank].blank?
        stock[key_rank] = 50
      end

      if !stock[:evebitda].blank? && stock[:evebitda] < 0
        stock[:evebitda_rank] = 50
      end
    end

    progress_bar.increment
  end
end

def compute_stockrank(data)
  progress_bar = ProgressBar.create(title: "Compute Stockrank", starting_at: 0, total: data.count)

  data.each do |stock|
    ranks = [stock[:pe_rank], stock[:ps_rank], stock[:pb_rank], stock[:pfcf_rank], stock[:shy_rank], stock[:evebitda_rank]].map(&:to_f)

    # Sum ranks
    stock[:rank] = ranks.inject(:+)
    progress_bar.increment
  end
end

def create_output_directory
  date_str = Time.now.strftime('%m_%d_%Y')
  FileUtils.mkdir_p("output/#{date_str}")

  return date_str
end

def to_csv(folder_name, data)
  column_names = data.first.keys
  file =  CSV.generate do |csv|
    csv << column_names
    data.each do |stock|
      csv << stock.values
    end
  end
  File.write("output/#{folder_name}/stocks.csv", file)
end

def to_html(folder_name, data, orderBy = :rank, filename_ext = nil)
  # HEADER
  headers = [:ticker, :company, :sector, :industry, :country, :market_cap, :p_free_cash_flow, :dividend_yield, :performance_half_year, :price, :bb, :bby, :shy, :pe, :pe_rank, :ps, :ps_rank, :pb, :pb_rank, :pfcf, :pfcf_rank, :shy, :shy_rank, :evebitda, :evebitda_rank, :rank, :ovr_rank]
  # headers = [:ticker, :company, :sector, :market_cap, :dividend_yield, :price, :performance_half_year, :rank, :ovr_rank]

  # TABLE
  data = data.reject {|stock| stock[:ovr_rank].blank? }
  data = data.sort_by { |stock| !stock[:ovr_rank] }

  tableOrder = headers.index(orderBy) + 3

  xm = Builder::XmlMarkup.new(indent: 2)
  xm.head {
    xm.link(href: "http://cdn.datatables.net/1.10.2/css/jquery.dataTables.min.css", rel: "stylesheet", type: "text/css")
    xm.script(src: "http://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min.js", type: "text/javascript") {}
    xm.script(src: "http://cdn.datatables.net/1.10.2/js/jquery.dataTables.min.js", type: "text/javascript") {}
    xm.script("$(document).ready(function(){ $('#stock_table').dataTable({'paging': false, 'order': [[ #{tableOrder}, 'desc' ]]}); });")
  }
  xm.body {
    xm.table(:class => 'display compact', :id => 'stock_table', :cellspacing => "0", :width => "100%") {
      xm.thead {
        xm.tr {
          xm.th("#")
          xm.th("G")
          xm.th("Y")
          headers.each { |key|
            xm.th(key.to_s.upcase)
          }
        }
      }
      xm.tbody {
        data.each_with_index { |row, index|
          xm.tr {
            xm.td {
              xm.text(index)
            }
            xm.td {
              xm.a(href: "https://www.google.com/finance?q=#{row[:ticker]}", target: "_blank") { xm.text("G") }
            }
            xm.td {
              xm.a(href: "http://finance.yahoo.com/q?d=t&s=#{row[:ticker]}", target: "_blank") { xm.text("Y") }
            }
            headers.each { |key|
              xm.td(row[key].present? ? row[key] : " ")
            }
          }
        }
      }
    }
  }

  # Write file
  filename = "output/#{folder_name}/stocks"
  filename += "-#{filename_ext}" unless filename_ext.nil?
  File.write("#{filename}.html", xm)
end

# Do the script!
@stocks = []
generate_snapshot(@stocks)

new_folder = create_output_directory

to_csv(new_folder, @stocks)
to_html(new_folder, @stocks)

# Picks
#
# Top Decile ordered by :ovr_rank
@stocks = @stocks.sort_by { |stock| !stock[:ovr_rank] }[0, (@stocks.length*0.1).ceil]
to_html(new_folder, @stocks, :ovr_rank, "decile")

# Reject if less than 420
@stocks = @stocks.reject {|stock| stock[:rank] < 400}

# Top 25 ordered by :performance_half_year
@stocks = @stocks.sort_by { |stock| !stock[:performance_half_year] }[0, 25]
to_html(new_folder, @stocks, :performance_half_year, "picks")