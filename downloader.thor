#!/usr/bin/env ruby
require 'rubygems'
require 'open-uri'
require 'hpricot'
require 'uri'
require 'thor'
# require 'pry'

class WebPage < Thor

  desc 'fetch',
        "downloads all links/images specified in options. \n\nUSAGE: thor webpage:fetch --url=www.example.com --types=pdf zip java --selector=.html-class --images=true --imgselector=.img-html-class\n"
  method_option :url,
                :required => true,
                :type => :string,
                :banner => 'example.com',
                :desc => 'URL for the page you would like to download files from'
  method_option :file_types,
                :type => :array,
                :banner => 'pdf zip txt' ,
                :default => ['pdf', 'zip', 'gz', 'txt']
  method_option :selector,
                :type => :string,
                :banner => 'selector',
                :desc => 'for links'
  method_option :images,
                :type => :boolean,
                :default => false,
                :banner => 'true',
                :desc => 'to download images'
  method_option :imgselector,
                :type => :string,
                :banner => 'selector',
                :desc =>  'for images'
  def fetch
    @allowed_file_extensions = options[:file_types]
    @url = URI.parse(options[:url])

    doc = open(@url.to_s) { |f| Hpricot(f) }
    @extensions = Array.new
    @success = Array.new
    @fail = Array.new

    # File selectors
    link_selector = options[:selector] ? options[:selector] : "a"
    images_selector = options[:imgselector] ? options[:imgselector] : "img"
    # File downloads
    download_files((doc/link_selector))
    download_images((doc/images_selector)) if options[:images] || options[:imgselector]

    print_download_summary()
  end

  # Below are commands that shouldn't be exposed to CLI
  no_commands do

    def download_files links
      links.each do |link_element|
        link = link_element.attributes['href']
        file_extension = get_link_file_extension(link)
        @extensions << file_extension
        if @allowed_file_extensions.include?(file_extension)
          get_file link
        end
      end
    end

    def download_images links
      links.each { |link_element| get_file(link_element.attributes['src']) }
    end

    def get_file link
      if system("wget #{linkify(link)}")
        @success << linkify(link)
      else
        @fail << linkify(link)
      end
    end

    def is_top_domain? file_extension
      %w(se com uk co nu net org se/ com/ uk/ co/ nu/ net/ org/).include?(file_extension)
    end

    def remove_params link
      last_questionmark = link.rindex(/\?/)
      last_questionmark ? link[0..last_questionmark] : link
    end

    def get_link_file_extension link
      remove_params(link)
      last_dot = link.rindex(/\./)
      unless last_dot.nil? || (link.length - last_dot.to_i > 8)
        file_extension = link[last_dot+1..link.length]
        return file_extension unless is_top_domain?(file_extension)
      end
      return ''
    end

    def linkify link
      uri = URI.parse(link)
      return link if uri.absolute?
      return "#{@url.host}/#{link}" if link[0].eql? "/"
      "#{@url.hostname}#{@url.path.gsub /index\.php/, ''}#{link}" # FIXME: Ugly hack with index.php
    end

    def print_download_summary
      puts "\n\n\n\n"
      puts "============================"
      @extensions.uniq!.delete("")
      puts "File extensions on page:\n #{@extensions.join(", ")}"
      puts "============================"
      puts "\n"
      puts "#{@extensions.length} unique extensions found."
      puts "#{@success.length} files downloaded."
      puts "#{@fail.length} files FAILED to download."
    end

  end # end of no_commands

end

WebPage.start # Starts the program

