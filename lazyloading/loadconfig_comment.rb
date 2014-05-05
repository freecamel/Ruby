=begin
Design:
1. as load_config() is called at boot time and needs to be fast, therefore the config is designed as lazy loading.
   At boot, it loads an empty config; each group gets loaded on first access. The disadvantage is that initial access will be slow
2. As access needs to be fast, the items are stored in hash
3. As the config might be very large and certain queries are more often, LRU is used here to remove certain queries out of memory
4. utilize one hash structure of limited size for both hash and LRU, space saved
=end

# overload Hash method_missing method to Handle *.*
class Hash
  def method_missing(method, *opts)
    m = method.to_s

    begin

      if self.has_key?(m)
        return self[m]
      elsif self.has_key?(m.to_sym)
        return self[m.to_sym]
      end

    rescue
      return nil
    end

    return nil
  end
end

# main class for managing config options dynamically
class Configuration
  attr_reader :file
  attr_accessor :conf
  attr_accessor :count
  attr_accessor :hashLimit
  attr_accessor :overrides

  def initialize(file_path, overrides=[])
    @file = File.new(file_path, "r")
    @conf = {}
    @count = 0
    @hashLimit = 100      # the max allowed size for hash 
    @overrides = overrides.map(&:to_s)

  end

  def insertHash(group_id, value)

    @conf[group_id.to_s] = value # value is a hash
  end

  def deleteCurHashEntry(group_id)
    @conf.delete(group_id.to_s)
  end

  def deleteOldestEntry()
    @conf.delete(@conf.keys[0])
  end

  # return hash conf[group_id]
  def loadConf(group_id)

    # if it is in hash, return value directly
    # reinsert hash to fake LRU
    if @conf.has_key?(group_id.to_s)
      value = @conf[group_id.to_s]
      self.deleteCurHashEntry(group_id)
      self.insertHash(group_id, value)
      return @conf[group_id.to_s]
    end

    # if the hash is full, remove least recently used
    if @count == @hashLimit

      #  objective: to remove existing methods but does not work
      #  Would you please kindly provide me some hints?

      #  remove_method (@conf.first[0]).to_sym  #remove the old  method
      self.deleteOldestEntry
      @count -= 1
    end

    # load the group
    value = readGroup(group_id)

    # insert into hash table
    if !value.nil?
      self.insertHash(group_id, value)
      @count += 1
      return @conf[group_id.to_s]
    else
      return nil
    end
  end

  # processing parameter format
  # save parameter pairs in store
  def filterKeyPair(line="", store={})

    temp = line.split("=")
    left = temp[0].strip
    key_comb = left.split(/<|>/)
    key = key_comb[0].strip.to_sym

    if temp[1].include? "\""
      value = temp[1].strip.split('"')[1]
    elsif ["yes", "true", "1"].include? temp[1].strip # assumption yes, true , 1 => true; no false 0 => false
      value = true
    elsif ["no", "false", "0"].include? temp[1].strip
      value = false
    elsif temp[1].strip.split(",").length > 1
      value = temp[1].strip.split(",")
    else
      value = temp[1].strip
    end

    if key_comb.length == 1
      store[key]=value
    elsif @overrides.include? key_comb[1].strip
      store[key]=value
    elsif !store.include?(key)
      store[key]=value
    end

  end

  # read files to retrieve group,
  # return a hash representing parameters, nil otherwise
  def readGroup(group_id)
    @file.rewind

    enter = false
    store = {}

    while (line = @file.gets)
      line = line.split(";")[0]

      if line.strip.empty? 
        next
      end

      if /\[.*\]/.match(line).nil? and enter == true #  =

        filterKeyPair(line, store)

      else
        tempGroup = line.split(/\[|\]/)[1]

        if tempGroup == group_id.to_s and enter == false
          enter = true
        end

        if enter == true and tempGroup != group_id.to_s
          enter = false
          return store
        end

      end
    end

    if enter == true
      return store
    end

    return nil
  end

  # dynamically define methods to handle conf.group[.*]
  def method_missing(group_id, *args, &block)

    self.class.send :define_method, group_id do

      begin
        value = loadConf(group_id)
        return value
      rescue
        return nil
      end

    end

    self.send(group_id)

  end

end

def load_config(file_path, overrides=[])
  begin
    conf = Configuration.new(file_path, overrides)
  rescue
    abort("configuration initialize failed")
  end
  return conf
end
