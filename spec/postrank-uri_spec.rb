# -*- encoding: utf-8 -*-

require 'helper'

describe PostRank::URI do

  let(:igvita) { 'http://igvita.com/' }

  context "escaping" do
    it "should escape PostRank::URI string" do
      PostRank::URI.escape('id=1').should == 'id%3D1'
    end

    it "should escape spaces as %20's" do
      PostRank::URI.escape('id= 1').should match('%20')
    end
  end

  context "unescape" do
    it "should unescape PostRank::URI" do
      PostRank::URI.unescape(PostRank::URI.escape('id=1')).should == 'id=1'
    end

    it "should unescape PostRank::URI with spaces" do
      PostRank::URI.unescape(PostRank::URI.escape('id= 1')).should == 'id= 1'
    end

    context "accept improperly escaped PostRank::URI strings" do
      # See http://tools.ietf.org/html/rfc3986#section-2.3

      it "should unescape PostRank::URI with spaces encoded as '+'" do
        PostRank::URI.unescape('?id=+1').should == '?id= 1'
      end

      it "should unescape PostRank::URI with spaces encoded as '+'" do
        PostRank::URI.unescape('?id%3D+1').should == '?id= 1'
      end

      it "should unescape PostRank::URI with spaces encoded as %20" do
        PostRank::URI.unescape('?id=%201').should == '?id= 1'
      end

      it "should not unescape '+' to spaces in paths" do
        PostRank::URI.unescape('/foo+bar?id=foo+bar').should == '/foo+bar?id=foo bar'
      end
    end

  end

  context "normalize" do
    def n(uri)
      PostRank::URI.normalize(uri).to_s
    end

    it "should normalize paths in PostRank::URIs" do
      n('http://igvita.com/').should == igvita
      n('http://igvita.com').to_s.should == igvita
      n('http://igvita.com///').should == igvita

      n('http://igvita.com/../').should == igvita
      n('http://igvita.com/a/b/../../').should == igvita
      n('http://igvita.com/a/b/../..').should == igvita
    end

    it "should normalize query strings in PostRank::URIs" do
      n('http://igvita.com/?').should == igvita
      n('http://igvita.com?').should == igvita
      n('http://igvita.com/a/../?').should == igvita
    end

    it "should normalize anchors in PostRank::URIs" do
      n('http://igvita.com#test').should == igvita
      n('http://igvita.com#test#test').should == igvita
      n('http://igvita.com/a/../?#test').should == igvita
    end

    it "should clean whitespace in PostRank::URIs" do
      n('http://igvita.com/a/../?  ').should == igvita
      n('http://igvita.com/a/../? #test').should == igvita
      n('http://igvita.com/ /../').should == igvita
    end

    it "should default to http scheme if missing" do
      n('igvita.com').should == igvita
      n('https://test.com/').to_s.should == 'https://test.com/'
    end

    it "should downcase hostname" do
      n('IGVITA.COM').should == igvita
      n('IGVITA.COM/ABC').should == (igvita + "ABC")
    end

    it "should remove trailing slash on paths" do
      n('http://igvita.com/').should == 'http://igvita.com/'

      n('http://igvita.com/a').should == 'http://igvita.com/a'
      n('http://igvita.com/a/').should == 'http://igvita.com/a'

      n('http://igvita.com/a/b').should == 'http://igvita.com/a/b'
      n('http://igvita.com/a/b/').should == 'http://igvita.com/a/b'
    end

  end

  context "canonicalization" do
    def c(uri)
      PostRank::URI.c14n(uri).to_s
    end

    context "query parameters" do
      it "should handle nester parameters" do
        c('igvita.com/?id=a&utm_source=a').should == 'http://igvita.com/?id=a'
      end

      it "should preserve order of parameters" do
        url = 'http://a.com/?'+('a'..'z').to_a.shuffle.map {|e| "#{e}=#{e}"}.join("&")
        c(url).should == url
      end

      it "should remove Google Analytics parameters" do
        c('igvita.com/?id=a&utm_source=a').should == 'http://igvita.com/?id=a'
        c('igvita.com/?id=a&utm_source=a&utm_valid').should == 'http://igvita.com/?id=a&utm_valid'
      end

      it "should remove awesm/sms parameters" do
        c('igvita.com/?id=a&utm_source=a&awesm=b').should == 'http://igvita.com/?id=a'
        c('igvita.com/?id=a&sms_ss=a').should == 'http://igvita.com/?id=a'
      end

      it "should remove PHPSESSID parameter" do
        c('http://www.nachi.org/forum?PHPSESSID=9ee2fb10b7274ef2b15d1d4006b8c8dd').should == 'http://www.nachi.org/forum?'
        c('http://www.nachi.org/forum/?PHPSESSID=9ee2fb10b7274ef2b15d1d4006b8c8dd').should == 'http://www.nachi.org/forum/?'
        c('http://www.nachi.org/forum?id=123&PHPSESSID=9ee2fb10b7274ef2b15d1d4006b8c8dd').should == 'http://www.nachi.org/forum?id=123'
      end
    end

    context "hashbang" do
      it "should rewrite twitter links to crawlable versions" do
        c('http://twitter.com/#!/igrigorik').should == 'http://twitter.com/igrigorik'
        c('http://twitter.com/#!/a/statuses/1').should == 'http://twitter.com/a/statuses/1'
        c('http://nontwitter.com/#!/a/statuses/1').should == 'http://nontwitter.com/#!/a/statuses/1'
      end
    end

    context "tumblr" do
      it "should strip slug" do
        c('http://test.tumblr.com/post/4533459403/some-text').should == 'http://test.tumblr.com/post/4533459403/'
        c('http://tumblr.com/xjl2evo3hh').should == 'http://tumblr.com/xjl2evo3hh'
      end
    end

    context "embedded links" do
      it "should extract embedded redirects from Google News" do
        u = c('http://news.google.com/news/url?sa=t&fd=R&&url=http://www.ctv.ca/CTVNews/Politics/20110111/')
        u.should == 'http://www.ctv.ca/CTVNews/Politics/20110111'
      end

      it "should extract embedded redirects from xfruits.com" do
        u = c('http://xfruits.com/MrGroar/?url=http%3A%2F%2Faap.lesroyaumes.com%2Fdepeches%2Fdepeche351820908.html')
        u.should == 'http://aap.lesroyaumes.com/depeches/depeche351820908.html'
      end

      it "should extract embedded redirects from MySpace" do
        u = c('http://www.myspace.com/Modules/PostTo/Pages/?u=http%3A%2F%2Fghanaian-chronicle.com%2Fnews%2Fother-news%2Fcanadian-high-commissioner-urges-media%2F&t=Canadian%20High%20Commissioner%20urges%20media')
        u.should == 'http://ghanaian-chronicle.com/news/other-news/canadian-high-commissioner-urges-media'
      end
    end
  end

  context "clean" do
    def c(uri)
      PostRank::URI.clean(uri)
    end

    it "should unescape, c14n and normalize" do
      c('http://igvita.com/?id=1').should == 'http://igvita.com/?id=1'
      c('igvita.com/?id=1').should == 'http://igvita.com/?id=1'

      c('http://igvita.com/?id= 1').should == 'http://igvita.com/?id=%201'
      c('http://igvita.com/?id=+1').should == 'http://igvita.com/?id=%201'
      c('http://igvita.com/?id%3D%201').should == 'http://igvita.com/?id=%201'

      c('igvita.com/a/..?id=1&utm_source=a&awesm=b#c').should == 'http://igvita.com/?id=1'

      c('igvita.com?id=<>').should == 'http://igvita.com/?id=%3C%3E'
      c('igvita.com?id="').should == 'http://igvita.com/?id=%22'

      c('test.tumblr.com/post/23223/text-stub').should == 'http://test.tumblr.com/post/23223'
    end

    it "should clean host specific parameters" do
      YAML.load_file('spec/c14n_hosts.yml').each do |orig, clean|
        c(orig).should == clean
      end
    end
  end

  context "hash" do
    def h(uri, opts = {})
      PostRank::URI.hash(uri, opts)
    end

    it "should compute the MD5 hash without cleaning the URI" do
      hash = '55fae8910d312b7878a3201ed653b881'

      h('http://everburning.com/feed/post/1').should == hash
      h('everburning.com/feed/post/1').should_not == hash
    end

    it "should normalize the URI if requested and compute MD5 hash" do
      hash = '55fae8910d312b7878a3201ed653b881'

      h('http://EverBurning.Com/feed/post/1', :clean => true).should == hash
      h('Everburning.com/feed/post/1', :clean => true).should == hash
      h('everburning.com/feed/post/1', :clean => true).should == hash
      h('everburning.com/feed/post/1/', :clean => true).should == hash
    end
  end

  context "extract" do
    def e(text)
      PostRank::URI.extract(text)
    end

    context "TLDs" do
      it "should not pick up bad grammar as a domain name and think it has a link" do
        e("yah.lets").should be_empty
      end

      it "should not pickup bad TLDS" do
        e('stuff.zz a.b.c d.zq').should be_empty
      end
    end

    it "should extract twitter links with hashbangs" do
      e('test http://twitter.com/#!/igrigorik').should include('http://twitter.com/igrigorik')
    end

    it "should extract mobile twitter links with hashbangs" do
      e('test http://mobile.twitter.com/#!/_mm6').should include('http://mobile.twitter.com/_mm6')
    end

    it "should handle a URL that comes after text without a space" do
      e("text:http://spn.tw/tfnLT").should include("http://spn.tw/tfnLT")
      e("text;http://spn.tw/tfnLT").should include("http://spn.tw/tfnLT")
      e("text.http://spn.tw/tfnLT").should include("http://spn.tw/tfnLT")
      e("text-http://spn.tw/tfnLT").should include("http://spn.tw/tfnLT")
    end

    it "should not pick up anything on or after the first . in the path of a URL with a shortener domain" do
      e("http://bit.ly/9cJ2mz......if ur pickin up anythign here, u FAIL.").should == ["http://bit.ly/9cJ2mz"]
    end

    it "should pickup urls without protocol" do
      u = e('abc.com abc.co')
      u.should include('http://abc.com/')
      u.should include('http://abc.co/')
    end

    it "should pickup urls inside tags" do
      u = e("<a href='http://bit.ly/3fds3'>abc.com</a>")
      u.should include('http://abc.com/')
    end

    context "multibyte characters" do
      it "should stop extracting URLs at the full-width CJK space character" do
        e("http://www.youtube.com/watch?v=w_j4Lda25jA　　とんかつ定食").should == ["http://www.youtube.com/watch?v=w_j4Lda25jA"]
      end
    end

  end

  context "href extract" do
    it "should extract links from html text" do
      g,b = PostRank::URI.extract_href("<a href='google.com'>link to google</a> with text <a href='b.com'>stuff</a>")

      g.first.should == 'http://google.com/'
      b.first.should == 'http://b.com/'

      g.last.should == 'link to google'
      b.last.should == 'stuff'
    end

    it "should handle empty hrefs" do
      lambda do
        l = PostRank::URI.extract_href("<a>link to google</a> with text <a href=''>stuff</a>")
        l.should be_empty
      end.should_not raise_error
    end

    context "relative paths" do
      it "should reject relative paths" do
        l = PostRank::URI.extract_href("<a href='/stuff'>link to stuff</a>")
        l.should be_empty
      end

      it "should resolve relative paths if host is provided" do
        i = PostRank::URI.extract_href("<a href='/stuff'>link to stuff</a>", "igvita.com").first
        i.first.should == 'http://igvita.com/stuff'
        i.last.should == 'link to stuff'
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
        it "should extract #{expected_result.inspect} from #{url}" do
          u = PostRank::URI.clean(url, :raw => true)
          u.domain.should == expected_result
        end
      end
    end
  end

  context "parse" do
    it 'should not fail on large host-part look-alikes' do
      PostRank::URI.parse('a'*64+'.ca').host.should == nil
    end

    it 'should not pancake javascript scheme URIs' do
      PostRank::URI.parse('javascript:void(0);').scheme.should == 'javascript'
    end

    it 'should not pancake mailto scheme URIs' do
      PostRank::URI.parse('mailto:void(0);').scheme.should == 'mailto'
    end

    it 'should not pancake xmpp scheme URIs' do
      PostRank::URI.parse('xmpp:void(0);').scheme.should == 'xmpp'
    end
  end

  context 'valid?' do
    it 'marks incomplete URI string as invalid' do
      PostRank::URI.valid?('/path/page.html').should be_false
    end

    it 'marks www.test.c as invalid' do
      PostRank::URI.valid?('http://www.test.c').should be_false
    end

    it 'marks www.test.com as valid' do
      PostRank::URI.valid?('http://www.test.com').should be_true
    end

    it 'marks Unicode domain as valid (NOTE: works only with a scheme)' do
      PostRank::URI.valid?('http://президент.рф').should be_true
    end

    it 'marks punycode domain domain as valid' do
      PostRank::URI.valid?('xn--d1abbgf6aiiy.xn--p1ai').should be_true
    end
  end
end
