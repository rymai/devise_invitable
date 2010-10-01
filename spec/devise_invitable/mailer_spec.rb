require 'spec_helper'

describe Devise::Models::Invitable do
  subject { User.invite(:email => "valid@email.com") }
  
  before(:each) do
    Devise.mailer_sender = "test@example.com"
    ActionMailer::Base.deliveries.clear
    subject # trigger the invitation!
  end
  
  it "should send an email sent on invite" do
    ActionMailer::Base.deliveries.size.should == 1
  end
  
  it "should set content type should be set to html and charset to UTF8" do
    last_delivery.content_type.should == "text/html; charset=UTF-8"
  end
  
  it "should send the email the email of the invited resource" do
    last_delivery.to.should == [subject.email]
  end
  
  it "should set the email sender from Devise configuration file" do
    last_delivery.from.should == ["test@example.com"]
  end
  
  it "should setup email subject from I18n" do
    store_translations :en, :devise => { :mailer => { :invitation_instructions => { :subject => 'You Got An Invitation!' } } } do
      User.invite(:email => "valid2@email.com")
      last_delivery.subject.should == "You Got An Invitation!"
    end
  end
  
  it "should retrieve in priority subject namespaced by model" do
    store_translations :en, :devise => { :mailer => { :invitation_instructions => { :user_subject => 'You Got An User Invitation!' } } } do
      User.invite(:email => "valid2@email.com")
      last_delivery.subject.should == "You Got An User Invitation!"
    end
  end
  
  it "should send an email containing record's email" do
    last_delivery.body.should =~ /#{subject.email}/
  end
  
  it "should send an email containing a link to accept the invitation" do
    last_delivery.body.should =~ %r{<a href=\"http://#{ActionMailer::Base.default_url_options[:host]}/users/invitation/accept/#{subject.invitation_token}">}
  end
  
  def last_delivery
    ActionMailer::Base.deliveries.last
  end
  
end