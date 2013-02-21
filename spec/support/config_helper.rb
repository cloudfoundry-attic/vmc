module ConfigHelper
  def write_token_file(config={})
    File.open(File.expand_path(tokens_file_path), 'w') do |f|
      f.puts YAML.dump(
        { "https://api.some-domain.com" =>
          {
            :version => 2,
            :token => 'bearer token',
            :refresh_token => nil
          }.merge(config)
        }
      )
    end
  end
end
