require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "Name ist Pflicht und eindeutig" do
    assert_not Category.new.valid?
    assert_not Category.new(name: "aufstriche").valid?
  end
end
