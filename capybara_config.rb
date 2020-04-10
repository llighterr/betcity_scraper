
require 'capybara'
require 'browsermob/proxy'
require 'browsermob/proxy/webdriver_listener'

path = Dir.pwd + "/browserup-proxy-2.0.1/bin/browserup-proxy"
server = BrowserMob::Proxy::Server.new(path)
server.start
$proxy = server.create_proxy

Capybara.register_driver :selenium_proxy do |app|
  Capybara::Selenium::Driver.load_selenium
  browser_options = ::Selenium::WebDriver::Chrome::Options.new.tap do |opts|
    opts.args << '--headless'
    opts.args << '--disable-gpu' if Gem.win_platform?
    # Workaround https://bugs.chromium.org/p/chromedriver/issues/detail?id=2650&q=load&sort=-id&colspec=ID%20Status%20Pri%20Owner%20Summary
    opts.args << '--disable-site-isolation-trials'
    opts.args << '--ignore-certificate-errors'
    opts.args << '--proxy-server=http://' + $proxy.selenium_proxy.http
  end
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
end

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :selenium_proxy
end
