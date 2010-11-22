require "haml"
require "sass/engine"
require "erb"
require "cgi"
require "rack"

module CSS
  class Annotate

    # @param [Hash, String, nil] options Hash with options, just the path, or
    # nil
    # @options options [String] path Path to your CSS/SCSS/SASS source files
    # @options options [Array<String>] load_paths Additional paths for loading
    # CSS files
    # @options options [Boolean] all If nil, true show all styles (with buttons to
    # show only commented); if false show only commented styles.
    def initialize(options = nil)
      @options = String === options ? { :path=>options } : options ? options.clone : {}
      @options[:path] ||= "public/stylesheets/"
      paths =[@options[:path]]
      paths.concat Compass::Frameworks::ALL.map { |framework| framework.stylesheets_directory } if defined?(Compass)
      @options[:load_paths] = paths
      @options[:all] = true unless @options.has_key?(:all)
    end

    attr_reader :options, :rows

    # Annotate the named file. Sets and returns rows.
    def annotate(filename)
      engine = Sass::Engine.new(IO.read(filename), options.merge(:syntax=>guess_syntax(filename)))
      tree = engine.to_tree
      tree.perform!(Sass::Environment.new)
      resolve_rules tree
      @rows = to_rows(tree)
    end

    # Annotate the named file, returns HTML document.
    def to_html(filename)
      rows = annotate(filename)
      ERB.new(IO.read(File.dirname(__FILE__) + "/annotate/template.erb")).result(binding)
    rescue Sass::SyntaxError=>error
      error = Sass::SyntaxError.exception_to_css error, @options.merge(:full_exception=>true)
      ERB.new(IO.read(File.dirname(__FILE__) + "/annotate/template.erb")).result(binding)
    end

    # ERB template uses this to HTML escape content.
    def h(raw)
      CGI.escapeHTML(raw.to_s)
    end

    # ERB template uses this to obtain our own stylesheet.
    def styles
      Sass::Engine.new(IO.read(File.dirname(__FILE__) + "/annotate/style.scss"), :syntax=>:scss).render
    end
   
    # EBB template uses this to determine if it should show all, or just
    # commented, styles. 
    def all?
      !!options[:all]
    end

    def call(env)
      request = Rack::Request.new(env)
      filename = request.path_info.split("/").last
      filename = File.expand_path(filename, @options[:path]) if filename
      if filename && File.exist?(filename)
        html = to_html(filename)
        [200, { "Content-Type"=>"text/html", "Content-Length"=>html.length.to_s }, [html]]
      else
        [404, { "Content-Type"=>"text/plain" }, ["Could not find '#{filename}'"]]
      end
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
            selector = (node.resolved_rules || node.parsed_rules).to_a.join
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
      { ".css"=>:scss, ".sass"=>:sass, ".scss"=>:scss }[File.extname(filename)] || :scss
    end

  end
end
