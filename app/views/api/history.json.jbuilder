    json.role "student"
    json.id @student_history["student"].id
    json.pname @student_history["student"].pname
    json.startdate @student_history["startdate"].strftime("%a %d/%m/%Y")
    json.enddate @student_history["enddate"].strftime("%a %d/%m/%Y")
    json.lessons @student_history["lessons"] do |lesson|
        json.id lesson[0]
        json.kind lesson[1]
        json.daytime lesson[2].strftime("%a %l:%M %p %d/%m/%Y")
        json.site lesson[3]
        json.tutors lesson[4] do |s|
            json.tutor s
        end
        json.students lesson[5] do |t|
            json.student t
        end
        json.status lesson[6]
    end
