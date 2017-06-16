require 'prawn'

require_relative './JeopardyQuestionPrinter.rb'
require_relative './Toggle.rb'

class JeopardyFinalQuestionPrinter < JeopardyQuestionPrinter
  FINAL_WIDTH = 360
  FINAL_HEIGHT = 216

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

  def printFinalJeopardies
    finals = @db.execute("SELECT * FROM FINAL_JEOPARDY WHERE GAME_ID IN (#{@game_ids.join(', ')})").map { |final|
      { :game_id => final[0], :category => final[1], :clue => final[2], :answer => final[3] }
    }

    Prawn::Document.generateWithFonts("cards/games_final.pdf") { |pdf|
      left_edges = [20, 296]
      finals.each_index { |final_index|
        final = finals[final_index]
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
      pdf.text_box game_date,
        :at => [0, 20],
        :align => :right,
        :width => 206
      pdf.fill_color '000000'
    }
  end
end