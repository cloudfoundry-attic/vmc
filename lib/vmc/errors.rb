module VMC
  class UserFriendlyError < RuntimeError
    def initialize(msg)
      @message = msg
    end

    def to_s
      @message
    end
  end

  class UserError < UserFriendlyError; end

  class NotAuthorized < UserError
    def initialize
      @message = "Not authorized."
    end
  end
end
