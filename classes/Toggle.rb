class Toggle
  attr_accessor :counter

  def initialize(one, two)
    @values = [one, two]
    @counter = 0
  end

  def value
    @values[@counter % 2]
  end

  def first
    @values.first
  end

  def last
    @values.last
  end

  def toggle
    @counter += 1
  end
end