module Guard
  class KonachaRails
    class Runner
      DEFAULT_OPTIONS = {
        run_all_on_start: true,
        notification: true,
        rails_environment_file: './config/environment'
      }.freeze

      attr_reader :options, :formatter

      def initialize(options = {})
        @options = DEFAULT_OPTIONS.merge(options)

        # Require project's rails environment file to load Konacha configuration.
        require_rails_environment
        raise 'Konacha not loaded' unless defined? ::Konacha

        # Custom formatter to handle multiple runs.
        @formatter = Formatter.new
        ::Konacha.config.formatters = [@formatter]

        # Reusable session to increase performance.
        @session = Capybara::Session.new(::Konacha.driver, Server.new)

        ::Konacha.mode = :runner

        UI.info 'Guard::KonachaRails Initialized'
      end

      def start
        run if options[:run_all_on_start]
      end

      def run(paths = [''])
        formatter.reset

        paths.each do |path|
          if path.empty? or File.exists? real_path path
            UI.info "Guard::KonachaRails running #{specs_description(path)}"
            runner.run konacha_path(path)
          end
        end

        formatter.write_summary
        notify
      rescue => e
        UI.error(e)
      end

      private

      def require_rails_environment
        if @options[:rails_environment_file]
          require @options[:rails_environment_file]
        else
          dir = '.'
          while File.expand_path(dir) != '/' do
            env_file = File.join(dir, 'config/environment.rb')
            if File.exist?(env_file)
              require File.expand_path(env_file)

              break
            end
            dir = File.join(dir, '..')
          end
        end
      end

      def specs_description(path)
        path.empty? ? "all specs" : path
      end

      def runner
        ::Konacha::Runner.new(@session)
      end

      def konacha_path(path)
        '/' + path.gsub(/^#{::Konacha.config[:spec_dir]}\/?/, '').gsub(/\.coffee$/, '').gsub(/\.js$/, '')
      end

      def real_path(path)
        path.empty? ? all_specs_path : specific_path(path)
      end

      def all_specs_path
        "#{::Rails.root.join(::Konacha.config[:spec_dir])}#{konacha_path('')}"
      end

      def specific_path(path)
        ::Rails.root.join(path).to_s
      end

      def unique_id
        "#{Time.now.to_i}#{rand(100)}"
      end

      def notify
        if options[:notification]
          image = @formatter.success? ? :success : :failed
          ::Guard::Notifier.notify(@formatter.summary_line, title: 'Konacha Specs', image: image)
        end
      end
    end
  end
end
