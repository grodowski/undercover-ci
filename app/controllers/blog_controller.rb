# frozen_string_literal: true

class BlogController < ApplicationController
  layout "static_page"

  POSTS_DIR = Rails.root.join("app/content/blog")

  def show
    @post = load_posts.find { |p| p[:slug] == params[:slug] }
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false unless @post
  end

  private

  def load_posts
    Dir.glob(POSTS_DIR.join("*.md")).map { |path| parse_post(path) }
  end

  def parse_post(path)
    content = File.read(path)
    frontmatter, body = split_frontmatter(content)
    meta = frontmatter ? YAML.safe_load(frontmatter, permitted_classes: [Date]) : {}
    slug = File.basename(path, ".md").sub(/\A\d{4}-\d{2}-\d{2}-/, "")

    {
      slug: slug,
      title: meta["title"],
      date: meta["date"],
      description: meta["description"],
      body: render_markdown(body.strip)
    }
  end

  def split_frontmatter(content)
    return [nil, content] unless content.start_with?("---\n")

    parts = content.split(/^---\s*$/, 3)
    parts.length >= 3 ? [parts[1], parts[2]] : [nil, content]
  end

  class BootstrapRenderer < Redcarpet::Render::HTML
    def initialize(options = {})
      super
      @view_context = options.delete(:view_context)
    end

    def table(header, body)
      "<table class=\"table table-sm table-bordered\"><thead>#{header}</thead><tbody>#{body}</tbody></table>"
    end

    def image(link, title, alt)
      # Convert blog image paths to asset pipeline URLs
      image_url = if link.start_with?("http://", "https://", "/")
                    link
                  else
                    @view_context.image_path("blog/#{link}")
                  end
      "<img src=\"#{image_url}\" alt=\"#{alt}\" title=\"#{title}\" />"
    end
  end

  def render_markdown(text)
    Redcarpet::Markdown.new(
      BootstrapRenderer.new(hard_wrap: true, view_context: view_context),
      fenced_code_blocks: true,
      tables: true,
      autolink: true,
      strikethrough: true
    ).render(text)
  end
end
