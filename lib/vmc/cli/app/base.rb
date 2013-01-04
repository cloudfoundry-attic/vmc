require "vmc/cli"

module VMC
  module App
    class Base < CLI
      # choose the right color for app/instance state
      def state_color(s)
        case s
        when "STARTING"
          :neutral
        when "STARTED", "RUNNING"
          :good
        when "DOWN"
          :bad
        when "FLAPPING"
          :error
        when "N/A"
          :unknown
        else
          :warning
        end
      end

      def app_status(a)
        health = a.health

        if a.debug_mode == "suspend" && health == "0%"
          c("suspended", :neutral)
        else
          c(health.downcase, state_color(health))
        end
      end

      def memory_choices(exclude = 0)
        info = client.info
        used = info[:usage][:memory]
        limit = info[:limits][:memory]
        available = limit - used + exclude

        mem = 64
        choices = []
        until mem > available
          choices << human_mb(mem)
          mem *= 2
        end

        choices
      end

      def human_mb(num)
        human_size(num * 1024 * 1024, 0)
      end

      def human_size(num, precision = 1)
        sizes = %w(G M K)
        sizes.each.with_index do |suf, i|
          pow = sizes.size - i
          unit = 1024.0 ** pow
          if num >= unit
            return format("%.#{precision}f%s", num / unit, suf)
          end
        end

        format("%.#{precision}fB", num)
      end

      def megabytes(str)
        if str =~ /T$/i
          str.to_i * 1024 * 1024
        elsif str =~ /G$/i
          str.to_i * 1024
        elsif str =~ /M$/i
          str.to_i
        elsif str =~ /K$/i
          str.to_i / 1024
        else # assume megabytes
          str.to_i
        end
      end
    end
  end
end
