require 'test_helper'

class SlotTest < ActiveSupport::TestCase
  fixtures :slots

  test "Slot creation attributes are valid" do
    slot = Slot.new
    assert slot.invalid?, "creating empty slot object should not be a valid object"
    assert slot.errors[:timeslot].any?, "timeslot must be present"
    assert slot.errors[:location].any?, "location must be present"
    assert slot.errors[:comment].none?, "Comment is not mandatory"

    slot.timeslot = "2016-08-29 17:00:00"
    slot.location = "Woden"
    assert slot.valid?, "adding mandatory fields to student object makes it valid"

 end


  test "slot records must be unique across timeslot and location fields" do
    slot = Slot.new(timeslot: "2016-08-29 17:30:00",
                    location: "Woden")
    assert slot.valid?, "failed verification that initials are OK before check of duplicates"

    slot.timeslot = slots(:one).timeslot
    assert slot.valid?, "duplicate timeslot only allowed"

    slot.timeslot = "2016-08-29 17:30:00"
    slot.location = slots(:one).location
    assert slot.valid?, "duplicate only location allowed"

    slot.timeslot = slots(:one).timeslot
    assert slot.invalid?, "should not allow duplicate combined timeslot and location"
  end


end
