require "securerandom"

class StrategistsController < ApplicationController
  before_action :require_authentication

  def show
    @last_scrape_url = session[:last_scrape_url]
    @last_scrape_result = session[:last_scrape_result]
    @last_analysis_report = session[:last_analysis_report]
    @generated_token = session[:generated_token]
    @tier = session[:analysis_tier] || "basic"
    @status_message = session[:status_message]
    @status_type = session[:status_type] || "notice"

    if params[:download] == "pdf"
      render plain: build_download_pdf, content_type: "application/pdf"
    elsif params[:download] == "txt"
      render plain: build_download_text, content_type: "text/plain; charset=utf-8"
    else
      render :show
    end
  end

  def create
    url = scrape_params[:url]
    user = Current.user

    session[:status_message] = "Scanning #{url}..."
    session[:status_type] = "notice"
    session.delete(:generated_token)
    session.delete(:last_analysis_report)
    session.delete(:last_scrape_result)

    result = WebsiteScraper.perform(
      url: url,
      strategist_token: user&.strategist_token
    )

    session[:last_scrape_url] = result[:url]
    session[:last_scrape_result] = result

    tier = (scrape_params[:tier] || "basic").to_s.downcase
    analysis = AiStrategistService.perform(
      url: url,
      scrape_result: result,
      tier: tier,
      target_market: scrape_params[:target_market],
      demographic: scrape_params[:demographic],
      geography: scrape_params[:geography]
    )

    session[:last_analysis_report] = analysis[:report]
    session[:analysis_tier] = analysis[:tier]
    session[:status_message] = "Scan completed successfully."
    session[:status_type] = "notice"

    redirect_to strategist_path
  rescue WebsiteScraper::ScrapeError => e
    if e.message == "No strategist token found in the website head tag."
      token = SecureRandom.hex(8)
      user.update_column(:strategist_token, token) if user.present?
      session[:generated_token] = token
      session[:status_message] = "No strategist token was found. We generated a token for your account (see it below). Add it to the target site head tag and run the scan again."
      session[:status_type] = "alert"
    else
      session[:status_message] = e.message
      session[:status_type] = "alert"
    end

    redirect_to strategist_path
  end

  private

  def scrape_params
    params.permit(:url, :tier, :target_market, :demographic, :geography)
  end

  def build_download_text
    [
      "Go-to-market guide",
      "",
      "URL: #{@last_scrape_url}",
      "Title: #{@last_scrape_result&.dig(:title)}",
      "Summary: #{@last_scrape_result&.dig(:summary)}",
      "",
      @last_analysis_report.to_s
    ].join("\n")
  end

  def build_download_pdf
    content = build_download_text
    stream_content = build_pdf_stream(content)
    objects = []
    objects << "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
    objects << "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n"
    objects << "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n"
    objects << "4 0 obj\n<< /Length #{stream_content.bytesize} >>\nstream\n#{stream_content}\nendstream\nendobj\n"
    objects << "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"

    pdf = "%PDF-1.4\n"
    offsets = [0]
    objects.each do |object|
      offsets << pdf.bytesize
      pdf << object
    end

    xref_offset = pdf.bytesize
    pdf << "xref\n0 #{objects.size + 1}\n"
    pdf << "0000000000 65535 f \n"
    offsets[1..].each do |offset|
      pdf << format("%010d 00000 n \n", offset)
    end

    pdf << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\n"
    pdf << "startxref\n#{xref_offset}\n%%EOF\n"
    pdf
  end

  def build_pdf_stream(content)
    lines = content.split("\n")
    stream_lines = ["BT", "/F1 12 Tf", "72 720 Td"]

    lines.each_with_index do |line, index|
      stream_lines << "(#{escape_pdf_text(line)}) Tj"
      stream_lines << "0 -14 Td" unless index == lines.size - 1
    end

    stream_lines << "ET"
    stream_lines.join("\n")
  end

  def escape_pdf_text(text)
    text.to_s.gsub(/([\()])/,'\\\1').gsub("\n", "\\n")
  end

end
