require "jasmine/flatiron/version"

module Jasmine
  module Flatiron
    class UsernameParser
      def self.get_username
        parser = NetrcInteractor.new
        username = parser.username

        if !username
          print "Enter your github username: "
          username = gets.strip
          user_id = GitHubInteractor.get_user_id_for(username)
          parser.write(username, user_id)
        end

        username
      end
    end

    class UserIdParser
      def self.get_user_id
        parser = NetrcInteractor.new
        user_id = parser.user_id
      end
    end

    class GitHubInteractor
      attr_reader :username, :user_id

      def self.get_user_id_for(username)
        new(username).get_user_id
      end

      def initialize(username)
        @username = username
      end

      def get_user_id
        @user_id ||= Oj.load(
          open("https://api.github.com/users/#{username}").read,
          symbol_keys: true
        )[:id]
      end
    end

    class NetrcInteractor
      attr_reader :username, :user_id, :netrc

      def initialize
        @netrc = Netrc.read
        @username, @user_id = netrc["flatiron-push"]
      end

      def write(username, user_id)
        netrc["flatiron-push"] = username, user_id
        netrc.save
      end
    end

    class RepoParser
      def self.get_repo
        begin
          repo = Git.open(FileUtils.pwd)
        rescue
          puts "Not a valid Git repository"
          die
        end

        url = repo.remote.url

        repo_name = url.match(/(?:https:\/\/|git@).*\/(.+)(?:\.git)/)[1]
      end

      def self.die
        exit
      end
    end

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
      attr_reader :no_color, :local, :browser, :conn, :color_opt, :out
      attr_accessor :json_results

      def self.run(username, user_id, repo_name, options)
        new(username, user_id, repo_name, options).run
      end

      def initialize(username, user_id, repo_name, options)
        @no_color = !!options[:color]
        @color_opt = !no_color ? "" : "NoColor"
        @local = !!options[:local]
        @browser = !!options[:browser]
        @out = options[:out]
        @json_results = {
          username: username,
          github_user_id:user_id,
          repo_name: repo_name,
          build: {
            test_suite: [{
              framework: 'jasmine',
              formatted_output: [],
              duration: 0.0
            }]
          },
          tests: 0,
          errors: 0,
          failures: 0
        }
        @conn = Faraday.new(url: SERVICE_URL) do |faraday|
          faraday.adapter  Faraday.default_adapter
        end
      end

      def run
        make_runner_html
        run_jasmine
        make_json
        push_to_flatiron unless local || browser
        clean_up
      end

      def run_jasmine
        if browser
          system("open #{FileFinder.location_to_dir('runners')}/SpecRunner#{color_opt}.html")
        else
          system("phantomjs #{FileFinder.location_to_dir('runners')}/run-jasmine.js #{FileFinder.location_to_dir('runners')}/SpecRunner#{color_opt}.html")
        end
      end

      def make_json
        if local || !browser
          test_xml_files.each do |f|
            parsed = JSON.parse(Crack::XML.parse(File.read(f)).to_json)["testsuites"]["testsuite"]
            json_results[:build][:test_suite][0][:formatted_output] << parsed["testcase"]
            json_results[:build][:test_suite][0][:formatted_output].flatten!
            json_results[:tests] += parsed["tests"].to_i
            json_results[:errors] += parsed["errors"].to_i
            json_results[:failures] += parsed["failures"].to_i
            json_results[:build][:test_suite][0][:duration] += parsed["time"].to_f
          end
          set_passing_test_count
        end

        if out
          write_json_output
        end
      end

      def set_passing_test_count
        json_results[:passing_count] = json_results[:tests] - json_results[:failures] - json_results[:errors]
      end

      def write_json_output
        File.open(out, 'w+') do |f|
          f.write(json_results.to_json)
        end
      end

      def push_to_flatiron
        conn.post do |req|
          req.url SERVICE_ENDPOINT
          req.headers['Content-Type'] = 'application/json'
          req.body = json_results.to_json
        end
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

      def test_xml_files
        Dir.entries(FileUtils.pwd).keep_if { |f| f.match(/TEST/) }
      end

      def clean_up
        test_xml_files.each do |file|
          FileUtils.rm(file)
        end
      end
    end
  end
end
