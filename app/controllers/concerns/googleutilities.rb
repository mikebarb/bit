  #app/controllers/concerns/googleutilities.rb
module Googleutilities
    extend ActiveSupport::Concern

    included do
    end

    def googleauthorisation(request)
        # place any code you want executed when concern is invoked.    

        # gems for the authorisation libraries are:
        # gem 'googleauth', :require => ['googleauth/stores/file_token_store', 'googleauth']
        user_id = 'mike'
        # This store (YAML::Store) simply stores and retrieves a passed token against an id.
        store_options = {:file => './google_tokens'}
        token_store = Google::Auth::Stores::FileTokenStore.new(store_options)
        myid = Google::Auth::ClientId.from_file('./client_secrets.json')
        scopes = ['https://www.googleapis.com/auth/spreadsheets']
        myauthorizer = Google::Auth::WebUserAuthorizer.new(myid, scopes, token_store)
        mycredentials = myauthorizer.get_credentials(myid.id, request)
        if mycredentials.nil?
          myoptions = {:user_id => user_id, :request => request}
          myauthorizationurl = myauthorizer.get_authorization_url(myoptions)
          redirect_to myauthorizationurl and return
        end
        # Initialize the Google API to access spreadsheets
        # Note: to make this library work, you must have in the gem file (the require:)
        # gem 'google-api-client', '~> 0.19', require: 'google/apis/sheets_v4'
        service = Google::Apis::SheetsV4::SheetsService.new
        service.client_options.application_name = "bit3"
        service.authorization = mycredentials
        service
    end

