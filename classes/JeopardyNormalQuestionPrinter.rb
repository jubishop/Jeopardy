require 'prawn'
require 'sqlite3'

require_relative './JeopardyQuestionPrinter.rb'
require_relative './Toggle.rb'

class JeopardyNormalQuestionPrinter < JeopardyQuestionPrinter
  Q_WIDTH = 432 # 6 * 72
  Q_HEIGHT = 288 # 4 * 72
  Q_LEFT_MARGIN = 90
  Q_TOP_MARGIN = 108

  TEXT_LEFT_MARGIN = 10
  TEXT_RIGHT_MARGIN = 10

  CIRCLE_WIDTH = 32
  CIRCLE_HEIGHT = 20
  CIRCLE_LEFT_MARGIN = 10
  CIRCLE_TOP_MARGIN = 2

  QUESTION_FONT_SIZE = 8
  ANSWER_FONT_SIZE = 9
  ANSWER_INDENT = 24

  JEOPARDY_LOGO_Y = 26
  JEOPARDY_LOGO_WIDTH = 60

  DATE_Y = 36
  CATEGORY_HORIZONTAL_MARGIN = 36
  CATEGORY_VERTICAL_MARGIN = 18
  CATEGORY_FONT_SIZE = 42

  def initialize(db, game_ids)
    super

    @questions = @db.execute("SELECT * FROM QUESTION WHERE GAME_ID IN (#{@game_ids.join(', ')})").map { |q|
      {
        :game_id => q[1],
        :category_id => q[2],
        :value => q[3],
        :round => q[4],
        :daily_double => q[5],
        :clue => q[6],
        :answer => q[7]
      }
    }

    @questions_round1 = Hash.new { |hash, key| hash[key] = Array.new }
    @questions_round2 = Hash.new { |hash, key| hash[key] = Array.new }
    category_ids = Hash.new
    @questions.each { |question|
      category_ids[question[:category_id]] = true
      (question[:round] == 1 ? @questions_round1 : @questions_round2)[question[:category_id]].push(question)
    }

    categories = @db.execute("SELECT * FROM CATEGORY WHERE ID IN (#{category_ids.keys.join(', ')})")
    @categories_by_id = categories.map { |category|
      [category[0], {:game_id => category[1], :name => category[2], :round => category[3]}]
    }.to_h
  end

  def printGames(round1_filename, round2_filename)
    rnd1 = Prawn::Document.newWithFonts(:margin => 0)
    rnd2 = Prawn::Document.newWithFonts(:margin => 0)

    print_a_card = lambda { |pdf, questions|
      y_pos = Toggle.new(pdf.bounds.height - Q_TOP_MARGIN, pdf.bounds.height - Q_TOP_MARGIN - Q_HEIGHT)
      printed_categories = Array.new
      until (questions.empty?)
        category_id, card_questions = questions.shift
        if print_card(pdf, y_pos.value, card_questions)
          y_pos.toggle
          printed_categories.push(category_id)
        end
        if (printed_categories.length == 2)
          pdf.start_new_page
          printed_categories.each { |printed_category|
            print_category(pdf, y_pos.value, printed_category)
            y_pos.toggle
          }
          printed_categories.clear
          pdf.start_new_page unless (questions.empty?)
        end
      end

      unless (printed_categories.empty?)
        pdf.start_new_page
        y_pos.reset
        print_category(pdf, y_pos.value, printed_categories.pop)
      end
    }
    print_a_card.call(rnd1, @questions_round1.clone)
    print_a_card.call(rnd2, @questions_round2.clone)

    rnd1.render_file round1_filename
    rnd2.render_file round2_filename
  end

  private

  def print_card(pdf, y_pos, questions)
    return false if questions.length < 5 # not all questions asked

    # no international chars in clue OR answer
    questions.each { |question|
      question[:clue].strip_international
      question[:answer].strip_international
    }

    # validate questions
    return false if questions.index { |question| not valid_question? question[:clue] }

    pdf.bounding_box([Q_LEFT_MARGIN, y_pos], :width => Q_WIDTH, :height => Q_HEIGHT) {
      draw_border(pdf)
      pdf.bounding_box([TEXT_LEFT_MARGIN + CIRCLE_WIDTH + CIRCLE_LEFT_MARGIN, Q_HEIGHT],
        :width => Q_WIDTH - CIRCLE_WIDTH - CIRCLE_LEFT_MARGIN - TEXT_LEFT_MARGIN - TEXT_RIGHT_MARGIN,
        :height => Q_HEIGHT) {
        questions.each { |question|
          pdf.pad(12) {
            # circle with question's value
            pdf.fill_color 'cccccc'
            pdf.fill_ellipse [
                -TEXT_LEFT_MARGIN - CIRCLE_WIDTH / 2,
                pdf.cursor - CIRCLE_HEIGHT / 2 - CIRCLE_TOP_MARGIN
              ],
              CIRCLE_WIDTH / 2, CIRCLE_HEIGHT / 2
            pdf.stroke_ellipse [
                -TEXT_LEFT_MARGIN - CIRCLE_WIDTH / 2,
                pdf.cursor - CIRCLE_HEIGHT / 2 - CIRCLE_TOP_MARGIN
              ],
              CIRCLE_WIDTH / 2, CIRCLE_HEIGHT / 2
            pdf.fill_color '000000'
            pdf.font 'Helvetica Inserat', :size => 12
            pdf.text_box question[:value].to_s,
              :at => [-TEXT_LEFT_MARGIN - CIRCLE_WIDTH, pdf.cursor - CIRCLE_TOP_MARGIN],
              :align => :center,
              :valign => :center,
              :width => CIRCLE_WIDTH,
              :height => CIRCLE_HEIGHT

            # clue
            pdf.font 'ITC Korinna', :style => :bold, :size => QUESTION_FONT_SIZE
            pdf.text question[:clue].jeopardy_upcase

            # answer
            pdf.font 'Chalkboard', :style => :bold, :size => ANSWER_FONT_SIZE
            pdf.text_box question[:answer].jeopardy_upcase, :at => [ANSWER_INDENT, pdf.cursor]
          }
        }

        # text of question didn't fit
        if (pdf.cursor < 20)
          puts "Long text, cursor at: #{pdf.cursor}. page: #{pdf.page_number}, round #{questions.first[:round]}"
        end
      }
    }
    return true
  end

  def print_category(pdf, y_pos, category_id)
    category = @categories_by_id[category_id]
    pdf.bounding_box([Q_LEFT_MARGIN, y_pos], :width => Q_WIDTH, :height => Q_HEIGHT) {
      pdf.bounding_box([CATEGORY_HORIZONTAL_MARGIN, Q_HEIGHT - CATEGORY_VERTICAL_MARGIN],
        :width => Q_WIDTH - CATEGORY_HORIZONTAL_MARGIN * 2,
        :height => Q_HEIGHT - CATEGORY_VERTICAL_MARGIN * 2) {
        pdf.font 'Helvetica Inserat', :size => CATEGORY_FONT_SIZE
        pdf.text_box category[:name],
          :at => [0, pdf.bounds.height],
          :align => :center,
          :valign => :center

        height = pdf.height_of category[:name]
        if (height >= pdf.bounds.height - 2)
          puts "Tall category: #{category}, height of #{height}. page: #{pdf.page_number}"
        end
      }

      print_date(pdf, @games[category[:game_id]], {
        :at => [CATEGORY_HORIZONTAL_MARGIN, DATE_Y],
        :align => :right,
        :width => Q_WIDTH - CATEGORY_HORIZONTAL_MARGIN * 2
      })
    }
  end
end