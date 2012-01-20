class PackagerMailer < ActionMailer::Base
  default :from => "udaman@hawaii.edu"
  
  # def rake_notification(rake_task, download_string, error_string, summary_string)
  #   @download_string = download_string
  #   @error_string = error_string
  #   @summary_string = summary_string
  #   mail(:to => ["bentut@gmail.com","btrevino@hawaii.edu"], :subject => "UDAMAN New Download or Error (#{rake_task})")
  # end

  def rake_notification(rake_task, download_results, errors, series, output_path, dates)
    @download_results = download_results
    @errors = errors
    @series = series
    @output_path = output_path
    @dates = dates
    mail(:to => ["btrevino@hawaii.edu", "jchfung@hawaii.edu", "james29@hawaii.edu", "icintina@gmail.com", "fuleky@hawaii.edu", "bonham@hawaii.edu"], :subject => "UDAMAN New Download or Error (#{rake_task})")
  end
  
  def rake_error(e, output_path)
    @error = e
    @output_path = output_path
    mail(:to => ["btrevino@hawaii.edu"], :subject => "Rake failed in an unexpected way")
  end

  
end