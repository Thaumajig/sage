class Measurement

  attr_accessor :values

  # Constructor, given the measurement's name and an array of values.
  def initialize(name, values)

    @name = name
    @values = values
  end

  # Find how many values are stored.
  def count

    # Return the count of values.
    return @values.count
  end

  # Sum the values.
  def sum

    # Find result.
    result = @values.reduce(:+) || 0.0

    # Return the sum of all values.
    return result.round(2)
  end

  # Find the minimum value.
  def min

    # Find result.
    result = @values.min || 0.0

    # Return min.
    return result.round(2)
  end

  # Find the maximum value.
  def max

    # Find result.
    result = @values.max || 0.0

    # Return max.
    return result.round(2)
  end

  # Find mean.
  def mean

    # Return the mean average.
    if count > 0
      return (sum / count).round(2)
    else
      return 0.0
    end
  end

  # Find variance.
  def variance

    # Cache the mean.
    m = mean

    # Calculate variance.
    if count > 0
      amount = @values.reduce(0.0) { |total, x| total + (x - m) ** 2 } / count
    else
      amount = 0.0
    end

    # Return variance.
    return amount.round(2)
  end

  # Find standard deviation.
  def std_dev

    # Return standard deviation.
    return Math.sqrt(variance).round(2)
  end

  # Output for displays.
  def to_s

    # Define average string.
    averages = "#{mean} (#{min}-#{max}, s: #{std_dev})"

    # Neatly display values.
    return "#{@name}: #{count} items, averaging #{averages}"
  end

  # Append new data.
  def <<(value)

    # Append value to values array.
    @values << value
  end

  # Output for tables.
  def display_csv

    # Display in comma separated value format.
    return "#{@name},#{count},#{mean},#{min},#{max},#{std_dev}"
  end
end
