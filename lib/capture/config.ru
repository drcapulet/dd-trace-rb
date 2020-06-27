require 'pry'

class Application
  def call(env)
    binding.pry
    status  = 200
    headers = { "Content-Type" => "text/html" }
    body    = ["Captured!"]

    [status, headers, body]
  end
end

run Application.new
