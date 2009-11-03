require "java"
require "set"
require "base64"
require "rubygems"
require "hpricot"
require "uri"

module JUtil include_package "java.util" end
import java.util.Iterator
import org.apache.http.client.ResponseHandler
import org.apache.http.impl.client.DefaultHttpClient
import org.apache.http.client.methods.HttpGet

class WebSelector < com.vamosa.tasks.ParameterisedTask

  def usage()
    requiresProject("project", "the default to select content from")
    requiresURL("startUrl", "the URL of the page to start crawling from", "http://www.vamosa.com/")
    requiresInteger("maxNoURLs", "the maximum no. of URLs to crawl", 20)
  end
  
  def retrieve_additional_cups(project)
    cups_resource = $projectManagerService.findProjectResourceByNameAndProject("CUPs", project)
    additional_cups = []
    unless cups_resource.nil?
      cups_resource.contents.each_line {|line| additional_cups << [Regexp.new(line.split(",")[0]), line.split(",")[1]] }
    end
    additional_cups
  end

  def iterator(project, startUrl, maxNoURLs)
    begin
      $logger.info "Starting Web Crawl"
      cups = [ [/#{startUrl}.*/,"include"] ] + retrieve_additional_cups(project)
      WebResourceIterator.new($logger, project, startUrl, cups, maxNoURLs)
    rescue Exception => e
      puts e
      puts e.backtrace
      $logger.error(e.message)
      $logger.error(e.backtrace.to_s)
    end
  end

end

class WebResourceIterator
  include JUtil::Iterator
  include ResponseHandler

  def initialize(logger, project, start_url, cups, maxNoURLs)
    @logger = logger
    @http_client = DefaultHttpClient.new
    @crawled_resources = JUtil::LinkedList.new
    @crawled_urls = Set.new
    @crawl_queue = Set.new [start_url]
    @project = project
    @cups = cups
    @maxNoURLs = maxNoURLs
  end

  def hasNext()
    not @crawl_queue.empty? and @maxNoURLs > 0
  end

  def retrieve_links_from_content(content)
    doc = Hpricot(content)

    elements = doc.search("[@href]")
    elements = elements.push *doc.search("[@src]")
    links = (elements.map {|element| element['href'] or element['src'] }).reject {|link| link =~ /\Ajavascript/ or link =~ /\Amailto/}

    base_elem = doc.at("base")
    base = base_elem['href'] unless base_elem.nil?
    [base, links]
  end

  def absolutize(base_url, additional_url, parsed_additional_url = nil) #:nodoc:
    begin
      # escape the urls if they contain spaces
      # base_url = CGI::escape(base_url) if base_url and base_url =~ / /
      # additional_url = CGI::escape(additional_url) if additional_url and additional_url =~ / /
      # parsed_additional_url = CGI::escape(base_url) if parsed_additional_url and parsed_additional_url =~ / /

      parsed_additional_url ||= URI.parse(additional_url)
      case parsed_additional_url.scheme
      when nil
        u = base_url.is_a?(URI) ? base_url : URI.parse(base_url)
        if additional_url[0].chr == '/'
          "#{u.scheme}://#{u.host}#{additional_url}"
        elsif u.path.nil? || u.path == ''
          "#{u.scheme}://#{u.host}/#{additional_url}"
        elsif u.path[0].chr == '/'
          "#{u.scheme}://#{u.host}#{u.path}/#{additional_url}"
        else
          "#{u.scheme}://#{u.host}/#{u.path}/#{additional_url}"
        end
      else
        additional_url
      end
    rescue
      additional_url
    end
  end

  def matches_cup(link)
    @logger.debug "matching #{link} against cups..."
    matches = false
    @cups.each do |pattern, type|
        @logger.debug "matching #{link} against #{pattern} for #{type}..."
        matches = true if link =~ pattern
        return false if link =~ pattern and type.downcase == "exclude"
        @logger.debug "current state: #{matches}"
    end
    @logger.debug "returning #{matches}"
    matches
  end

  def handleResponse(response)
    @crawled_urls << @current_url
    unless response.entity.nil?
      if response.entity.contentType.value =~ /text/
        content = org.apache.http.util.EntityUtils.toString(response.entity)
        if response.entity.contentType.value =~ /text\/html/

          # retrieve all links from content
          base, harvested_links = retrieve_links_from_content(content)
          base ||= @current_url

          # convert all URLs harvested to absolute URLs if they're not already
          absolutized_links = harvested_links.map {|link| absolutize(base, link)}

          # strip off # or /# from the end of URLs
          hash_stripped_links = absolutized_links.map { |link| link =~ /\A(.*)(?:\/#)/ or link =~ /\A(.*)(?:#)/ ? $1 : link }

          # compare links to crawl url pattens
          cups_filtered_links = hash_stripped_links.find_all {|link| matches_cup(link)}

          # make sure links have previously not been crawler or are scheduled to be crawled
          uncrawled_links = cups_filtered_links.reject {|link| @crawled_urls.include?(link) or @crawl_queue.include?(link)}
          uncrawled_links.each do |link|
            # puts "#{@current_url} introduces #{link}"
            @crawl_queue.add link
          end
        end
      else
        content_bytes = org.apache.http.util.EntityUtils.toByteArray(response.entity)
        content = org.apache.commons.codec.binary.Base64.encodeBase64String(content_bytes)
      end
    end
    metadata = {}
    response.allHeaders.each { |hdr| metadata["Identify Metadata.#{hdr.name}"] = hdr.value }

    [content, metadata, absolutized_links ||= []]
  end

  def retrieve(url)
    puts "Retrieving #{url}"
    @logger.info "Retrieving #{url}"
    @maxNoURLs -= 1
    get = org.apache.http.client.methods.HttpGet.new(url)
    content, metadata, links = @http_client.execute(get, self)
    [url, content, metadata, links]
  end

  def next()
    begin
      if not @crawl_queue.empty? and @maxNoURLs > 0
        if @crawl_queue.size > 0
          @current_url = @crawl_queue.to_a[0]
          @crawl_queue.delete(@current_url)
          url, content, metadata, outbound_links = retrieve(@current_url)
          content_descriptor = com.vamosa.content.ContentDescriptor.new(url, @project)
          content_descriptor.addContentData(content)
          content_descriptor.metadata.putAll(metadata)
          outbound_links.each {|link| content_descriptor.addOutboundLink(link)}
          puts "Retrieved #{url} [#{@crawled_urls.length} Crawled, #{@crawl_queue.length} Queued]"
          @logger.info "Retrieved #{url} [#{@crawled_urls.length} Crawled, #{@crawl_queue.length} Queued]"
          content_descriptor
        end
      else
        @http_client.connectionManager.shutdown
        nil
      end
    rescue Exception => e
      puts e
      puts e.backtrace
      @logger.error(e.message)
      @logger.error(e.backtrace.to_s)
    end
  end

  def remove()
  end
end
