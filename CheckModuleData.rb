# 
# CheckDataException
# 
class CheckDataException < Exception
end

# 
# CheckModuleData
#  Used to identify if the hiera layout is in line with the data it finds inside of hiera. 
#  Data in hiera must match the expected format for the module to handle properly. i.e. if we
#  expect a string and not an array, then we need to identify that the data is indeed in the
#  correct format before we even try to pass it to the module, to prevent errors occurring
#
class CheckModuleData
  require 'yaml'
  attr_reader :data, :yamls, :test_yam
  
  def initialize(extension, exclusion, mod)
    @test_yam = nil
    @mod = mod
    @layout = "modules/#{@mod}/test/layout"
    @dir = '**/*'
    @exclusion = exclusion.nil? ? 'hiera.yaml' : exclusion 
    @extension = extension
    @yamls = self.get_files
    @data = Hash.new
  end

  # 
  # Retrieve all the yaml files and exclude the file, (this could be an array but code would need amending)
  # only used so we exclude the hiera.yaml file but you may want to exclude others.
  # 
  def get_files
    @yamls = Dir["#{@dir}/*.#{@extension}"].reject { |x| x == @exclusion }
  end

  #
  # Check that the layout file exists and if not then raise exception
  #
  def dirs_test
    begin
      File.open(@layout)
    rescue
      raise CheckDataException, "Module: #{@mod} needs #{@mod}/test/layout with right perms" 
    end
  end

  # 
  # Load the test layout yaml file and store it in the initialized object
  #
  def get_test
    if self.dirs_test
      @test_yam = YAML.load(File.open(@layout))
    end
  end

  #
  # Used to raise exceptions
  #
  def raise_exception
    raise CheckDataException, "Data for module: #{@mod} is not inline with the defined layout: #{@layout}"
  end

  #
  # Make the test layout hash have the same number of keys as that of the data found so the iteration
  # is like for like
  #
  def redefine_hash(h1, h2)
    ((h2.size+1)..h1.size).inject(h2) do |h, i|
      h2['key'+i.to_s]=h2.values[i-2]
    end
    return [h1, h2]
  end

  #
  # Called when the key is a hash, iterate over until we have actual values and no more 
  # key hashes. Get the type of object the value is i.e. string, array etc. Test if it is boolean
  # as TrueClass and FalseClass need to be identified as boolean. 
  # Check if the key is optional 'key?' and present or skip.
  # Create two new hashes and compare them in the scope they are created in.
  #
  def iterate(y_hobj, t_hobj, cmp_h = nil, cmp_t = nil)
    cmp_h ||= Hash.new
    cmp_t ||= Hash.new

    y_hobj.zip(t_hobj).each do |(yk,yv),(tk,tv)|
      if yv.is_a?(Hash) and tv.is_a?(Hash)
        iterate(Hash[yv.sort], Hash[tv.sort], Hash[cmp_h.sort], Hash[cmp_t.sort])
      else
        if tk.include?('?') and y_hobj.key?(tk.sub(/\?$/,''))
          tk = tk.sub(/\?$/,'')
          cmp_h[yk] = yv.class.to_s.downcase
          cmp_t[tk] = tv
        elsif tk.include?('?') and not y_hobj.key?(tk.sub(/\?$/,''))
          cmp_t.delete(tk)
        else
          cmp_h[yk] = yv.class.to_s.downcase
          cmp_t[tk] = tv
        end
        cmp_h.collect { |y_t, y_i| cmp_h[y_t] = self.check_bool(y_i) }
      end
    end
    print "Module layout hash: #{cmp_h}\n" unless cmp_h.empty?
    print "Test layout hash: #{cmp_t}\n\n" unless cmp_t.empty?
    if not cmp_h.eql?(cmp_t)
      self.raise_exception
    end
  end
  
  #
  # Identify the type of data we are handling here for both hiera and test layout
  # If it's a hash then pass it to iterate to handle, otherwise, handle it locally
  # and test the data against one another
  #
  def cmp_obj(y_obj, t_obj)
    if y_obj.is_a?(Hash) and t_obj.is_a?(Hash)
      iterate(Hash[y_obj.sort], Hash[t_obj.sort])
    else
      if y_obj.is_a?(Array)
        if check_array(y_obj) != t_obj.downcase
          self.raise_exception
        end
      end
      if check_bool(y_obj) != t_obj.downcase
        self.raise_exception
      end
    end
  end

  #
  # Return string array if it's an array object
  #
  def check_array(obj)
    if obj.is_a?(Array)
      'array'
    else
      obj
    end
  end

  #
  # Return string boolean if it's a boolean object TrueClass or FalseClass
  #
  def check_bool(obj)
    if (obj.is_a?(TrueClass) or obj.is_a?(FalseClass))
      'boolean'
    elsif obj =~ /(true|false)class/
       'boolean'
    else
      obj
    end
  end

  #
  # Compose the data into objects and pass it to the relevant functions for handling
  # to find out if the expected data is in the expected format
  #
  def match_all
    h_test = self.get_test
    @yamls.each do |yam|
      y_file = YAML.load(File.open(yam))
      unless !y_file
        h_test.keys.each do |t_key|
          if y_file.has_key?(t_key)
            yobj, tobj = redefine_hash(y_file[t_key], h_test[t_key])
            cmp_obj(Hash[yobj.sort], Hash[tobj.sort])
          end
        end
      end
    end
  end    
      
end
