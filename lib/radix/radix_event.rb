
# monkeypatch
# TODO: use active support as a package
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


module Radix
  module Event

    # trigger key exchange
    def trKey( target = :data, dest = /.*/, chan = :control, event = :onKey )
      @log.info("[#{@config[:radix][:id]}/#{__method__}] #{chan.to_s}/#{event.to_s} #{target.to_s} #{dest}")
      # update server key as well
      trigger( keygen!( target ), dest, chan, event )
    end

    def onKey( payload, _chan, _event )
      # trigger channel event by PusherAgent#trigger enchan payload
      source, dest, data = dechan( payload, _chan, _event )
      dest = /#{dest}/

      id, method = @config[:radix][:id], "#{id}/#{__method__}"
      @log.debug( "#{id}/#{__method__}: #{source} #{dest} #{data}" )

      # prevent self-keying or false destination     
      return if id == source or not id =~ dest

      @log.info("[#{method}] new key from #{source}")
      # stop control thread by the new leader
      stop( :control )
      # set the new keys
      config!( data ) 
    end

    # data xc
    def trData(data=Time.now.to_s,chan=:data,event=:onData)
      @log.info("[#{@config[:radix][:id]}/#{__method__}] trigger: #{chan.to_s}/#{event.to_s}")
      trigger(data,chan,event)
    end

    # TODO: prevent message loss by retry the old key?
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
      # TODO: send to the local queue and to dashing
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
