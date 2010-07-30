require 'rubygems'
require 'ap'
module Primadoro
  class <<self
    def run
      @config_options = read_config
      ap @config_options
      @views = load_views(@config_options['views']) || 
        [
          Views::Tunes.new,
          Views::Growl.new,
          Views::Sound.new
        ]
      @views += add_commands(@config_options['commands'])

      @actions = {'break_time' => 5, 'pomodoro' => 25}
      @actions.merge!(@config_options['actions']) if @config_options['actions']
      # puts "Actions after merge:"
      # ap @actions
      # puts "Views:"
      # ap @views

      while(true)
        # TODO: Add action hooks later
        action('pomodoro')
        action('break_time')
      end
    end
  
    def action(action_taken)
      puts "#{action_taken} at #{Time.now.strftime('%D %T')}"
            
      @views.each {|v| v.send(action_taken.to_sym)}
      sleep(@actions[action_taken] * 60)
    end

    private

    def read_config
      require 'yaml'
      config = YAML.load(File.read(File.expand_path('~/.primadoro'))) rescue {}
    end

    # You can't handle the true
    def falsy(value)
      answer = false
      case value
      when nil
        answer = true
      when false
        answer = true
      when /off|no|False/i
        answer = true
      when 0
        answer = true
      end
      answer
    end

    def load_views(views)
      return if views.nil?
      enabled_views = []
      views.each do |view, enable|
        puts "Handling #{view} as #{enable} (#{! falsy(enable)})"
        case view
        when /growl/
          enabled_views << Views::Growl.new unless falsy(enable)
        when /tunes/
          enabled_views << Views::Tunes.new unless falsy(enable)
        when /sound/
          enabled_views << Views::Sound.new unless falsy(enable)
        else
          puts "Wha? There's no #{view_name.class}, fool!"
        end
      end
      enabled_views
    end

    def add_commands(commands)
      return if commands.nil?
      enabled_commands = []
      commands.each do |command, args|
        # puts "Adding #{command} with #{args}"
        # ap command
        # ap args
        enabled_commands << Views::Command.new(args)
      end
      enabled_commands
    end
  end

  module Views
    class Base
      # TODO: Add intermittent update displays for timers etc.
      def display?(runner); false; end
    
      def display!
        raise "Implement the display! method on #{self.class.name} if you're going to make me display, fool!"
      end

      def pomodoro; end
      
      def break_time; end
    end

    class Growl < Base
      begin
        require 'ruby-growl'

        def initialize
          @growler = ::Growl.new "localhost", "Primadoro", ["pomodoro", "break time"]
        end  
      
        def pomodoro
          @growler.notify "pomodoro", "Pomodoro time!", "Get your work on..." rescue puts "! Growl not configured properly (make sure you allow network connections)"
        end
      
        def break_time
          @growler.notify "break time", "Break time!", "Get your break on..." rescue puts "! Growl not configured properly (make sure you allow network connections)"
        end
      rescue Exception
        require 'rubygems' and retry 
        
        puts "! Install ruby-growl for growl support (no Windows etc. support yet)"
      end
    end

    class Sound < Base
      def play(file)
        if RUBY_PLATFORM =~ /darwin/
          `afplay #{file}`
        elsif RUBY_PLATFORM =~ /mswin32/
          `sndrec32 /play /close "#{file}"`
        else
          `play #{file}`
        end
      end
      
      def pomodoro
        play(File.join(File.dirname(__FILE__), "..", "resources", "windup.wav"))
      end
      
      def break_time
        play(File.join(File.dirname(__FILE__), "..", "resources", "bell.mp3"))        
      end
    end

    class Tunes < Base
      begin
        require 'rbosa'
        
        def initialize
          @app = OSA.app('iTunes')
        end

        def pomodoro
          @app.play rescue puts '! iTunes not running'
        end

        def break_time
          @app.pause rescue puts '! iTunes not running'
        end
      rescue Exception
        require 'rubygems' and retry 
        
        puts "! To use the iTunes integration, you need rubyosa installed! (no Windows etc. support yet)"
      end
    end

    class Command < Base
      def initialize(options = {})
        @cmd = options.delete('command')
        @p_cmd = options.delete('pomodoro')
        @b_cmd = options.delete('break_time')
        @args = options
        @args.each do |k,v|
          instance_variable_set("@#{k}", v)
        end
      end

      def pomodoro
        cmd = eval '"' + (@p_cmd || @cmd) + '"'
        system(cmd)
      end

      def break_time
        cmd = eval '"' + (@b_cmd || @cmd) + '"'
        system(cmd)
      end
    end
  end
end