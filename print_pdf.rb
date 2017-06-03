require 'prawn'
require 'sqlite3'

Prawn::Font::AFM.hide_m17n_warning = true

class Numeric; def to_bool; self != 0; end; end;

$db = SQLite3::Database.new "jeopardy.sqlite3"

def print_game(game_id)
  null, game_utc = *$db.execute('SELECT * FROM GAME WHERE ID = ?', game_id).first
  game_date = Time.at(game_utc).to_datetime

  questions_by_category = Hash.new { |hash, key| hash[key] = Array.new }
  questions = $db.execute('SELECT * FROM QUESTION WHERE GAME_ID = ?', game_id)
  questions.each { |id, game_id, category_id, value, round, daily_double, clue, answer|
    questions_by_category[category_id].push({
      :clue => clue,
      :answer => answer,
      :daily_double => daily_double.to_bool,
      :round => round,
      :value => value
    })
  }

  categories = $db.execute("SELECT * FROM CATEGORY WHERE ID IN (#{questions_by_category.keys.join(', ')})")
  categories_by_id = categories.map { |id, game_id, category, round|
    [id, {:name => category, :round => round}]
  }.to_h

  Prawn::Document.generate("cards/game_#{game_id}_questions.pdf") do
    font_families.update(
      'Chalkboard' => { :bold => 'fonts/Chalkboard-Bold.ttf'},
      'Courgette' => { :normal => 'fonts/Courgette-Regular.ttf' },
      'Helvetica Inserat' => { :normal => 'fonts/Helvetica Inserat LT.ttf' },
      'ITC Korinna' => {
        :normal => 'fonts/Korinna Regular.ttf',
        :bold => 'fonts/Korinna Bold.ttf'
      }
    )

    box_count = 0
    questions_by_category.each { |id, questions|
      box_count += 1
      box_base_y = box_count.odd? ? 720 : 340
      bounding_box([20, box_base_y], :width => 500, :height => 340) do
        stroke_bounds
        bounding_box([65, 330], :width => 420, :height => 325) do
          fill_color '000000'
          questions.each { |question|
            pad(15) {
              stroke_ellipse [-32, cursor - 13], 20, 10
              font 'Helvetica Inserat', :size => 10
              value =
              text_box question[:daily_double] ? "DD" : question[:value].to_s,
                :at => [-42, cursor - 9],
                :align => :center,
                :width => 20

              font 'ITC Korinna', :style => :bold, :size => 9
              text question[:clue].upcase

              font 'Chalkboard', :style => :bold, :size => 10
              text_box question[:answer].upcase, :at => [20, cursor - 1]
            }
          }
          font 'Courgette', :size => 10
          fill_color '666666'
          text_box game_date.strftime('%B %-d, %Y'),
            :at => [20, 25],
            :width => 400,
            :align => :right
        end
      end

      start_new_page if box_count.even?
    }
  end
end

print_game(5654)