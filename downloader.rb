require 'mechanize'
require 'open-uri'
require 'json'

module ExHDownloader
  
  attr_reader :agent, :cookies
  attr_reader :current_doc
  attr_reader :uid, :page_cnt, :total_cnt
  attr_reader :next_link, :timeout, :redownloads

  UID_regex = /\/g\/(\d+)/
  TotalImg_regex = /Showing(.+)of (\d+) images/i
  DownloadLocation = "Downloads/"
  FailLogLoction   = "FailLogs/"
  DownloadAsync = true
  DefaultTimeout = 10

  module_function
  def initialize()
    @agent = Mechanize.new
    File.open('cookie.json', 'r') do |file|
      content = file.read
      @cookies = JSON.parse(content)
    end
    @cookies.each do |ck|
      @agent.cookie_jar << Mechanize::Cookie.new(ck)
    end

    $mutex = Mutex.new
    @current_doc = nil
    @next_link   = nil
    @page_cnt    = 0
    @total_cnt   = 0
    @timeout     = $timeout ? $timeout : DefaultTimeout
    @redownloads = []
    @failed      = []
    @flag_terminte = false
    @total_time = 0
    @total_size = 0
    @succ_cnt = 0
    puts "Engine initialized, download timeout: #{@timeout} seconds"
  end

  def eval_action(load_msg, &block)
    print(load_msg)
    yield block
    puts ("succeed")
  end

  def connect(link)
    unless verify_link(link) && link.match(UID_regex)
      puts "Invalid link!"
      exit
    end
    @uid = $1
    puts "UID: #{@uid}"
    eval_action("Connecting to `#{link}`...") do
      @current_doc = @agent.get(link)
      begin
        @current_doc.title
      rescue Exception
        puts("failed\nGot a sad panda :( please check your 'cookie.json' has correct info or update it")
        exit
      end
    end
    
    folder = build_folder
    preprare_download
    start_download(folder)
    redownload_images(folder) if @redownloads.size > 0
    summerize(folder)
  end

  def verify_link(link)
    return false unless link.downcase.start_with?("https://exhentai.org/g")
    return true
  end

  def build_folder
    title = DownloadLocation + @current_doc.title.gsub(' - ExHentai.org','').tr('?*:><|\\/\"','')

    eval_action("Build folder `#{title}``...") do
      unless File.exist?(title)
        Dir.mkdir(title)
      end
    end
    return title
  end

  def preprare_download
    if @current_doc.search(".gpc").text.match(TotalImg_regex)
      @total_cnt = $2.to_i
      puts "Total images: #{@total_cnt}"
    end
    puts "Preparing download"
    @next_link = @current_doc.links_with(href: Regexp.new("#{@uid}-1")).first.uri
  end

  def start_download(folder)
    while !@current_doc.uri.to_s.include?(@next_link.to_s)
      @current_doc = @agent.get(@next_link)
      node = @current_doc.search("#i3").first
      node = Nokogiri::HTML(node.children[0].to_s)
      @next_link = node.css("a").first["href"]
      image = node.css('img').first['src']
      path  = "#{folder}/#{format_image_filename(image, @page_cnt)}"
      time_st = Time.now
      download_image(image, path, DownloadAsync)
      time_st = wait4download(time_st)
      puts "Time taken: #{time_st.round(3)} sec"
      @total_time += time_st
      @page_cnt += 1
    end
  end

  def wait4download(start_t, redownload=true)
    if DownloadAsync
      while !$th_ok
        sleep(0.1)
        if (Time.now - start_t).to_f > @timeout
          puts "Download timeout (> #{@timeout} sec), killing thread"
          Thread.kill($worker)
          if redownload
            @redownloads << $cur_download_url
          else
            @failed << $cur_download_url
          end
          $th_ok = true
          break
        end
      end
    end
    return (Time.now - start_t).to_f
  end

  def download_image(img_url, path, async=true)
    return _download_image(img_url, path) unless async
    $cur_download_url = img_url
    $th_ok = false
    $worker = Thread.new{
      $mutex.synchronize{
        _download_image(img_url, path)
        @succ_cnt += 1
        $th_ok = true
      }
    }
  end

  def _download_image(img_url, path)
    verbose = $verbose ? "(#{img_url} => #{path})\n-----------------" : ''
    eval_action("Downloading #{@page_cnt+1}/#{@total_cnt > 0 ? @total_cnt : '???'}#{verbose}...") do
      open(img_url) do |img|
        File.open(path, 'wb') do |file|
          buffer = img.read
          file.puts(buffer)
          @total_size += buffer.size
        end
      end
    end
  end

  def redownload_images(folder)
    puts "Redownload timeout images..."
    @page_cnt = 0
    @total_cnt = @redownloads.size
    @redownloads.each do |img_url|
      path = "#{folder}/#{format_image_filename(img_url, @page_cnt)}"
      time_st = Time.now
      download_image(img_url, path)
      time_st = wait4download(time_st, false)
      puts "Time taken: #{time_st.round(3)} sec"
      @total_time += time_st
      @page_cnt += 1
    end
  end

  def summerize(folder)
    title = folder.split("/").last
    puts "===================="
    puts "Total time taken: #{@total_time.round(3)} seconds"
    scale = 0
    ori_tsize = @total_size
    while @total_size > 1024
      @total_size /= 1024
      scale += 1
    end
    puts "Total size: ~#{@total_size.round(2)} #{["Bytes", "KB", "MB", "GB", "TB", "PB", "EB"].at(scale)}"
    puts "Download speed: ~#{ori_tsize / (@total_time * 1024 * 1024)} MB/sec"
    puts "Downloaded files: #{@succ_cnt}"
    puts "Failed download: #{@failed.size}"
    if @failed.size > 0
      path = FailLogLoction + "#{title}.txt"
      puts "Image url of failed downloads has outputed to `#{path}`"
      File.open(path, 'w') do |file|
        @failed.each do |url|
          file.puts(url)
        end
      end
    end
  end

  def to_fileid(num)
    deg = 3 # 3-digit
    n = num.to_i
    cnt = 0
    while n > 0
      n /= 10
      cnt += 1
    end
    cnt = [cnt, 1].max
    return ('0' * (deg - cnt)) + num.to_s
  end

  def format_image_filename(img, cnt)
    to_fileid(cnt) + '.' + img.split('.').last
  end
end