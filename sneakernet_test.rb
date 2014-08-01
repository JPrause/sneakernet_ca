begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
end
require "minitest/autorun"
require_relative "sneakernet.rb"

# gem install minitest # -v "5.4"

class SneakernetTest < MiniTest::Test
  attr_accessor :described_class
  attr_accessor :subject

  def setup
    self.described_class = Sneakernet
  end

  # test data coming in

  def test_calculated_values
    File.stub(:exist?, false) do
      subject = described_class.new(env("POLL", csr, cookie))
      assert_nil subject.delay_in_seconds
      assert_equal "/var/lib/sneakernet", subject.root
      assert_equal "", subject.response
      assert_equal nil, subject.exit_status
    end
  end

  def test_override_values
    File.stub(:exist?, false) do
      subject = described_class.new(env("POLL", csr, cookie), :delay_in_seconds => 5, :root => "/x")
      assert_equal 5, subject.delay_in_seconds
      assert_equal "/x", subject.root
    end
  end

  def test_env_params
    File.stub(:exist?, false) do
      subject = described_class.new(env("POLL", csr, cookie))
      assert_equal "POLL", subject.operation
      assert_equal csr, subject.csr
      assert_equal cookie, subject.cookie
    end
  end

  def test_calculate_sha1_from_csr
    File.stub(:exist?, false) do
      subject = described_class.new(env("POLL", csr, nil))
      assert_equal cookie, subject.sha1
      assert_equal cookie, subject.cookie
    end
  end

  def test_cookie_not_blow_up
    File.stub(:exist?, false) do
      subject = described_class.new(env("POLL", nil, nil))
      assert_equal nil, subject.csr
      assert_equal nil, subject.sha1
      assert_equal nil, subject.cookie
    end
  end
  # test logging

  def test_logging_not_found
    File.stub(:exist?, false) do
      logger = TestLogger.new
      subject = described_class.new(env("POLL", csr, cookie), :logger => logger)
      subject.run
      assert_equal "POLL[#{cookie}] -> wait", logger.response
    end
  end

  def test_logging_found
    File.stub(:exist?, true) do
      IO.stub(:read, "FILE_CONTENTS") do
        logger = TestLogger.new
        subject = described_class.new(env("POLL", csr, cookie), :logger => logger)
        subject.run
        assert_equal "POLL[#{cookie}] -> ok no name, /var/lib/sneakernet/#{cookie}.crt", logger.response
      end
    end
  end

  # CERTMONGER_OPERATION=POLL CERTMONGER_CSR=`cat ~/sneakers/c66afc46b2b3848137d3af2d41e8c97062b06a36.csr` \
  # CERTMONGER_COOKIE=c66afc46b2b3848137d3af2d41e8c97062b06a36 ./sneakernet

  def test_poll_with_delay_not_found
    File.stub(:exist?, false) do
      subject = described_class.new(env("POLL", csr, cookie), :delay_in_seconds => 10 )
      subject.run
      assert_equal 5, subject.exit_status
      assert_equal "#{subject.delay_in_seconds}\n#{subject.cookie}", subject.response
    end
  end

  def test_poll_not_found
    File.stub(:exist?, false) do
      subject = described_class.new(env("POLL", csr, cookie))
      subject.run
      assert_equal 1, subject.exit_status
      assert_equal "#{subject.cookie}", subject.response
    end
  end

  def test_poll_found
    File.stub(:exist?, true) do
      IO.stub(:read, "FILE_CONTENTS") do
        subject = described_class.new(env("POLL", csr, cookie))
        subject.run
        assert_equal 0, subject.exit_status
        assert_equal "FILE_CONTENTS", subject.response
      end
    end
  end

  # CERTMONGER_OPERATION=SUBMIT CERTMONGER_CSR=`cat ~/sneakers/c66afc46b2b3848137d3af2d41e8c97062b06a36.csr` ./sneakernet

  def test_submit
    File.stub(:write, csr) do
      subject = described_class.new(env("SUBMIT", csr, nil))
      subject.run
      assert_equal 1, subject.exit_status
      assert_equal cookie, subject.response
    end
  end

  # CERTMONGER_OPERATION=FETCH-ROOTS ./sneakernet

  def test_fetch_roots_not_found
    File.stub(:exist?, false) do
      subject = described_class.new(env("FETCH-ROOTS"))
      subject.run
      assert_equal 1, subject.exit_status
    end
  end

  def test_fetch_roots_found
    File.stub(:exist?, true) do
      IO.stub(:read, "FILE_CONTENTS") do
        subject = described_class.new(env("FETCH-ROOTS"))
        subject.run
        assert_equal 0, subject.exit_status
        assert_equal "sneakernet\nFILE_CONTENTS", subject.response
      end
    end
  end

  # CERTMONGER_OPERATION=IDENTIFY ./sneakernet

  def test_identify
    subject = described_class.new(env("IDENTIFY"))
    subject.run
    assert_equal 0, subject.exit_status
    assert_match(/Sneakernet/i, subject.response)
  end

  def test_unknown_request
    subject = described_class.new(env("OTHER-REQUEST"))
    subject.run
    assert_equal 6, subject.exit_status
  end

  private

  def env(op, csr = nil, cookie = nil)
    {
      "CERTMONGER_OPERATION" => op,
      "CERTMONGER_CSR"       => csr,
      "CERTMONGER_CA_COOKIE" => cookie
    }.delete_if { |_n, v| v.nil? }
  end

  def csr
    @csr ||= IO.read("test/support/#{cookie}.csr")
  end

  def cookie
    "6e9b73e69f8ac144f6be56f54435c3c1aeb2de60"
  end

  class TestLogger
    attr_accessor :lines
    def initialize
      self.lines = []
    end

    def warning(msg)
      lines << msg
    end

    def response
      lines.join("\n")
    end
  end
end
