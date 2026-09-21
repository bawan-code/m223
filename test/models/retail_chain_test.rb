require "test_helper"

class RetailChainTest < ActiveSupport::TestCase
  test "Name ist Pflicht und eindeutig" do
    assert_not RetailChain.new.valid?
    assert_not RetailChain.new(name: "MIGROS").valid?
  end
end
