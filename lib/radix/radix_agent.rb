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

      # init the log
      log = open(@config[:radix][:log], File::WRONLY | File::APPEND | File::CREAT) || STDOUT
      log.sync = true
      @log = Logger.new(log)
      @log.level = @config[:global][:debug] ? Logger::DEBUG : Logger::INFO
      @log.formatter = proc do |severity, datetime, progname, msg|
        "#{severity} #{datetime}: #{msg}\n"
      end
 
      # init rsa
      init_rsa_cipher(inbound, outbound)

      # init aes
      init_aes_cipher

      # init pusher
      init_pusher
    end

    def bind(chan,event)
      @log.info("[#{@config[:radix][:id]}/#{__method__}] #{chan}/#{event}")
      chan,event = enmap(chan,event)
      socket[chan].bind(event) do |data|
        if not @config[:radix][:id] =~ data[:to]
          @log.info("[#{@config[:radix][:id]}/#{__method__}] not for me")
          return     
        end
        data = data[:data]
        yield(data,chan,event)
      end if block_given?
    end

  end # Agent


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
      # key watch
      client_thread
      # key heartbeat
      control_thread
      connect
    end
  end

end
