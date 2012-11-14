
# EM monkeypatch
module EventMachine
  def EventMachine.schedule_periodic_timer(proc,delay=120)
    schedule(proc)
    add_periodic_timer(delay, proc)
  end
end


module Radix
  module PusherAgent
    def init_pusher
      cfg = @config[:radix][:relay][:pusher]
      # TODO: do call
      Pusher.app_id    = cfg[:app_id]
      Pusher.key       = cfg[:key]
      Pusher.secret    = cfg[:secret]
      Pusher.encrypted = cfg[:encrypted]

      # open log file or fallback to stdout
      # TODO: duplication with Agent
      begin
        log = open( @config[:radix][:log], File::WRONLY | File::APPEND | File::CREAT )
        log.sync = true
      rescue
        log = STDOUT
      end  

      PusherClient.logger = Logger.new(log)
      PusherClient.logger.level = @config[:global][:debug] ? Logger::DEBUG : Logger::INFO

      # connect to pusher
      begin
        @socket = PusherClient::Socket.new( cfg[:key], { :secret => cfg[:secret] } )
      rescue Exception => ex
        @log.debug("[#{id}/#{__method__}] #{ex.inspect}")
        puts ex.backtrace
      end 
    end

    def init_amqp
      return
    end

    # event triggers
    def trigger( data = nil, dest = /.*/, chan = :data, event = :onData )
      raise 'empty trigger' if data.nil?
      
      cfg = @config[:radix]
      # obfuscate channel and event
      _chan, _event = enmap( chan, event )
      raise 'map error' if _chan.nil? or _event.nil?

      # construct payload
      payload = [cfg[:id], dest.to_s, data]

      # begin pushing the event
      # catch it by onEvent dechan -> source, dest, data
      Pusher[_chan].trigger(_event, enchan( payload, _chan, _event ) ) if not cfg[:relay][:pusher].nil?

      # amqp
    end

    # stop a thread
    def stop( thread = :control )
      cfg = @config[:radix][:threads]
      return if cfg[thread][:thread].nil?
      return if cfg[thread][:thread].status == false
      @log.info("[#{@config[:radix][:id]}/#{__method__}] stop #{thread.to_s}")         
      cfg[:control][:thread].exit
    end

    # start a thread
    def start( thread = :data )
      cfg = @config[:radix][:threads]
      return if cfg[thread][:thread].nil?
      if cfg[thread][:thread].status == 'sleep'
        @log.info("[#{@config[:radix][:id]}/#{__method__}] resume data thread")
        cfg[thread][:thread].run
      end
    end

    # self reconfig
    def config!(data)
      data.each do |chan,opts|
        @config[:radix][:channels][chan.to_sym] = Hash[opts.map{ |k, v| [k.to_sym, v] }]
        @config[:radix][:threads][chan.to_sym][:last] = Time.now.to_i
      end
    end

    # pusher api
    def subscribe(chan)
      @socket.subscribe(enmap(chan))
    end

    def connect
      @socket.connect
    end

    # triggers aes key change for data channel
    def control_thread
      @config[:radix][:threads][:control][:thread] = Thread.new do
        delay = @config[:radix][:threads][:control][:delay]

        EventMachine::run do 
          EventMachine::schedule_periodic_timer( Proc.new { trKey }, delay )
        end

      end
    end

    # aes key change listener
    def client_thread
      Thread.new do
        client = Client.new(@config)
        client.bind(:control,:onKey) do |data,chan,event|
          client.onKey(data,chan,event)
        end
        client.connect
      end
    end

    # remote config clients
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

    # send data
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
