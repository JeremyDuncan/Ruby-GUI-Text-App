require 'gtk3'
require 'pathname'
require 'twilio-ruby'
require 'dotenv'
require 'sinatra/base'
require 'thin'
require 'open3'
require 'json'
require 'net/http'
require 'uri'

# Load environment variables from .env file
Dotenv.load

class TextApp
  @instance = nil

  def self.instance
    @instance
  end

  def self.instance=(instance)
    @instance = instance
  end

  def initialize
    puts "Initializing GTK application..."
    Gtk.init

    glade_file = Pathname.new(__FILE__).dirname + 'interface.glade'
    puts "Loading Glade file from #{glade_file.to_s}..."

    unless File.exist?(glade_file.to_s)
      raise "Glade file not found at #{glade_file.to_s}"
    end

    builder = Gtk::Builder.new
    begin
      builder.add_from_file(glade_file.to_s)
    rescue => e
      raise "Error loading Glade file: #{e.message}"
    end

    @window = builder.get_object("window1")
    if @window.nil?
      raise "Could not find object 'window1' in Glade file"
    end
    @window.signal_connect("destroy") { Gtk.main_quit }

    @phone_number_entry = builder.get_object("phone_number_entry")
    if @phone_number_entry.nil?
      raise "Could not find object 'phone_number_entry' in Glade file"
    end

    @message_entry = builder.get_object("message_entry")
    if @message_entry.nil?
      raise "Could not find object 'message_entry' in Glade file"
    end

    @send_button = builder.get_object("send_button")
    if @send_button.nil?
      raise "Could not find object 'send_button' in Glade file"
    end
    @send_button.signal_connect("clicked") { on_send_button_clicked }

    @messages_text_view = builder.get_object("messages_text_view")
    if @messages_text_view.nil?
      raise "Could not find object 'messages_text_view' in Glade file"
    end

    puts "Showing all components..."
    @window.show_all
    puts "Window should now be visible."

    start_server
    set_twilio_webhook('https://gull-shining-peacock.ngrok-free.app')
  end

  def on_send_button_clicked
    phone_number = @phone_number_entry.text
    message_body = @message_entry.text

    if phone_number.empty? || message_body.empty?
      puts "Phone number or message body cannot be empty"
      return
    end

    send_message(phone_number, message_body)
    @message_entry.text = ""
  end

  def send_message(phone_number, message_body)
    account_sid = ENV['TWILIO_ACCOUNT_SID']
    auth_token = ENV['TWILIO_AUTH_TOKEN']
    twilio_phone_number = ENV['TWILIO_PHONE_NUMBER']

    client = Twilio::REST::Client.new(account_sid, auth_token)

    message = client.messages.create(
      body: message_body,
      to: phone_number,
      from: twilio_phone_number
    )

    puts" "
    puts "######################################################################"
    puts message.inspect
    puts "######################################################################"
    puts " "
    append_message("Sent to #{phone_number}: #{message_body}")
  end

  def append_message(text)
    buffer = @messages_text_view.buffer
    end_iter = buffer.end_iter
    buffer.insert(end_iter, text + "\n")
  end

  def start_server
    Thread.new do
      MySinatraApp.run!
    end
  end

  def set_twilio_webhook(ngrok_url)
    account_sid = ENV['TWILIO_ACCOUNT_SID']
    auth_token = ENV['TWILIO_AUTH_TOKEN']
    client = Twilio::REST::Client.new(account_sid, auth_token)
    phone_number_sid = client.incoming_phone_numbers.list.first.sid
    client.incoming_phone_numbers(phone_number_sid).update(
      sms_url: "#{ngrok_url}/incoming",
      sms_method: 'POST'
    )
    puts "Twilio webhook set to #{ngrok_url}/incoming"
  end

  def run
    puts "Running GTK main loop..."
    Gtk.main
  end
end

class MySinatraApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 80

  post '/incoming' do
    body = params['Body']
    from = params['From']
    puts "Incoming message from #{from}: #{body}" # Debug statement
    TextApp.instance.append_message("Received from #{from}: #{body}")

    twiml = Twilio::TwiML::MessagingResponse.new do |r|
      # Uncomment to use reply message upon receipt of texts.
      # r.message body: 'We got your message, thank you!'
    end

    content_type 'text/xml'
    twiml.to_s
  end

  def self.run!
    Rack::Handler::Thin.run(self, Host: '127.0.0.1', Port: 4567)
  end
end

begin
  app = TextApp.new
  TextApp.instance = app
  app.run
rescue StandardError => e
  puts "An error occurred: #{e.message}"
end
