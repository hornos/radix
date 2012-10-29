module Radix
  module Cipher

    # inbound connection is decrypted by the secure key and the passord
    def inbound(target=:client)
      cfg = @config[:radix][:keys]
      raise ":#{target.to_s} not found" if not cfg.has_key? target
      @rsa_dec_key = OpenSSL::PKey::RSA.new(File.read(cfg[target][:sec]),cfg[target][:pas])
    end

    # outbound connection is encrypted by the public key
    def outbound(target=:server)
      cfg = @config[:radix][:keys]
      raise ":#{target.to_s} not found" if not cfg.has_key? target
      @rsa_enc_key = OpenSSL::PKey::RSA.new(File.read(cfg[target][:pub]))
    end

    def init_rsa_cipher(inb=:client,outb=:server)
      raise ':keys not found' if not @config[:radix].has_key? :keys
      inbound(inb)
      outbound(outb)
    end

    def init_aes_cipher(aes="aes-256-cbc",sha2=256)
      @cipher = OpenSSL::Cipher::Cipher.new(aes)
      @cipher.decrypt
      @hasher = Digest::SHA2.new(sha2)
    end

    # rsa cipher
    def decrypt(data)
      @rsa_dec_key.private_decrypt(data)
    end

    def encrypt(data)
      @rsa_enc_key.public_encrypt(data)
    end

    # channel cipher
    def enciphr(data,chan)
      cfg = @config[:radix][:channels]
      @cipher.encrypt
      @cipher.key = cfg[chan][:key]
      @cipher.iv  = cfg[chan][:iv]
      @cipher.update(data) + @cipher.final
    end

    def deciphr(data,chan)
      cfg = @config[:radix][:channels]
      @cipher.decrypt
      @cipher.key = cfg[chan][:key]
      @cipher.iv  = cfg[chan][:iv]
      @cipher.update(data) + @cipher.final
    end

    # dictionary mapper
    # human to guff readable
    def enmap(*data)
      data.map { |d| @config[:radix][:maps][d] }
    end

    # guff to human readable
    def demap(*data)
      data.map { |d| @config[:radix][:maps].rassoc(d)[0] }
    end

    # data coder
    def encode(redux,data)
      log = "data(#{data.to_s.size})"
      redux.inject(data) do |enc,encoder|
        data = send(encoder.to_sym, data, :encode)
        log+=" #{encoder}(#{data.to_s.size})"
      end
      @log.debug("[#{@config[:radix][:id]}/#{__method__}] #{log}")
      data
    end

    def decode(redux,data)
      log = " data(#{data.to_s.size})"
      redux.reverse.inject(data) do |enc,encoder|
        data = send(encoder.to_sym, data, :decode)
        log+=" #{encoder}(#{data.to_s.size})"
      end
      @log.debug("[#{@config[:radix][:id]}/#{__method__}]#{log}")
      data
    end

    # channel coder
    def enchan(data,_chan,_event)
      chan,event = demap(_chan,_event)
      @log.debug("[#{@config[:radix][:id]}/#{__method__}] event: #{chan}/#{event}")
      encode(@config[:radix][:channels][chan.to_sym][:redux], data)
    end

    def dechan(data,_chan,_event)
      chan,event  = demap(_chan,_event)
      @log.debug("[#{@config[:radix][:id]}/#{__method__}] event: #{chan}/#{event}")
      decode(@config[:radix][:channels][chan.to_sym][:redux],data)
    end

    # generate new aes key
    def keygen!(chan=:data,len=32)
      @config[:radix][:channels][chan][:iv] = SecureRandom.urlsafe_base64(len)
      @config[:radix][:channels][chan][:key] = SecureRandom.urlsafe_base64(len)
      @config[:radix][:channels][chan][:time] = Time.now.to_i
      {chan=>@config[:radix][:channels][chan]}
    end
  end
end
