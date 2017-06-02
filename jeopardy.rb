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

# TODO: Need to scrape daily doubles

doc = Nokogiri::HTML(open('page.txt'))

title = doc.css('#game_title').text

rounds = doc.css('table.round') # 2, single and double
value_multiplier = [1, 2] # single and double jeopardy

rounds.each { |round| # single and double
  # calculate value
  values = [200, 400, 600, 800, 1000] 
  multiplier = value_multiplier.shift

  # get all categories
  categories = round.css('td.category_name').map { |td| td.text }
  
  # gather all questions
  clue_tds = round.css('td.clue')
  questions = Array.new
  0.upto(clue_tds.length - 1) { |clue_idx|
    clue_td = clue_tds[clue_idx]
    answer = clue_td.css('div').first['onmouseover'].match('<em class="correct_response">(.+?)</em>').captures.first
    clue = clue_td.css('td.clue_text').first.text
    questions.push({
      :category => categories[clue_idx % 6],
      :clue => clue,
      :answer => answer,
      :value => values[(clue_idx / 6).floor] * multiplier,
      :round => (multiplier == 1) ? "single" : "double"
    })
  }
}

final_round_table = doc.css('table.final_round')
final_round_div = final_round_table.css('div')
puts final_round_div.first['onmouseover']# .match('<em class="correct_response">')