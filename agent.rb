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

  def setup(si=0, di=nil)
    @redownloads = []
    @redownload_index = []
    @current_doc = nil
    @next_link   = nil
    @progress    = [0, (di || 0) - si]
    @start_index, @dest_index = si, di
  end

  def download_current_page(is_redownloading)
    @next_link, image = *find_links
    file_index = is_redownloading ? @redownload_index[@page_cnt] : @page_cnt
    path  = "#{@target_folder}/#{ExHDownloader.format_image_filename(image, file_index)}"
    time_st = Time.now
    download_image(image, path)
    time_st = wait4download(time_st, redownloading)
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

  def wait4download(start_t)
    while !@th_ok
      sleep(0.1)
      if (Time.now - start_t).to_f > @timeout
        puts "Worker##{@index} - Download timeout (> #{@timeout} sec), killing thread and retry"
        Thread.kill(@worker)
        if !is_redownloading
          @redownloads << @current_doc.uri.dup.to_s
          @redownload_index << @page_cnt
        else
          @failed << $cur_download_url
        end
        $th_ok = true
        break
      end
    end
    return (Time.now - start_t).to_f
  end

end