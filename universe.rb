require 'csv'
require 'ostruct'

# My classes
require './stock'

class Universe
  attr_reader :stocks

  def initialize(input_csv)
    @input_csv = input_csv
    @stocks ||= read_input
  end

  def read_input
    stocks = []
    CSV.foreach(@input_csv, headers: true) do |row|
      row_hash = downcase_and_symbolize_keys(row.to_hash)
      stocks << OpenStruct.new(row_hash)
    end
    return stocks
  end

  # Returns the ticker data from the csv
  #
  # @return [Hash]
  def find(ticker)
    @stocks.find { |stock| stock.ticker.downcase. == ticker.to_s.downcase }
  end

  private

  def downcase_and_symbolize_keys(hash)
    Hash[hash.map { |k, v|
      [
        k.to_s.gsub(".", "").gsub(" ", "_").gsub("/", "_").downcase.to_sym,
        v
      ]
    }]
  end

  # def rank
  #   compute_somerank(data, :pe)
  #   compute_somerank(data, :ps)
  #   compute_somerank(data, :pb)
  #   compute_somerank(data, :pfcf, :p_free_cash_flow)
  #   compute_bby(data)
  #   compute_shy(data)
  #   compute_somerank(data, :shy, nil, false)
  #   compute_somerank(data, :evebitda, nil, true, true)
  #   set_mediums(data)
  #   compute_stockrank(data)
  #   compute_somerank(data, :ovr, :rank, false)
  # end
  #
  # def compute_somerank(data, key, origkey = nil, reverse = true, filterpositive = false)
  #   origkey = key if origkey.nil?
  #
  #   # reject nil values
  #   data = data.reject {|stock| stock[origkey].blank? and (filterpositive or stock[origkey] < 0)}
  #   data = data.sort_by! { |k| k[origkey] }
  #   data.reverse! if reverse == true
  #
  #   amount = data.length
  #   progress_bar = ProgressBar.create(title: "Computing #{key.upcase} Rank", starting_at: 0, total: data.count)
  #
  #   i = 0
  #   data.each do |stock|
  #     last_rank = i unless stock[origkey].blank?
  #     new_key = "#{key.to_s}_rank".parameterize.underscore.to_sym
  #     stock[new_key] = (last_rank.to_f / amount.to_f)*100
  #     i += 1
  #     progress_bar.increment
  #   end
  # end
  #
  # def compute_bby(data)
  #   progress_bar = ProgressBar.create(title: "Computing BBY", starting_at: 0, total: data.count)
  #
  #   data = data.reject {|stock| stock[:bb].blank?}
  #   data.each do |stock|
  #     stock[:bby] = -((stock[:bb].to_f/stock[:market_cap])*100)
  #     progress_bar.increment
  #   end
  # end
  #
  # def compute_shy(data)
  #   progress_bar = ProgressBar.create(title: "Computing SHY", starting_at: 0, total: data.count)
  #
  #   data.each do |stock|
  #     stock[:shy] = 0
  #
  #     unless stock[:dividend_yield].blank?
  #       stock[:shy] += stock[:dividend_yield].to_f
  #     end
  #
  #     unless stock[:bby].blank?
  #       stock[:shy] += stock[:bby].to_f
  #     end
  #
  #     progress_bar.increment
  #   end
  # end
  #
  # def set_mediums(data)
  #   progress_bar = ProgressBar.create(title: "Setting Mediums", starting_at: 0, total: data.count)
  #
  #   data.each do |stock|
  #     [:pe, :ps, :pb, :pfcf, :shy, :evebitda].each do |key|
  #       key_rank = "#{key.to_s}_rank".parameterize.underscore.to_sym
  #       if stock[key_rank].blank?
  #         stock[key_rank] = 50
  #       end
  #
  #       if !stock[:evebitda].blank? && stock[:evebitda] < 0
  #         stock[:evebitda_rank] = 50
  #       end
  #     end
  #
  #     progress_bar.increment
  #   end
  # end
  #
  # def compute_stockrank(data)
  #   progress_bar = ProgressBar.create(title: "Compute Stockrank", starting_at: 0, total: data.count)
  #
  #   data.each do |stock|
  #     ranks = [stock[:pe_rank], stock[:ps_rank], stock[:pb_rank], stock[:pfcf_rank], stock[:shy_rank], stock[:evebitda_rank]].map(&:to_f)
  #
  #     # Sum ranks
  #     stock[:rank] = ranks.inject(:+)
  #     progress_bar.increment
  #   end
  # end
  #
  # # Top Decile ordered by :ovr_rank
  # def top_decile
  # end
  #
  # # Ranked over 420
  # def highly_ranked
  # end
  #
  # def to_csv
  #   column_names = data.first.keys
  #   file =  CSV.generate do |csv|
  #     csv << column_names
  #     data.each do |stock|
  #       csv << stock.values
  #     end
  #   end
  #   File.write("output/#{folder_name}/stocks.csv", file)
  # end
  #
  # def to_html(folder_name, data, orderBy = :rank, filename_ext = nil)
  #   # HEADER
  #   headers = [:ticker, :company, :sector, :industry, :country, :market_cap, :p_free_cash_flow, :dividend_yield, :performance_half_year, :price, :bb, :bby, :shy, :pe, :pe_rank, :ps, :ps_rank, :pb, :pb_rank, :pfcf, :pfcf_rank, :shy, :shy_rank, :evebitda, :evebitda_rank, :rank, :ovr_rank]
  #   # headers = [:ticker, :company, :sector, :market_cap, :dividend_yield, :price, :performance_half_year, :rank, :ovr_rank]
  #
  #   # TABLE
  #   data = data.reject {|stock| stock[:ovr_rank].blank? }
  #   data = data.sort_by { |stock| !stock[:ovr_rank] }
  #
  #   tableOrder = headers.index(orderBy) + 3
  #
  #   xm = Builder::XmlMarkup.new(indent: 2)
  #   xm.head {
  #     xm.link(href: "http://cdn.datatables.net/1.10.2/css/jquery.dataTables.min.css", rel: "stylesheet", type: "text/css")
  #     xm.script(src: "http://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min.js", type: "text/javascript") {}
  #     xm.script(src: "http://cdn.datatables.net/1.10.2/js/jquery.dataTables.min.js", type: "text/javascript") {}
  #     xm.script("$(document).ready(function(){ $('#stock_table').dataTable({'paging': false, 'order': [[ #{tableOrder}, 'desc' ]]}); });")
  #   }
  #   xm.body {
  #     xm.table(:class => 'display compact', :id => 'stock_table', :cellspacing => "0", :width => "100%") {
  #       xm.thead {
  #         xm.tr {
  #           xm.th("#")
  #           xm.th("G")
  #           xm.th("Y")
  #           headers.each { |key|
  #             xm.th(key.to_s.upcase)
  #           }
  #         }
  #       }
  #       xm.tbody {
  #         data.each_with_index { |row, index|
  #           xm.tr {
  #             xm.td {
  #               xm.text(index)
  #             }
  #             xm.td {
  #               xm.a(href: "https://www.google.com/finance?q=#{row[:ticker]}", target: "_blank") { xm.text("G") }
  #             }
  #             xm.td {
  #               xm.a(href: "http://finance.yahoo.com/q?d=t&s=#{row[:ticker]}", target: "_blank") { xm.text("Y") }
  #             }
  #             headers.each { |key|
  #               xm.td(row[key].present? ? row[key] : " ")
  #             }
  #           }
  #         }
  #       }
  #     }
  #   }
  #
  #   # Write file
  #   filename = "output/#{folder_name}/stocks"
  #   filename += "-#{filename_ext}" unless filename_ext.nil?
  #   File.write("#{filename}.html", xm)
  # end
end
