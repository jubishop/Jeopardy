require 'sqlite3'

raise "Usage: ruby print_pdf.rb <start_date> [<end_date>]" unless ARGV.length == 1 or ARGV.length == 2

db = SQLite3::Database.new "jeopardy.sqlite3"

# TODO: Get all dates on UTC
start_date = Date.strptime(ARGV[0], "%m/%d/%Y")

if (ARGV.length == 2)
  end_date = Date.strptime(ARGV[1], "%m/%d/%Y")
  game_ids = db.execute("SELECT * FROM GAME WHERE
    DATE >= #{start_date.to_time.utc.to_i} AND
    DATE <= #{end_date.to_time.utc.to_i}").map { |game| game[0] }
else
  game = db.execute("SELECT * FROM GAME WHERE DATE = ?", start_date.to_time.to_i)
  if (game.empty?)
    puts "No game of Jeopardy was played on #{ARGV[0]}"
    exit
  end
  game_ids = [game[0]]
end

puts "Printing #{game_ids.length} games"

require './classes/JeopardyNormalQuestionPrinter.rb'
normalPrinter = JeopardyNormalQuestionPrinter.new(db, game_ids)
normalPrinter.printGames('cards/round1.pdf', 'cards/round2.pdf')

require './classes/JeopardyFinalQuestionPrinter.rb'
finalPrinter = JeopardyFinalQuestionPrinter.new(db, game_ids)
finalPrinter.printFinalJeopardies('cards/final.pdf')