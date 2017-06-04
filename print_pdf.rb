require 'prawn'
require 'sqlite3'

Prawn::Font::AFM.hide_m17n_warning = true

class Numeric; def to_bool; self != 0; end; end;

module Prawn
  class Document
    def self.newWithFonts(options = {}, &block)
      new(options) {
        font_families.update(
          'Chalkboard' => { :bold => 'fonts/Chalkboard-Bold.ttf'},
          'Courgette' => { :normal => 'fonts/Courgette-Regular.ttf' },
          'Helvetica Inserat' => { :normal => 'fonts/Helvetica Inserat LT.ttf' },
          'ITC Korinna' => {
            :normal => 'fonts/Korinna Regular.ttf',
            :bold => 'fonts/Korinna Bold.ttf'
          })
        block.call(self) if block
      }
    end

    def self.generateWithFonts(filename, options = {}, &block)
      pdf = newWithFonts(options, &block)
      pdf.render_file(filename)
    end
  end
end

$db = SQLite3::Database.new "jeopardy.sqlite3"

def print_category(rnd, box_y, category)
  rnd.bounding_box([20, box_y], :width => 500, :height => 340) {
    rnd.font 'Helvetica Inserat', :size => 64
    rnd.text_box category,
      :at => [0, 340],
      :align => :center,
      :valign => :center
  }
end

def print_games(game_ids)
  games = *$db.execute("SELECT * FROM GAME WHERE ID IN (#{game_ids.join(', ')})")

  rnd1 = Prawn::Document.newWithFonts
  rnd2 = Prawn::Document.newWithFonts

  games.each { |game|
    round1_count, round2_count = *print_game(game[0], Time.at(game[1]).to_datetime, rnd1, rnd2)
    unless (game == games.last)
      rnd1.start_new_page if (round1_count > 0)
      rnd2.start_new_page if (round2_count > 0)
    end
  }

  rnd1.render_file "cards/games_round1.pdf"
  rnd2.render_file "cards/games_round2.pdf"
end

def print_game(game_id, game_date, rnd1, rnd2)
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
  categories_by_id = categories.map { |category|
    [category[0], {:name => category[2], :round => category[3]}]
  }.to_h

  # print round1 and round2 questions into respective pdf's
  [[questions_round1, rnd1], [questions_round2, rnd2]].each { |questions_by_category, rnd|
    box_count = 0
    category_cards = Array.new
    questions_by_category.each { |id, questions|
      next if (questions.length < 5)

      box_count += 1
      rnd.start_new_page if box_count > 1 and box_count.odd?

      box_base_y = box_count.odd? ? 720 : 340
      rnd.bounding_box([20, box_base_y], :width => 500, :height => 340) {
        rnd.stroke_color '999999'
        rnd.stroke_bounds
        rnd.stroke_color '000000'
        rnd.bounding_box([70, 330], :width => 410, :height => 325) {
          questions.each { |question|
            rnd.pad(15) {
              rnd.fill_color 'cccccc'
              rnd.fill_ellipse [-34, rnd.cursor - 13], 20, 10
              rnd.stroke_ellipse [-34, rnd.cursor - 13], 20, 10
              rnd.fill_color '000000'
              rnd.font 'Helvetica Inserat', :size => 12
              rnd.text_box question[:value].to_s,
                :at => [-46, rnd.cursor - 9],
                :align => :center,
                :width => 24

              rnd.font 'ITC Korinna', :style => :bold, :size => 9
              rnd.text question[:clue].upcase

              rnd.font 'Chalkboard', :style => :bold, :size => 10
              rnd.text_box question[:answer].upcase, :at => [20, rnd.cursor - 1]
            }
          }
          rnd.font 'Courgette', :size => 10
          rnd.fill_color '666666'
          rnd.text_box game_date.strftime('%B %-d, %Y'),
            :at => [10, 25],
            :align => :right,
            :width => 400
          rnd.fill_color '000000'

          rnd.image "jeopardy_logo.png", :at => [-50, 30], :width => 60
        }
      }

      category_cards.push(categories_by_id[id][:name])
      if (category_cards.length == 2)
        rnd.start_new_page
        print_category(rnd, 720, category_cards.first)
        print_category(rnd, 340, category_cards.last)
        category_cards.clear
      end
    }

    if (not category_cards.empty?)
      rnd.start_new_page
      print_category(rnd, 720, category_cards.shift)
    end
  }

  return [questions_round1.length, questions_round2.length]
end

def print_final_jeopardies(game_ids)
  finals = *$db.execute("SELECT * FROM FINAL_JEOPARDY WHERE GAME_ID IN (#{game_ids.join(', ')})").map { |final|
    { :category => final[1], :clue => final[2], :answer => final[3] }
  }

  Prawn::Document.generateWithFonts("cards/game_#{game_id}_final.pdf") { |pdf|
    pdf.bounding_box([40, 720], :width => 460, :height => 400) {
      pdf.font 'ITC Korinna', :style => :bold, :size => 24
      pdf.text_box final_clue.upcase,
        :align => :center,
        :valign => :center
    }

    pdf.line_width = 40
    pdf.stroke { pdf.horizontal_line 0, 540, :at => 200 }

    pdf.font 'Helvetica Inserat', :size => 36
    pdf.text_box final_category,
      :at => [0, 100],
      :align => :center

    pdf.image "jeopardy_logo.png", :at => [20, 25], :width => 60

    pdf.font 'Courgette', :size => 10
    pdf.fill_color '666666'
    pdf.text_box game_date.strftime('%B %-d, %Y'),
      :at => [0, 20],
      :align => :right,
      :width => 540
    pdf.fill_color '000000'
  }
end

print_games((5650..5657).to_a)
# print_final_jeopardies((101..200).to_a)