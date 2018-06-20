module TutorsHelper
    def xlateTableField(t, f)
        case t
        when "Tutrole"
            case f
            when "comment"
                return "tutor lesson comment"
            when "status"
                return "tutor lesson status"
            when "kind"
                return "tutor lesson kind"
            end
        when "Tutor"
            case f
            when "comment"
                return "tutor personal comment"
            when "status"
                return "tutor status"
            when "subjects"
                return "tutor subjects"
            end
        when "Role"
            case f
            when "comment"
                return "student lesson comment"
            when "status"
                return "student lesson status"
            when "kind"
                return "student lesson kind"
            end
        when "Student"
            case f
            when "comment"
                return "student comment"
            when "status"
                return "student status"
            when "study"
                return "student study"
            end
        when "Lesson"
            case f
            when "comments"
                return "lesson comment"
            when "status"
                return "lesson status"
            end
        end
        return t + '/' + f 
        
    end
end
