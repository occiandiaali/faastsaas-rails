class AiStrategistService
  class AnalysisError < StandardError; end

  def self.perform(url:, scrape_result:, tier:, target_market: nil, demographic: nil, geography: nil)
    prompt = build_prompt(
      url: url,
      scrape_result: scrape_result,
      tier: tier,
      target_market: target_market,
      demographic: demographic,
      geography: geography
    )

    return { report: fallback_report(prompt, tier), tier: tier.to_s.downcase } if ENV.fetch("MISTRAL_API_KEY", "").blank?

    uri = URI("https://api.mistral.ai/v1/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{ENV.fetch('MISTRAL_API_KEY')}"
    request.body = {
      model: "mistral-small-latest",
      messages: [
        { role: "system", content: "You are a senior growth consultant for indie founders." },
        { role: "user", content: prompt }
      ],
      temperature: 0.7
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise AnalysisError, response.body unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    content = payload.dig("choices", 0, "message", "content")
    raise AnalysisError, "The AI response was empty." if content.blank?

    { report: content, tier: tier.to_s.downcase }
  rescue StandardError => e
    Rails.logger.warn("AI strategist analysis fallback triggered: #{e.message}")
    { report: fallback_report(prompt, tier), tier: tier.to_s.downcase, fallback: true }
  end

  def self.build_prompt(url:, scrape_result:, tier:, target_market: nil, demographic: nil, geography: nil)
    base = [
      "You are a marketing strategist specializing in indie developer projects.",
      "Analyze the following website: #{url}",
      "Website title: #{scrape_result[:title]}",
      "Website summary: #{scrape_result[:summary]}",
      "Target market: #{target_market.presence || 'Not provided'}",
      "Demographic focus: #{demographic.presence || 'Not provided'}",
      "Geographic focus: #{geography.presence || 'Not provided'}"
    ]

    if tier.to_s.downcase == "pro"
      base << "Provide a comprehensive go-to-market plan including:"
      base << "- SEO and technical optimization (crawlability, speed, schema markup)"
      base << "- Content marketing strategy (pillar content, repurposing, guest posts)"
      base << "- Social media distribution tailored to demographics"
      base << "- Backlink and partnership opportunities"
      base << "- Email campaign ideas (drip sequences, newsletters)"
      base << "- Community engagement (Discord, Reddit, niche forums)"
      base << "- Growth loops and retention strategies"
      base << "- A phased roadmap (Week 1–4, Month 2–3, Month 6+)"
      base << "- 10 prioritized recommendations with clear next steps"
    else
      base << "Provide a detailed roadmap including:"
      base << "- SEO audit (titles, meta, headings, alt text)"
      base << "- Content strategy (blog posts, tutorials, community engagement)"
      base << "- ICP definition and Distribution channels (social media, forums, newsletters)"
      base << "- Suggested timeline for execution (short-term vs long-term)"
      base << "- 5 prioritized recommendations with rationale"
    end

    base.join("\n")
  end

  def self.fallback_report(prompt, tier)
    report = []
    report << "Go-to-market guide (#{tier.to_s.titleize} tier)"
    report << ""
    report << "This report is a structured fallback generated locally so the strategist flow remains usable without an external AI key."
    report << ""
    report << "1. Positioning and messaging"
    report << "- Clarify the core promise in one sentence."
    report << "- Frame the product around the user’s immediate pain point."
    report << ""
    report << "2. Growth channels"
    report << "- Publish weekly insights that explain the problem space."
    report << "- Use product-led SEO and community-driven distribution."
    report << ""
    report << "3. Recommended next steps"
    report << "- Improve homepage clarity and call-to-action language."
    report << "- Add one proof-oriented case study or testimonial."

    if tier.to_s.downcase == "pro"
      report << "- Build a simple onboarding sequence and referral loop."
      report << "- Create a three-part content pillar and repurpose it across channels."
    else
      report << "- Create one tutorial and one social post per week."
      report << "- Review SEO basics on headings, title tags, and images."
    end

    report.join("\n")
  end
end
