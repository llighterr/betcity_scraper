require 'capybara'
require 'capybara/dsl'
require 'pry'

# Capybara.register_driver :selenium_chrome_headless
Capybara.run_server = false
Capybara.default_driver = :selenium_chrome_headless

class BetcityScraper
  include Capybara::DSL

  SITE_URL = 'https://betcityru.com/ru?login=1'

  def initialize(account_number, password)
    @agent = initialize_agent
    @account_number = account_number
    @password = password    
  end

  def login
    binding.pry
  end

  private

  attr_reader :agent

  def initialize_agent
    
  end
end

if $0 == __FILE__
  BetcityScraper.new('g8657706', '11707844').login
end