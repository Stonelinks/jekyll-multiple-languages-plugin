require 'yaml'
$translations = {}
$output_missing_keys = true

module Jekyll
  class Site
    alias :process_org :process

    def process
      # variables
      self.config['baseurl_root'] = self.config['baseurl']
      dest_org = self.dest
      baseurl_org = self.baseurl
      languages = self.config['languages']

      # loop
      self.config['lang'] = languages.first
      puts
      puts "Building site for default language: \"#{self.config['lang']}\" to: " + self.dest
      # process_org
      languages.drop(1).each do |lang|
        
        $translations = {} if lang != "en" and $output_missing_keys
      
        # build site for language lang
        self.dest = self.dest + "/" + lang
        self.baseurl = self.baseurl + "/" + lang
        self.config['baseurl'] = self.baseurl
        self.config['lang'] = lang
        puts "Building site for language: \"#{self.config['lang']}\" to: " + self.dest
        process_org

        # reset variables for next language
        self.dest = dest_org
        self.baseurl = baseurl_org
        self.config['baseurl'] = baseurl_org
        
        if lang != "en" and $output_missing_keys
          $output_missing_keys = false
          puts $translations.to_yaml
        end
      end
      puts 'Build complete'
    end
  end

  class LocalizeInclude < Jekyll::Tags::IncludeTag
    def render(context)
      if "#{context[@file]}" != "" # check for page variable
        file = "#{context[@file]}"
      else
        file = @file
      end

      includes_dir = File.join(context.registers[:site].source, '_i18n/' + context.registers[:site].config['lang'])

      if File.symlink?(includes_dir)
        return "Includes directory '#{includes_dir}' cannot be a symlink"
      end
      if file !~ /^[a-zA-Z0-9_\/\.-]+$/ || file =~ /\.\// || file =~ /\/\./
        return "Include file '#{file}' contains invalid characters or sequences"
      end

      Dir.chdir(includes_dir) do
        choices = Dir['**/*'].reject { |x| File.symlink?(x) }
        if choices.include?(file)
          source = File.read(file)
          partial = Liquid::Template.parse(source)

          context.stack do
            context['include'] = parse_params(context) if @params
            contents = partial.render(context)
            site = context.registers[:site]
            ext = File.extname(file)

            converter = site.converters.find { |c| c.matches(ext) }
            contents = converter.convert(contents) unless converter.nil?

            contents
          end
        else
          "Included file '#{file}' not found in #{includes_dir} directory"
        end
      end
    end
  end

  class LocalizeTag < Liquid::Tag

    def initialize(tag_name, key, tokens)
      super
      @key = key.strip
    end

    def render(context)
      if "#{context[@key]}" != "" # check for page variable
        key = "#{context[@key]}"
      else
        key = @key
      end
      lang = context.registers[:site].config['lang']
      candidate = YAML.load_file(context.registers[:site].source + "/_i18n/#{lang}.yml")

      if candidate[key]
        candidate = candidate[key]
      else
        candidate = ""
      end

      # path = key.split(/\./) if key.is_a?(String)
      # path[0] += '.' if key[-1] == '.'
      # while !path.empty?
        # key = path.shift
        # if candidate[key]
          # candidate = candidate[key]
        # else
          # candidate = ""
        # end
      # end
      
      ret = ''
      
      if candidate == ""
        # puts "Missing i18n key: " + lang + ":" + key
        # puts "'" + key + "': ''"
        $translations[key] = ''
        ret = key
      else
        
        # {{ site.baseurl_root }}
        # {{ site.lang }}
        # $translations[key] = candidate
        ret = candidate
      end
      
      return ret.gsub(/{{ site.lang }}/, lang).gsub(/{{ site.baseurl_root }}/, context.registers[:site].config['baseurl_root'])
    end
  end
end

Liquid::Template.register_tag('t', Jekyll::LocalizeTag)
Liquid::Template.register_tag('tf', Jekyll::LocalizeInclude)
Liquid::Template.register_tag('translate', Jekyll::LocalizeTag)
Liquid::Template.register_tag('translate_file', Jekyll::LocalizeInclude)
