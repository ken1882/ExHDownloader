# -*- coding: utf-8 -*-

require 'mechanize'
require 'open-uri'
require 'json'

module ExHDownloader
  
  attr_reader :agent, :cookies
  attr_reader :parent_doc
  attr_reader :uid, :page_cnt, :total_cnt
  attr_reader :next_link, :timeout, :redownloads, :retry_max

  UID_regex = /\/g\/(\d+)\/(.+)/
  TotalImg_regex = /Showing(.+)of (\d+) images/i
  DownloadLocation = "Downloads/"
  FailLogLoction   = "FailLogs/"
  DownloadAsync = true
  DefaultTimeout  = 10
  DefaultRetryMax = 5

  module_function
  def initialize()
    @agents = [Agent.new(0), Agent.new(1)]

    File.open('cookie.json', 'r') do |file|
      content = file.read
      @cookies = JSON.parse(content)
    end
    @cookies.each do |ck|
      begin
        if is_cookie_expired(ck)
          puts "Your cookie is expired, please update `cookie.json`"
          exit
        end
        @agents.first.cookie_jar << Mechanize::Cookie.new(ck)
      rescue Exception
        puts "Error while loading cookie! Please make sure 'cookie.json' has correct info or update it"
        exit
      end
    end
    @agents.each{|ag| ag.cookie_jar = @agents.first.cookie_jar}

    $mutex = Mutex.new
    @timeout     = $timeout ? $timeout : DefaultTimeout
    @retry_max   = $retry_max ? $retry_max : DefaultRetryMax
    init_members()
    puts "Engine initialized, download timeout: #{@timeout} seconds"
  end

  def retry_max; @retry_max; end
  def timeout; @timeout; end

  def init_members
    @flag_terminte = false
  end

  def is_cookie_expired(ck)
    return Time.now.to_f >= ck["expirationDate"]
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
      @parent_doc = fetch(link)

      begin
        @parent_doc.title
      rescue Exception
        puts("failed\nGot a sad panda :( please check your 'cookie.json' has correct info or update it")
        exit
      end
    end
    check_content_valid()
    folder = build_folder
    preprare_download
    start_download(folder)
  end

  def verify_link(link)
    return false unless link.downcase.start_with?("https://exhentai.org/g")
    return true
  end

  def check_content_valid()
    return true if (@parent_doc.title || '').include?("- ExHentai.org")
    puts "The link you entered: `#{@parent_doc.uri}` seems invalid, please check it."
    puts "Abort program"
    exit
  end

  def build_folder
    title = DownloadLocation + @parent_doc.title.gsub(' - ExHentai.org','').tr('?*:><|\\/\"','')

    eval_action("Build folder `#{title}``...") do
      unless File.exist?(title)
        Dir.mkdir(title)
      end
    end
    return title
  end

  def preprare_download
    if @parent_doc.search(".gpc").text.match(TotalImg_regex)
      @total_cnt = $2.to_i
      puts "Total images: #{@total_cnt}"
    end
    puts "Preparing download"
    @agents.each{|ag| ag.setup(@parent_doc, @total_cnt)}
  end

  def find_links
    node = @parent_doc.search("#i3").first
    node = Nokogiri::HTML(node.children[0].to_s)
    return [node.css("a").first["href"], node.css('img').first['src']]
  end

  def start_download(folder)
    while !@parent_doc.uri.to_s.include?(@next_link.to_s)
      @parent_doc = fetch(@next_link)
      download_current_page(folder, false)
    end
  end

  def download_current_page(folder, redownloading)
    @next_link, image = *find_links
    file_index = redownloading ? @redownload_index[@page_cnt] : @page_cnt
    path  = "#{folder}/#{format_image_filename(image, file_index)}"
    time_st = Time.now
    download_image(image, path, DownloadAsync)
    time_st = wait4download(time_st, redownloading)
    puts "Time taken: #{time_st.round(3)} sec" if time_st < @timeout
    @total_time += time_st
    @page_cnt += 1
  end

  def wait4download(start_t, is_redownloading=false)
    if DownloadAsync
      while !$th_ok
        sleep(0.1)
        if (Time.now - start_t).to_f > @timeout
          puts "Download timeout (> #{@timeout} sec), killing thread"
          Thread.kill($worker)
          if !is_redownloading
            @redownloads << @parent_doc.uri.dup.to_s
            @redownload_index << @page_cnt
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
      begin
        open(img_url) do |img|
          File.open(path, 'wb') do |file|
            buffer = img.read
            file.puts(buffer)
            @total_size += buffer.size
          end
        end
      rescue OpenSSL::SSL::SSLError => err
        warning("\nA SSL error has encountered: #{err}, SSL verification will be disabled!\n")
        open(img_url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}) do |img|
          File.open(path, 'wb') do |file|
            buffer = img.read
            file.puts(buffer)
            @total_size += buffer.size
          end
        end
      end # begin
    end # eval_action
  end

  def redownload_images(folder)
    puts "Redownload timeout images..."
    @page_cnt = 0
    @total_cnt = @redownloads.size
    @redownloads.each do |link|
      @parent_doc = fetch(link)
      download_current_page(folder, true)
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
    deg = 4 # 4-digit
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
