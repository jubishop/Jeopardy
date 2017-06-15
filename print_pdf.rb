require 'prawn'
require 'sqlite3'

Prawn::Font::AFM.hide_m17n_warning = true

# TODO: Skip any category with a question containing "seen here"

class Numeric; def to_bool; self != 0; end; end;
class String
  def jeopardy_upcase
    self.upcase.gsub(/(\d+)S/, '\1s')
  end
end

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

class JeopardyQuestionPrinter
  PAPER_MARGIN = 10

  Q_WIDTH = 432
  Q_HEIGHT = 288
  Q_LEFT_MARGIN = 72
  Q_TOP_MARGIN = 72

  TEXT_LEFT_MARGIN = 10
  TEXT_RIGHT_MARGIN = 10

  CIRCLE_WIDTH = 32
  CIRCLE_HEIGHT = 20
  CIRCLE_LEFT_MARGIN = 10
  CIRCLE_TOP_MARGIN = 2

  QUESTION_FONT_SIZE = 8
  ANSWER_FONT_SIZE = 9
  ANSWER_INDENT = 24
  JEOPARDY_LOGO_WIDTH = 60

  CATEGORY_HORIZONTAL_MARGIN = 36
  CATEGORY_VERTICAL_MARGIN = 18
  CATEGORY_FONT_SIZE = 42

  FINAL_WIDTH = 360
  FINAL_HEIGHT = 216

  def initialize(db, game_ids)
    @db = db
    @game_ids = game_ids
    @games = @db.execute("SELECT * FROM GAME WHERE ID IN (#{@game_ids.join(', ')})").to_h
  end

  def printGames
    @rnd1 = Prawn::Document.newWithFonts(:left_margin => PAPER_MARGIN, :right_margin => PAPER_MARGIN)
    @rnd2 = Prawn::Document.newWithFonts(:left_margin => PAPER_MARGIN, :right_margin => PAPER_MARGIN)

    @games.each_pair { |game_id, game_date|
      round1_count, round2_count = *print_game(game_id, Time.at(game_date).to_datetime)
      unless (game_id == @games.keys.last)
        @rnd1.start_new_page if (round1_count > 0)
        @rnd2.start_new_page if (round2_count > 0)
      end
    }

    @rnd1.render_file "cards/games_round1.pdf"
    @rnd2.render_file "cards/games_round2.pdf"
  end

  def printFinalJeopardies
    finals = @db.execute("SELECT * FROM FINAL_JEOPARDY WHERE GAME_ID IN (#{@game_ids.join(', ')})").map { |final|
      { :game_id => final[0], :category => final[1], :clue => final[2], :answer => final[3] }
    }

    Prawn::Document.generateWithFonts("cards/games_final.pdf") { |pdf|
      left_edges = [20, 296]
      finals.each_index { |final_index|
        final = finals[final_index]
        game_date = Time.at(@games[final[:game_id]]).to_datetime

        # TODO: Skip final jeopardy questions that are crap like "clue crew"

        pdf.start_new_page if (final_index > 0 && final_index % 3 == 0)

        if (final_index % 3 == 0)
          print_question_side(pdf, 50, 710, final, game_date)
        elsif (final_index % 3 == 1)
          print_question_side(pdf, 266, 710, final, game_date)
        else
          pdf.rotate(-90, :origin => [270, 200]) {
            print_question_side(pdf, 120, 380, final, game_date)
          }
        end

        if (final_index % 3 == 2 || final_index == finals.size - 1)
          pdf.start_new_page
          (final_index % 3 + 1).times {
            if (final_index % 3 == 0)
              print_answer_side(pdf, 20, 710, finals[final_index])
            elsif (final_index % 3 == 1)
              print_answer_side(pdf, 296, 710, finals[final_index])
            else
              pdf.rotate(-90, :origin => [270, 200]) {
                print_answer_side(pdf, 200, 380, finals[final_index])
              }
            end
            final_index -= 1
          }
        end
      }
    }
  end

  private

  # printGames helper
  def print_game(game_id, game_date)
    questions_round1 = Hash.new { |hash, key| hash[key] = Array.new }
    questions_round2 = Hash.new { |hash, key| hash[key] = Array.new }
    category_ids = Hash.new
    questions = @db.execute('SELECT * FROM QUESTION WHERE GAME_ID = ?', game_id)
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

    categories = @db.execute("SELECT * FROM CATEGORY WHERE ID IN (#{category_ids.keys.join(', ')})")
    categories_by_id = categories.map { |category|
      [category[0], {:name => category[2], :round => category[3]}]
    }.to_h

    # print round1 and round2 questions into respective pdf's
    [[questions_round1, @rnd1], [questions_round2, @rnd2]].each { |questions_by_category, rnd|
      box_count = 0
      category_cards = Array.new
      questions_by_category.each { |id, questions|
        next if questions.length < 5
        next if questions.index { |question| question[:clue].match(/seen here/i) }
        next if questions.index { |question| question[:clue].match(/^\(.*?presents.*?\)/i) }
        next if questions.index { |question| question[:clue].match(/^\(.*?clue.*?\)/i) }
        next if questions.index { |question| question[:clue].match(/^\(.*?i\'m.*?\)/i) }
        next if questions.index { |question| question[:clue].match(/^\(.*?reads.*?\)/i) }
        next if questions.index { |question| question[:clue].match(/^\(.*?reports.*?\)/i) }
        questions.each { |question|
          question[:clue].gsub!('Â', '')
          question[:clue].gsub!('â', '')
        }

        chars_match = /^[\p{Latin}|0-9|\s|'|&|\-|\"|\,|\.|\/|\!|\;|\:|\_|\?|\(|\)|\$|\#|\%|\+|\=|\‑|\¿|\°|\@|\¡|\*]+$/
        tt = questions.index { |question| question[:clue].match(chars_match).nil? }
        next if (tt)

        box_count += 1
        rnd.start_new_page if box_count > 1 and box_count.odd?

        box_base_y = box_count.odd? ? rnd.bounds.height - Q_TOP_MARGIN : rnd.bounds.height - Q_TOP_MARGIN - Q_HEIGHT
        print_question_card(rnd, box_base_y, questions)

        category_cards.push(categories_by_id[id])
        if (category_cards.length == 2)
          rnd.start_new_page
          print_category(rnd, rnd.bounds.height - Q_TOP_MARGIN, category_cards.first, game_date)
          print_category(rnd, rnd.bounds.height - Q_TOP_MARGIN - Q_HEIGHT, category_cards.last, game_date)
          category_cards.clear
        end
      }

      if (not category_cards.empty?)
        rnd.start_new_page
        print_category(rnd, 720, category_cards.shift, game_date)
      end
    }

    return [questions_round1.length, questions_round2.length]
  end

  # print_game helpers
  def print_category(rnd, box_y, category, game_date)
    rnd.bounding_box([Q_LEFT_MARGIN, box_y], :width => Q_WIDTH, :height => Q_HEIGHT) {
      rnd.stroke_bounds
      rnd.bounding_box([CATEGORY_HORIZONTAL_MARGIN, Q_HEIGHT - CATEGORY_VERTICAL_MARGIN],
        :width => Q_WIDTH - CATEGORY_HORIZONTAL_MARGIN * 2,
        :height => Q_HEIGHT - CATEGORY_VERTICAL_MARGIN * 2) {
        rnd.font 'Helvetica Inserat', :size => CATEGORY_FONT_SIZE
        rnd.text_box category[:name],
          :at => [0, rnd.bounds.height],
          :align => :center,
          :valign => :center

        height = rnd.height_of category[:name]
        if (height > rnd.bounds.height)
          puts "Tall category: #{category}, height of #{height}. page: #{rnd.page_number}"
        end
      }

      rnd.font 'Courgette', :size => 10
      rnd.fill_color '666666'
      rnd.text_box game_date.strftime('%B %-d, %Y'),
        :at => [0, 20],
        :align => :right,
        :width => Q_WIDTH - CATEGORY_HORIZONTAL_MARGIN / 2
      rnd.fill_color '000000'
    }
  end

  def print_question_card(rnd, box_y, questions)
    rnd.bounding_box([Q_LEFT_MARGIN, box_y], :width => Q_WIDTH, :height => Q_HEIGHT) {
      rnd.stroke_color '999999'
      rnd.stroke_bounds
      rnd.stroke_color '000000'
      rnd.bounding_box([TEXT_LEFT_MARGIN + CIRCLE_WIDTH + CIRCLE_LEFT_MARGIN, Q_HEIGHT],
        :width => Q_WIDTH - CIRCLE_WIDTH - CIRCLE_LEFT_MARGIN - TEXT_LEFT_MARGIN - TEXT_RIGHT_MARGIN,
        :height => Q_HEIGHT) {
        questions.each { |question|
          rnd.pad(12) {
            # circle with value
            rnd.fill_color 'cccccc'
            rnd.fill_ellipse [
                -TEXT_LEFT_MARGIN - CIRCLE_WIDTH / 2,
                rnd.cursor - CIRCLE_HEIGHT / 2 - CIRCLE_TOP_MARGIN
              ],
              CIRCLE_WIDTH / 2, CIRCLE_HEIGHT / 2
            rnd.stroke_ellipse [
                -TEXT_LEFT_MARGIN - CIRCLE_WIDTH / 2,
                rnd.cursor - CIRCLE_HEIGHT / 2 - CIRCLE_TOP_MARGIN
              ],
              CIRCLE_WIDTH / 2, CIRCLE_HEIGHT / 2
            rnd.fill_color '000000'
            rnd.font 'Helvetica Inserat', :size => 12
            rnd.text_box question[:value].to_s,
              :at => [-TEXT_LEFT_MARGIN - CIRCLE_WIDTH, rnd.cursor - CIRCLE_TOP_MARGIN],
              :align => :center,
              :valign => :center,
              :width => CIRCLE_WIDTH,
              :height => CIRCLE_HEIGHT

            # clue
            rnd.font 'ITC Korinna', :style => :bold, :size => QUESTION_FONT_SIZE
            rnd.text question[:clue].jeopardy_upcase

            # answer
            rnd.font 'Chalkboard', :style => :bold, :size => ANSWER_FONT_SIZE
            rnd.text_box question[:answer].jeopardy_upcase, :at => [ANSWER_INDENT, rnd.cursor]
          }
        }
        rnd.image "jeopardy_logo.png",
          :at => [rnd.bounds.width - JEOPARDY_LOGO_WIDTH, JEOPARDY_LOGO_WIDTH / 2],
          :width => JEOPARDY_LOGO_WIDTH

        # we don't want to waste printing groups that don't fit
        if (rnd.cursor < 20)
          puts "Long text, cursor at: #{rnd.cursor}. page: #{rnd.page_number}, round #{questions.first[:round]}"
        end
      }
    }
  end

  # printFinalJeopardy helpers
  def print_answer_side(pdf, left_edge, top_edge, final)
    pdf.bounding_box([left_edge, top_edge], :width => 216, :height => 360) {
      pdf.bounding_box([20, 340], :width => 176, :height => 320) {
        pdf.font 'Chalkboard', :style => :bold, :size => 24
        pdf.text_box final[:answer].jeopardy_upcase,
          :align => :center,
          :valign => :center
      }
    }
  end

  def print_question_side(pdf, left_edge, top_edge, final, game_date)
    pdf.bounding_box([left_edge, top_edge], :width => 216, :height => 360) {
      pdf.line_width = 1
      pdf.stroke_color '999999'
      pdf.stroke_bounds
      pdf.stroke_color '000000'

      pdf.bounding_box([10, 350], :width => 196, :height => 200) {
        pdf.font 'ITC Korinna', :style => :bold, :size => 16
        pdf.text_box final[:clue].jeopardy_upcase,
          :align => :center,
          :valign => :center
        height = pdf.height_of final[:clue].jeopardy_upcase
        if (height > 180)
          puts "#{height}: #{pdf.page_number}"
        end
      }

      pdf.line_width = 20
      pdf.stroke { pdf.horizontal_line 0, 216, :at => 120 }

      pdf.bounding_box([10, 110], :width => 196, :height => 90) {
        pdf.font 'Helvetica Inserat', :size => 24
        pdf.text_box final[:category].jeopardy_upcase,
          :align => :center,
          :valign => :center
      }

      pdf.image "jeopardy_logo.png", :at => [10, 20], :width => 50

      pdf.font 'Courgette', :size => 10
      pdf.fill_color '666666'
      pdf.text_box game_date.strftime('%B %-d, %Y'),
        :at => [0, 20],
        :align => :right,
        :width => 206
      pdf.fill_color '000000'
    }
  end
end

raise "Usage: ruby print_pdf.rb <start_date> [<end_date>]" unless ARGV.length == 1 or ARGV.length == 2


db = SQLite3::Database.new "jeopardy.sqlite3"

start_date = DateTime.strptime(ARGV[0], "%m/%d/%Y") + (7/24.0)

if (ARGV.length == 2)
  end_date = DateTime.strptime(ARGV[1], "%m/%d/%Y") + (7/24.0)
  game_ids = db.execute("SELECT * FROM GAME WHERE
    DATE >= #{start_date.to_time.to_i} AND
    DATE <= #{end_date.to_time.to_i}").map { |game| game[0] }
  puts "Printing #{game_ids.length} games"
else
  game = db.execute("SELECT * FROM GAME WHERE DATE = ?", start_date.to_time.to_i)
  game_ids = [game[0]]
end

# TODO: Mash all questions together so that every page is full, not split by game_id

jeopardyPrinter = JeopardyQuestionPrinter.new(db, game_ids)
# jeopardyPrinter.printGames
jeopardyPrinter.printFinalJeopardies