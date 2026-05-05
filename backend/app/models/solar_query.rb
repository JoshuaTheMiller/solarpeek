# frozen_string_literal: true

# Plain value object passed to SolarPolicy for Pundit authorization.
# Holds the parsed date range from the solar readings request.
SolarQuery = Struct.new(:start_date, :end_date, keyword_init: true)