#------------------------------------------------------------------------
#
# This set of routines finds the tutorial or student database record 
# matching a name within the provided string
#
#------------------------------------------------------------------------
  # input: string extracted from a spreadsheet cell
  # see if any db name is embedded in this string
  def findTutor(this_string, db_records)
    found = []
    db_records.each do |r|
        mc = r.pname
        if m = this_string.match(/(#{mc})/)
          found.push(m[1])
        end
    end
    found
  end
  
  #input: array of text strings
  #       OR single text string
  #return: array of hashes [{name, comment}, ...]
  def findTutorNameComment(textArray, db_records)
    mytutors = []
    if textArray.class == Array    # array of text strings
        textArray.each do |e1|
          findTutor(e1, db_records).each do |t|
            mytutors.push({"name" => t, "comment" => e1})
          end
        end
    elsif textArray.class == String
        findTutor(textArray, db_records).each do |t|
          #logger.debug "textArray.each t: " + t.inspect
          mytutors.push({"name" => t, "comment" => textArray})
        end
    end
    #logger.debug "mytutors: " + mytutors.inspect
    mytutors
    
  end

  def findStudentNameComment(textArray, db_records)
    #byebug
    thisStudentName = getStudentName(textArray)
    #check if this student is in the database
    thisStudent = @students.where(pname: thisStudentName)
    if thisStudent.length == 0
      return [{"name" => "",
               "comment" => "Student not found in db: #{textArray}"}]
    else
      return [{"name" => thisStudentName,
               "comment" => "#{textArray}"}]
    end      
    #findTutorNameComment(textArray, db_records)
  end
#------------------------------------------------------------------------
#
# This set of routines manipulates names
#
#------------------------------------------------------------------------
  #extract tutor name, subjects from google sheet name + subject used
  # in the scheduling sheet
  # example: JOE F
  #          | M9 S8 E12 |
  def getTutorName(name)
      n = name.match(/([\w ]+?)\n/)
      n.strip
  end
  
  #Extract student name, year and sex from 'Student's Name + Year' which is
  # a spreadsheet field in the student tab.
  # =>Alexandra (Alex) Cosgrove 12
  # =>Aanya Daga 4 (male)
  # =>Riley Howatson 1 (female)
  # =>Amelia Clark (kindy)
  # =>Elisha Stojanovski K
  # =>Bella Parsonage Phelan 8
  def getStudentNameYearSex(name)
      sname = name.strip  # ensure no trailing space
      if n = sname.match(/^(.+)\s(\d+)(.*)/)    # contains a number
          myname = n[1].strip
          myyear = n[2]
          mysex = ""
          if n[3] != nil && n[3] != ""      # third component exists after digit 
              if n[3].match(/female/i)
                  mysex = "female"
              elsif n[3].match(/male/i)
                  mysex = "male"
              end
          end
      else    # no number so must be kindy or missing grade
          # search for 'k' or 'kindy' with or without brackets around it.
          # had trouble matching Joshua Kerr
          #byebug
          #? is there a male or female at the end with or without brackets
          mysex = ""
          if m = sname.match(/(.+)\s\(?(male|female)\)?$/i)     #at end with leading space
            mysex = m[2]
            # keep first section string
            rname = m[1].strip
          else    # n sex portion, keep all as remaining name
            rname = sname.strip
          end
          # now look for kindy/k at end with or without brackets
          if m = rname.match(/(.+)\s(\(?(kindy|k)\)?)$/i)
            myname = m[1].strip
            myyear = "K"
          elsif # no year / kindy so all is name
            myname = rname.strip
            myyear = ""
          end              
      end
      [myname, myyear, mysex]
  end
  
  def getStudentName(name)
      m = getStudentNameYearSex(name)
      m[0]
  end
      

#------------------------------------------------------------------------
#
# This set of routines manipulates colours extracted from the spreadsheet
#
# Key routines are:
# => convert colours into a status
# => display a colour as text.
#
#------------------------------------------------------------------------
  # This routine provides the mapping between colours and their statuses.
  # Done as a routine so that the same dataset can be called from 
  # multiple locations or routines - mapping keyed in once only.
  def getColourStatuses()
    [
      [ [1.0, 1.0, 0.0], {  "tutor"   => "BFL",
                            "student" => "N/A",
                            "colour"  => "Yellow" }
      ],  
      [ [0.0, 1.0, 0.0], {  "tutor"   => "N/A",
                            "student" => "1stFree",
                            "colour"  => "Green" }
      ],  
      [ [0.7137255, 0.84313726, 0.65882355], {
                            "tutor"   => "Dickson Tutor",
                            "student" => "1stPaid",
                            "colour"  => "Light Green 2" }
      ],  
      [ [1.0, 0.0, 0.0], {  "student" => "undealtAbsent",
                            "tutor"   => "undealtAbsent",
                            "colour"  => "Red" }
      ],  
      [ [1.0, 0.6, 0.0], {  "tutor"   => "Know steps remaining",
                            "student" => "Know steps remaining",
                            "colour"  => "Orange" }
      ],  
      [ [1.0, 0.0, 1.0], {  "tutor"   => "Needs Attention",
                            "student" => "Needs Attention",
                            "colour"  => "Pink" }
      ],  
      [ [0.0, 1.0, 1.0], {  "tutor"   => "breakRoutine",
                            "student" => "breakRoutne",
                            "colour"  => "Cyan" }
      ],  
      [ [0.6, 0.0, 1.0], {  "tutor"   => "bewareIssue",
                            "student" => "bewareIssue",
                            "colour"  => "Purple" }
      ],  
      [ [0.4, 0.4, 0.4], {  "tutor"   => "dealtAbsent",
                            "student" => "dealtAbsent",
                            "colour"  => "Gray" }
      ],  
      [ [0.63529414, 0.76862746, 0.7882353], {
                            "tutor"   => "fortnightly",
                            "student" => "fortnightly",
                            "colour"  => "Light-cyan 2" }
      ],  
      [ [0.8, 0.0, 0.0], {  "tutor"   => "red",
                            "student" => "red",
                            "colour"  => "Dark Red" }
      ],
      [ [0.42745098, 0.61960787, 0.92156863], {
                            "tutor"   => "T3W1",
                            "student" => "T3W1",
                            "colour"  => "Light Cornflower Blue1" }
      ],  
      [ [0.8352941, 0.6509804, 0.7411765], {
                            "tutor"   => "On Call",
                            "student" => "On Call",
                            "colour"  => "Light Magneta 2" }
      ],  
      [ [ 0.91764706, 0.81960785, 0.8627451], {
                            "tutor"   => "Setup",
                            "student" => "Setup",
                            "colour"  => "Light Magneta 3" }
      ],  
      [ [0.7882353, 0.85490197, 0.972549], {
                            "tutor"   => "Gungahlin Student",
                            "student" => "Gungahlin Student",
                            "colour"  => "Light Green 3" }
      ],  
      [ [0.8509804, 0.8235294, 0.9137255], {
                            "tutor"   => "Kaleen Student",
                            "student" => "Kaleen Student",
                            "colour"  => "Light Purple 3" }
      ],  
      [ [0.8509804, 0.91764706, 0.827451], {
                            "tutor"   => "Dickson Student",
                            "student" => "Dickson Student",
                            "colour"  => "Light Green 3" }
      ],
      [ [0.8509804, 0.8509804, 0.8509804], {
                            "tutor"   => "Woden Student",
                            "student" => "Woden Student",
                            "colour"  => "Light Grey 1" }
      ],  
      [ [1.0, 0.9490196, 0.8], {
                            "tutor"   => "Kambah Student",
                            "student" => "Kambah Student",
                            "colour"  => "Light Yellow 3" }
      ],  
      [ [0.9882353, 0.8980392, 0.8039216], {
                            "tutor"   => "Notes",
                            "student" => "Notes",
                            "colour"  => "Light Orange 3" }
      ],  
      [ [1.0, 1.0, 1.0], {
                            "tutor"   => "Blank cell",
                            "student" => "Blank cell",
                            "colour"  => "White" }
      ], 
      [ [0.6431373, 0.7607843, 0.95686275], {
                            "tutor"   => "Gungahlin Tutor",
                            "student" => "Gungahlin Tutor",
                            "colour"  => "Light Cornflower Blue 2" }
      ],  
      [ [0.6, 0.6, 0.6], {
                            "tutor"   => "Tutor note",
                            "student" => "Tutor note",
                            "colour"  => "Dark Grey 2" }
      ],
      [ [0.7058824, 0.654902, 0.8392157], {
                            "tutor"   => "Kaleen Tutor",
                            "student" => "Kaleen Tutor",
                            "colour"  => "Light Purple 2" }
      ],
      [ [0.7176471, 0.7176471, 0.7176471], {
                            "tutor"   => "Woden Tutor",
                            "student" => "Woden Tutor",
                            "colour"  => "Dark Grey 1" }
      ],
      [ [1.0, 0.8980392, 0.6], {
                            "tutor"   => "Kambah Tutor",
                            "student" => "Kambah Tutor",
                            "colour"  => "Light Yellow 2" }
      ]
    ]
  end

# In the google spreadsheet, colours have specific meanings.
# this routine convers colours into meaningful statuses.
  def colourToStatus(mycolour)
    mc = colourToArray(mycolour)
    if mc != nil 
        colourStatuses = getColourStatuses()
        colourStatuses.each do |row|
        if mc == row[0]
          return row[1]
        end
      end
    end
    return {"student" => "", "tutor" => "", "colour" => ""};
  end
  
  # convert the colour object into a text string
  # google colour => string "R:G:B number:number:number"
  def showcolour(o, sf_colour = nil)
    #sf_colour  # make number smaller = significant figures for decimals
    outcolour = "R:G:B "
    if o != nil
      cr = o.red   ? o.red.to_d   : 0.0.to_d
      cg = o.green ? o.green.to_d : 0.0.to_d
      cb = o.blue  ? o.blue.to_d  : 0.0.to_d
      if(sf_colour)
        cr = cr.truncate(sf_colour)
        cg = cg.truncate(sf_colour)
        cb = cb.truncate(sf_colour)
      end
      outcolour += "#{cr.to_s}:#{cg.to_s}:#{cb.to_s}"
    end
    outcolour
  end

  # generic colour to an array
  # input: colour object as obtained from google spreadsheet cell properties
  #        OR colour string in format "R:G:B red_value:green_value:blue_value"
  #        OR array [red_value, green_value, blue_value]
  # returns: array
  #          OR nil if invalid colour format.
  def colourToArray(mycolour)
    if mycolour.class == String &&
      mycolour.match(/^(R:G:B)/)
      if mycolour.match(/\d/)
        m=mycolour.match(/(R:G:B) ([\d\.]+):([\d\.]+):([\d\.]+)/)
        return [m[2].to_f, m[3].to_f, m[4].to_f]
      else
        return nil
      end
    elsif mycolour.class == Array &&
      mycolour.length == 3
      return mycolour
    elsif mycolour.class == Google::Apis::SheetsV4::Color
      m = colourObjectToArray(mycolour)
      return m
    else
      return nil
    end
  end

  def colourObjectToArray(o) 
        c1_r   = o.red   ? o.red.to_f    : 0.0
        c1_g   = o.green ? o.green.to_f  : 0.0
        c1_b   = o.blue  ? o.blue.to_f   : 0.0
        [c1_r, c1_g, c1_b]
  end  

  
  # match two colours
  # o1 & o2 are two google colour objects
  # variation is the difference allowed in absolute
  # values - defaults to 0 meaning exact match
  def matchcolourObjects(colourArray1, colourArray2, 
                        varation = 0)
      matchcolourArrays(colourObjectToArray(colourArray1),
                        colourObjectToArray(colourArray1),
                        varation)
  end
  
  # do the actual matching colourArrays are an array containing
  # the values for [0]=red_value [1]=green_value and [2]=blue_value
  def matchcolourArrays(colourArray1, colourArray2, varation = 0)
        c1_r   = colourArray1[0]
        c1_g   = colourArray1[1]
        c1_b   = colourArray1[2]
        c2_r   = colourArray2[0]
        c2_g   = colourArray2[1]
        c2_b   = colourArray2[2]
        # c1 matches within a window around c2
        m = m_r = m_g = m_b = FALSE 
        m_r = TRUE if c1_r < c2_r+varation &&
                      c1_r > c2_r-varation
        m_g = TRUE if c1_g < c2_g+varation &&
                      c1_g > c2_g-varation
        m_b = TRUE if c1_b < c2_b+varation &&
                      c1_b > c2_b-varation
        m = TRUE if m_r && m_g && m_b
        m
  end
  
  
  
#------------------------------------------------------------------------
# Helper routnes to get values and formats form a spreadsheet cell
#
# Key routines are:
# => getvalue(cell)
# => getformat(cell)
#------------------------------------------------------------------------
  # use: cell_value = getvalue(row.values[j])
  def getvalue(cell) 
        #cc = r.values[j]
        cc = cell
        cx = ""
        if cc
          if cc.formatted_value
            cvx = cc.formatted_value
            cvx == nil ? cx = "" : cx = cvx.strip #ensure clean value
          end
        end
        cx
  end
  
  # use: cell_background_color = getformat(row.values[j])
  def getformat(cell)
        cc = cell
        cf = nil
        if cc
          if cc.effective_format
            cf = cc.effective_format.background_color
          end
        end
        cf
  end

end
    
    