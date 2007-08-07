class BeIdenticalWith
  def initialize(expected)
    @expected = expected
  end
  def matches?(actual)
    @actual = actual
    FileUtils.identical?(@actual, @expected)
  end
  def failure_message
    "expected #{@actual.inspect} to be identical with #{@expected.inspect}"
  end
  def negative_failure_message
    "expected #{@actual.inspect} to not be identical with #{@expected.inspect}"
  end
end

def be_identical_with(expected)
  BeIdenticalWith.new(expected)
end

class ExistsPredicate

  def matches?(actual)
    actual.exists?
  end
  def failure_message
    "expected #{@actual.inspect} to exist, it doesn't."
  end
  def negative_failure_message
    "expected #{@actual.inspect} to not exist, yet it does."
  end
end

def be_in_existence
  ExistsPredicate.new
end

class MatchPath
  def initialize(*expected)
    if(expected.size < 2)
      @expected = File.expand_path(expected.first)
    else
      @expected = expected.map {|e| e.is_a?(Regexp) ? e.to_s : Regexp.escape(e)}
      @expected = File.expand_path(File.join(*@expected), RAILS_ROOT)
      @expected = %r(^#{@expected}$)
    end
  end
  def matches?(actual)
    @actual = actual
    if @expected.is_a?(Regexp)
      File.expand_path(actual) =~ @expected
    else
      File.expand_path(actual) == @expected
    end
  end
  def failure_message
    "expected #{@actual.inspect} to match #{@expected}."
  end
  def negative_failure_message
    "expected #{@actual.inspect} to not match #{@expected}, yet it does."
  end
end

# Match a path without bothering whether they are formatted the same way.
# can also take several parameters, any number of which may be regexes
def match_path(*expected)
  MatchPath.new(*expected)
end

class HavePermissions
  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    @actual = actual
    # Satisfy expectation here. Return false or raise an error if it's not met.
    (File.stat(@actual.path).mode & 0777) == @expected
  end

  def failure_message
    "expected #{@actual.inspect} to have permissions #{@expected.to_s(8)}, but they were #{(File.stat(@actual.path).mode & 0777).to_s(8)}"
  end

  def negative_failure_message
    "expected #{@actual.inspect} not to have permissions #{@expected.to_s(8)}, but it did"
  end
end

def have_permissions(expected)
  HavePermissions.new(expected)
end

class BeNoLargerThan
  def initialize(width, height)
    @width, @height = width, height
  end

  def matches?(actual)
    @actual = actual
    # Satisfy expectation here. Return false or raise an error if it's not met.
    require 'RMagick'
    img = ::Magick::Image.read(@actual.path).first
    @actual_width = img.columns
    @actual_height = img.rows
    @actual_width <= @width && @actual_height <= @height
  end

  def failure_message
    "expected #{@actual.inspect} to be no larger than #{@width} by #{@height}, but it was #{@actual_height} by #{@actual_width}."
  end

  def negative_failure_message
    "expected #{@actual.inspect} to be larger than #{@width} by #{@height}, but it wasn't."
  end
end

def be_no_larger_than(width, height)
  BeNoLargerThan.new(width, height)
end

class HaveTheExactDimensionsOf
  def initialize(width, height)
    @width, @height = width, height
  end

  def matches?(actual)
    @actual = actual
    # Satisfy expectation here. Return false or raise an error if it's not met.
    require 'RMagick'
    img = ::Magick::Image.read(@actual.path).first
    @actual_width = img.columns
    @actual_height = img.rows
    @actual_width == @width && @actual_height == @height
  end

  def failure_message
    "expected #{@actual.inspect} to have an exact size of #{@width} by #{@height}, but it was #{@actual_height} by #{@actual_width}."
  end

  def negative_failure_message
    "expected #{@actual.inspect} not to have an exact size of #{@width} by #{@height}, but it did."
  end
end

def have_the_exact_dimensions_of(width, height)
  HaveTheExactDimensionsOf.new(width, height)
end