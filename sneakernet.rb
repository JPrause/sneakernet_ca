#!/usr/bin/env ruby

require 'digest/sha1'

class Sneakernet
  CA_CERT = "primary_ca_root_file"

  # inputs / config
  attr_accessor :root
  attr_accessor :logger
  attr_accessor :delay_in_seconds
  attr_accessor :env

  # outputs
  attr_reader :exit_status

  def initialize(env, options = {})
    self.root = "/var/lib/sneakernet"
    @responses = []
    self.env = env

    options.each { |n, v| public_send("#{n}=", v) }
  end

  # inputs

  def operation
    @operation ||= env['CERTMONGER_OPERATION']
  end

  def csr
    @csr ||= env['CERTMONGER_CSR']
  end

  def sha1
    csr ? Digest::SHA1.hexdigest(csr) : nil
  end

  def cookie
    @cookie ||= env['CERTMONGER_CA_COOKIE'] || sha1
  end

  # outputs

  def respond(str)
    @responses << str
  end

  def response
    @responses.join("\n")
  end

  def status(exit_status)
    @exit_status = exit_status
  end

  def run
    case operation
    when "FETCH-ROOTS"
      respond_or_wait "#{root}/#{CA_CERT}", self.class.name.downcase, nil
    when "SUBMIT"
      File.write "#{root}/#{cookie}.csr", csr
      respond_call_back cookie
    when "POLL"
      respond_or_wait "#{root}/#{cookie}.crt", nil, cookie
    when "IDENTIFY"
      respond_ok "#{self.class.name} (manual CA)"
    else
      respond_unknown_command
    end
    self
  end

  def respond_or_wait(filename, suggested_name, token)
    if File.exist?(filename)
      respond_ok suggested_name, filename
    else
      respond_call_back token, filename
    end
  end

  def respond_call_back(token, filename = nil)
    log "wait", token
    if delay_in_seconds
      respond delay_in_seconds
      respond token if token
      @exit_status = 5
    else
      respond token if token
      @exit_status = 1
    end
  end

  def respond_ok(suggested_name = nil, crt = nil)
    log "ok #{suggested_name || "no name"}, #{crt || "no file"}"
    respond suggested_name if suggested_name
    respond IO.read(crt) if crt
    @exit_status = 0
  end

  def respond_unknown_command
    log "unknown"
    @exit_status = 6
  end

  def log(action, token = cookie)
    logger.warning("#{operation}[#{token}] -> #{action}") if logger
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV[0] == "--log"
    require 'syslog'
    logger = Syslog
  end

  s = Sneakernet.new(ENV, :logger => logger)
  Syslog.open(s.class.name.downcase) if logger
  s.run
  Syslog.close if logger
  print s.response.chomp
  exit s.exit_status
end
