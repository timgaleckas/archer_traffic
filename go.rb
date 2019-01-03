#!/usr/bin/env ruby

require 'kimurai'
require 'sqlite3'

class ArcherSpider < Kimurai::Base
  @name = "archer_spider"
  @engine = :selenium_chrome
  @start_urls = ["http://#{ENV.fetch('ARCHER_IP', '192.168.0.1')}"]
  @config = {
    user_agent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.84 Safari/537.36",
  }

  def parse(response, url:, data: {})
    # Log in
    browser.fill_in 'userName', with: ENV.fetch('ARCHER_USERNAME')
    browser.fill_in 'pcPassword', with: ENV.fetch('ARCHER_PASSWORD')
    browser.evaluate_script 'PCSubWin()'

    raise 'Login Failed' unless browser.has_xpath?("//frameset/frame[@name='bottomLeftFrame']")

    #get DHCP client list (for name)
    browser.within_frame(:xpath, "//frameset/frame[@name='bottomLeftFrame']"){ browser.evaluate_script('doClick(26)') }
    results = {}
    as_of = Time.now
    browser.within_frame(:xpath, "//frameset/frame[@name='mainFrame']") do
      browser.evaluate_script('location.href="AssignedIpAddrListRpm.htm"')
      browser.evaluate_script('DHCPDynList').in_groups_of(4).each do |result|
        results[result[2]] = {
          name: result[0],
          mac: result[1],
          ip: result[2],
          as_of: as_of.to_s
        } if result[2]
      end
    end

    #get statistics (only support 100 records)
    browser.within_frame(:xpath, "//frameset/frame[@name='bottomLeftFrame']"){ browser.evaluate_script('doClick(71)') }
    browser.within_frame(:xpath, "//frameset/frame[@name='mainFrame']") do
      browser.evaluate_script('location.href="SystemStatisticRpm.htm?NumPerPage=100"')
      browser.evaluate_script('document.forms[0].Num_per_page.value=100')
      browser.evaluate_script('document.sysStatic.submit()')
      stat_list = browser.evaluate_script('statList')

      stat_list.in_groups_of(13).map{|l| [l[1], l[2], l[4]] if l[4]}.compact.each do |result|
        results[result[0]] ||= {}
        results[result[0]].merge!(
          {
            ip: result[0],
            mac: result[1],
            bytes: result[2],
            gb: result[2] / 1024 / 1024 / 1024,
            as_of: as_of.to_s
          })
      end
    end

    #logout
    browser.within_frame(:xpath, "//frameset/frame[@name='bottomLeftFrame']"){ browser.evaluate_script('doClick(72)') }

    #push results into DB
    db = SQLite3::Database.new "/data/db.db"
    rows = db.execute <<-SQL
      create table IF NOT EXISTS stats (
        name varchar(128),
        mac varchar(128),
        ip varchar(128),
        bytes int,
        gb int,
        as_of datetime
      );
    SQL

    results.each do |ip, result|
      db.execute "insert into stats values ( ?, ?, ?, ?, ?, ? )", result.values_at(:name, :mac, :ip, :bytes, :gb, :as_of)
    end
  end
end

ArcherSpider.crawl!
