require 'spec_helper'

describe Devise::Models::Invitable do
  
  describe "Non-disturbance" do
    subject { Factory(:user) }
    
    context "non invited record" do
      it "should not disable password validations on new record" do
        user = Factory.build(:user, :password => "123")
        user.should_not be_valid
        user.errors[:password].should be_present
      end
      
      it "should not disable password validations on persisted record" do
        subject.update_attributes(:password => "123")
        subject.errors[:password].should be_present
      end
      
      it "should not generate invitation token after creating a record" do
        subject.invitation_token.should be_nil
      end
      
      it "should be possible to edit name without entering password" do
        subject.name = "Jack Daniels"
        subject.should be_valid
        subject.save
        subject.reload.name.should == "Jack Daniels"
      end
    end
    
    context "invited record" do
      subject { User.invite(:email => "valid@email.com") }
      
      it "should be possible to edit name without entering password" do
        subject.name = "Jack Daniels"
        subject.should be_valid
        subject.save
        subject.reload.name.should == "Jack Daniels"
      end
    end
  end
  
  describe "Class Methods" do
    describe ".invite" do
      subject { User.invite(:email => "valid@email.com") }
      
      it "should return a record with no errors" do
        subject.errors.should be_empty
      end
      
      it "should set invitation_token" do
        subject.invitation_token.should be_present
      end
      
      it "should send invitation email" do
        emails_sent { subject }
      end
      
      it "should return a record with no errors, set invitation_token and send invitation email even if user is invalid and Devise.validate_on_invite = false" do
        emails_sent do
          Devise.stub!(:validate_on_invite).and_return(false)
          user = User.invite(:email => "valid@email.com", :name => "a"*50)
          user.should be_persisted
          user.invitation_token.should be_present
        end
      end
      
      it "should return a new record with errors, no invitation_token and no email sent if user is invalid and Devise.validate_on_invite = true" do
        emails_not_sent do
          Devise.stub!(:validate_on_invite).and_return(true)
          user = User.invite(:email => "valid@email.com", :name => "a"*50)
          user.should be_new_record
          user.errors[:name].size.should == 1
          user.invitation_token.should be_nil
          Devise.stub!(:validate_on_invite).and_return(false)
        end
      end
      
      it "should set additional accessible attributes" do
        User.invite(:email => "valid@email.com", :name => "John Doe").name.should == "John Doe"
      end
      
      it "should skip confirmation if user is confirmable" do
        User.invite(:email => "valid@email.com").confirmed_at.should be_present
      end
      
      it "should return existing user with errors if email has already been taken" do
        user = Factory(:user)
        invited_user = User.invite(:email => user.email)
        invited_user.should == user
        invited_user.errors[:email].should == ["has already been taken"]
      end
      
      it "should return a new record with errors if email is blank" do
        [nil, ""].each do |email|
          user = User.invite(:email => email)
          user.should be_new_record
          user.errors[:email].should == ["can't be blank"]
        end
      end
      
      it "should return a new record with errors if email is invalid" do
        user = User.invite(:email => "invalid_email")
        user.should be_new_record
        user.errors[:email].should == ["is invalid"]
      end
    end
    
    describe ".accept_invitation"do
      subject { User.invite(:email => "valid@email.com") }
      
      it "should find a user to set his password with a given invitation_token" do
        User.accept_invitation(:invitation_token => subject.invitation_token).should == subject
      end
      
      it "should return a new record with errors if the given invitation token is not found" do
        user = User.accept_invitation(:invitation_token => "invalid_token")
        user.should be_new_record
        user.errors[:invitation_token].should == ["is invalid"]
      end
      
      [nil, ""].each do |invitation_token|
        it "should return a new record with errors if the given invitation token is #{invitation_token.to_s}" do
          user = User.accept_invitation(:invitation_token => invitation_token)
          user.should be_new_record
          user.errors[:invitation_token].should == ["can't be blank"]
        end
      end
      
      it "should return record with errors if the given invitation token is expired" do
        subject.invitation_sent_at = 2.days.ago
        subject.save(:validate => false)
        User.stub!(:invite_for).and_return(10.hours)
        invited_user = User.accept_invitation(:invitation_token => subject.invitation_token)
        invited_user.should == subject
        invited_user.errors[:invitation_token].should == ["is invalid"]
      end
      
      context "invalid record" do
        context "no password given" do
          before(:each) { User.accept_invitation(:invitation_token => subject.invitation_token) }
          
          it "should not set invitation_accepted_at" do
            subject.invitation_accepted_at.should be_nil
          end
          
          it "should not clear invitation token" do
            subject.invitation_token.should be_present
          end
        end
        
        context "invalid password" do
          before(:each) { User.accept_invitation(:invitation_token => subject.invitation_token, :password => "12") }
          
          it "should not set invitation_accepted_at" do
            subject.invitation_accepted_at.should be_nil
          end
          
          it "should not clear invitation token" do
            subject.invitation_token.should be_present
          end
        end
        
        context "invalid other attributes" do
          before(:each) { User.accept_invitation(:invitation_token => subject.invitation_token, :password => "123456", :name => "a"*50) }
          
          it "should not set invitation_accepted_at" do
            subject.invitation_accepted_at.should be_nil
          end
          
          it "should not clear invitation token" do
            subject.invitation_token.should be_present
          end
        end
        
        it "should return a record with errors" do
          invited_user = User.accept_invitation(:invitation_token => subject.invitation_token, :password => "new_password", :name => "a"*50)
          invited_user.errors.should be_present
        end
      end
      
      context "valid record" do
        it "should not clear invitation token with a valid password" do
          subject.invitation_token.should be_present
          User.accept_invitation(:invitation_token => subject.invitation_token, :password => "123456")
          subject.invitation_token.should be_present
        end
        
        it "should set password from params" do
          user = User.accept_invitation(:invitation_token => subject.invitation_token, :password => "123456789")
          user.should be_valid_password("123456789")
        end
        
        it "should be able to change the record's attributes during the invitation acceptation" do
          user = User.invite(:email => "valid@email.com")
          invited_user = User.accept_invitation(:invitation_token => user.invitation_token, :email => "new@email.com", :password => "new_password")
          invited_user.email.should == "new@email.com"
        end
      end
    end
  end
  
  describe "Instance Methods" do
    describe "#invited?" do
      subject { Factory.build(:invited_user) }
      
      it "should be invited? after invite" do
        subject.invite
        subject.should be_invited
      end
      
      it "should be invited? even after accepting invitation" do
        subject.invite
        subject.accept_invitation
        subject.should be_invited
      end
    end
    
    describe "#invitation_accepted?" do
      subject { Factory.build(:invited_user) }
      
      it "should be invitation_accepted? after accept_invitation" do
        subject.invite
        subject.password = "123456"
        subject.accept_invitation
        subject.should be_invitation_accepted
      end
    end
    
    describe "#valid_invitation?" do
      subject { User.invite(:email => "valid@email.com") }
      
      it "should always be a valid invitation if invite_for is nil" do
        Devise.stub!(:invite_for).and_return(nil)
        subject.invitation_sent_at = 10.years.ago
        subject.reload.should be_valid_invitation
      end
      
      it "should always be a valid invitation if invite_for is 0" do
        Devise.stub!(:invite_for).and_return(0)
        subject.invitation_sent_at = 10.years.ago
        subject.reload.should be_valid_invitation
      end
      
      it "should be a valid invitation if the date of invitation is between today and the invite_for interval" do
        Devise.stub!(:invite_for).and_return(10.days)
        subject.invitation_sent_at = 5.days.ago
        subject.reload.should be_valid_invitation
      end
      
      it "should not be a valid invitation if the date of invitation is older than the invite_for interval" do
        Devise.stub!(:invite_for).and_return(10.days)
        subject.invitation_sent_at = 15.days.ago
        subject.should_not be_valid_invitation
        Devise.stub!(:invite_for).and_return(0)
      end
    end
    
    describe "#invite" do
      context "an invalid new record" do
        subject { Factory.build(:invited_user, :name => "a"*50) }
        
        context "with Devise.validate_on_invite = true" do
          before(:each) do
            Devise.stub!(:validate_on_invite).and_return(true)
            subject.invite
          end
          
          it "should add errors to the record" do
            subject.errors.should be_present
          end
          
          it "should not persist the record" do
            subject.should be_new_record
          end
          
          it "should not set an invitation token " do
            subject.invitation_token.should be_nil
          end
          
          it "should not send invitation email" do
            emails_not_sent do
              subject.invite
            end
          end
        end
        
        context "with Devise.validate_on_invite = false" do
          before(:each) do
            Devise.stub!(:validate_on_invite).and_return(false)
            subject.invite
          end
          
          it "should add errors to the record" do
            subject.errors.should be_empty
          end
          
          it "should persist the record" do
            subject.should be_persisted
          end
          
          it "should set an invitation token" do
            subject.invitation_token.should be_present
          end
          
          it "should send invitation email" do
            emails_sent do
              subject.invite
            end
          end
        end
      end
      
      context "a valid new record" do
        subject { Factory.build(:invited_user) }
        
        context "with Devise.validate_on_invite = true" do
          before(:each) do
            Devise.stub!(:validate_on_invite).and_return(true)
            subject.invite
          end
          
          it "should not add errors to the record" do
            subject.errors.should be_empty
          end
          
          it "should persist the record" do
            subject.should be_persisted
          end
          
          it "should set an invitation token" do
            subject.invitation_token.should be_present
          end
          
          it "should send invitation email" do
            emails_sent do
              subject.invite
            end
          end
        end
        
        context "with Devise.validate_on_invite = false" do
          before(:each) do
            Devise.stub!(:validate_on_invite).and_return(false)
            subject.invite
          end
          
          it "should not add errors to the record" do
            subject.errors.should be_empty
          end
          
          it "should persist the record" do
            subject.should be_persisted
          end
          
          it "should set an invitation token" do
            subject.invitation_token.should be_present
          end
          
          it "should send invitation email" do
            emails_sent do
              subject.invite
            end
          end
        end
        
        it "should set additional accessible attributes" do
          user = Factory.build(:invited_user, :name => "John Doe")
          user.invite
          user.name.should == "John Doe"
        end
        
        it "should skip confirmation if user is confirmable" do
          user = Factory.build(:invited_user)
          user.invite
          user.confirmed_at.should be_present
        end
        
        it "should set invitation_sent_at on each new User#invite" do
          user = User.invite(:email => "valid@email.com")
          user.invitation_sent_at = 10.days.ago
          user.save(:validate => false)
          old_invitation_sent_at = user.invitation_sent_at
          user.invite
          old_invitation_sent_at.should_not == user.invitation_sent_at
        end
        
        it "should not generate a new invitation token on each new User#invite" do
          user = User.invite(:email => "valid@email.com")
          2.times do
            old_token = user.invitation_token
            user.invite
            old_token.should == user.invitation_token
          end
        end
        
        it "should generate a new invitation token on each new User#invite with :reset_invitation_token option is present" do
          user = User.invite(:email => "valid@email.com")
          2.times do
            old_token = user.invitation_token
            user.invite(:reset_invitation_token => true)
            old_token.should_not == user.invitation_token
          end
        end
      end
      
      context "a persisted & not invited record" do
        subject { Factory(:user) }
        before(:each) { subject.invite }
        
        it "should not set invitation_sent_at" do
          subject.invitation_sent_at.should be_nil
        end
        
        it "should not set invitation_token" do
          subject.invitation_token.should be_nil
        end
        
        it "should not send invitation email" do
          emails_not_sent do
            subject.invite
          end
        end
      end
    end
    
    describe "#accept_invitation" do
      subject { User.invite(:email => "valid@email.com") }
      
      context "invalid record" do
        context "no password given" do
          before(:each) { subject.accept_invitation }
          
          it "should not set invitation_accepted_at" do
            subject.invitation_accepted_at.should be_nil
          end
          
          it "should not clear invitation token" do
            subject.invitation_token.should be_present
          end
        end
        
        context "invalid password" do
          before(:each) do
            subject.password = "12"
            subject.accept_invitation
          end
          
          it "should not set invitation_accepted_at" do
            subject.invitation_accepted_at.should be_nil
          end
          
          it "should not clear invitation token" do
            subject.invitation_token.should be_present
          end
        end
        
        context "invalid other attributes" do
          before(:each) do
            subject.password = "123456"
            subject.name = "a"*50
            subject.accept_invitation
          end
          
          it "should not set invitation_accepted_at" do
            subject.invitation_accepted_at.should be_nil
          end
          
          it "should not clear invitation token" do
            subject.invitation_token.should be_present
          end
          
          it "should return a record with errors" do
            subject.errors.should be_present
          end
        end
        
      end
      
      context "valid password given" do
        before(:each) { subject.password = "123456" }
        
        it "should set invitation_accepted_at" do
          subject.invitation_accepted_at.should be_nil
          subject.accept_invitation
          subject.invitation_accepted_at.should be_present
        end
        
        it "should not clear invitation_token" do
          subject.invitation_token.should be_present
          subject.accept_invitation
          subject.invitation_token.should be_present
        end
        
        it "should set password" do
          subject.accept_invitation
          subject.encrypted_password.should be_present
        end
      end
    end
  end
  
end