VERSION = "0.1.0"

# fix windows getrlimit not implement bug
if Gem.win_platform?
  module Process
    RLIMIT_NOFILE = 7

    def self.getrlimit(*args)
      [1024]
    end
  end
end

alias exit_exh exit
def exit(*args, &block)
  print "Press any key to quit"
  ch = STDIN.getch
  exit_exh(*args, &block)
end

require 'optparse'
require 'io/console'
require './downloader'

Options = Struct.new(:name)

class Parser
  def self.parse(options)
    args = Options.new("world")

    opt_parser = OptionParser.new do |opts|
      opts.banner = %{
        Usage: main.rb/ExHDownloader.exe [URL] [Options]
        URL: Link of the upload
        Options:
      }.split(/[\r\n]+/).inject(''){|r, s| r + s.lstrip + "\n"}.chop

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end
      
      opts.on('-v', '--version', 'Prints current version') do
        puts VERSION
        exit
      end

      opts.on("--verbose", "Verbose output") do
        $verbose = true
      end

      opts.on("-tTIMEOUT", "--timeout=TIMEOUT", "Set async download timeout in seconds (default is 10)") do |t|
        $timeout = t.to_i
      end
    end

    opt_parser.parse!(options)
    return args
  end
end

begin
  options = Parser.parse(ARGV)
rescue OptionParser::MissingArgument => err
  puts "Missing argument for option '#{err.args.first}'"
  exit
rescue OptionParser::InvalidOption => err
  puts "Unknown argument: '#{err.args.first}'"
  exit
end

ExHDownloader.initialize()
url = ARGV.first

loop do
  unless url
    print "Please enter the page url: "
    url = gets.chomp
  end
  puts "Link received: #{url}"
  ExHDownloader.init_members()
  ExHDownloader.connect(url)
  url = nil
  print "Press Q to quit, others to continue: "
  ch = STDIN.getch
  puts ch.upcase
  break if ch.upcase == 'Q'
end