require "#{File.dirname(__FILE__)}/../lib/git_store"
require 'pp'

describe GitStore::User do
  it 'should parse a user string' do
    user = GitStore::User.parse('Mr. T <mr.t@a-team.us> 1234567890 -0600')
    user.name.should == 'Mr. T'
    user.email.should == 'mr.t@a-team.us'
    user.time.should == Time.at(1234567890 - 2160000)
  end
end
