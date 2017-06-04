require 'nokogiri'
require 'open-uri'
require 'sqlite3'

class FalseClass; def to_i; 0; end; end;
class TrueClass; def to_i; 1; end; end;

class ScrapeException < Exception; end;

$db = SQLite3::Database.new "jeopardy.sqlite3"

def strip_answer_tags(answer)
  Nokogiri::HTML(answer).text.gsub('\\', '')
end

def scrape(game_id)
  begin
    doc = Nokogiri::HTML(open("games/game_#{game_id}.html"))

    error = doc.css('p.error')
    raise ScrapeException, "#{game_id}: #{error.text}" if (not error.empty?)

    title = doc.css('#game_title').text
    raise ScrapeException, "#{game_id}: No title" if (title.empty?)

    game_date = Date.parse(title)

    $db.execute('INSERT INTO GAME VALUES (?, ?)',
      game_id,
      game_date.to_time.to_i
    )

    rounds = doc.css('table.round') # 2, single and double
    raise ScrapeException, "#{game_id}: No rounds" if (rounds.empty?)

    value_multiplier = [1, 2] # single and double jeopardy
    rounds.each { |round| # single and double
      # calculate value
      values = [200, 400, 600, 800, 1000]
      multiplier = value_multiplier.shift

      # get all categories
      category_names = round.css('td.category_name').map { |td| td.text }
      category_ids = category_names.map { |category|
        $db.execute('INSERT INTO CATEGORY VALUES (null, ?, ?, ?)',
          game_id,
          category,
          multiplier # round (1 or 2)
        )
        $db.last_insert_row_id
      }
      categories = Hash[category_names.zip category_ids]

      # gather all questions
      clue_tds = round.css('td.clue')
      0.upto(clue_tds.length - 1) { |clue_idx|
        clue_td = clue_tds[clue_idx]

        answer_div = clue_td.css('div')
        next if (answer_div.empty?) # question never called

        # get the answer and the clue
        answer = strip_answer_tags(
          answer_div.first['onmouseover'].match('<em class="correct_response">(.+?)</em>').captures.first
        )
        clue = clue_td.css('td.clue_text').first.text

        # detect if this clue is a daily double
        daily_double = !clue_td.css('td.clue_value_daily_double').empty?

        # get our category id
        category_id = categories[category_names[clue_idx % 6]]

        $db.execute('INSERT INTO QUESTION VALUES (null, ?, ?, ?, ?, ?, ?, ?)',
          game_id,
          category_id,
          values[(clue_idx / 6).floor] * multiplier, # value of question
          multiplier, # round (1 or 2)
          daily_double.to_i, # is it a daily double?
          clue,
          answer
        )
      }
    }

    final_round_table = doc.css('table.final_round')
    unless (final_round_table.empty?)
      final_round_div = final_round_table.css('div')
      final_round_answer = strip_answer_tags(final_round_div.first['onmouseover'].match(
        '<em class=\\\"correct_response\\\">(.+?)</em>'
      ).captures.first)
      final_round_clue = final_round_table.css('td.clue_text').text

      $db.execute('INSERT INTO FINAL_JEOPARDY VALUES (?, ?, ?)',
        game_id,
        final_round_clue,
        final_round_answer
      )
    end
  rescue ScrapeException => exception
    puts exception.message
  end
end