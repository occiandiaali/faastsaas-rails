require "net/http"
require "uri"
require "nokogiri"

class WebsiteScraper
  class ScrapeError < StandardError; end

  def self.perform(url:, strategist_token: nil)
    raise ScrapeError, "A website URL is required." if url.blank?

    uri = URI.parse(url)
    raise ScrapeError, "Please provide a valid website URL." unless uri.host.present?

    response = Net::HTTP.get_response(uri)
    raise ScrapeError, "Unable to reach the requested website." unless response.is_a?(Net::HTTPSuccess)

    html = response.body
    doc = Nokogiri::HTML(html)
    head_tag = doc.at_css("head")
    token = head_tag&.css("meta[name='strategist-token']")&.first&.[](:content)

    raise ScrapeError, "The website you're trying to scan is not yet verified. Please add a strategist token to the website head tag." if token.blank?
    raise ScrapeError, "The strategist token does not match this account." if strategist_token.present? && token != strategist_token

    {
      title: doc.at_css("title")&.text&.strip || "Untitled",
      summary: doc.at_css("meta[name='description']")&.[](:content)&.strip || "No description available.",
      url: uri.to_s
    }
  rescue URI::InvalidURIError
    raise ScrapeError, "Please provide a valid website URL."
  rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError
    raise ScrapeError, "Unable to reach the requested website."
  end
end
