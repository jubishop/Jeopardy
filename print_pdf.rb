require 'prawn'
require 'sqlite3'

Prawn::Font::AFM.hide_m17n_warning = true

class Numeric; def to_bool; self != 0; end; end;

$db = SQLite3::Database.new "jeopardy.sqlite3"

def print_game(game_id)
  null, game_utc = *$db.execute('SELECT * FROM GAME WHERE ID = ?', game_id).first
  game_date = Time.at(game_utc).to_datetime

  questions_round1 = Hash.new { |hash, key| hash[key] = Array.new }
  questions_round2 = Hash.new { |hash, key| hash[key] = Array.new }
  category_ids = Hash.new
  questions = $db.execute('SELECT * FROM QUESTION WHERE GAME_ID = ?', game_id)
  questions.each { |id, game_id, category_id, value, round, daily_double, clue, answer|
    category_ids[category_id] = true
    (round == 1 ? questions_round1 : questions_round2)[category_id].push({
      :clue => clue,
      :answer => answer,
      :daily_double => daily_double.to_bool,
      :round => round,
      :value => value
    })
  }

  categories = $db.execute("SELECT * FROM CATEGORY WHERE ID IN (#{category_ids.keys.join(', ')})")
  categories_by_id = categories.map { |id, game_id, category, round|
    [id, {:name => category, :round => round}]
  }.to_h

  rnd1 = Prawn::Document.new
  rnd2 = Prawn::Document.new

  [rnd1, rnd2].each { |rnd|
    rnd.font_families.update(
      'Chalkboard' => { :bold => 'fonts/Chalkboard-Bold.ttf'},
      'Courgette' => { :normal => 'fonts/Courgette-Regular.ttf' },
      'Helvetica Inserat' => { :normal => 'fonts/Helvetica Inserat LT.ttf' },
      'ITC Korinna' => {
        :normal => 'fonts/Korinna Regular.ttf',
        :bold => 'fonts/Korinna Bold.ttf'
      }
    )
  }

  [[questions_round1, rnd1], [questions_round2, rnd2]].each { |questions_by_category, rnd|
    box_count = 0
    questions_by_category.each { |id, questions|
      next if (questions.length < 5)

      box_count += 1
      rnd.start_new_page if box_count > 1 and box_count.odd?

      box_base_y = box_count.odd? ? 720 : 340
      rnd.bounding_box([20, box_base_y], :width => 500, :height => 340) do
        rnd.stroke_bounds
        rnd.bounding_box([65, 330], :width => 420, :height => 325) do
          rnd.fill_color '000000'
          questions.each { |question|
            rnd.pad(15) {
              rnd.stroke_ellipse [-32, rnd.cursor - 13], 20, 10
              rnd.font 'Helvetica Inserat', :size => 10
              rnd.text_box question[:value].to_s,
                :at => [-42, rnd.cursor - 9],
                :align => :center,
                :width => 20

              rnd.font 'ITC Korinna', :style => :bold, :size => 9
              rnd.text question[:clue].upcase

              rnd.font 'Chalkboard', :style => :bold, :size => 10
              rnd.text_box question[:answer].upcase, :at => [20, rnd.cursor - 1]
            }
          }
          rnd.font 'Courgette', :size => 10
          rnd.fill_color '666666'
          rnd.text_box game_date.strftime('%B %-d, %Y'),
            :at => [20, 25],
            :width => 400,
            :align => :right
        end
      end
    }
  }

  rnd1.render_file "cards/game_#{game_id}_round1.pdf"
  rnd2.render_file "cards/game_#{game_id}_round2.pdf"
end

print_game(5654)