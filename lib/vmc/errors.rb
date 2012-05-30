module VMC
  class UserError < RuntimeError
    def initialize(msg)
      @message = msg
    end

    def to_s
      @message
    end
  end

  class NotAuthorized < UserError
    def initialize
      @message = "Not authorized."
    end
  end
end
