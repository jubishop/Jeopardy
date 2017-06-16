class Toggle
  attr_accessor :counter

  def initialize(*values)
    @values = values
    @counter = 0
  end

  def value
    @values[@counter % @values.length]
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

  def reset
    @counter = 0
  end
end