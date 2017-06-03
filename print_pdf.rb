require 'prawn'
require 'sqlite3'

Prawn::Font::AFM.hide_m17n_warning = true

class Numeric; def to_bool; self != 0; end; end;

db = SQLite3::Database.new "jeopardy.sqlite3"

questions_by_category = Hash.new { |hash, key| hash[key] = Array.new }

questions = db.execute('SELECT * FROM QUESTION WHERE GAME_ID = ?', 5654)
questions.each { |id, game_id, category_id, value, round, daily_double, clue, answer|
  questions_by_category[category_id].push({
    :clue => clue,
    :answer => answer,
    :daily_double => daily_double.to_bool,
    :round => round,
    :value => value
  })
}

categories = db.execute("SELECT * FROM CATEGORY WHERE ID IN (#{questions_by_category.keys.join(', ')})")
categories_by_id = categories.map { |id, game_id, category, round|
  [id, {:name => category, :round => round}]
}.to_h

Prawn::Document.generate("cards/test.pdf") do
  font_families.update(
     "ITC Korinna" => { :normal => "Korinna Regular.ttf" },
     "Helvetica Inserat" => { :normal => "Helvetica Inserat LT.ttf" }
  )

  box_count = 0
  questions_by_category.each { |id, questions|
    box_count += 1
    box_base_y = box_count.odd? ? 740 : 340
    bounding_box([20, box_base_y], :width => 500, :height => 360) do
      stroke_bounds
      bounding_box([20, 350], :width => 460, :height => 340) do
        questions.each { |question|
          pad(15) {
            font "ITC Korinna"
            text question[:clue]
            font "Helvetica Inserat"
            text_box question[:answer], :at => [20, cursor]
          }
        }
      end
    end

    start_new_page if box_count.even?
  }
end