require "jasmine/flatiron/version"

module Jasmine
  module Flatiron
    class PhantomChecker
      def self.installed?
        new.installed?
      end

      def installed?
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
        FileUtils.mkdir('spec')
        FileUtils.touch('spec/.keep')
      end

      def generate_app_js
        FileUtils.cp(
          "#{FileFinder.location_to_dir('templates')}/app.js.example",
          'app.js'
        )
      end
    end

    class FileFinder
      def self.location_to_dir(dir_name)
        new.location_to_dir(dir_name)
      end

      def location_to_dir(dir_name)
        puts __FILE__
        File.join(File.dirname(File.expand_path(__FILE__)), "#{dir_name}")
      end

      def self.location_to_file(file_name)
        new.location_to_file(file_name)
      end

      def location_to_file(file_name)
        File.join(File.dirname(File.expand_path(__FILE__)))
      end
    end
  end
end
