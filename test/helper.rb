require "simplecov"
SimpleCov.start do
  add_filter "/vendor/"
end

require "test/unit"
require "test/unit/rr"
require "pipe_fitter"
require "pry"

def create_tempfile(data)
  Tempfile.new("").tap { |f| f.puts data }.tap(&:flush)    
end
