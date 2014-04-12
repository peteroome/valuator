# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140411165900) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "stocks", force: true do |t|
    t.float    "ticker"
    t.float    "company"
    t.float    "marketcap"
    t.float    "pe"
    t.float    "ps"
    t.float    "pb"
    t.float    "pfreecashflow"
    t.float    "dividendyield"
    t.float    "performancehalfyear"
    t.float    "price"
    t.float    "bb"
    t.float    "evebitda"
    t.float    "bby"
    t.float    "shy"
    t.float    "perank"
    t.float    "psrank"
    t.float    "pbrank"
    t.float    "pfcfrank"
    t.float    "shyrank"
    t.float    "evebitdarank"
    t.float    "rank"
    t.float    "ovrran"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
