# -*- encoding: utf-8 -*-

require 'helper'

describe PostRank::URI do
  context "escaping" do
    it "escapes PostRank::URI string" do
      expect(PostRank::URI.escape('id=1')).to eq('id%3D1')
    end

    it "escapes spaces as %20's" do
      expect(PostRank::URI.escape('id= 1')).to match('%20')
    end
  end

  context "unescape" do
    it "unescapes PostRank::URI" do
      expect(PostRank::URI.unescape(PostRank::URI.escape('id=1'))).to eq('id=1')
    end

    it "unescapes PostRank::URI with spaces" do
      expect(PostRank::URI.unescape(PostRank::URI.escape('id= 1'))).to eq('id= 1')
    end

    context "accept improperly escaped PostRank::URI strings" do
      # See http://tools.ietf.org/html/rfc3986#section-2.3

      it "unescapes PostRank::URI with spaces encoded as '+'" do
        expect(PostRank::URI.unescape('?id=+1')).to eq('?id= 1')
      end

      it "unescapes PostRank::URI with spaces encoded as '+'" do
        expect(PostRank::URI.unescape('?id%3D+1')).to eq('?id= 1')
      end

      it "unescapes PostRank::URI with spaces encoded as %20" do
        expect(PostRank::URI.unescape('?id=%201')).to eq('?id= 1')
      end

      it "does not unescape '+' to spaces in paths" do
        expect(PostRank::URI.unescape('/foo+bar?id=foo+bar')).to eq('/foo+bar?id=foo bar')
      end
    end

  end

  context "normalize" do
    let(:igvita) { 'http://igvita.com/' }

    def n(uri)
      PostRank::URI.normalize(uri).to_s
    end

    it "normalizes paths in PostRank::URIs" do
      expect(n('http://igvita.com/')).to eq(igvita)
      expect(n('http://igvita.com').to_s).to eq(igvita)
      expect(n('http://igvita.com///')).to eq(igvita)

      expect(n('http://igvita.com/../')).to eq(igvita)
      expect(n('http://igvita.com/a/b/../../')).to eq(igvita)
      expect(n('http://igvita.com/a/b/../..')).to eq(igvita)
    end

    it "normalizes query strings in PostRank::URIs" do
      expect(n('http://igvita.com/?')).to eq(igvita)
      expect(n('http://igvita.com?')).to eq(igvita)
      expect(n('http://igvita.com/a/../?')).to eq(igvita)
    end

    it "normalizes anchors in PostRank::URIs" do
      expect(n('http://igvita.com#test')).to eq(igvita)
      expect(n('http://igvita.com#test#test')).to eq(igvita)
      expect(n('http://igvita.com/a/../?#test')).to eq(igvita)
    end

    it "cleans whitespace in PostRank::URIs" do
      expect(n('http://igvita.com/a/../?  ')).to eq(igvita)
      expect(n('http://igvita.com/a/../? #test')).to eq(igvita)
      expect(n('http://igvita.com/ /../')).to eq(igvita)
    end

    it "defaults to http scheme if missing" do
      expect(n('igvita.com')).to eq(igvita)
      expect(n('https://test.com/').to_s).to eq('https://test.com/')
    end

    it "downcases the hostname" do
      expect(n('IGVITA.COM')).to eq(igvita)
      expect(n('IGVITA.COM/ABC')).to eq(igvita + "ABC")
    end

    it "removes trailing slash on paths" do
      expect(n('http://igvita.com/')).to eq('http://igvita.com/')

      expect(n('http://igvita.com/a')).to eq('http://igvita.com/a')
      expect(n('http://igvita.com/a/')).to eq('http://igvita.com/a')

      expect(n('http://igvita.com/a/b')).to eq('http://igvita.com/a/b')
      expect(n('http://igvita.com/a/b/')).to eq('http://igvita.com/a/b')
    end
  end

  context "canonicalization" do
    def c(uri)
      PostRank::URI.c14n(uri).to_s
    end

    context "query parameters" do
      it "should handle nester parameters" do
        expect(c('igvita.com/?id=a&utm_source=a')).to eq('http://igvita.com/?id=a')
      end

      it "preserves the order of parameters" do
        url = 'http://a.com/?'+('a'..'z').to_a.shuffle.map {|e| "#{e}=#{e}"}.join("&")
        expect(c(url)).to eq(url)
      end

      it "removes Google Analytics parameters" do
        expect(c('igvita.com/?id=a&utm_source=a')).to eq('http://igvita.com/?id=a')
        expect(c('igvita.com/?id=a&utm_source=a&utm_valid')).to eq('http://igvita.com/?id=a&utm_valid')
      end

      it "removes awesm/sms parameters" do
        expect(c('igvita.com/?id=a&utm_source=a&awesm=b')).to eq('http://igvita.com/?id=a')
        expect(c('igvita.com/?id=a&sms_ss=a')).to eq('http://igvita.com/?id=a')
      end

      it "removes PHPSESSID parameter" do
        expect(c('http://www.nachi.org/forum?PHPSESSID=9ee2fb10b7274ef2b15d1d4006b8c8dd')).to eq('http://www.nachi.org/forum?')
        expect(c('http://www.nachi.org/forum/?PHPSESSID=9ee2fb10b7274ef2b15d1d4006b8c8dd')).to eq('http://www.nachi.org/forum/?')
        expect(c('http://www.nachi.org/forum?id=123&PHPSESSID=9ee2fb10b7274ef2b15d1d4006b8c8dd')).to eq('http://www.nachi.org/forum?id=123')
      end
    end

    context "hashbang" do
      it "rewrites twitter links to crawlable versions" do
        expect(c('http://twitter.com/#!/igrigorik')).to eq('http://twitter.com/igrigorik')
        expect(c('http://twitter.com/#!/a/statuses/1')).to eq('http://twitter.com/a/statuses/1')
        expect(c('http://nontwitter.com/#!/a/statuses/1')).to eq('http://nontwitter.com/#!/a/statuses/1')
      end
    end

    context "tumblr" do
      it "strips the slug" do
        expect(c('http://test.tumblr.com/post/4533459403/some-text')).to eq('http://test.tumblr.com/post/4533459403/')
        expect(c('http://tumblr.com/xjl2evo3hh')).to eq('http://tumblr.com/xjl2evo3hh')
      end
    end

    context "embedded links" do
      it "extracts embedded redirects from Google News" do
        u = c('http://news.google.com/news/url?sa=t&fd=R&&url=http://www.ctv.ca/CTVNews/Politics/20110111/')
        expect(u).to eq('http://www.ctv.ca/CTVNews/Politics/20110111')
      end

      it "extracts embedded redirects from xfruits.com" do
        u = c('http://xfruits.com/MrGroar/?url=http%3A%2F%2Faap.lesroyaumes.com%2Fdepeches%2Fdepeche351820908.html')
        expect(u).to eq('http://aap.lesroyaumes.com/depeches/depeche351820908.html')
      end

      it "extracts embedded redirects from MySpace" do
        u = c('http://www.myspace.com/Modules/PostTo/Pages/?u=http%3A%2F%2Fghanaian-chronicle.com%2Fnews%2Fother-news%2Fcanadian-high-commissioner-urges-media%2F&t=Canadian%20High%20Commissioner%20urges%20media')
        expect(u).to eq('http://ghanaian-chronicle.com/news/other-news/canadian-high-commissioner-urges-media')
      end
    end
  end

  context "clean" do
    def c(uri)
      PostRank::URI.clean(uri)
    end

    it "unescapes, canonicalizes and normalizes" do
      expect(c('http://igvita.com/?id=1')).to eq('http://igvita.com/?id=1')
      expect(c('igvita.com/?id=1')).to eq('http://igvita.com/?id=1')

      expect(c('http://igvita.com/?id= 1')).to eq('http://igvita.com/?id=%201')
      expect(c('http://igvita.com/?id=+1')).to eq('http://igvita.com/?id=%201')
      expect(c('http://igvita.com/?id%3D%201')).to eq('http://igvita.com/?id=%201')

      expect(c('igvita.com/a/..?id=1&utm_source=a&awesm=b#c')).to eq('http://igvita.com/?id=1')

      expect(c('igvita.com?id=<>')).to eq('http://igvita.com/?id=%3C%3E')
      expect(c('igvita.com?id="')).to eq('http://igvita.com/?id=%22')

      expect(c('test.tumblr.com/post/23223/text-stub')).to eq('http://test.tumblr.com/post/23223')
    end

    it "cleans host specific parameters" do
      YAML.load_file('spec/c14n_hosts.yml').each do |orig, clean|
        expect(c(orig)).to eq(clean)
      end
    end

    context "reserved characters" do
      it "preserves encoded question marks" do
        expect(c('http://en.wikipedia.org/wiki/Whose_Line_Is_It_Anyway%3F_%28U.S._TV_series%29')).
          to eq('http://en.wikipedia.org/wiki/Whose_Line_Is_It_Anyway%3F_(U.S._TV_series)')
      end

      it "preserves encoded ampersands" do
        expect(c('http://example.com/?foo=BAR%26BAZ')).
          to eq('http://example.com/?foo=BAR%26BAZ')
      end

      it "preserves consecutive reserved characters" do
        expect(c('http://example.com/so-quizical%3F%3F%3F?foo=bar')).
          to eq('http://example.com/so-quizical%3F%3F%3F?foo=bar')
      end
    end
  end

  context "hash" do
    def h(uri, opts = {})
      PostRank::URI.hash(uri, opts)
    end

    it "computes the MD5 hash without cleaning the URI" do
      hash = '55fae8910d312b7878a3201ed653b881'

      expect(h('http://everburning.com/feed/post/1')).to eq(hash)
      expect(h('everburning.com/feed/post/1')).not_to eq(hash)
    end

    it "normalizes the URI if requested and compute MD5 hash" do
      hash = '55fae8910d312b7878a3201ed653b881'

      expect(h('http://EverBurning.Com/feed/post/1', :clean => true)).to eq(hash)
      expect(h('Everburning.com/feed/post/1', :clean => true)).to eq(hash)
      expect(h('everburning.com/feed/post/1', :clean => true)).to eq(hash)
      expect(h('everburning.com/feed/post/1/', :clean => true)).to eq(hash)
    end
  end

  context "extract" do
    def e(text)
      PostRank::URI.extract(text)
    end

    context "TLDs" do
      it "does not pick up bad grammar as a domain name and think it has a link" do
        expect(e("yah.lets")).to be_empty
      end

      it "does not pickup bad TLDS" do
        expect(e('stuff.zz a.b.c d.zq')).to be_empty
      end
    end

    it "extracts twitter links with hashbangs" do
      expect(e('test http://twitter.com/#!/igrigorik')).to include('http://twitter.com/igrigorik')
    end

    it "extracts mobile twitter links with hashbangs" do
      expect(e('test http://mobile.twitter.com/#!/_mm6')).to include('http://mobile.twitter.com/_mm6')
    end

    it "handles a URL that comes after text without a space" do
      expect(e("text:http://spn.tw/tfnLT")).to include("http://spn.tw/tfnLT")
      expect(e("text;http://spn.tw/tfnLT")).to include("http://spn.tw/tfnLT")
      expect(e("text.http://spn.tw/tfnLT")).to include("http://spn.tw/tfnLT")
      expect(e("text-http://spn.tw/tfnLT")).to include("http://spn.tw/tfnLT")
    end

    it "does not pick up anything on or after the first . in the path of a URL with a shortener domain" do
      expect(e("http://bit.ly/9cJ2mz......if ur pickin up anythign here, u FAIL.")).to eq(["http://bit.ly/9cJ2mz"])
    end

    it "picks up urls without protocol" do
      u = e('abc.com abc.co')
      expect(u).to include('http://abc.com/')
      expect(u).to include('http://abc.co/')
    end

    it "picks up urls inside tags" do
      u = e("<a href='http://bit.ly/3fds3'>abc.com</a>")
      expect(u).to include('http://abc.com/')
    end

    context "multibyte characters" do
      it "stops extracting URLs at the full-width CJK space character" do
        expect(e("http://www.youtube.com/watch?v=w_j4Lda25jA　　とんかつ定食")).to eq(["http://www.youtube.com/watch?v=w_j4Lda25jA"])
      end
    end

  end

  context "href extract" do
    it "extracts links from html text" do
      g,b = PostRank::URI.extract_href("<a href='google.com'>link to google</a> with text <a href='b.com'>stuff</a>")

      expect(g.first).to eq('http://google.com/')
      expect(b.first).to eq('http://b.com/')

      expect(g.last).to eq('link to google')
      expect(b.last).to eq('stuff')
    end

    it "handles empty hrefs" do
      expect do
        l = PostRank::URI.extract_href("<a>link to google</a> with text <a href=''>stuff</a>")
        expect(l).to be_empty
      end.not_to raise_error
    end

    context "relative paths" do
      it "rejects relative paths" do
        l = PostRank::URI.extract_href("<a href='/stuff'>link to stuff</a>")
        expect(l).to be_empty
      end

      it "resolves relative paths if host is provided" do
        i = PostRank::URI.extract_href("<a href='/stuff'>link to stuff</a>", "igvita.com").first
        expect(i.first).to eq('http://igvita.com/stuff')
        expect(i.last).to eq('link to stuff')
      end
    end

    context "domain extraction" do
      url_list = {
        "http://alex.pages.example.com" => "example.com",
        "alex.pages.example.com" => "example.com",
        "http://example.com/2011/04/01/blah" => "example.com",
        "http://example.com" => "example.com",
        "example.com" => "example.com",
        "ExampLe.com" => "example.com",
        "ExampLe.com:3000" => "example.com",
        "http://alex.pages.example.COM" => "example.com",
        "http://www.example.ag.it/2011/04/01/blah" => "example.ag.it",
        "ftp://www.example.com/2011/04/01/blah" => 'example.com',
        "http://com" => nil,
        "http://alex.pages.examplecom" => nil,
        "example" => nil,
        "http://127.0.0.1" => nil,
        "localhost" => nil,
        "hello-there.com/you" => "hello-there.com"
      }

      url_list.each_pair do |url, expected_result|
        it "extracts #{expected_result.inspect} from #{url}" do
          u = PostRank::URI.clean(url, :raw => true)
          expect(u.domain).to eq(expected_result)
        end
      end
    end
  end

  context "parse" do
    it 'does not fail on large host-part look-alikes' do
      expect(PostRank::URI.parse('a'*64+'.ca').host).to eq(nil)
    end

    it 'does not pancake javascript scheme URIs' do
      expect(PostRank::URI.parse('javascript:void(0);').scheme).to eq('javascript')
    end

    it 'does not pancake mailto scheme URIs' do
      expect(PostRank::URI.parse('mailto:void(0);').scheme).to eq('mailto')
    end

    it 'does not pancake xmpp scheme URIs' do
      expect(PostRank::URI.parse('xmpp:void(0);').scheme).to eq('xmpp')
    end
  end

  context 'valid?' do
    it 'marks incomplete URI string as invalid' do
      expect(PostRank::URI.valid?('/path/page.html')).to be false
    end

    it 'marks www.test.c as invalid' do
      expect(PostRank::URI.valid?('http://www.test.c')).to be false
    end

    it 'marks www.test.com as valid' do
      expect(PostRank::URI.valid?('http://www.test.com')).to be true
    end

    it 'marks Unicode domain as valid (NOTE: works only with a scheme)' do
      expect(PostRank::URI.valid?('http://президент.рф')).to be true
    end

    it 'marks punycode domain domain as valid' do
      expect(PostRank::URI.valid?('xn--d1abbgf6aiiy.xn--p1ai')).to be true
    end
  end
end
