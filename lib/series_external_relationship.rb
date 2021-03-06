module SeriesExternalRelationship
  def find_prognoz_data_file
  	pdfs = PrognozDataFile.all
  	pdfs.each do |pdf|
  		return pdf if pdf.series_loaded.include?(self.name) 
  	end
  	return nil
  end
  
   def set_output_series(multiplier)
     self.update_attributes(:mult => multiplier)
   end
  
  def toggle_mult
    self.mult ||= 1
    return set_output_series(1000) if self.mult == 1
    return set_output_series(10) if self.mult == 1000
    return set_output_series(1) if self.mult == 10
  end
  
  def a_diff(value, series_value)
    # diff_trunc = (value - series_value.aremos_trunc).abs  
    # diff_round = (value - series_value.single_precision.aremos_round).abs  
    # diff_sci = (value - series_value.single_precision.to_sci).abs
    # return diff_sci if diff_sci < diff_round and diff_sci < diff_trunc  
    # diff_first = diff_trunc < diff_round ? diff_trunc : diff_round
    # diff_second = diff_first < diff_sci ? diff_first : diff_sci
    
    diff_trunc = (value - series_value.aremos_trunc).abs.round(3)  
    diff_sig_5 = (value.sig_digits(5).round(3) - series_value.sig_digits(5).round(3)).abs
    diff_sig_6 = (value.sig_digits(6).round(3) - series_value.sig_digits(6).round(3)).abs

    diff_first = diff_trunc < diff_sig_5 ? diff_trunc : diff_sig_5
    diff_second = diff_first < diff_sig_6 ? diff_first : diff_sig_6
        
    #diffsecond used to have to be greater than 0.001. Turned down sensitivity... on 4/12/13 to address the big subtraction problem
    return diff_second > 0.01 ? diff_second : 0
  end
  
  def Series.a_diff(value, series_value)    
    diff_trunc = (value - series_value.aremos_trunc).abs.round(3)  
    diff_sig_5 = (value.sig_digits(5).round(3) - series_value.sig_digits(5).round(3)).abs
    diff_sig_6 = (value.sig_digits(6).round(3) - series_value.sig_digits(6).round(3)).abs

    diff_first = diff_trunc < diff_sig_5 ? diff_trunc : diff_sig_5
    diff_second = diff_first < diff_sig_6 ? diff_first : diff_sig_6
    
    return diff_second > 0.001 ? diff_second : 0
  end
  
  #no test or spec for this
  def aremos_comparison(save_series = true)
    begin
      as = AremosSeries.get self.name
      if as.nil?
        #puts "NO MATCH: #{self.name}"
        self.aremos_missing = "-1"
        self.save if save_series
        return {:missing => "No Matching Aremos Series", :diff => "No Matching Aremos Series"}
      end
      missing_keys = (as.data.keys - self.data.keys)
      
      #remove all suppressed values
      missing_keys.delete_if {|key| as.data[key] == 1000000000000000.0}
      
      self.aremos_missing = missing_keys.count
      self.aremos_diff = 0
      #self.units ||= 1
      as.data.each do |datestring, value|
        unless self.data[datestring].nil?
          #have to do all the rounding because it still seems to suffer some precision errors after initial rounding
          diff = a_diff(value, self.units_at(datestring))
          self.aremos_diff +=  diff 
          puts "#{self.name}: #{datestring}: #{value}, #{self.units_at(datestring)} diff:#{diff}" if diff != 0
        end
      end
      self.save if save_series
      #puts "Compared #{self.name}: Missing: #{self.aremos_missing} Diff:#{self.aremos_diff}"
      return {:missing => self.aremos_missing, :diff => self.aremos_diff}
    rescue Exception => e
      puts e.message
      puts "ERROR WITH \"#{self.name}\".ts.aremos_comparison"
    end
  end
  
  def Series.aremos_quick_diff(name, data)
    as = AremosSeries.get name
    aremos_diff = 0
    a_data = as.data
    data.each do |date_string, val|
      
      a_val = a_data[date_string]
      s_val = val #could use units at... might screw up with scale
      #puts "#{name}: #{date_string}: #{a_val}, #{s_val} "
      next if a_val.nil?
      diff = a_diff(a_val, s_val)
      aremos_diff += diff
    end
    return aremos_diff
  end
  
  def aremos_comparison_display_array
    
    results = []
    begin
      as = AremosSeries.get self.name
      if as.nil?
        return []
      end
      
      as.data.each do |datestring, value|
        data = self.data
        unless data[datestring].nil?
          diff = a_diff(value, self.units_at(datestring))
          dp = DataPoint.where(:series_id => self.id, :date_string => datestring, :current=>true)[0]
          source_code = dp.source_type_code
          puts "#{self.name}: #{datestring}: #{value}, #{self.units_at(datestring)} diff:#{diff}" if diff != 0
          results.push(0+source_code) if diff == 0
          results.push(1+source_code) if diff > 0 and diff <= 1.0
          results.push(2+source_code) if diff > 1.0 and diff  <= 10.0
          results.push(3+source_code) if diff > 10.0          
          next #need this. otherwise might add two array elements per diff
        end
        
        if data[datestring].nil? and value == 1000000000000000.0
          results.push(0)
        else
          results.push(-1)
        end
      end
      results
    rescue Exception => e
      puts e.message
      puts "ERROR WITH \"#{self.name}\".ts.aremos_comparison"
    end
    
  end
  
  def aremos_series
    AremosSeries.get self.name
  end
  
  def aremos_data_side_by_side
    comparison_hash = {}
    as = self.aremos_series
    
    all_dates = self.data.keys | as.data.keys
    all_dates.each { |date_string| comparison_hash[date_string] = {:aremos => as.data[date_string], :udaman => self.units_at(date_string)} }
    return comparison_hash
  end
  
  def ma_data_side_by_side
    comparison_hash = {}
    ma = self.moving_average
    all_dates = self.data.keys | ma.data.keys
    all_dates.each do |date_string| 
      ma_point = ma.data[date_string].nil? ? nil : ma.data[date_string] 
      residual = ma.data[date_string].nil? ? nil : ma.data[date_string] - self.data[date_string]
      comparison_hash[date_string] = {:ma => ma_point, :udaman => self.data[date_string], :residual => residual } 
    end
    return comparison_hash
  end
  
  def data_diff(comparison_data, digits_to_round)
    self.units = 1000 if name[0..2] == "TGB" #hack for the tax scaling. Should not save units
    cdp = current_data_points
    diff_hash = {}
    results = []
    comparison_data.each do |date_string, value|      
      # dp = cdp.reject! {|dp| dp.date_string == date_string} # only used for pseudo_history_check
      # dp = dp[0] if dp.class == Array
      dp_val = units_at(date_string)
      
      if dp_val.nil?
        if value.nil?         #no data in series - no data in spreadsheet
          results.push 0
          next
        else                  #data in spreadsheet, but not in series
          results.push 3
          diff_hash[date_string] = nil
          next
        end
      end
            
      dp_idx = cdp.index {|dp| dp.date_string == date_string }
      dp = dp_idx.nil? ? dp_idx : cdp.delete_at(dp_idx)
      
      if !dp_val.nil? and value.nil? #data in series, no data in spreadsheet
        if dp.pseudo_history
          results.push 0
        else
          results.push 4
        end
        next
      end
      
      diff = dp_val - value
      
      if diff < 10**-digits_to_round #same data in series and spreadsheet
        results.push 1
      elsif diff <= 0.05 * value #small difference in data in series and spreadsheet 
        results.push 2
        diff_hash[date_string] = diff
      else #large data difference in data in series and spreadsheet | 
        results.push 3
        diff_hash[date_string] = diff
      end
    end
    {:diffs => diff_hash, :display_array => results}
  end
  
  
  
  def find_units
    begin
      unit_options = [1,10,100,1000]
      lowest_diff = nil
      best_unit = nil
    
      unit_options.each do |u|
        self.units = u
        diff = aremos_comparison[:diff]
        if lowest_diff.nil? or diff.abs < lowest_diff
          lowest_diff = diff.abs
          best_unit = u
        end
      end
    
      puts "#{self.name}: SETTING units = #{best_unit}"
      self.units = best_unit
      self.aremos_comparison  
    rescue Exception
      puts "#{self.name}: SETTING DEFAULT"
      self.update_attributes(:units => 1)
    end
  end
  
end