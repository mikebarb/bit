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
    
      #Extract student name, year and sex from 'Sudent's Name + Year'
      #Alexandra (Alex) Cosgrove 12
      #Aanya Daga 4 (male)
      #Riley Howatson 1 (female)
      #Amelia Clark (kindy)
      #Elisha Stojanovski K
      #Bella Parsonage Phelan 8
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
      
  # convert the colour object into a text string
  # google colour => string "R:G:B number:number:number"
  def showcolour(o, sf_colour = 3)
        #sf_colour = 2             # make numer smaller
        outcolour = "R:G:B "
        outcolour += o.red ? o.red.to_d.truncate(sf_colour).to_s : '0.0'
        outcolour += ' : '
        outcolour += o.green ? o.green.to_d.truncate(sf_colour).to_s : '0.0'
        outcolour += ' : '
        outcolour += o.blue ? o.blue.to_d.truncate(sf_colour).to_s : '0.0'
  end

  #extract tutor name, subjects from google sheet name + subject used
  # in the scheduling sheet
  # example: JOE F
  #          | M9 S8 E12 |
  def getTutorName(name)
      n = name.match(/([\w ]+?)\n/)
      n.strip
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
  
  def colourObjectToArray(o) 
        c1_r   = o.red   ? o.red.to_d    : 0
        c1_g   = o.green ? o.green.to_d  : 0
        c1_b   = o.blue  ? o.blue.to_d   : 0
        [c1_r, c1_g, c1_b]
  end  
  
  # use: cell_value = getvalue(row.values[j])
  def getvalue1(cell) 
        #cc = r.values[j]
        cc = cell
        cx = ""
        if cc
          if cc.formatted_value
            #cvx = cc.effective_value.string_value
            cvx = cc.formatted_value
            cvx == nil ? cx = "" : cx = cvx.strip #ensure clean value
          end
        end
        cx
  end
  
  # use: cell_background_color = getformat(row.values[j])
  def getformat1(cell)
        #cc = r.values[j]
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
    
    