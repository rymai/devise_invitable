module DeviseInvitable
  module Controllers
    module Helpers
    protected
      # This method is used as a before_filter in the InvitationsController.
      # Override it in your ApplicationController to fit your needs.
      def authenticate_inviter!
        send(:"authenticate_#{resource_name}!")
      end
    end
  end
end
ActionController::Base.send :include, DeviseInvitable::Controllers::Helpers