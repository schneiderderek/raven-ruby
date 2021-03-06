require 'spec_helper'
require 'raven/integrations/rack'

describe Raven::Event do
  before do
    Raven::Context.clear!
    Raven::BreadcrumbBuffer.clear!
  end

  context 'a fully implemented event' do
    let(:hash) do
      Raven::Event.new(:message => 'test',
                       :level => 'warning',
                       :logger => 'foo',
                       :tags => {
                         'foo' => 'bar'
                       },
                       :extra => {
                         'my_custom_variable' => 'value'
                       },
                       :server_name => 'foo.local',
                       :release => '721e41770371db95eee98ca2707686226b993eda',
                       :environment => 'production').to_hash
    end

    it 'has message' do
      expect(hash[:message]).to eq('test')
    end

    it 'has level' do
      expect(hash[:level]).to eq(30)
    end

    it 'has logger' do
      expect(hash[:logger]).to eq('foo')
    end

    it 'has server name' do
      expect(hash[:server_name]).to eq('foo.local')
    end

    it 'has release' do
      expect(hash[:release]).to eq('721e41770371db95eee98ca2707686226b993eda')
    end

    it 'has environment' do
      expect(hash[:environment]).to eq('production')
    end

    it 'has tag data' do
      expect(hash[:tags]).to eq('foo' => 'bar')
    end

    it 'has extra data' do
      expect(hash[:extra]["my_custom_variable"]).to eq('value')
    end

    it 'has platform' do
      expect(hash[:platform]).to eq('ruby')
    end

    it 'has SDK' do
      expect(hash[:sdk]).to eq("name" => "raven-ruby", "version" => Raven::VERSION)
    end

    it 'has server os' do
      expect(hash[:extra][:server][:os].keys).to eq([:name, :version, :build, :kernel_version])
    end

    it 'has runtime' do
      expect(hash[:extra][:server][:runtime][:version]).to match(/ruby/)
    end
  end

  context 'user context specified' do
    let(:hash) do
      Raven.user_context('id' => 'hello')

      Raven::Event.new(:level => 'warning',
                       :logger => 'foo',
                       :tags => {
                         'foo' => 'bar'
                       },
                       :extra => {
                         'my_custom_variable' => 'value'
                       },
                       :server_name => 'foo.local').to_hash
    end

    it "adds user data" do
      expect(hash[:user]).to eq('id' => 'hello')
    end
  end

  context 'tags context specified' do
    let(:hash) do
      Raven.tags_context('key' => 'value')

      Raven::Event.new(:level => 'warning',
                       :logger => 'foo',
                       :tags => {
                         'foo' => 'bar'
                       },
                       :extra => {
                         'my_custom_variable' => 'value'
                       },
                       :server_name => 'foo.local').to_hash
    end

    it "merges tags data" do
      expect(hash[:tags]).to eq('key' => 'value',
                                'foo' => 'bar')
    end
  end

  context 'extra context specified' do
    let(:hash) do
      Raven.extra_context('key' => 'value')

      Raven::Event.new(:level => 'warning',
                       :logger => 'foo',
                       :tags => {
                         'foo' => 'bar'
                       },
                       :extra => {
                         'my_custom_variable' => 'value'
                       },
                       :server_name => 'foo.local').to_hash
    end

    it "merges extra data" do
      expect(hash[:extra]['key']).to eq('value')
      expect(hash[:extra]['my_custom_variable']).to eq('value')
    end
  end

  context 'rack context specified' do
    require 'stringio'

    let(:hash) do
      Raven.rack_context('REQUEST_METHOD' => 'POST',
                         'QUERY_STRING' => 'biz=baz',
                         'HTTP_HOST' => 'localhost',
                         'SERVER_NAME' => 'localhost',
                         'SERVER_PORT' => '80',
                         'HTTP_X_FORWARDED_FOR' => '1.1.1.1, 2.2.2.2',
                         'REMOTE_ADDR' => '192.168.1.1',
                         'PATH_INFO' => '/lol',
                         'rack.url_scheme' => 'http',
                         'rack.input' => StringIO.new('foo=bar'))

      Raven::Event.new(:level => 'warning',
                       :logger => 'foo',
                       :tags => {
                         'foo' => 'bar'
                       },
                       :extra => {
                         'my_custom_variable' => 'value'
                       },
                       :server_name => 'foo.local').to_hash
    end

    it "adds http data" do
      expect(hash[:request]).to eq(:data => { 'foo' => 'bar' },
                                   :env => { 'SERVER_NAME' => 'localhost', 'SERVER_PORT' => '80', "REMOTE_ADDR" => "192.168.1.1" },
                                   :headers => { 'Host' => 'localhost', "X-Forwarded-For" => "1.1.1.1, 2.2.2.2" },
                                   :method => 'POST',
                                   :query_string => 'biz=baz',
                                   :url => 'http://localhost/lol',
                                   :cookies => nil)
    end

    it "sets user context ip address correctly" do
      expect(hash[:user][:ip_address]).to eq("1.1.1.1")
    end
  end

  context "rack context, long body" do
    let(:hash) do
      Raven.rack_context('REQUEST_METHOD' => 'GET',
                         'rack.url_scheme' => 'http',
                         'rack.input' => StringIO.new('a' * 16_000))

      Raven::Event.new.to_hash
    end

    it "truncates http data" do
      expect(hash[:request][:data]).to eq("a" * 2048)
    end
  end

  context 'configuration tags specified' do
    let(:hash) do
      config = Raven::Configuration.new
      config.tags = { 'key' => 'value' }
      config.release = "custom"
      config.current_environment = "custom"

      Raven::Event.new(
        :level => 'warning',
        :logger => 'foo',
        :tags => {
          'foo' => 'bar'
        },
        :server_name => 'foo.local',
        :configuration => config
      ).to_hash
    end

    it 'merges tags data' do
      expect(hash[:tags]).to eq('key' => 'value',
                                'foo' => 'bar')
      expect(hash[:release]).to eq("custom")
      expect(hash[:environment]).to eq("custom")
    end
  end

  context 'configuration tags unspecified' do
    it 'should not persist tags between unrelated events' do
      config = Raven::Configuration.new
      config.logger = Logger.new(nil)

      Raven::Event.new(
        :level => 'warning',
        :logger => 'foo',
        :tags => {
          'foo' => 'bar'
        },
        :server_name => 'foo.local',
        :configuration => config
      )

      hash = Raven::Event.new(
        :level => 'warning',
        :logger => 'foo',
        :server_name => 'foo.local',
        :configuration => config
      ).to_hash

      expect(hash[:tags]).to eq({})
    end
  end

  context 'tags hierarchy respected' do
    let(:hash) do
      config = Raven::Configuration.new
      config.logger = Logger.new(nil)
      config.tags = {
        'configuration_context_event_key' => 'configuration_value',
        'configuration_context_key' => 'configuration_value',
        'configuration_event_key' => 'configuration_value',
        'configuration_key' => 'configuration_value'
      }

      Raven.tags_context('configuration_context_event_key' => 'context_value',
                         'configuration_context_key' => 'context_value',
                         'context_event_key' => 'context_value',
                         'context_key' => 'context_value')

      Raven::Event.new(
        :level => 'warning',
        :logger => 'foo',
        :tags => {
          'configuration_context_event_key' => 'event_value',
          'configuration_event_key' => 'event_value',
          'context_event_key' => 'event_value',
          'event_key' => 'event_value'
        },
        :server_name => 'foo.local',
        :configuration => config
      ).to_hash
    end

    it 'merges tags data' do
      expect(hash[:tags]).to eq('configuration_context_event_key' => 'event_value',
                                'configuration_context_key' => 'context_value',
                                'configuration_event_key' => 'event_value',
                                'context_event_key' => 'event_value',
                                'configuration_key' => 'configuration_value',
                                'context_key' => 'context_value',
                                'event_key' => 'event_value')
    end
  end

  context 'merging user context' do
    before do
      Raven.user_context('context_event_key' => 'context_value',
                         'context_key' => 'context_value')
    end

    let(:hash) do
      Raven::Event.new(:user => {
                         'context_event_key' => 'event_value',
                         'event_key' => 'event_value'
                       }).to_hash
    end

    it 'prioritizes event context over request context' do
      expect(hash[:user]).to eq('context_event_key' => 'event_value',
                                'context_key' => 'context_value',
                                'event_key' => 'event_value')
    end
  end

  context 'merging extra context' do
    before do
      Raven.extra_context('context_event_key' => 'context_value',
                          'context_key' => 'context_value')
    end

    let(:hash) do
      Raven::Event.new(:extra => {
                         'context_event_key' => 'event_value',
                         'event_key' => 'event_value'
                       }).to_hash
    end

    it 'prioritizes event context over request context' do
      expect(hash[:extra]['context_event_key']).to eq('event_value')
      expect(hash[:extra]['context_key']).to eq('context_value')
      expect(hash[:extra]['event_key']).to eq('event_value')
    end
  end

  context 'merging exception context' do
    class ExceptionWithContext < StandardError
      def raven_context
        { :extra => {
          'context_event_key' => 'context_value',
          'context_key' => 'context_value'
        } }
      end
    end

    let(:hash) do
      Raven::Event.from_exception(ExceptionWithContext.new, :extra => {
                                    'context_event_key' => 'event_value',
                                    'event_key' => 'event_value'
                                  }).to_hash
    end

    it 'prioritizes event context over request context' do
      expect(hash[:extra]['context_event_key']).to eq('event_value')
      expect(hash[:extra]['context_key']).to eq('context_value')
      expect(hash[:extra]['event_key']).to eq('event_value')
    end
  end

  describe '.initialize' do
    it 'should not touch the env object for an ignored environment' do
      Raven.configure do |config|
        config.current_environment = 'test'
        config.logger = Logger.new(nil)
      end
      Raven.rack_context({})
      Raven::Event.new
    end
  end

  describe '.to_json_compatible' do
    subject do
      Raven::Event.new(:extra => {
                         'my_custom_variable' => 'value',
                         'date' => Time.utc(0),
                         'anonymous_module' => Class.new
                       })
    end

    it "should coerce non-JSON-compatible types" do
      json = subject.to_json_compatible

      expect(json["extra"]['my_custom_variable']).to eq('value')
      expect(json["extra"]['date']).to be_a(String)
      expect(json["extra"]['anonymous_module']).not_to be_a(Class)
    end
  end

  describe '.capture_message' do
    let(:message) { 'This is a message' }
    let(:hash) { Raven::Event.capture_message(message).to_hash }

    context 'for a Message' do
      it 'returns an event' do
        expect(Raven::Event.capture_message(message)).to be_a(Raven::Event)
      end

      it "sets the message to the value passed" do
        expect(hash[:message]).to eq(message)
      end

      it 'has level ERROR' do
        expect(hash[:level]).to eq(40)
      end

      it 'accepts an options hash' do
        expect(Raven::Event.capture_message(message, :logger => 'logger').logger).to eq('logger')
      end

      it 'accepts a stacktrace' do
        backtrace = ["/path/to/some/file:22:in `function_name'",
                     "/some/other/path:1412:in `other_function'"]
        evt = Raven::Event.capture_message(message, :backtrace => backtrace)
        expect(evt[:stacktrace]).to be_a(Raven::StacktraceInterface)

        frames = evt[:stacktrace].to_hash[:frames]
        expect(frames.length).to eq(2)
        expect(frames[0][:lineno]).to eq(1412)
        expect(frames[0][:function]).to eq('other_function')
        expect(frames[0][:filename]).to eq('/some/other/path')

        expect(frames[1][:lineno]).to eq(22)
        expect(frames[1][:function]).to eq('function_name')
        expect(frames[1][:filename]).to eq('/path/to/some/file')
      end
    end
  end

  describe '.capture_exception' do
    let(:message) { 'This is a message' }
    let(:exception) { Exception.new(message) }
    let(:hash) { Raven::Event.capture_exception(exception).to_hash }

    context 'for an Exception' do
      it 'returns an event' do
        expect(Raven::Event.capture_exception(exception)).to be_a(Raven::Event)
      end

      it "sets the message to the exception's message and type" do
        expect(hash[:message]).to eq("Exception: #{message}")
      end

      # sentry uses python's logging values; 40 is the value of logging.ERROR
      it 'has level ERROR' do
        expect(hash[:level]).to eq(40)
      end

      it 'uses the exception class name as the exception type' do
        expect(hash[:exception][:values][0][:type]).to eq('Exception')
      end

      it 'uses the exception message as the exception value' do
        expect(hash[:exception][:values][0][:value]).to eq(message)
      end

      it 'does not belong to a module' do
        expect(hash[:exception][:values][0][:module]).to eq('')
      end
    end

    context 'for a nested exception type' do
      module Raven::Test
        class Exception < RuntimeError; end
      end
      let(:exception) { Raven::Test::Exception.new(message) }

      it 'sends the module name as part of the exception info' do
        expect(hash[:exception][:values][0][:module]).to eq('Raven::Test')
      end
    end

    context 'for a Raven::Error' do
      let(:exception) { Raven::Error.new }
      it 'does not create an event' do
        expect(Raven::Event.capture_exception(exception)).to be_nil
      end
    end

    context 'for an excluded exception type' do
      module Raven::Test
        class BaseExc < RuntimeError; end
        class SubExc < BaseExc; end
        module ExcTag; end
      end
      let(:config) do
        config = Raven::Configuration.new
        config.logger = Logger.new(nil)
        config
      end

      context "invalid exclusion type" do
        it 'returns Raven::Event' do
          config.excluded_exceptions << nil
          config.excluded_exceptions << 1
          config.excluded_exceptions << {}
          expect(Raven::Event.capture_exception(Raven::Test::BaseExc.new,
                                                :configuration => config)).to be_a(Raven::Event)
        end
      end

      context "defined by string type" do
        it 'returns nil for a class match' do
          config.excluded_exceptions << 'Raven::Test::BaseExc'
          expect(Raven::Event.capture_exception(Raven::Test::BaseExc.new,
                                                :configuration => config)).to be_nil
        end

        it 'returns nil for a top class match' do
          config.excluded_exceptions << '::Raven::Test::BaseExc'
          expect(Raven::Event.capture_exception(Raven::Test::BaseExc.new,
                                                :configuration => config)).to be_nil
        end

        it 'returns nil for a sub class match' do
          config.excluded_exceptions << 'Raven::Test::BaseExc'
          expect(Raven::Event.capture_exception(Raven::Test::SubExc.new,
                                                :configuration => config)).to be_nil
        end

        it 'returns nil for a tagged class match' do
          config.excluded_exceptions << 'Raven::Test::ExcTag'
          expect(Raven::Event.capture_exception(Raven::Test::SubExc.new.tap { |x| x.extend(Raven::Test::ExcTag) },
                                                :configuration => config)).to be_nil
        end

        it 'returns Raven::Event for an undefined exception class' do
          config.excluded_exceptions << 'Raven::Test::NonExistentExc'
          expect(Raven::Event.capture_exception(Raven::Test::BaseExc.new,
                                                :configuration => config)).to be_a(Raven::Event)
        end
      end

      context "defined by class type" do
        it 'returns nil for a class match' do
          config.excluded_exceptions << Raven::Test::BaseExc
          expect(Raven::Event.capture_exception(Raven::Test::BaseExc.new,
                                                :configuration => config)).to be_nil
        end

        it 'returns nil for a sub class match' do
          config.excluded_exceptions << Raven::Test::BaseExc
          expect(Raven::Event.capture_exception(Raven::Test::SubExc.new,
                                                :configuration => config)).to be_nil
        end

        it 'returns nil for a tagged class match' do
          config.excluded_exceptions << Raven::Test::ExcTag
          expect(Raven::Event.capture_exception(Raven::Test::SubExc.new.tap { |x| x.extend(Raven::Test::ExcTag) },
                                                :configuration => config)).to be_nil
        end
      end
    end

    # Only check causes when they're supported
    if Exception.new.respond_to? :cause
      context 'when the exception has a cause' do
        let(:exception) { build_exception_with_cause }

        it 'captures the cause' do
          expect(hash[:exception][:values].length).to eq(2)
        end
      end

      context 'when the exception has nested causes' do
        let(:exception) { build_exception_with_two_causes }

        it 'captures nested causes' do
          expect(hash[:exception][:values].length).to eq(3)
        end
      end
    end

    context 'when the exception has a recursive cause' do
      let(:exception) { build_exception_with_recursive_cause }

      it 'should handle it gracefully' do
        expect(hash[:exception][:values].length).to eq(1)
      end
    end

    if RUBY_PLATFORM == "java"
      context 'when running under jRuby' do
        let(:exception) do
          begin
            raise java.lang.OutOfMemoryError, "A Java error"
          rescue Exception => e
            return e
          end
        end

        it 'should have a backtrace' do
          frames = hash[:exception][:values][0][:stacktrace][:frames]
          expect(frames.length).not_to eq(0)
        end
      end
    end

    context 'when the exception has a backtrace' do
      let(:exception) do
        e = Exception.new(message)
        allow(e).to receive(:backtrace).and_return [
          "/path/to/some/file:22:in `function_name'",
          "/some/other/path:1412:in `other_function'"
        ]
        e
      end

      it 'parses the backtrace' do
        frames = hash[:exception][:values][0][:stacktrace][:frames]
        expect(frames.length).to eq(2)
        expect(frames[0][:lineno]).to eq(1412)
        expect(frames[0][:function]).to eq('other_function')
        expect(frames[0][:filename]).to eq('/some/other/path')

        expect(frames[1][:lineno]).to eq(22)
        expect(frames[1][:function]).to eq('function_name')
        expect(frames[1][:filename]).to eq('/path/to/some/file')
      end

      context 'with internal backtrace' do
        let(:exception) do
          e = Exception.new(message)
          allow(e).to receive(:backtrace).and_return(["<internal:prelude>:10:in `synchronize'"])
          e
        end

        it 'marks filename and in_app correctly' do
          frames = hash[:exception][:values][0][:stacktrace][:frames]
          expect(frames[0][:lineno]).to eq(10)
          expect(frames[0][:function]).to eq("synchronize")
          expect(frames[0][:filename]).to eq("<internal:prelude>")
        end
      end

      it "sets the culprit" do
        expect(hash[:culprit]).to eq("/path/to/some/file in function_name at line 22")
      end

      context 'when a path in the stack trace is on the load path' do
        before do
          $LOAD_PATH << '/some'
        end

        after do
          $LOAD_PATH.delete('/some')
        end

        it 'strips prefixes in the load path from frame filenames' do
          frames = hash[:exception][:values][0][:stacktrace][:frames]
          expect(frames[0][:filename]).to eq('other/path')
        end
      end
    end

    describe "#get_file_context" do
      it "delegates to the linecache" do
        expect(subject.linecache).to receive(:get_file_context)

        subject.get_file_context("this", 2, 10)
      end
    end

    it 'accepts an options hash' do
      expect(Raven::Event.capture_exception(exception, :logger => 'logger').logger).to eq('logger')
    end

    it 'uses an annotation if one exists' do
      Raven.annotate_exception(exception, :logger => 'logger')
      expect(Raven::Event.capture_exception(exception).logger).to eq('logger')
    end

    it 'accepts a checksum' do
      expect(Raven::Event.capture_exception(exception, :checksum => 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa').checksum).to eq('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    end

    it 'accepts a release' do
      expect(Raven::Event.capture_exception(exception, :release => '1.0').release).to eq('1.0')
    end

    it 'accepts a fingerprint' do
      expect(Raven::Event.capture_exception(exception, :fingerprint => ['{{ default }}', 'foo']).fingerprint).to eq(['{{ default }}', 'foo'])
    end

    it 'accepts a logger' do
      expect(Raven::Event.capture_exception(exception, :logger => 'root').logger).to eq('root')
    end
  end
end
