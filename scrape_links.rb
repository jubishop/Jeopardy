require 'nokogiri'
require 'open-uri'

# def scrape_gameLinks(season, file)
#   doc = Nokogiri::HTML(open("http://j-archive.com/showseason.php?season=#{season}"))
#   links = doc.css('table').css('tr').css('td').css('a').map { |link| link['href'] }
#   links.delete_if { |link| not link.include? 'game_id=' }
#   file.puts links.join("\n")
# end
#
# linksFile = File.open("gamelinks.txt", "w")
# 1.upto(33) { |season| scrape_gameLinks(season, linksFile) }
# linksFile.close