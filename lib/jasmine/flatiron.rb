require "jasmine/flatiron/version"

module Jasmine
  module Flatiron
    class PhantomChecker
      def self.check_installation
        new.check_installation
      end

      def check_installation
        if !brew_installed?
          puts "You must have Homebrew installed."
          exit
        else
          if !phantom_installed?
            install_phantomjs
          end
        end
      end

      def brew_installed?
        !`which brew`.empty?
      end

      def phantom_installed?
        !`brew ls --versions phantomjs`.empty?
      end

      def install_phantomjs
        `brew install phantomjs`
      end
    end

    class Initializer
      def self.run
        new.run
      end

      def run
        make_spec_directory
        generate_app_js
      end

      def make_spec_directory
        FileUtils.mkdir_p('spec')
        FileUtils.touch('spec/.keep')
      end

      def generate_app_js
        FileUtils.cp(
          "#{FileFinder.location_to_dir('templates')}/requires.yml.example",
          'requires.yml'
        )
      end
    end

    class FileFinder
      def self.location_to_dir(dir_name)
        new.location_to_dir(dir_name)
      end

      def location_to_dir(dir_name)
        File.join(File.dirname(File.expand_path(__FILE__)), "#{dir_name}")
      end

      def self.location_to_file(file_name)
        new.location_to_file(file_name)
      end

      def location_to_file(file_name)
        File.join(File.dirname(File.expand_path(__FILE__)))
      end
    end

    class Runner
      attr_reader :no_color, :local, :browser, :conn, :color_opt
      attr_accessor :json_results

      def self.run(options)
        new(options).run
      end

      def initialize(options)
        @no_color = !!options[:color]
        @color_opt = !no_color ? "" : "NoColor"
        @local = !!options[:local]
        @browser = !!options[:browser]
        @json_results = {
          testsuites: [],
          tests: 0,
          errors: 0,
          failures: 0,
          time: 0.0
        }
        @conn = Faraday.new(url: SERVICE_URL) do |faraday|
          faraday.request  :url_encoded
          faraday.adapter  Faraday.default_adapter
        end
      end

      def run
        make_runner_html

        if browser
          `open #{FileFinder.location_to_dir('runners')}/SpecRunner#{color_opt}.html`
        else
          system("phantomjs #{FileFinder.location_to_dir('runners')}/run-jasmine.js #{FileFinder.location_to_dir('runners')}/SpecRunner#{color_opt}.html")
        end

        make_json
        puts json_results.inspect
        # unless local
        #   push_to_flatiron
        # end

        # clean_up
      end

      def make_json
        Dir.entries(FileUtils.pwd).keep_if { |f| f.match(/TEST/) }.each do |f|
          parsed = JSON.parse(Crack::XML.parse(File.read(f)).to_json)["testsuites"]["testsuite"]
          json_results[:testsuites] << parsed["testcase"]
          json_results[:testsuites].flatten!
          json_results[:tests] += parsed["tests"].to_i
          json_results[:errors] += parsed["errors"].to_i
          json_results[:failures] += parsed["failures"].to_i
          json_results[:time] += parsed["time"].to_f
        end
      end

      def push_to_flatiron
        conn.post(SERVICE_ENDPOINT, )
      end

      def make_runner_html
        template = ERB.new(File.read("#{FileFinder.location_to_dir('templates')}/SpecRunnerTemplate#{color_opt}.html.erb"))

        yaml = YAML.load(File.read('requires.yml'))["javascripts"]
        required_files = yaml["files"]
        required_specs = yaml["specs"]

        @javascripts = required_files.map {|f| "#{FileUtils.pwd}/#{f}"}.concat(
          required_specs.map {|s| "#{FileUtils.pwd}/#{s}"}
        )

        File.open("#{FileFinder.location_to_dir('runners')}/SpecRunner#{color_opt}.html", 'w+') do |f|
          f << template.result(binding)
        end
      end

      def clean_up
        FileUtils.rm("#{FileFinder.location_to_dir('runners')}/SpecRunner#{color_opt}.html")
      end
    end
  end
end
