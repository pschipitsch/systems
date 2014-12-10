require 'rexml/document'

class Hypervisor
  def initialize(hostname, status)
    @hostname              = hostname
    @status                = status
    @cpu                   = 0
    @memory                = 0
    @storage_pools         = Array.new
    @storage_capacity      = 0
    @storage_used          = 0
    @storage_available     = 0
    @guests                = Array.new
    @guest_cpu             = 0
    @guest_memory          = 0
    @guest_storage_volumes = Array.new
    @storage_allocated     = 0
  end
  
  def set_resources
    begin
      result=`virsh --connect qemu://#{@hostname}/system nodeinfo`
      result.split("\n").each do |line|
        if    line =~ /Memory size:\s+(\d+)/
          @memory = $1.to_i
        elsif line =~ /CPU\(s\)\:\s+(\d+)/
          @cpu    = $1.to_i
        end
      end
      @memory = "unknown" if @memory == 0
      @cpu    = "unknown" if @cpu    == 0
    rescue
      puts "Unable to retrieve resources from #{@hostname}."
    end
  end
  
  def set_storage_pools
    begin
      result = `virsh --connect qemu://#{@hostname}/system pool-list`
      result.split("\n").each do |line|
        if line =~ /(\S+)\s+(active)/
          @storage_pools << $1
        end
      end
    rescue
      puts "Unable to retrieve storage pools from #{@hostname}."
    end  
  end
  
  def set_storage_resources
    unless @storage_pools.empty?
      begin
        @storage_pools.each do |pool|
          result = `virsh --connect qemu://#{@hostname}/system pool-refresh #{pool}; 
                    virsh --connect qemu://#{@hostname}/system pool-dumpxml #{pool}`
          doc = REXML::Document.new result
          doc.elements.each('/pool/capacity')   {|element| @storage_capacity  += element.text.to_i}
          doc.elements.each('/pool/allocation') {|element| @storage_used      += element.text.to_i}
          doc.elements.each('/pool/available')  {|element| @storage_available += element.text.to_i}
        end
      rescue Exception => e 
        puts "Unable to retrieve storage resources from #{@hostname}."
        puts e.message
        puts e.backtrace.inspect
      end
    else
      @storage_capacity = "unknown"
      @storage_used     = "unknown" 
    end
  end
  
  def set_guests
    begin
      result = `virsh --connect qemu://#{@hostname}/system list --all`
      result.split("\n").each do |line|
        if line =~ /\d+\s+(\S+)\s+/
          @guests << $1
        end
      end
    rescue
      puts "Unable to retrieve guests from #{@hostname}."
    end
  end
  
  def set_guest_resources
    unless @guests.empty?
      begin
        @guests.each do |guest|
          result = `virsh --connect qemu://#{@hostname}/system dumpxml #{guest}`
          doc = REXML::Document.new result
          doc.elements.each('/domain/currentMemory')       {|element| @guest_memory          += element.text.to_i}
          doc.elements.each('/domain/vcpu')                {|element| @guest_cpu             += element.text.to_i}
          doc.elements.each('/domain/devices/disk/source') {|element| @guest_storage_volumes << element.attributes['file']}
        end
      rescue
        puts "Unable to retrieve guest resources from #{@hostname}."
      end
    else
      @guest_memory = "unknown"
      @guest_cpu    = "unknown" 
    end
  end
  
  def set_storage_allocated
    unless @guest_storage_volumes.empty?
      @guest_storage_volumes.each do |vol|
        begin
          result = `virsh --connect qemu://#{@hostname}/system vol-dumpxml #{vol}`
          doc = REXML::Document.new result
          doc.elements.each("/volume/capacity"){|ele| @storage_allocated += ele.text.to_i}
        rescue
          puts "Unable to retrieve storage allocation from #{@hostname}."
        end
      end
      if @storage_used.kind_of?(Numeric)
        @storage_allocated = (@storage_allocated > @storage_used ? @storage_allocated : @storage_used)
      end
    else
      @storage_allocated = @storage_used
    end
  end
  
  def get_all_resources
    info = { :hostname => @hostname,
             :status   => @status,
             :cpu      => {
               :total => @cpu,
               :used  => @guest_cpu
             },
             :memory  => {
               :total => @memory,
               :used  => @guest_memory
             },
             :disk => {
               :total => @storage_capacity,
               :used  => @storage_allocated
             }
            }
    info                        
  end
end
