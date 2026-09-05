module Workspace
  # Display formatting for values the agent hands to data components.
  module Format
    NUMBERS = ActiveSupport::NumberHelper

    module_function

    # @param value [Object]
    # @param format [String, nil] currency | number | integer | percent | date | datetime | text
    def value(value, format = nil)
      return "" if value.nil?

      case format.to_s
      when "currency" then NUMBERS.number_to_currency(numeric(value))
      when "number" then NUMBERS.number_to_delimited(round(numeric(value)))
      when "integer" then NUMBERS.number_to_delimited(numeric(value).to_i)
      when "percent" then NUMBERS.number_to_percentage(numeric(value), precision: 2)
      when "date" then time(value)&.strftime("%b %-d, %Y") || value.to_s
      when "datetime" then time(value)&.strftime("%b %-d, %Y %H:%M") || value.to_s
      else
        value.is_a?(Numeric) ? NUMBERS.number_to_delimited(round(value)) : value.to_s
      end
    end

    def numeric(value)
      return value if value.is_a?(Numeric)

      text = value.to_s.delete(",$ ")
      text.include?(".") ? text.to_f : text.to_i
    end

    def round(number)
      number.is_a?(Float) ? number.round(2) : number
    end

    def time(value)
      case value
      when Time, DateTime then value
      when Date then value.to_time
      else Time.zone.parse(value.to_s)
      end
    rescue ArgumentError
      nil
    end
  end
end
