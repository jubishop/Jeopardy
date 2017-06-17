require 'prawn'
require 'sqlite3'

require_relative './JeopardyQuestionPrinter.rb'
require_relative './Toggle.rb'

class JeopardyFinalQuestionPrinter < JeopardyQuestionPrinter
  F_WIDTH = 216 # 3 * 72
  F_HEIGHT = 360 # 5 * 72
  F_LEFT_MARGIN = 90
  F_TOP_MARGIN = 36

  ANSWER_MARGIN = 20
  ANSWER_FONT_SIZE = 24

  QUESTION_TOP_MARGIN = 4
  QUESTION_MARGIN = 10
  QUESTION_FONT_SIZE = 14
  QUESTION_HEIGHT = 200

  SEPARATOR_THICKNESS = 20
  CATEGORY_MARGIN = 10

  DATE_Y = 20
  JEOPARDY_LOGO_HEIGHT = 14

  def initialize(db, game_ids)
    super

    @finals = @db.execute("SELECT * FROM FINAL_JEOPARDY WHERE GAME_ID IN (#{@game_ids.join(', ')})").map { |final|
      { :game_id => final[0], :category => final[1], :clue => final[2], :answer => final[3] }
    }
  end

  def printFinalJeopardies(final_filename)
    Prawn::Document.generateWithFonts(final_filename, :margin => 0) { |pdf|
      x_values = [F_LEFT_MARGIN, F_LEFT_MARGIN + F_WIDTH]
      y_values = [pdf.bounds.height - F_TOP_MARGIN, pdf.bounds.height - F_TOP_MARGIN - F_HEIGHT]
      pos = Toggle.new(
        [x_values[0], y_values[0]],
        [x_values[1], y_values[0]],
        [x_values[0], y_values[1]],
        [x_values[1], y_values[1]]
      )
      printed_finals = Array.new

      @finals.each_index { |final_index|
        final = @finals[final_index]
        if (print_question_side(pdf, pos.value[0], pos.value[1], final, @games[final[:game_id]]))
          pos.toggle
          printed_finals.push(final)
        end
        if (printed_finals.length == 4)
          pdf.start_new_page
          printed_finals.each { |printed_final|
            print_answer_side(pdf, pos.value[0], pos.value[1], printed_final)
            pos.toggle
          }
          printed_finals.clear
          pdf.start_new_page unless (final_index == @finals.length - 1)
        end
      }

      unless (printed_finals.empty?)
        pdf.start_new_page
        pos.reset
        until (printed_finals.empty?)
          print_answer_side(pdf, pos.value[0], pos.value[1], printed_finals.shift)
          pos.toggle
        end
      end
    }
  end

  private

  def print_question_side(pdf, left_edge, top_edge, final, game_date)
    return false unless valid_question? final[:clue]

    pdf.bounding_box([left_edge, top_edge], :width => F_WIDTH, :height => F_HEIGHT) {
      draw_border(pdf)

      # question
      pdf.bounding_box([QUESTION_MARGIN, F_HEIGHT - QUESTION_TOP_MARGIN],
        :width => F_WIDTH - QUESTION_MARGIN * 2,
        :height => QUESTION_HEIGHT) {
        pdf.font 'ITC Korinna', :style => :bold, :size => QUESTION_FONT_SIZE
        pdf.text_box final[:clue].jeopardy_upcase,
          :align => :center,
          :valign => :center
        height = pdf.height_of final[:clue].jeopardy_upcase
        if (height >= pdf.bounds.height - 2)
          puts "Tall final question, height of #{height}. page: #{pdf.page_number}"
        end
      }

      # separator line
      separator_y = F_HEIGHT - QUESTION_HEIGHT - QUESTION_MARGIN * 2
      pdf.line_width = SEPARATOR_THICKNESS
      pdf.stroke { pdf.horizontal_line 0, F_WIDTH, :at => separator_y }

      # category. to see before bidding, goes below separator line
      pdf.bounding_box([CATEGORY_MARGIN, separator_y - (SEPARATOR_THICKNESS / 2)],
        :width => F_WIDTH - CATEGORY_MARGIN * 2,
        :height => separator_y - (SEPARATOR_THICKNESS / 2) - CATEGORY_MARGIN - DATE_FONT_SIZE) {
        pdf.font 'Helvetica Inserat', :size => 24
        pdf.text_box final[:category].jeopardy_upcase,
          :align => :center,
          :valign => :center

        height = pdf.height_of final[:category].jeopardy_upcase
        if (height >= pdf.bounds.height - 2)
          puts "Tall final category, height of #{height}. page: #{pdf.page_number}"
        end
      }

      print_date(pdf, game_date, {
        :at => [CATEGORY_MARGIN, DATE_Y],
        :align => :right,
        :width => F_WIDTH - CATEGORY_MARGIN * 2
      })
    }

    return true
  end

  def print_answer_side(pdf, left_edge, top_edge, final)
    pdf.bounding_box([left_edge, top_edge], :width => F_WIDTH, :height => F_HEIGHT) {
      pdf.bounding_box([ANSWER_MARGIN, F_HEIGHT - ANSWER_MARGIN],
        :width => F_WIDTH - ANSWER_MARGIN * 2,
        :height => F_HEIGHT - ANSWER_MARGIN * 2) {
        pdf.font 'Chalkboard', :style => :bold, :size => ANSWER_FONT_SIZE
        pdf.text_box final[:answer].jeopardy_upcase,
          :align => :center,
          :valign => :center
      }
    }
  end
end