module VMCExtensions

  def say(message)
    VMC::Cli::Config.output.puts(message) if VMC::Cli::Config.output
  end

  def header(message, filler = '-')
    say "\n"
    say message
    say filler.to_s * message.size
  end

  def banner(message)
    say "\n"
    say message
  end

  def display(message, nl=true)
    if nl
      say message
    else
      if VMC::Cli::Config.output
        VMC::Cli::Config.output.print(message)
        VMC::Cli::Config.output.flush
      end
    end
  end

  def clear(size=80)
    return unless VMC::Cli::Config.output
    VMC::Cli::Config.output.print("\r")
    VMC::Cli::Config.output.print(" " * size)
    VMC::Cli::Config.output.print("\r")
    #VMC::Cli::Config.output.flush
  end

  def err(message, prefix='Error: ')
    raise VMC::Cli::CliExit, "#{prefix}#{message}"
  end

  def warn(msg)
    say "#{"[WARNING]".yellow} #{msg}"
  end

  def quit(message = nil)
    raise VMC::Cli::GracefulExit, message
  end

  def blank?
    self.to_s.blank?
  end

  def uptime_string(delta)
    num_seconds = delta.to_i
    days = num_seconds / (60 * 60 * 24);
    num_seconds -= days * (60 * 60 * 24);
    hours = num_seconds / (60 * 60);
    num_seconds -= hours * (60 * 60);
    minutes = num_seconds / 60;
    num_seconds -= minutes * 60;
    "#{days}d:#{hours}h:#{minutes}m:#{num_seconds}s"
  end

  def pretty_size(size, prec=1)
    return 'NA' unless size
    return "#{size}B" if size < 1024
    return sprintf("%.#{prec}fK", size/1024.0) if size < (1024*1024)
    return sprintf("%.#{prec}fM", size/(1024.0*1024.0)) if size < (1024*1024*1024)
    return sprintf("%.#{prec}fG", size/(1024.0*1024.0*1024.0))
  end
end

module VMCStringExtensions

  def red
    colorize("\e[0m\e[31m")
  end

  def green
    colorize("\e[0m\e[32m")
  end

  def yellow
    colorize("\e[0m\e[33m")
  end

  def bold
    colorize("\e[0m\e[1m")
  end

  def colorize(color_code)
    if VMC::Cli::Config.colorize
      "#{color_code}#{self}\e[0m"
    else
      self
    end
  end

  def blank?
    self =~ /^\s*$/
  end

  def truncate(limit = 30)
    return "" if self.blank?
    etc = "..."
    stripped = self.strip[0..limit]
    if stripped.length > limit
      stripped.gsub(/\s+?(\S+)?$/, "") + etc
    else
      stripped
    end
  end

end

class Object
  include VMCExtensions
end

class String
  include VMCStringExtensions
end
