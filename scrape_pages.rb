require 'nokogiri'
require 'open-uri'

5650.upto(5682) { |game_id|
  File.open("games/game_#{game_id}.html", "w") { |file|
    file.print open("http://www.j-archive.com/showgame.php?game_id=#{game_id}").read
  }
}