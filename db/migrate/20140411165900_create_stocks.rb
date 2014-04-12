class CreateStocks < ActiveRecord::Migration
  def change
    create_table :stocks do |t|
      t.string :ticker
      t.string :company
      t.float :marketcap
      t.float :pe
      t.float :ps
      t.float :pb
      t.float :pfreecashflow
      t.float :dividendyield
      t.float :performancehalfyear
      t.float :price
      t.float :bb
      t.float :evebitda
      t.float :bby
      t.float :shy
      t.float :perank
      t.float :psrank
      t.float :pbrank
      t.float :pfcfrank
      t.float :shyrank
      t.float :evebitdarank
      t.float :rank
      t.float :ovrran
      
      t.timestamps
    end
  end
end
