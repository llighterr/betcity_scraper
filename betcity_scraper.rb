require 'bigdecimal'
require 'capybara/dsl'

class BetcityScraper
  include Capybara::DSL

  SITE_URL = 'https://betcityru.com/ru?login=1'
  DEFAULT_BET_RANGE = (10..200)
  DEFAULT_TIMEOUT = 10
  NO_BETS_ALLOWED = 'Приём ставок временно остановлен'

  def initialize(account_number, password, proxy:)
    @account_number = account_number
    @password = password
    @proxy = proxy
  end

  def login
    visit SITE_URL
    close_popup
    fill_in 'login', with: @account_number
    fill_in 'pass', with: @password
    click_button 'Войти'
  end

  def balance
    path = '//span[contains(text(),"Баланс")]/following-sibling::span[1]'
    amount = find(:xpath, path).text.delete(' ').sub(',', '.').delete('руб')
    BigDecimal(amount)
  end

  def list_of_live_events(unacceptable_bets: false)
    close_popup
    container_path = '//app-live-block/div/div[contains(@class,"line__wrapper")]'
    events = find(:xpath, container_path).all('a.line-event__name-link')
    unacceptable_bets ? filter_unacceptable_bets(events) : events
  end

  def set_random_bet_for(link)
    retries ||= 0
    sleep 1

    visit link
    sleep 1
    event_id ||= current_path.split('/').last
    amount ||= [rand(DEFAULT_BET_RANGE), balance.to_i].min
    status ||= :pending

    button_path = "//app-dop-ext[.//span[contains(text(),'Фактический исход')]]"\
                  "//div[@data-first-index='Wm' and ./span[contains(text(),"\
                  "'1')]]/button"
    find(:xpath, button_path).click
    fill_in 'Сумма', with: amount
    click_button 'сделать ставку'

    Timeout.timeout(DEFAULT_TIMEOUT) do
      sleep 0.5 until has_content? 'Принято: 1'
    end
    status = :success
    { event_id: event_id, status: status, amount: amount }
  rescue Capybara::ElementNotFound, Net::HTTPBadResponse
    if has_content? NO_BETS_ALLOWED
      status = :failure
    elsif retries < 2
      retries += 1
      retry
    else
      status = :failure
    end
    { event_id: event_id, status: status, amount: amount }
  rescue Timeout::Error
    status = :failure
    { event_id: event_id, status: status, amount: amount }
  end

  private

  def close_popup
    first(:xpath, '//div[@role="button" and contains(text(),"Позже")]').click
  rescue Capybara::ExpectationNotMet
  end

  def filter_unacceptable_bets(events)
    events.delete_if do |event|
      event.find(:xpath, './../../../..').text =~ Regexp.new(NO_BETS_ALLOWED)
    end
  end
end

if $0 == __FILE__
  require 'pp'
  require 'redis'
  require 'json'

  load './capybara_config.rb'

  bet_city = BetcityScraper.new('g8657706', '11707844', proxy: $proxy)
  bet_city.login
  puts "Текущий баланс: #{'%.2f' % bet_city.balance}"

  events_amount = 4
  links = bet_city.list_of_live_events.sample(events_amount).map do |event|
    event[:href]
  end

  data = links.collect do |link|
    bet_city.set_random_bet_for(link)
  end

  puts 'Статус оппераций:'
  pp data

  redis = Redis.new
  redis.set('results', data.to_json)
end
