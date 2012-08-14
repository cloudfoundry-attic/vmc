require "sinatra"

get "/" do
  "Sup, world? Ruby #{RUBY_VERSION}, Gem #{Gem::VERSION}"
end
