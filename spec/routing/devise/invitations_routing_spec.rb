require 'spec_helper'

describe Devise::InvitationsController do
  
  it { should route(:get,  "users/invitation/new").to(:action => 'new') }
  it { should route(:post, "users/invitation").to(:action => 'create') }
  it { should route(:get,  "users/invitation/accept/token").to(:action => 'edit', :invitation_token => "token") }
  it { should route(:put,  "users/invitation").to(:action => 'update') }
  
end