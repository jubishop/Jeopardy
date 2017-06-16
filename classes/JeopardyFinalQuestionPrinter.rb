require 'prawn'
require 'sqlite3'

require_relative './JeopardyQuestionPrinter.rb'
require_relative './Toggle.rb'

class JeopardyFinalQuestionPrinter < JeopardyQuestionPrinter
  F_WIDTH = 216 # 3 * 72
  F_HEIGHT = 360 # 5 * 72

  ANSWER_MARGIN = 20
  ANSWER_FONT_SIZE = 24

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
    Prawn::Document.generateWithFonts(final_filename) { |pdf|
      @finals.each_index { |final_index|
        final = @finals[final_index]
        game_date = @games[final[:game_id]]

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

        if (final_index % 3 == 2 || final_index == @finals.size - 1)
          pdf.start_new_page
          (final_index % 3 + 1).times {
            if (final_index % 3 == 0)
              print_answer_side(pdf, 20, 710, @finals[final_index])
            elsif (final_index % 3 == 1)
              print_answer_side(pdf, 296, 710, @finals[final_index])
            else
              pdf.rotate(-90, :origin => [270, 200]) {
                print_answer_side(pdf, 200, 380, @finals[final_index])
              }
            end
            final_index -= 1
          }
        end
      }
    }
  end

  private

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

  def print_question_side(pdf, left_edge, top_edge, final, game_date)
    pdf.bounding_box([left_edge, top_edge], :width => F_WIDTH, :height => F_HEIGHT) {
      draw_border(pdf)

      # question
      pdf.bounding_box([QUESTION_MARGIN, F_HEIGHT - QUESTION_MARGIN],
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
      pdf.bounding_box([CATEGORY_MARGIN, separator_y - (SEPARATOR_THICKNESS / 2) - CATEGORY_MARGIN],
        :width => F_WIDTH - CATEGORY_MARGIN * 2,
        :height => separator_y - (SEPARATOR_THICKNESS / 2) - (CATEGORY_MARGIN * 2) - DATE_FONT_SIZE) {
        pdf.font 'Helvetica Inserat', :size => 24
        pdf.text_box final[:category].jeopardy_upcase,
          :align => :center,
          :valign => :center

        height = pdf.height_of final[:category].jeopardy_upcase
        if (height >= pdf.bounds.height - 2)
          puts "Tall final category, height of #{height}. page: #{pdf.page_number}"
        end
      }

      pdf.image "jeopardy_logo.png", :at => [CATEGORY_MARGIN, DATE_Y], :height => JEOPARDY_LOGO_HEIGHT

      print_date(pdf, game_date, {
        :at => [CATEGORY_MARGIN, DATE_Y],
        :align => :right,
        :width => F_WIDTH - CATEGORY_MARGIN * 2
      })
    }
  end
end