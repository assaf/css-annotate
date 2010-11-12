$: << File.dirname(__FILE__) + "/lib"

Gem::Specification.new do |spec|
  spec.name           = "css-annotated"
  spec.version        = IO.read("VERSION")
  spec.author         = "Assaf Arkin"
  spec.email          = "assaf@labnotes.org"
  spec.homepage       = "http://github.com/assaf/#{spec.name}"
  spec.summary        = "The Annotated CSS tells you which style to use where."
  spec.description    = "Uses in-line docs to map the stylesheet. Supports CSS and SCSS."
  spec.post_install_message = "To get started, run the command css-annotate"

  spec.files          = Dir["{bin,lib,test}/**/*", "CHANGELOG", "VERSION", "MIT-LICENSE", "README.rdoc", "Rakefile", "Gemfile", "*.gemspec"]
  spec.executable     = "css-annotate"

  spec.has_rdoc         = true
  spec.extra_rdoc_files = "README.rdoc", "CHANGELOG"
  spec.rdoc_options     = "--title", "#{spec.name} #{spec.version}", "--main", "README.rdoc",
                          "--webcvs", "http://github.com/assaf/#{spec.name}"

  spec.required_ruby_version = '>= 1.8.7'
  spec.add_dependency "haml", "~>3.0"
end
