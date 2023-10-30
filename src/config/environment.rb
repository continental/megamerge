# frozen_string_literal: true

# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!


#class Logger
#  def format_message(severity, timestamp, progname, msg)
#    time = Time.now.strftime("%H:%M:%S.%L")
#    "\n#{time} [#{$$}] #{msg}" unless msg.blank?
#  end
#end