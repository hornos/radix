module Radix

  class Agent
    # mixins
    include Cipher
    include Redux
    include PusherAgent
    include Event
    # include DataAgent
    # include Events

    # public attributes
    attr_accessor :socket # pusher socket
    attr_accessor :config
    attr_accessor :log

    def initialize(config,inbound=:client,outbound=:server)
      raise 'nil config' if config.nil?
      @config = config
      cfg = @config[:radix]

      # init the log
      # TODO: sentry integration
      begin
        log = open(cfg[:log], File::WRONLY | File::APPEND | File::CREAT) if not cfg[:log].nil?
        log.sync = true
      rescue
        log = STDOUT
      end
      @log = Logger.new(log)
      @log.level = @config[:global][:debug] ? Logger::DEBUG : Logger::INFO
      @log.formatter = proc do |severity, datetime, progname, msg|
        "#{severity} #{datetime}: #{msg}\n"
      end
 
      # init rsa for aes keys
      init_rsa_cipher( inbound, outbound )

      # init aes for data
      init_aes_cipher

      # init pusher
      init_pusher if not cfg[:relay][:pusher].nil?

      # init amqp
      # init_amqp if not cfg[:relay][:amqp].nil?
    end

    # bind block to a channel event
    def bind( chan, event )
      @log.info("[#{@config[:radix][:id]}/#{__method__}] #{chan}/#{event}")
      chan, event = enmap( chan, event )

      socket[chan].bind(event) do |data|
        yield(data,chan,event)
      end if block_given?

    end

  end # Agent


  # top level classes
  class Client < Agent
    def initialize(config)
      super(config,:client,:server)
    end

    def run
      data_thread
      connect
    end
  end

  class Server < Agent
    def initialize(config)
      super(config,:server,:client)
    end

    def run
      # client thread listens server heratbeat change
      client_thread
      # heartbeat by key
      control_thread
      connect
    end
  end

end
