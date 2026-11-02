# frozen_string_literal: true

require "rails_helper"

describe "/blog" do
  def meta_content(name)
    Nokogiri::HTML(response.body).at_css("meta[property='#{name}']")&.[]("content")
  end

  describe "GET /blog" do
    it "lists posts newest first" do
      get "/blog"

      expect(response.status).to eq(200)
      html = Nokogiri::HTML(response.body)
      expect(html.css("article h2 a").map { |a| a["href"] }).to eq(
        [
          "/blog/winter-update",
          "/blog/undercover-0-9",
          "/blog/feedback-loops-for-agentic-coding",
          "/blog/claude-code-experiment"
        ]
      )
      expect(html.css("article")[2].text).to include("June 11, 2026", "AI agents write code fast")
      expect(html.at_css(".navbar a.nav-link.active[href='/blog']")).to be_present
    end
  end

  describe "GET /blog/:slug" do
    it "renders a known post" do
      get "/blog/claude-code-experiment"
      expect(response.status).to eq(200)
      expect(response.body).to include("Teaching Claude Code to Test What Breaks")
    end

    it "sizes an image whose title is a width" do
      get "/blog/winter-update"

      img = Nokogiri::HTML(response.body).at_css("img[alt=critical_paths_files]")
      expect(img["style"]).to eq("width: 240px")
      expect(img["title"]).to be_nil
    end

    it "renders every post" do
      Dir.glob(BlogController::POSTS_DIR.join("*.md")).each do |path|
        get "/blog/#{File.basename(path, '.md').sub(/\A\d{4}-\d{2}-\d{2}-/, '')}"

        expect(response.status).to eq(200), path
        expect(meta_content("og:description")).to be_present, path
      end
    end

    it "returns 404 for unknown slug" do
      get "/blog/does-not-exist"
      expect(response.status).to eq(404)
    end

    it "renders social preview tags from the post's front matter" do
      get "/blog/feedback-loops-for-agentic-coding"

      expect(meta_content("og:title")).to eq(
        "UndercoverCI | 4 ways to steer your agents towards better tests with Undercover CI"
      )
      expect(meta_content("og:description")).to start_with("AI agents write code fast but skip tests.")
      expect(meta_content("og:url")).to eq("http://www.example.com/blog/feedback-loops-for-agentic-coding")
      expect(meta_content("og:image")).to start_with("http://www.example.com/assets/blog/coverage_agent_fail")
      expect(meta_content("twitter:card")).to eq("summary_large_image")
      expect(meta_content("twitter:image")).to eq(meta_content("og:image"))
    end

    it "falls back to the default social preview image" do
      get "/blog/claude-code-experiment"

      expect(meta_content("og:image")).to start_with("http://www.example.com/assets/check_screenshot")
    end
  end

  describe "top banner" do
    def banner
      Nokogiri::HTML(response.body).at_css(".top-banner")
    end

    it "is hidden without a message" do
      stub_const("ENV", ENV.to_h.except("MAINTENANCE_REASON", "ANNOUNCEMENT"))
      get "/blog/claude-code-experiment"

      expect(banner).to be_nil
    end

    it "renders an announcement" do
      stub_const("ENV", ENV.to_h.merge("ANNOUNCEMENT" => '<a href="/blog/undercover-0-9">undercover 0.9</a> is out'))
      get "/blog/claude-code-experiment"

      expect(banner["aria-label"]).to eq("Announcement")
      expect(banner.at_css("a[href='/blog/undercover-0-9']").text).to eq("undercover 0.9")
      expect(banner.at_css("button[aria-label='Dismiss']")).to be_present
      expect(banner["data-key"]).to match(/\Aannouncement_\h{12}\z/)
    end

    it "shows maintenance instead of an announcement" do
      stub_const("ENV", ENV.to_h.merge("ANNOUNCEMENT" => "News", "MAINTENANCE_REASON" => "Down for maintenance"))
      get "/blog/claude-code-experiment"

      expect(banner["aria-label"]).to eq("Maintenance notification")
      expect(banner.text).to include("Down for maintenance")
      expect(banner.text).not_to include("News")
    end
  end

  it "keeps the small twitter card on pages without an image" do
    get "/docs"

    expect(meta_content("twitter:card")).to eq("summary")
    expect(meta_content("og:image")).to be_nil
  end
end
