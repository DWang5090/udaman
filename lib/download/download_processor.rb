require 'roo'
require 'csv'

# Error handling in download processor calls
# --------------------------------------------
# line level calls should always raise descriptive errors. 
# Errors can be rescued by Packager or Front End
# as necessary

class DownloadProcessor
  def initialize(handle, options, cached_files = nil)
    raise "File type must be specified when initializing a Download Processor" if options[:file_type].nil?
    
    @cached_files = cached_files.nil? ? DownloadsCache.new : cached_files 
    @handle = handle
    @options = options
    @file_type = options[:file_type]
    @spreadsheet = CsvFileProcessor.new(handle, options, parse_date_options, @cached_files) if @file_type == "csv" and validate_csv
    @spreadsheet = XlsFileProcessor.new(handle, options, parse_date_options, @cached_files) if @file_type == "xls" and validate_xls
  end

  def get_data
    return TextFileProcessor.new(@handle,@options, @cached_files).get_data if @file_type == "txt" #and validate_text
    return get_data_spreadsheet
  end

  def get_data_spreadsheet
    index = 0
    data = {}
    begin
      data_point = @spreadsheet.observation_at index 
      data.merge!(data_point) if data_point.class == Hash
      index += 1
    end until data_point.class == String
    data
  end

  # these two processes are a little weird because they require the handle and other parts of the 
  # pattern that the date processor itself would not generally need. might not be the best object
  # design...
  def parse_date_options
    date_info = {}
    date_info[:start] = @options[:start_date] unless @options[:start_date].nil?
    date_info[:start] = read_date_from_file(@options[:start_row], @options[:start_col]) if @options[:start_date].nil?
    date_info[:rev] = @options[:rev] == true ? true : false
    date_info
  end

  def read_date_from_file(start_row, start_col)
    #assumption is that these will not be files with dates to process. just static file and sheet strings
    #assuming that date is a recognizable format to ruby
    puts @cached_files.csv(@handle)[start_row-1][start_col-1].to_s + "is csv" if @file_type == "csv"
    return @cached_files.csv(@handle)[start_row-1][start_col-1].to_s if @file_type == "csv"
    return @cached_files.xls(@handle, @options[:sheet]).cell(start_row, start_col).to_s if @file_type == "xls"
  end
  
  def validate_csv
    return true unless !date_ok or @options[:row].nil? or @options[:col].nil? or @options[:frequency].nil?
    error_string = ""
    error_string += "start date information, " if !date_ok
    error_string += "row specification, " if @options[:row].nil?
    error_string += "column specification, " if @options[:col].nil?
    error_string += "frequency specification, " if @options[:frequency].nil?
    raise "incomplete Download Processor specification because the following information is missing: " + error_string.chop.chop
  end
  
  def date_ok
    return false if @options[:start_date].nil? and (@options[:start_row].nil? or @options[:start_col].nil?)
    return true
  end
  
  def validate_xls
    return true unless !date_ok or @options[:row].nil? or @options[:col].nil? or @options[:sheet].nil? or @options[:frequency].nil?
    error_string = ""
    error_string += "start date information, " if !date_ok
    error_string += "row specification, " if @options[:row].nil?
    error_string += "column specification, " if @options[:col].nil?
    error_string += "sheet specification, " if @options[:sheet].nil?
    error_string += "frequency specification, " if @options[:frequency].nil?
    raise "incomplete Download Processor specification because the following information is missing: " + error_string.chop.chop
  end
end

