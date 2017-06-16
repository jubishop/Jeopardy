require 'sqlite3'

class Numeric; def to_bool; self != 0; end; end;
class String
  def jeopardy_upcase
    self.upcase.gsub(/(\d+)S/, '\1s')
  end
  
  def strip_international
    self.gsub!('Â', '')
    self.gsub!('â', '')
  end
end

class JeopardyQuestionPrinter
  def initialize(db, game_ids)
    @db = db
    @game_ids = game_ids
    @games = @db.execute("SELECT * FROM GAME WHERE ID IN (#{@game_ids.join(', ')})").map { |game|
      [game[0], Time.at(game[1]).to_datetime.strftime('%B %-d, %Y')]
    }.to_h
  end
end