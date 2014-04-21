require 'nokogiri'
require 'json'
require 'net/http'
require 'taglib'

module HypeMachine
  class HypeMachine
    DEFAULTS = {
      :options       => {
        :start     => 1,
        :finish    => nil,
        :wait      => 0,
        :proxy     => nil,
        :port      => nil,
        :tor       => false,
        :overwrite => false,
        :quiet     => false,
        :strict    => false,
        :demo      => false
      },
      :headers       => {
        'Accept'              => 'text/html, application/xhtml+xml, application/xml;q=0.9,*/*;q=0.8',
        'Accept-Charset'      => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
        'Accept-Language'     => 'en-us,en;q=0.5',
        'Connection'          => 'close',
        'User-Agent'          => 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:2.0.1) Gecko/20100101 Firefox/4.0.1',
        'X-Prototype-Version' => '1.7',
        'X-Requested-With'    => 'XMLHttpRequest'
      },
      :max_redirects => 2,
      :filename      => {
        :extension          => 'mp3',
        :max_length         => 255,
        :invalid_characters => /[\x00\/\\:\*\?\"<>\|]/
      },
      :tor           => {
        :proxy => '127.0.0.1',
        :port  => 9151
      }
    }

    attr_accessor :path, :directory, :options, :url, :headers,
                  :completed, :failed, :skipped, :total

    def initialize (path, directory = nil, options = {})
      path = path.strip
      raise 'Invalid path' if path.nil? || path.empty?

      directory = File.expand_path(directory || URI.unescape(path).gsub(DEFAULTS[:filename][:invalid_characters], '_'))

      options = DEFAULTS[:options].merge(options)

      if options[:tor]
        options[:proxy] = DEFAULTS[:tor][:proxy]
        options[:port]  = DEFAULTS[:tor][:port]
      end

      options[:finish]  ||= options[:start]
      options[:headers] ||= DEFAULTS[:headers].dup

      raise "Invalid start #{options[:start]}" unless options[:start] >= 1
      raise "Invalid finish #{options[:finish]}" unless options[:finish] >= options[:start]
      raise "Invalid wait #{options[:wait]}" unless options[:wait] >= 0

      frame_factory                       = TagLib::ID3v2::FrameFactory.instance
      frame_factory.default_text_encoding = TagLib::String::UTF8

      self.path      = path
      self.directory = directory
      self.options   = options
      self.headers   = options[:headers]
      self.url       = "http://hypem.com/#{URI.escape(URI.unescape(path))}"
      self.completed = 0
      self.failed    = 0
      self.skipped   = 0
      self.total     = 0
    end

    def run
      puts "Downloading from #{url}/#{options[:start]} to #{url}/#{options[:finish]} into #{directory}", '' unless options[:quiet]
      Dir.mkdir(directory) unless File.directory?(directory)
      (options[:start]..options[:finish]).each { |page| scan(page) }
      puts "Finished downloading tracks from #{url}/#{options[:start]} to #{url}/#{options[:finish]}", "#{total} total, #{completed} completed, #{skipped} skipped, #{failed} failed", 'Enjoy!', ''
    end

    def request (url, headers, redirects = DEFAULTS[:max_redirects])
      uri      = URI.parse(url)
      proxy    = Net::HTTP::Proxy(options[:host], options[:port])
      response = proxy.start(uri.host) do |http|
        http.request_get(uri.request_uri, headers)
      end

      if response.is_a?(Net::HTTPRedirection) && redirects > 0
        url = response['Location']
        puts "\t\tRedirecting request to #{url}" unless options[:quiet]
        response = request(url, headers, redirects - 1)
      end

      response.error! unless response.is_a?(Net::HTTPSuccess)
      response
    end

    def scan (page)
      page_url           = "#{url}/#{page}"
      headers['Referer'] = page_url
      puts "\tScanning for tracks at #{page_url}" unless options[:quiet]
      response          = request("#{page_url}?ax=1", headers)
      headers['Cookie'] = response['Set-Cookie'] if response['Set-Cookie']

      document  = Nokogiri::HTML(response.body)
      data      = document.css('script#displayList-data')
      tracks    = JSON.parse(data.text)['tracks']
      completed = 0
      failed    = 0
      skipped   = 0
      total     = tracks.size

      self.total += total

      puts "\tFound #{total} tracks at #{page_url}", '' unless options[:quiet]
      tracks.each do |track|
        success = download(document, track, page_url)
        if success.nil?
          failed      += 1
          self.failed += 1
        elsif success
          completed      += 1
          self.completed += 1
        else
          skipped      += 1
          self.skipped += 1
        end
      end

      puts "\tFinished downloading tracks from #{page_url}", "\t#{total} total, #{completed} completed, #{skipped} skipped, #{failed} failed", '' unless options[:quiet]
    end

    def download (document, track, page_url)
      success   = nil
      id        = track['id']
      key       = track['key']
      timestamp = track['ts']
      section   = document.css("div#section-track-#{id}")
      links     = section.css('h3.track_name a')
      artist    = links[0] ? links[0]['title'].split(' - ').tap { |artist| artist.pop }.join(' ') : 'Unknown Artist'
      title     = links[1] ? links[1]['title'].split(' - ').tap { |artist| artist.pop }.join(' ') : 'Unknown Title'
      thumb_url = nil
      link      = section.css('a.thumb')[0]
      if link
        /background:\s*url\((.*?)\)/.match(link.attribute('style')) do |match|
          thumb_url = match[1]
        end
      end

      trackname = "#{artist}___#{title}".gsub(DEFAULTS[:filename][:invalid_characters], '_')
      filename  = "#{trackname}___#{id}___#{timestamp}"
      filepath  = "#{directory}/#{filename}.#{DEFAULTS[:filename][:extension]}"

      available_length = DEFAULTS[:filename][:max_length] - filepath.length
      if available_length < 0
        filepath = "#{directory}/#{trackname[0..available_length-1]}___#{id}___#{timestamp}.#{DEFAULTS[:filename][:extension]}"
      end

      if options[:demo]
        puts "\t\tSkipping track #{filename} in demo mode", '' unless options[:quiet]
        success = false
      else
        begin
          if File.exists?(filepath) && !options[:overwrite]
            puts "\t\tSkipping existing track #{filename}", '' unless options[:quiet]
            success = false
          else
            if options[:wait] > 0
              puts "\t\tWaiting #{options[:wait]} seconds", '' unless options[:quiet]
              sleep(options[:wait])
            end

            puts "\t\tStarting track #{filename}" unless options[:quiet]
            source_url = "http://hypem.com/serve/source/#{id}/#{key}"
            puts "\t\tGetting source from #{source_url}" unless options[:quiet]
            response = request(source_url, headers)

            data = JSON.parse(response.body)
            raise 'Invalid track ID' unless data['itemid'] == id

            file_url = data['url']

            puts "\t\tDownloading from #{file_url}" unless options[:quiet]
            begin
              response = request(file_url, headers)
            rescue StandardError => error
              source_url += "?retry=1"
              puts "\t\tRetry getting source from #{source_url}" unless options[:quiet]
              response = request(source_url, headers)

              data = JSON.parse(response.body)
              raise 'Invalid track ID' unless data['itemid'] == id
              file_url = data['url']

              puts "\t\tRetry downloading from #{file_url}" unless options[:quiet]
              response = request(file_url, headers)
            end

            puts "\t\tWriting data to file #{filepath}" unless options[:quiet]
            File.open(filepath, 'wb') { |file| file.write(response.body) }

            if File.exists?("#{filepath}.log")
              puts "\t\tDeleting log file #{filepath}.log" unless options[:quiet]
              File.delete("#{filepath}.log")
            end

            TagLib::MPEG::File.open(filepath) do |file|
              puts "\t\tUpdating ID3 metadata of file #{filepath}" unless options[:quiet]
              tag(file, artist, title, id, thumb_url)
            end

            puts "\t\tFinished downloading track #{filename}", '' unless options[:quiet]
            success = true
          end
        rescue StandardError => error
          if options[:strict]
            raise
          else
            message = error.to_s
            File.open("#{filepath}.log", 'w') do |file|
              file.write(strip_heredoc(<<-LOG))
                Page   : #{page_url}
                Source : #{source_url}
                File   : #{file_url}
                Error  : #{message}
              LOG
            end
            puts "\t\tException logged to #{filename}.log: #{message}", '' unless options[:quiet]
          end
        end
      end

      success
    end

    def tag (file, artist, title, id, thumb_url = nil)
      file.strip

      tag         = file.id3v2_tag(true)
      tag.artist  = artist
      tag.title   = title
      tag.album   = 'HYPEM'
      tag.comment = id

      time      = Time.at(timestamp.to_i).localtime
      date      = TagLib::ID3v2::TextIdentificationFrame.new('TDRC', TagLib::String::UTF8)
      date.text = time.strftime('%Y-%m-%d')
      tag.add_frame(date)

      if thumb_url
        response          = request(thumb_url, headers)
        cover             = TagLib::ID3v2::AttachedPictureFrame.new
        cover.mime_type   = 'image/png'
        cover.description = 'Cover'
        cover.type        = TagLib::ID3v2::AttachedPictureFrame::FrontCover
        cover.picture     = response.body
        tag.add_frame(cover)
      end

      file.save
    end

    def strip_heredoc (heredoc)
      min    = heredoc.scan(/^[ \t]*(?=\S)/).min
      indent = min.respond_to?(:size) ? min.size : 0
      heredoc.gsub(/^[ \t]{#{indent}}/, '')
    end
  end
end
