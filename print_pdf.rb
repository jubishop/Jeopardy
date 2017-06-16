require 'prawn'
require 'sqlite3'

Prawn::Font::AFM.hide_m17n_warning = true

module Prawn
  class Document
    def self.newWithFonts(options = {}, &block)
      new(options) {
        font_families.update(
          'Chalkboard' => { :bold => 'fonts/Chalkboard-Bold.ttf'},
          'Courgette' => { :normal => 'fonts/Courgette-Regular.ttf' },
          'Helvetica Inserat' => { :normal => 'fonts/Helvetica Inserat LT.ttf' },
          'ITC Korinna' => {
            :normal => 'fonts/Korinna Regular.ttf',
            :bold => 'fonts/Korinna Bold.ttf'
          })
        block.call(self) if block
      }
    end

    def self.generateWithFonts(filename, options = {}, &block)
      pdf = newWithFonts(options, &block)
      pdf.render_file(filename)
    end
  end
end

raise "Usage: ruby print_pdf.rb <start_date> [<end_date>]" unless ARGV.length == 1 or ARGV.length == 2

db = SQLite3::Database.new "jeopardy.sqlite3"

start_date = DateTime.strptime(ARGV[0], "%m/%d/%Y") + (7/24.0)

if (ARGV.length == 2)
  end_date = DateTime.strptime(ARGV[1], "%m/%d/%Y") + (7/24.0)
  game_ids = db.execute("SELECT * FROM GAME WHERE
    DATE >= #{start_date.to_time.to_i} AND
    DATE <= #{end_date.to_time.to_i}").map { |game| game[0] }
  puts "Printing #{game_ids.length} games"
else
  game = db.execute("SELECT * FROM GAME WHERE DATE = ?", start_date.to_time.to_i)
  game_ids = [game[0]]
end

# require './classes/JeopardyNormalQuestionPrinter.rb'
# normalPrinter = JeopardyNormalQuestionPrinter.new(db, game_ids)
# normalPrinter.printGames

require './classes/JeopardyFinalQuestionPrinter.rb'
finalPrinter = JeopardyFinalQuestionPrinter.new(db, game_ids)
finalPrinter.printFinalJeopardies