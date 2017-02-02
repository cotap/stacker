$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rspec/its'
require 'pry'
require 'stacker'

def templates_path
  File.expand_path('../support/templates', __FILE__)
end
