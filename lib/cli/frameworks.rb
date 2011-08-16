module VMC::Cli

  class Framework

    DEFAULT_FRAMEWORK = "http://b20nine.com/unknown"
    DEFAULT_MEM = '256M'

    FRAMEWORKS = {
      'Rails'    => ['rails3',  { :mem => '256M', :description => 'Rails Application'}],
      'Spring'   => ['spring',  { :mem => '512M', :description => 'Java SpringSource Spring Application'}],
      'Grails'   => ['grails',  { :mem => '512M', :description => 'Java SpringSource Grails Application'}],
      'Lift'   =>   ['lift',    { :mem => '512M', :description => 'Scala Lift Application'}],
      'JavaWeb'  => ['java_web',  { :mem => '512M', :description => 'Java Web Application'}],
      'Sinatra'  => ['sinatra', { :mem => '128M', :description => 'Sinatra Application'}],
      'Node'     => ['node',    { :mem => '64M',  :description => 'Node.js Application'}],
      'Erlang/OTP Rebar' => ['otp_rebar',  { :mem => '64M',  :description => 'Erlang/OTP Rebar Application'}],
      'WSGI'     => ['wsgi',    { :mem => '64M',  :description => 'Python WSGI Application'}],
      'Django'   => ['django',  { :mem => '128M', :description => 'Python Django Application'}],
    }

    class << self

      def known_frameworks
        FRAMEWORKS.keys
      end

      def lookup(name)
        return Framework.new(*FRAMEWORKS[name])
      end

      def detect(path)
        Dir.chdir(path) do

          # Rails
          if File.exist?('config/environment.rb')
            return Framework.lookup('Rails')

          # Java
          elsif Dir.glob('*.war').first
            war_file = Dir.glob('*.war').first
            contents = ZipUtil.entry_lines(war_file)

            # Spring/Lift Variations
            if contents =~ /WEB-INF\/lib\/grails-web.*\.jar/
              return Framework.lookup('Grails')
            elsif contents =~ /WEB-INF\/lib\/lift-webkit.*\.jar/
              return Framework.lookup('Lift')
            elsif contents =~ /WEB-INF\/classes\/org\/springframework/
              return Framework.lookup('Spring')
            elsif contents =~ /WEB-INF\/lib\/spring-core.*\.jar/
              return Framework.lookup('Spring')
            else
              return Framework.lookup('JavaWeb')
            end

          # Simple Ruby Apps
          elsif !Dir.glob('*.rb').empty?
            matched_file = nil
            Dir.glob('*.rb').each do |fname|
              next if matched_file
              File.open(fname, 'r') do |f|
                str = f.read # This might want to be limited
                matched_file = fname if (str && str.match(/^\s*require[\s\(]*['"]sinatra['"]/))
              end
            end
            if matched_file
              f = Framework.lookup('Sinatra')
              f.exec = "ruby #{matched_file}"
              return f
            end

          # Node.js
          elsif !Dir.glob('*.js').empty?
            if File.exist?('server.js') || File.exist?('app.js') || File.exist?('index.js') || File.exist?('main.js')
              return Framework.lookup('Node')
            end

          # Erlang/OTP using Rebar
          elsif !Dir.glob('releases/*/*.rel').empty? && !Dir.glob('releases/*/*.boot').empty?
            return Framework.lookup('Erlang/OTP Rebar')

          # Python Django
          # XXX: not all django projects keep settings.py in top-level directory
          elsif File.exist?('manage.py') && File.exist?('settings.py')
            return Framework.lookup('Django')

          # Python
          elsif !Dir.glob('wsgi.py').empty?
            return Framework.lookup('WSGI')

          end
        end
        nil
      end

    end

    attr_reader   :name, :description, :memory
    attr_accessor :exec

    alias :mem :memory

    def initialize(framework=nil, opts={})
      @name = framework || DEFAULT_FRAMEWORK
      @memory = opts[:mem] || DEFAULT_MEM
      @description = opts[:description] || 'Unknown Application Type'
      @exec = opts[:exec]
    end

    def to_s
      description
    end
  end

end
