class AdminsController < ApplicationController
  #require 'google/apis/drive_v2'
  #Drive = Google::Apis::DriveV2
  # GET /admins/load
  # GET /admins/load.json
  def load2
    #Google::Apis.logger.level = Logger::ERROR
    user_id = 'mike'
    # This store (YAML::Store) simply stores and retrieves a passed token against an id.
    store_options = {:file => './google_tokens'}
    token_store = Google::Auth::Stores::FileTokenStore.new(store_options)
    myid = Google::Auth::ClientId.from_file('./client_secrets.json')
    scopes = ['https://www.googleapis.com/auth/spreadsheets']
    myauthorizer = Google::Auth::WebUserAuthorizer.new(myid, scopes, token_store)
    #byebug
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
    spreadsheet_id = '1CbtBqeHyYb9jRmROCgItS2eEaYSwzOMpQZdUWLMvjng'
    range = 'TUTORS!B:C'
    logger.debug 'about to read spreadsheet'
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    @tutors = Array.new(response.values.length){Array.new(4)}
    logger.debug "tutors: " + @tutors.inspect
    rowcount = colcount = 0			   
    response.values.each do |r|
        #logger.debug "============ row #{rowcount} ================"
        #logger.debug "row: " + r.inspect
        colcount = 0
        @tutors[rowcount][0] = rowcount + 1
        r.each do |c|
          #logger.debug "============ cell value for column #{colcount} ================"
    	    #logger.debug "cell value: " + c.inspect
    	    @tutors[rowcount][1 + colcount] = c
    	          #bc = v.effective_format.background_color
    	          #logger.debug  "background color: red=" + bc.red.to_s +
    	          #              " green=" + bc.green.to_s +
    		        #              " blue=" + bc.blue.to_s
    		  colcount = colcount + 1
        end
        rowcount = rowcount + 1
    end
    #now get the comments field
    range = 'TUTORS!EC:EC'
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    				   #fields: "sheets(data)")
    				   #fields: "sheets(data,properties)")
    rowcount = colcount = 0			   
    response.values.each do |r|
        colcount = 0
        r.each do |c|
          #logger.debug "============ cell value for column #{colcount} ================"
    	    #logger.debug "cell value: " + c.inspect
    	    @tutors[rowcount][3 + colcount] = c
    	          #bc = v.effective_format.background_color
    	          #logger.debug  "background color: red=" + bc.red.to_s +
    	          #              " green=" + bc.green.to_s +
    		        #              " blue=" + bc.blue.to_s
    		  colcount = colcount + 1
        end
        rowcount = rowcount + 1
    end

    #logger.debug "tutors: " + @tutors.inspect
    #exit

  end

end
