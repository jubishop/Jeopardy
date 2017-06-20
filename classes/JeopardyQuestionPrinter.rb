require 'prawn'
require 'sqlite3'

class Numeric; def to_bool; self != 0; end; end;
class String
  def jeopardy_upcase
    self.upcase.gsub(/(\d+)([a-zA-Z]+)/) { |str| str.downcase }
  end

  def strip_international
    self.gsub!('Â', '')
    self.gsub!('â', '')
  end
end

Prawn::Font::AFM.hide_m17n_warning = true

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
  DATE_FONT_SIZE = 10

  def initialize(db, game_ids)
    @db = db
    @game_ids = game_ids
    @games = @db.execute("SELECT * FROM GAME WHERE ID IN (#{@game_ids.join(', ')})").map { |game|
      [game[0], Time.at(game[1]).to_datetime.strftime('%B %-d, %Y')]
    }.to_h
  end

  protected

  def print_date(pdf, date, text_options)
    pdf.font 'Courgette', :size => DATE_FONT_SIZE
    pdf.fill_color '666666'
    pdf.text_box date, text_options
    pdf.fill_color '000000'
  end
  
  def draw_border(pdf)
    pdf.line_width = 1
    pdf.stroke_color '999999'
    pdf.stroke_bounds
    pdf.stroke_color '000000'
  end

  def valid_question?(question)
    # visual clues
    return false if question.match(/seen here/i)
    return false if question.match(/^\(.*?presents.*?\)/i)
    return false if question.match(/^\(.*?clue.*?\)/i)
    return false if question.match(/^\(.*?i\'m.*?\)/i)
    return false if question.match(/^\(.*?reads.*?\)/i)
    return false if question.match(/^\(.*?shows.*?\)/i)
    return false if question.match(/^\(.*?reports.*?\)/i)

    # no international chars
    chars_match = /^[\p{Latin}|0-9|\s|'|&|\-|\"|\,|\.|\/|\!|\;|\:|\_|\?|\(|\)|\$|\#|\%|\+|\=|\‑|\¿|\°|\@|\¡|\*]+$/
    return false unless question.match(chars_match)

    return true
  end
end