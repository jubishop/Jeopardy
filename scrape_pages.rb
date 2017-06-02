require 'nokogiri'
require 'open-uri'

1.upto(5654) { |game_id|
  File.open("games/game_#{game_id}.html", "w") { |file|
    file.print open("http://www.j-archive.com/showgame.php?game_id=#{game_id}").read
  }
  sleep 6
}