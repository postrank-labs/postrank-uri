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
        PostRank::URI.unescape('id=+1').should == 'id= 1'
      end

      it "should unescape PostRank::URI with spaces encoded as '+'" do
        PostRank::URI.unescape('id%3D+1').should == 'id= 1'
      end

      it "should unescape PostRank::URI with spaces encoded as %20" do
        PostRank::URI.unescape('id=%201').should == 'id= 1'
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

  end

  context "canonicalization" do
    def c(uri)
      PostRank::URI.c18n(uri).to_s
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

    end
  end

  context "clean" do

    def c(uri)
      PostRank::URI.clean(uri)
    end

    it "should unescape, c18n and normalize" do
      c('http://igvita.com/?id=1').should == 'http://igvita.com/?id=1'
      c('igvita.com/?id=1').should == 'http://igvita.com/?id=1'

      c('http://igvita.com/?id= 1').should == 'http://igvita.com/?id=%201'
      c('http://igvita.com/?id=+1').should == 'http://igvita.com/?id=%201'
      c('http://igvita.com/?id%3D%201').should == 'http://igvita.com/?id=%201'

      c('igvita.com/a/..?id=1&utm_source=a&awesm=b#c').should == 'http://igvita.com/?id=1'

      c('igvita.com?id=<>').should == 'http://igvita.com/?id=%3C%3E'
      c('igvita.com?id="').should == 'http://igvita.com/?id=%22'
    end

    it "should clean host specific parameters" do
      YAML.load_file('spec/c18n_hosts.yml').each do |orig, clean|
        c(orig).should == clean
      end
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

    context "multibyte characters" do
      it "should stop extracting URLs at the full-width CJK space character" do
        e("http://www.youtube.com/watch?v=w_j4Lda25jA　　とんかつ定食").should == ["http://www.youtube.com/watch?v=w_j4Lda25jA"]
      end
    end
  end

end