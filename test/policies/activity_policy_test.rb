require "test_helper"

class ActivityPolicyTest < ActiveSupport::TestCase
  test "das Aktivitätsprotokoll sehen nur Moderation und Administration" do
    assert_not ActivityPolicy.new(nil, :activity).index?
    assert_not ActivityPolicy.new(users(:anna), :activity).index?
    assert ActivityPolicy.new(users(:moni), :activity).index?
    assert ActivityPolicy.new(users(:admin), :activity).index?
  end
end
