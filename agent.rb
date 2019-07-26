# -*- coding: utf-8 -*-

class Agent < Mechanize

  attr_reader :index
  attr_reader :current_doc
  attr_reader :next_link
  attr_reader :start_index, :dest_index
  attr_reader :progress, :redownload_index, :redownloads
  attr_accessor :target_folder

  def initialize(index=0)
    @index = index
    super()
  end
  
  def setup(parent_doc, total_cnt)
    @timeout = ExHDownloader.timeout
    @retry_max = ExHDownloader.retry_max
    @redownloads = []
    @redownload_index = []
    @current_doc = nil
    @next_link   = nil
    @progress    = [0, total_cnt]
    @start_index, @dest_index = si, di
    @parent_doc.links_with(href: Regexp.new("#{@uid}-1")).first.uri
  end

  def fetch(url, depth=0)
    begin
      return self.get(url)
    rescue OpenSSL::SSL::SSLError => err
      warning("\nA SSL error has encountered: #{err}, SSL verification will be disabled!\n")
      self.verify_mode = OpenSSL::SSL::VERIFY_NONE
      return self.get(url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE})
    rescue Mechanize::ResponseCodeError => err
      warning("\nReceived response code #{err.response_code}, retrying...(depth=#{depth})")
      sleep(0.1)
      return fetch(url, depth + 1) if depth < @retry_max
      puts "Retry times > #{@retry_max}, abort"
      puts "======================="
      puts report_exception(err)
      exit
    end
  end

  def cur_page_index
    return self.uri.split('-').last.to_i rescue nil
  end

  def download_current_page
    @next_link, image = *find_links
    file_index = @page_cnt
    path  = "#{@target_folder}/#{ExHDownloader.format_image_filename(image, file_index)}"
    time_st = Time.now
    download_image(image, path)
    time_st = wait4download(time_st, image, path)
    puts "Time taken: #{time_st.round(3)} sec" if time_st < @timeout
    @total_time += time_st
    @page_cnt += 1
  end

  def download_image(img_url, path)
    @cur_download_url = img_url
    @th_ok = false
    @worker = Thread.new{
      $mutex.synchronize{
        _download_image(img_url, path)
        @succ_cnt += 1
        @th_ok = true
      }
    }
  end

  def _download_image(img_url, path)
    verbose = $verbose ? "(#{img_url} => #{path})\n-----------------" : ''
    eval_action("Worker##{@index} - Downloading #{@page_cnt+1}/#{@total_cnt > 0 ? @total_cnt : '???'}#{verbose}...") do
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

  def find_links
    node = @current_doc.search("#i3").first
    node = Nokogiri::HTML(node.children[0].to_s)
    return [node.css("a").first["href"], node.css('img').first['src']]
  end

  def wait4download(start_t, image, path)
    while !@th_ok
      sleep(0.1)
      if (Time.now - start_t).to_f > @timeout
        puts "Worker##{@index} - Download timeout (> #{@timeout} sec), retry..."
        Thread.kill(@worker)
        @th_ok = false
        start_t = Time.now
        download_image(image, path)
      end
    end
    return (Time.now - start_t).to_f
  end


  def finihsed?
    return @progress.first > 0 && @progress.fist == @progress.last
  end
end