
module EventMachine
  def EventMachine.schedule_periodic_timer(proc,delay=120)
    schedule(proc)
    add_periodic_timer(delay, proc)
  end
end


module Radix
  module PusherAgent
    def init_pusher
      cfg = @config[:radix][:pusher]
      Pusher.app_id = cfg[:app_id]
      Pusher.key    = cfg[:key]
      Pusher.secret = cfg[:secret]
      Pusher.encrypted = config[:encrypted]     
      PusherClient.logger = Logger.new(STDOUT)
      PusherClient.logger.level = @config[:global][:debug] ? Logger::DEBUG : Logger::INFO

      options = {:secret => cfg[:secret]}
      key = cfg[:key]
      @socket = PusherClient::Socket.new(key, options)     
    end

    # trigger event
    def trigger(data,chan,event,callb=nil)
      _chan,_event = enmap(chan,event)
      raise 'map error' if _chan.nil? or _event.nil?
      cfg = @config[:radix][:pusher]
      count,time = 3, 5

      id = @config[:radix][:id]
      data = [id] << data
      data << callb if not callb.nil?

      begin
        Pusher[_chan].trigger(_event, enchan(data,_chan,_event) )
      rescue Exception => ex
        sleep time
        count -= 1
        @log.debug("[#{id}/#{__method__}] #{ex.inspect}")
        @log.warn("[#{id}/#{__method__}] retry: #{count}")
        puts ex.backtrace
        retry if count > 0
       end
    end

    def trigger!(data,chan,event)
      trigger(data,chan,event,:data)
    end

    # threads
    def stop(thread=:control)
      cfg = @config[:radix][:threads]
      return if cfg[thread][:thread].nil?
      return if cfg[thread][:thread].status == false
      @log.info("[#{@config[:radix][:id]}/#{__method__}] stop #{thread.to_s}")         
      cfg[:control][:thread].exit
    end

    def start(thread=:data)
      cfg = @config[:radix][:threads]

      return if cfg[thread][:thread].nil?

      if cfg[thread][:thread].status == 'sleep'
        @log.info("[#{@config[:radix][:id]}/#{__method__}] resume data thread")
        cfg[thread][:thread].run
      end
    end

    def config!(data)
      data.each do |chan,opts|
        @config[:radix][:channels][chan.to_sym] = Hash[opts.map{ |k, v| [k.to_sym, v] }]
        @config[:radix][:threads][chan.to_sym][:last] = Time.now.to_i
      end
    end

    # pusher
    def subscribe(chan)
      @socket.subscribe(enmap(chan))
    end

    def connect
      @socket.connect
    end

    # triggers aes key change
    def control_thread
      @config[:radix][:threads][:control][:thread] = Thread.new do
        delay = @config[:radix][:threads][:control][:delay]

        EventMachine::run do 
          EventMachine::schedule_periodic_timer( Proc.new { trKey }, delay )
        end

      end
    end

    # server key change
    def client_thread
      Thread.new do
        client = Client.new(@config)
        client.bind(:control,:onKey) do |data,chan,event|
          client.onKey(data,chan,event)
        end
        client.connect
      end
    end

    # client config
    def config_thread
      @config[:radix][:threads][:control][:thread] = Thread.new do
        delay = @cfg[:pushare][:threads][:control][:delay]
        prCfg = Proc.new do
          data = {:radix=>{:maps=>@config[:pushare][:maps].dup,
                             :channels=>{:data=>@config[:radix][:channels][:data].dup}}}
          trCfg(data)
        end
        EventMachine::run { EventMachine::schedule_periodic_timer(prCfg,delay) }
      end
    end

    # data
    def data_thread
      @config[:radix][:threads][:data] ||= {}
      @config[:radix][:threads][:data][:thread] = Thread.new do
        Thread.stop if not @config[:radix][:channels].has_key? :data
        id     = @config[:radix][:id]
        chan   = @config[:radix][:channels][:data]
        thread = @config[:radix][:threads][:data]       
        delay  = thread[:delay]
        prData = Proc.new do
          if thread[:last].nil? or Time.now.to_i - thread[:last] > thread[:timeout]
            @log.warn("[#{id}/#{__method__}] waiting") 
            Thread.stop
          end
          thread[:trData].each do |task,opts|
            @log.debug("[#{id}/#{__method__}] task: #{task.to_s}")
            trData(send(task.to_sym,opts))
          end if not thread[:trData].nil?
        end
        EventMachine::run { EventMachine::schedule_periodic_timer(prData,delay) }
      end # Thread
    end

  end
end
