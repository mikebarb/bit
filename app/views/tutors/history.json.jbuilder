    json.role "tutor"
    json.id @tutor_history["tutor"].id
    json.pname @tutor_history["tutor"].pname
    json.startdate @tutor_history["startdate"].strftime("%a %d/%m/%Y")
    json.enddate @tutor_history["enddate"].strftime("%a %d/%m/%Y")
    json.lessons @tutor_history["lessons"] do |lesson|
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
