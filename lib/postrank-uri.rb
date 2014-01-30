
require 'addressable/uri'
require 'digest/md5'
require 'nokogiri'
require 'public_suffix'
require 'yaml'

module Addressable
  class URI
    def domain
      host = self.host
      (host && PublicSuffix.valid?(host)) ? PublicSuffix.parse(host).domain : nil
    end

    def normalized_query
      @normalized_query ||= (begin
        if self.query && self.query.strip != ''
          (self.query.strip.split("&", -1).map do |pair|
            Addressable::URI.normalize_component(
              pair,
              Addressable::URI::CharacterClasses::QUERY.sub("\\&", "")
            )
          end).join("&")
        else
          nil
        end
      end)
    end

  end
end

module PostRank
  module URI

    c14ndb = YAML.load_file(File.dirname(__FILE__) + '/postrank-uri/c14n.yml')

    C14N = {}
    C14N[:global] = c14ndb[:all].freeze
    C14N[:hosts]  = c14ndb[:hosts].inject({}) {|h,(k,v)| h[/#{Regexp.escape(k)}$/.freeze] = v; h}

    URIREGEX = {}
    URIREGEX[:protocol] = /https?:\/\//i
    URIREGEX[:valid_preceding_chars] = /(?:|\.|[^-\/"':!=A-Z0-9_@＠]|^|\:)/i
    URIREGEX[:valid_domain] = /\b(?:[a-z0-9-]{1,63}\.){1,}[a-z]{2,63}(?::[0-9]+)?/i
    URIREGEX[:valid_general_url_path_chars] = /[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~]/i

    # Allow URL paths to contain balanced parens
    #  1. Used in Wikipedia URLs like /Primer_(film)
    #  2. Used in IIS sessions like /S(dfd346)/
    URIREGEX[:wikipedia_disambiguation] = /(?:\(#{URIREGEX[:valid_general_url_path_chars]}+\))/i

    # Allow @ in a url, but only in the middle. Catch things like http://example.com/@user
    URIREGEX[:valid_url_path_chars] = /(?:
      #{URIREGEX[:wikipedia_disambiguation]}|
      @#{URIREGEX[:valid_general_url_path_chars]}+\/|
      [\.,]#{URIREGEX[:valid_general_url_path_chars]}+|
      #{URIREGEX[:valid_general_url_path_chars]}+
    )/ix

    # Valid end-of-path chracters (so /foo. does not gobble the period).
    #   1. Allow =&# for empty URL parameters and other URL-join artifacts
    URIREGEX[:valid_url_path_ending_chars] = /[a-z0-9=_#\/\+\-]|#{URIREGEX[:wikipedia_disambiguation]}/io
    URIREGEX[:valid_url_query_chars] = /[a-z0-9!\*'\(\);:&=\+\$\/%#\[\]\-_\.,~]/i
    URIREGEX[:valid_url_query_ending_chars] = /[a-z0-9_&=#\/]/i

    URIREGEX[:valid_url] = %r{
          (                                               #   $1 total match
            (#{URIREGEX[:valid_preceding_chars]})         #   $2 Preceeding chracter
            (                                             #   $3 URL
              (https?:\/\/)?                              #   $4 Protocol
              (#{URIREGEX[:valid_domain]})                #   $5 Domain(s) and optional post number
              (/
                (?:
                  # 1+ path chars and a valid last char
                  #{URIREGEX[:valid_url_path_chars]}+#{URIREGEX[:valid_url_path_ending_chars]}|
                  # Optional last char to handle /@foo/ case
                  #{URIREGEX[:valid_url_path_chars]}+#{URIREGEX[:valid_url_path_ending_chars]}?|
                  # Just a # case
                  #{URIREGEX[:valid_url_path_ending_chars]}
                )?
              )?                                          #   $6 URL Path and anchor
              # $7 Query String
              (\?#{URIREGEX[:valid_url_query_chars]}*#{URIREGEX[:valid_url_query_ending_chars]})?
            )
          )
        }iox;

    URIREGEX[:escape]   = /([^ a-zA-Z0-9_.-]+)/x
    URIREGEX[:unescape] = /((?:%[0-9a-fA-F]{2})+)/x
    URIREGEX.each_pair{|k,v| v.freeze }

    module_function

    def extract(text)
      return [] if !text
      urls = []
      text.to_s.scan(URIREGEX[:valid_url]) do |all, before, url, protocol, domain, path, query|
        # Only extract the URL if the domain is valid
        if PublicSuffix.valid?(domain)
          url = clean(url)
          urls.push url.to_s
        end
      end

      urls.compact
    end

    def extract_href(text, host = nil)
      urls = []
      Nokogiri.HTML(text).search('a').each do |a|
        begin
          url = clean(a.attr('href'), :raw => true, :host => host)

          next unless url.absolute?

          urls.push [url.to_s, a.text]
        rescue
          next
        end
      end
      urls
    end

    def escape(uri)
      uri.gsub(URIREGEX[:escape]) do
        '%' + $1.unpack('H2' * $1.size).join('%').upcase
      end.gsub(' ','%20')
    end

    def unescape(uri)
      u = parse(uri)
      u.query = u.query.tr('+', ' ') if u.query
      u.to_s.gsub(URIREGEX[:unescape]) do
        [$1.delete('%')].pack('H*')
      end
    end

    def clean(uri, opts = {})
      uri = normalize(c14n(unescape(uri), opts))
      opts[:raw] ? uri : uri.to_s
    end

    def hash(uri, opts = {})
      Digest::MD5.hexdigest(opts[:clean] == true ? clean(uri) : uri)
    end

    def normalize(uri, opts = {})
      u = parse(uri, opts)
      u.path = u.path.squeeze('/')
      u.path = u.path.chomp('/') if u.path.size != 1
      u.query = nil if u.query && u.query.empty?
      u.fragment = nil
      u
    end

    def c14n(uri, opts = {})
      u = parse(uri, opts)
      u = embedded(u)

      if q = u.query_values(Array)
        q.delete_if { |k,v| C14N[:global].include?(k) }
        q.delete_if { |k,v| C14N[:hosts].find {|r,p| u.host =~ r && p.include?(k) } }
      end
      u.query_values = q

      if u.host =~ /^(mobile\.)?twitter\.com$/ && u.fragment && u.fragment.match(/^!(.*)/)
        u.fragment = nil
        u.path = $1
      end

      if u.host =~ /tumblr\.com$/ && u.path =~ /\/post\/\d+\//
        u.path = u.path.gsub(/[^\/]+$/, '')
      end

      u
    end

    def embedded(uri)
      embedded = if uri.host == 'news.google.com' && uri.path == '/news/url' \
         || uri.host == 'xfruits.com'
        uri.query_values['url']

      elsif uri.host =~ /myspace\.com/ && uri.path =~ /PostTo/
        embedded = uri.query_values['u']
      end

      uri = clean(embedded, :raw => true) if embedded
      uri
    end

    def parse(uri, opts = {})
      return uri if uri.is_a? Addressable::URI

      uri = Addressable::URI.parse(uri)

      if !uri.host && uri.scheme !~ /^javascript|mailto|xmpp$/
        if uri.scheme
          # With no host and scheme yes, the parser exploded
          return parse("http://#{uri}", opts)
        end

        if opts[:host]
          uri.host = opts[:host]
        else
          parts = uri.path.to_s.split(/[\/:]/)
          if parts.first =~ URIREGEX[:valid_domain]
            host = parts.shift
            uri.path = '/' + parts.join('/')
            uri.host = host
          end
        end
      end

      uri.scheme = 'http' if uri.host && !uri.scheme
      uri.normalize!
    end

    def valid?(uri)
      # URI is only valid if it is not nil, parses cleanly as a URI,
      # and the domain has a recognized, valid TLD component
      return false if uri.nil?

      is_valid = false
      cleaned_uri = clean(uri, :raw => true)

      if host = cleaned_uri.host
        is_valid = PublicSuffix.valid?(Addressable::IDNA.to_unicode(host))
      end

      is_valid
    end
  end
end
