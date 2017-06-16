require 'sqlite3'

raise "Usage: ruby print_pdf.rb <start_date> [<end_date>]" unless ARGV.length == 1 or ARGV.length == 2

db = SQLite3::Database.new "jeopardy.sqlite3"

start_date = DateTime.strptime(ARGV[0], "%m/%d/%Y") + (7/24.0)

if (ARGV.length == 2)
  end_date = DateTime.strptime(ARGV[1], "%m/%d/%Y") + (7/24.0)
  game_ids = db.execute("SELECT * FROM GAME WHERE
    DATE >= #{start_date.to_time.to_i} AND
    DATE <= #{end_date.to_time.to_i}").map { |game| game[0] }
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
normalPrinter.printGames('cards/games_round1.pdf', 'cards/games_round2.pdf')

require './classes/JeopardyFinalQuestionPrinter.rb'
finalPrinter = JeopardyFinalQuestionPrinter.new(db, game_ids)
finalPrinter.printFinalJeopardies('cards/games_final.pdf')