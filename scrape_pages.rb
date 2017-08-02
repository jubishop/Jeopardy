require 'nokogiri'
require 'open-uri'

5680.upto(5731) { |game_id|
  File.open("games/game_#{game_id}.html", "w") { |file|
    file.print open("http://www.j-archive.com/showgame.php?game_id=#{game_id}").read
  }
}