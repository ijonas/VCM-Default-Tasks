require "java"
require "set"
require "base64"
require "rubygems"
require "hpricot"
require "uri"


class Bloom
  import org.apache.hadoop.util.bloom.BloomFilter
  import org.apache.hadoop.util.bloom.Key

  def initialize(no_of_bits, no_of_hashes = 8, hash_type = 0)
    @filter = BloomFilter.new(no_of_bits, no_of_hashes, hash_type)
  end

  def include?(payload)
    @filter.membershipTest( generate_key(payload) )
  end

  def add(payload)
    @filter.add( generate_key(payload) )
  end

  private
  def generate_key(payload)
    org.apache.hadoop.util.bloom.Key.new(payload.to_java_bytes)
  end

end

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
      $logger.error(e.message)
      $logger.error(e.backtrace.to_s)
    end
  end

end

class WebResourceIterator
  import org.apache.http.impl.client.DefaultHttpClient
  import org.apache.http.client.methods.HttpGet
  import java.util.Iterator
  import org.apache.http.client.ResponseHandler
  include java.util.Iterator
  include ResponseHandler

  def initialize(logger, project, start_url, cups, maxNoURLs)
    @logger = logger
    @http_client = DefaultHttpClient.new
    @crawled_urls = Bloom.new(maxNoURLs)
    @crawl_queue = Set.new [start_url]
    @project = project
    @cups = cups
    @maxNoURLs = maxNoURLs
    @noUrlsCrawled = 0
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
    @crawled_urls.add @current_url
    metadata = {"Identify Metadata.Status-Code" => "#{response.statusLine.statusCode}", "Identify Metadata.Status" => "#{response.statusLine.reasonPhrase}"}
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
          uncrawled_links.each { |link| @crawl_queue.add link }
        end
      else
        #content_bytes = org.apache.http.util.EntityUtils.toByteArray(response.entity)
        #content = org.apache.commons.codec.binary.Base64.encodeBase64String(content_bytes)
        content = nil
      end
    end
    response.allHeaders.each { |hdr| metadata["Identify Metadata.#{hdr.name}"] = hdr.value }

    [content, metadata, absolutized_links ||= []]
  end

  def retrieve(url)
    @logger.info "Retrieving #{url}"
    @maxNoURLs -= 1
    get = org.apache.http.client.methods.HttpGet.new(url)
    content, metadata, links = @http_client.execute(get, self)
    [url, content, metadata, links]
  end

  def next()
    content_descriptor = nil
    retrieved_url = false
    while not retrieved_url and not @crawl_queue.empty?
      if not @crawl_queue.empty? and @maxNoURLs > 0
        @noUrlsCrawled+=1
        if @crawl_queue.size > 0
          @current_url = @crawl_queue.to_a[0]
          @crawl_queue.delete(@current_url)
          begin
            @logger.info "1"
            url, content, metadata, outbound_links = retrieve(@current_url)
            @logger.info "2"
            content_descriptor = com.vamosa.content.ContentDescriptor.new(url, @project)
            @logger.info "3"
            content_descriptor.addContentData(content)
            @logger.info "4"
            content_descriptor.metadata.putAll(metadata)
            @logger.info "5"
            outbound_links.each {|link| content_descriptor.addOutboundLink(link)}
            @logger.info "6"
            @logger.info "Retrieved #{url} [#{@noUrlsCrawled} Crawled, #{@crawl_queue.length} Queued]"
            @logger.info "7"
            retrieved_url = true
          rescue RuntimeError => e
            @logger.error(e.message)
            e.backtrace.each {|bt| @logger.error bt}
          end
          tries = 0
        end
      else
        @http_client.connectionManager.shutdown
        nil
      end
    end

    content_descriptor
  end

  def remove()
  end
end
