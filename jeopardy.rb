require 'nokogiri'
require 'open-uri'

doc = Nokogiri::HTML(open('games/game_3.html'))

title = doc.css('#game_title').text

rounds = doc.css('table.round') # 2, single and double
value_multiplier = [1, 2] # single and double jeopardy

questions = Array.new
rounds.each { |round| # single and double
  # calculate value
  values = [200, 400, 600, 800, 1000]
  multiplier = value_multiplier.shift

  # get all categories
  categories = round.css('td.category_name').map { |td| td.text }

  # gather all questions
  clue_tds = round.css('td.clue')
  0.upto(clue_tds.length - 1) { |clue_idx|
    clue_td = clue_tds[clue_idx]

    answer_div = clue_td.css('div')
    next if (answer_div.empty?) # question never called

    # get the answer and the clue
    answer = answer_div.first['onmouseover'].match('<em class="correct_response">(.+?)</em>').captures.first
    clue = clue_td.css('td.clue_text').first.text

    # detect if this clue is a daily double
    daily_double = !clue_td.css('td.clue_value_daily_double').empty?

    questions.push({
      :category => categories[clue_idx % 6],
      :clue => clue,
      :answer => answer,
      :value => values[(clue_idx / 6).floor] * multiplier,
      :round => (multiplier == 1) ? 'single' : 'double',
      :daily_double => daily_double
    })
  }
}

final_round_table = doc.css('table.final_round')
final_round_div = final_round_table.css('div')
final_round_answer = final_round_div.first['onmouseover'].match(
  '<em class=\\\"correct_response\\\">(.+?)</em>'
).captures.first
final_round_clue = final_round_table.css('td.clue_text').text