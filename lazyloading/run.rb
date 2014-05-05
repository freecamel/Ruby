
# read large files, multi-thread
# lazy load
# sample load file

## Given that the size might be large, should use a fixed size hash and then
## remove some query, keep a counter

## keep a hash
#class LRU
#end

## delete the one and then insert
## save space, {a=>b} , {b=1}, hash
## linked list b->a->c , remove one


# a fake LRU


class Group
  attr_reader :conf
  attr_reader :groupId
  attr_reader :count
  attr_reader :file
  attr_reader :hashLimit

  def initialize(id, conf, file)
      @conf = conf
      @groupId = id
      @hashLimit = 20 # limit the number of hash records
      @count = 0
      @file = file
      self.loadGroup
      ## load the group
  end

  def close
    @file.close
  end

  def loadConf

      if count == @hashLimit
        remove_method :@conf[@groupId.to_s].first[1]  #remove the old entry
        self.deleteOldestEntry
        @count -= 1
      end

      value = readFile(@file, @conf,@groupId, key_id)

      if !value.nil?

        self.insertHash(key_id, value)

        @count += 1
      end
  end

  def loadFile

    @file.rewind

    enter = false
    store = {}

    while (line = @file.gets)
      line = line.split(";")[0]

      if line.strip.empty?  ## discard empty line
        next
      end


      if /\[.*\]/.match(line).nil? and enter == true   #  =
        temp = line.split("=")
        key = temp[0].strip
        value = temp[1].strip
        store[key]=value

      else                 # [something like this]
        tempGroup = line.split(/\[|\]/)[1]

        if tempGroup == @groupId.to_s and enter == false
          enter = true
        end

        if enter == true and tempGroup != @groupId.to_s
          @conf[@groupId.to_s]=store
          break
        end

      end
    end

    return nil
  end

  def to_s
    res = Hash[@conf[@groupId.to_s].map{ |k, v| [k.to_sym, v] }]
    res.to_s
  end

  def inspect
    res = Hash[@conf[@groupId.to_s].map{ |k, v| [k.to_sym, v] }]
    res.to_s
  end

  def method_missing(key_id, *args, &block)

    if key_id.to_s == "to_ary"
      res = Hash[@conf[@groupId.to_s].map{ |k, v| [k.to_sym, v] }]
      arr=[]
      puts "hi to ary"
      arr << res
      return arr
    elsif key_id.to_s=="[]"
      puts "hi hash"
      return @conf[@groupId.to_s][args[0].to_s]
    end

    self.class.send :define_method, key_id do
      #self.loadConfig(key_id)
      return @conf[@groupId.to_s][key_id.to_s]
    end

    self.send(key_id)
  end



  def insertHash(key_id, value)

    temp = {}
    temp[key_id.to_s] = value
    @conf[@groupId.to_s] = temp

  end

  def deleteCurHashEntry(key_id)
    @conf[@groupId.to_s].delete(key_id.to_s)
    @conf.delete(@groupId.to_s)
  end

  def deleteOldestEntry( )

    @conf[@groupId.to_s].delete(@conf[@groupId.to_s].keys[0])

    if @conf[@groupId.to_s].size == 0
      @conf[@groupId.to_s].delete(@conf.keys[0])
    end

  end

=begin
  def loadConfig(key_id)

    if @conf.has_key?(@groupId.to_s) and @conf[@groupId.to_s].has_key?(key_id.to_s)  # search and then return a value
        value = @conf[@groupId.to_s][key_id.to_s]  #[0]
        self.deleteCurHashEntry(key_id)
        self.insertHash(key_id, value)

      else
        if count == @hashLimit

          remove_method :@conf[@groupId.to_s].first[1]  #remove the old entry

          self.deleteOldestEntry

          @count -= 1
        end

        value = readFile(@file, @conf,@groupId, key_id)
        if !value.nil?

          self.insertHash(key_id, value)

          @count += 1
        end

      end

  end


  def readFile(file, conf, groupId, key_id)   #return value

   # puts "readfile"

    file.rewind
    group = ""

    while (line = @file.gets)
      line = line.split(";")[0]

      if line.strip.empty?  ## discard empty line
        next
      end

      if /\[.*\]/.match(line).nil? and !group.empty?   #  =
        temp = line.split("=")
        key = temp[0].strip
        value = temp[1].strip
        if group == groupId.to_s and key == key_id.to_s
          return value
        end
      else                 # [something like this]
        tempGroup = line.split(/\[|\]/)[1]

        if tempGroup != groupId.to_s
          next
        end

        if group.empty?    # empty => update
          group = tempGroup
        else
          group = tempGroup
        end
      end
    end

    return nil

  end
=end
end

class Configuration
  attr_reader :file
  attr_accessor :conf

  def initialize(file_path, overrides=[])
    @file = File.new(file_path, "r")
    @conf = {}
  end


  def method_missing(group_id, *args, &block)

#    puts group_id
#    puts group_id.class
#    puts args

    self.class.send :define_method, group_id do

      value = Group.new(group_id, @conf, @file)  ## read them all??
      return value

    end

    self.send(group_id)

  end


end

def load_config(file_path, overrides=[])

  conf = Configuration.new(file_path, overrides)
  return conf
end


CONFIG=load_config("./test.conf" )
#puts CONFIG.common.paid_users_size_limit
puts CONFIG.ftp.name
#puts CONFIG.http.params
#puts CONFIG.ftp.lastname  # => nil?
#puts CONFIG.ftp.enabled   # false
puts CONFIG.ftp[:name]    # no value here
#CONFIG.ftp           # none
#puts val
#val2 = CONFIG.ftp
#puts val2["aa"]
#puts CONFIG.ftp[:enabled]
