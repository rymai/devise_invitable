require File.dirname(__FILE__) + '/acceptance_helper'

feature "Invitations:" do
  
  [false, true].each do |use_legacy_url|
    context "#{use_legacy_url ? "" : "not "}using legacy url" do
      scenario "not authenticated user who has already accepted invitation but has a nil invitation_token should be redirected to after_sign_out_path_for(resource_name) with an 'invalid invitation token' message" do
        user = invite
        invitation_token = user.invitation_token
        sign_out
        accept_invitation(:invitation_token => user.invitation_token)
        user.invitation_token = nil
        user.save(:validate => false)
        user.invitation_token.should be_nil
        sign_out
        visit_accept_invitation_url(invitation_token, use_legacy_url)
        
        current_url.should == "http://www.example.com/"
        page.should have_content(I18n.t("devise.invitations.invitation_token_invalid"))
      end
      
      scenario "not authenticated user who has already accepted invitation but has a nil invitation_token and a nil accepted_invitation_at should be redirected to after_sign_out_path_for(resource_name) with an 'invalid invitation token' message" do
        user = invite
        invitation_token = user.invitation_token
        sign_out
        accept_invitation(:invitation_token => user.invitation_token)
        user.invitation_token = nil
        user.invitation_accepted_at = nil
        user.save(:validate => false)
        sign_out
        visit_accept_invitation_url(invitation_token, use_legacy_url)
        
        current_url.should == "http://www.example.com/"
        page.should have_content(I18n.t("devise.invitations.invitation_token_invalid"))
      end
    end
  end
  
end