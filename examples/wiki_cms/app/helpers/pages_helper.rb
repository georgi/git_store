# frozen_string_literal: true

# Helper methods for rendering wiki pages
module PagesHelper
  # Render markdown content to HTML
  #
  # @param content [String] Markdown content
  # @return [String] HTML content
  def render_markdown(content)
    # Using a simple markdown implementation
    # In production, use a gem like 'redcarpet' or 'kramdown'
    return '' if content.blank?

    html = content.dup

    # Headers
    html.gsub!(/^### (.+)$/, '<h3>\1</h3>')
    html.gsub!(/^## (.+)$/, '<h2>\1</h2>')
    html.gsub!(/^# (.+)$/, '<h1>\1</h1>')

    # Bold and italic
    html.gsub!(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
    html.gsub!(/\*(.+?)\*/, '<em>\1</em>')

    # Code blocks
    html.gsub!(/```(\w*)\n(.*?)```/m) do
      lang = ::Regexp.last_match(1)
      code = ::Regexp.last_match(2)
      "<pre><code class=\"language-#{lang}\">#{ERB::Util.html_escape(code)}</code></pre>"
    end

    # Inline code
    html.gsub!(/`([^`]+)`/, '<code>\1</code>')

    # Links
    html.gsub!(/\[([^\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>')

    # Wiki-style links [[Page Name]]
    html.gsub!(/\[\[([^\]]+)\]\]/) do
      page_name = ::Regexp.last_match(1)
      slug = page_name.downcase.gsub(/\s+/, '-')
      escaped_name = ERB::Util.html_escape(page_name)
      escaped_slug = ERB::Util.html_escape(slug)
      "<a href=\"/pages/#{escaped_slug}\" class=\"wiki-link\">#{escaped_name}</a>"
    end

    # Paragraphs
    html.gsub!(/\n\n+/, '</p><p>')
    html = "<p>#{html}</p>"

    html.html_safe
  end

  # Format a timestamp in a human-readable way
  #
  # @param time [Time] The timestamp
  # @return [String] Formatted time
  def format_time(time)
    return 'Unknown' unless time

    if time.to_date == Date.today
      "Today at #{time.strftime('%H:%M')}"
    elsif time.to_date == Date.yesterday
      "Yesterday at #{time.strftime('%H:%M')}"
    else
      time.strftime('%B %d, %Y at %H:%M')
    end
  end

  # Truncate commit SHA for display
  #
  # @param sha [String] Full SHA
  # @return [String] Short SHA
  def short_sha(sha)
    sha&.first(7)
  end

  # Generate breadcrumb for a page
  #
  # @param page [Page] The page
  # @return [String] HTML breadcrumb
  def page_breadcrumb(page)
    links = [link_to('Wiki', pages_path)]
    links << link_to(page.title, page_path(page)) if page.persisted?
    safe_join(links, ' / ')
  end

  # Highlight search terms in text
  #
  # @param text [String] The text to highlight
  # @param query [String] The search query
  # @return [String] Text with highlighted terms
  def highlight_search(text, query)
    return ERB::Util.html_escape(text) if query.blank?

    escaped_text = ERB::Util.html_escape(text)
    escaped_query = ERB::Util.html_escape(query)
    escaped_text.gsub(/(#{Regexp.escape(escaped_query)})/i, '<mark>\1</mark>').html_safe
  end

  # Generate diff HTML from diff output
  #
  # @param diff [String] Diff output
  # @return [String] HTML diff
  def format_diff(diff)
    return '<p>No changes</p>'.html_safe if diff.blank?

    lines = diff.to_s.lines.map do |line|
      case line[0]
      when '+'
        "<div class=\"diff-add\">#{ERB::Util.html_escape(line)}</div>"
      when '-'
        "<div class=\"diff-remove\">#{ERB::Util.html_escape(line)}</div>"
      when '@'
        "<div class=\"diff-info\">#{ERB::Util.html_escape(line)}</div>"
      else
        "<div class=\"diff-context\">#{ERB::Util.html_escape(line)}</div>"
      end
    end

    "<pre class=\"diff\">#{lines.join}</pre>".html_safe
  end
end
