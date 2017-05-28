require 'test_helper'

class TutorTest < ActiveSupport::TestCase
  test "Tutor creation attributes are valid" do
    tutor = Tutor.new
    assert tutor.invalid?, "creating empty student object is not a valid object"
    assert tutor.errors[:gname].any?, "Given Name must be present"
    assert tutor.errors[:sname].any?, "Family Name must be present"
    assert tutor.errors[:initials].any?, "Initials must be present"
    assert tutor.errors[:pname].none?, "Preferred Name is not mandatory"
    assert tutor.errors[:sex].none?, "Sex is not mandatory"

    tutor.gname = "Mike"
    tutor.sname = "McAuliffe"
    tutor.initials = "MM"
    tutor.sex = "male"
    assert tutor.valid?, "adding mandatory fields to tutor object makes it valid"

    ok = %w{ male female }
    bad = %w{ m f ma fe mal fem fema femal x xxx girl boy }

    ok.each do |name|
      tutor.sex = name
      assert tutor.valid?, "tutor must be male or female or blank"
    end
    bad.each do |name|
      tutor.sex = name
      assert tutor.invalid?, "tutor must be male or female or blank - #{name} is invalid"
    end

  end


  test "Tutor initials must be unique" do
   tutor = Student.new(initials: "JS",
                             gname: "John",
                             sname: "Smith",
                             pname: "Jack",
                             sex:   "male" )
    assert tutor.valid?, "failed verification that initials are OK before check of duplicates"
    tutor.initials = students(:one).initials
    assert tutor.invalid?, "cannot have duplicate initials"
  end


end
