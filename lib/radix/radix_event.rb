class Hash
  # http://grosser.it/2009/04/14/recursive-symbolize_keys/
  def recursive_symbolize_keys!
    symbolize_keys!
    values.select { |v| v.is_a?(Hash) }.each { |h| h.recursive_symbolize_keys! }
  end

  # http://apidock.com/rails/Hash/symbolize_keys%21
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

  # http://rails.rubyonrails.org/classes/ActiveSupport/CoreExtensions/Hash/DeepMerge.html
  def deep_merge(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.deep_merge(newval) : newval
    end
  end
  def deep_merge!(other_hash)
    replace(deep_merge(other_hash))
  end

end

# TODO: trigger mod
module Radix
  module Event

    # key xc
    def trKey(target=:data,chan=:control,event=:onKey)
      @log.info("[#{@config[:radix][:id]}/#{__method__}] #{chan.to_s}/#{event.to_s} for #{target.to_s} channel")
      trigger(keygen!(target),chan,event)
    end

    def onKey(data,_chan,_event)
      source,config,target = dechan(data,_chan,_event)
      id = @config[:radix][:id]
      me = "#{id}/#{__method__}"
      return if id == source

      @log.info("[#{me}] from #{source}")
      stop(:control) # by friendly fire
      config!(config) # for the channel
      # start target
      start(target.to_sym) if not target.nil? 
    end

    # data xc
    def trData(data=Time.now.to_s,chan=:data,event=:onData)
      @log.info("[#{@config[:radix][:id]}/#{__method__}] trigger: #{chan.to_s}/#{event.to_s}")
      trigger(data,chan,event)
    end

    def onData(data,_chan,_event)
      id = @config[:radix][:id]
      me = "#{id}/#{__method__}"      
      @log.info("[#{me}]")
      begin
        dec = dechan(data,_chan,_event)
        @log.debug("[#{me}] data size: #{dec.to_s.size}")
      rescue Exception => ex
        @log.debug("[#{me}] data error: #{ex.inspect}")        
      end
    end

    def trCfg(data,chan=:data,event=:onCfg)
      @log.info("[#{@config[:radix][:id]}/#{__method__}] for #{chan.to_s}/#{event.to_s}")
      trigger(data,chan,event)      
    end

    def onCfg(data,_chan,_event)
      dec = dechan(data,_chan,_event)
      id  = @config[:radix][:id]
      me = "#{id}/#{__method__}"     
      @log.debug("[#{me}] #{dec.inspect}")
      return if dec.shift == id
      dec.each do |d|
        d.recursive_symbolize_keys!
        if d.has_key? :radix
          @cfg.deep_merge!(d)
          @log.debug("[#{me}] #{d.to_s}")
        end
      end
      # start(:data) # threads/data/thread
    end

    # exit
    def trExit(data=/.*/,chan=:control,event=:onExit)
      @log.info("[#{@config[:radix][:id]}/#{__method__}] trigger: #{chan.to_s}/#{event.to_s}")
      trigger(data,chan,event)      
    end    

    def onExit(data,_chan,_event)
      dec = dechan(data,_chan,_event)
      @log.info("[#{@config[:radix][:id]}/#{__method__}] exit from: #{dec[0]}")
      exit(1)
    end

  end # Events
end
