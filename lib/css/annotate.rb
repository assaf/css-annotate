require "haml"
require "sass/engine"
require "compass"
require "erb"
require "cgi"

module CSS
  class Annotate

    def initialize(filename, options = {})
      @filename = filename
      @options = options.clone
      paths = @options[:load_paths] || []
      paths.push File.dirname(@filename)
      paths.concat Compass::Frameworks::ALL.map { |framework| framework.stylesheets_directory }
      @options[:load_paths] = paths
      @options[:syntax] ||= guess_syntax(filename)
    end

    attr_reader :filename, :options, :rows

    def annotate
      engine = Sass::Engine.new(IO.read(filename), options)
      tree = engine.to_tree
      tree.perform!(Sass::Environment.new)
      resolve_rules tree
      @rows = to_rows(tree)
    end

    def h(raw)
      CGI.escapeHTML(raw.to_s)
    end

    def to_html
      rows = annotate
      ERB.new(IO.read(File.dirname(__FILE__) + "/annotate/template.erb")).result(binding)
    end

    def styles
      Sass::Engine.new(IO.read(File.dirname(__FILE__) + "/annotate/style.scss"), :syntax=>:scss).render
    end
    
    def all?
      !!options[:all]
    end

  protected

    def resolve_rules(parent)
      parent.children.each do |node|
        if node.respond_to?(:parsed_rules)
          rules = parent.respond_to?(:resolved_rules) ? parent.resolved_rules : nil
          node.resolved_rules = node.parsed_rules.resolve_parent_refs(rules)
          resolve_rules node
        end
      end
    end

    def to_rows(parent)
      rows = []
      nodes = parent.children
      nodes.each_with_index do |node, i|
        if Sass::Tree::RuleNode === node
          if i > 0 && (prev = nodes[i - 1]) && Sass::Tree::CommentNode === prev
            comment = prev.value.gsub(/(^\/\*\s*|\s*\*\/$)/, "")
          end
          if comment || options[:all]
            selector = (node.resolved_rules || node.parsed_rules).to_a.to_s
            style = "#{selector} {\n"
            style << node.children.select { |child| Sass::Tree::PropNode === child }.
              map { |prop| "  #{prop.resolved_name}: #{prop.resolved_value};" }.join("\n")
            style << "}\n"
            rows << { :comment=>comment, :selector=>selector, :style=>style }
          end
        end
        rows.concat to_rows(node) if node.has_children
      end
      rows
    end

    def guess_syntax(filename)
      ext = File.extname(filename).sub(/^\./, "")
      %{css sass scss}.include?(ext) ? ext.to_sym : :scss
    end

  end
end
