#!/usr/bin/env ruby

require 'eventmachine'
require 'em-http-request'

EventMachine.run do
  http = EventMachine::HttpRequest.new("ws://127.0.0.1:8080/websocket").get :timeout => 0 
  http.errback { puts "oops" }
  http.callback do
    puts "WebSocket connected!"
    http.send("Hello client")
  end
  http.stream do |msg|
    puts "Recieved: #{msg}"
    http.send "Pong: #{msg}"
  end
end
