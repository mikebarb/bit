require 'test_helper'

class StudentTest < ActiveSupport::TestCase
  fixtures :students

  test "Student creation attributes are valid" do
    student = Student.new
    assert student.invalid?, "creating empty student object is not a valid object"
    assert student.errors[:gname].any?, "Given Name must be present"
    assert student.errors[:sname].any?, "Family Name must be present"
    assert student.errors[:initials].any?, "Initials must be present"
    assert student.errors[:pname].none?, "Preferred Name is not mandatory"
    assert student.errors[:sex].none?, "Sex is not mandatory"

    student.gname = "Mike"
    student.sname = "McAuliffe"
    student.initials = "MM"
    student.sex = "male"
    assert student.valid?, "adding mandatory fields to student object makes it valid"

    ok = %w{ male female }
    bad = %w{ m f ma fe mal fem fema femal x xxx girl boy }

    ok.each do |name|
      student.sex = name
      assert student.valid?, "student must be male or female or blank"
    end
    bad.each do |name|
      student.sex = name
      assert student.invalid?, "student must be male or female or blank - #{name} is invalid"
    end

 end


  test "Student initials must be unique" do
    student = Student.new(initials: "JS",
                             gname: "John",
                             sname: "Smith",
                             pname: "Jack",
                             sex:   "male" )
    assert student.valid?, "failed verification that initials are OK before check of duplicates"
    student.initials = students(:one).initials
    assert student.invalid?, "cannot have duplicate initials"
  end

end
