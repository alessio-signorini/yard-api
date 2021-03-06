require 'fileutils'

module YARD::APIPlugin
  class YardocTask < ::YARD::Rake::YardocTask
    attr_reader :config

    def initialize(name=:yard_api)
      super(name) do |t|
        yield t if block_given?
        t.run
      end
    end

    def run
      YARD::APIPlugin.options.reset_defaults

      @config = api_options = YARD::APIPlugin.options.update(load_config)

      puts "Config: #{api_options.to_json}"

      self.verifier = YARD::APIPlugin::Verifier.new(config['verbose'])
      self.before = proc { FileUtils.rm_rf(config['output']) }
      self.files = config['files']

      config['debug'] ||= ENV['DEBUG']
      config['verbose'] ||= ENV['VERBOSE']

      config['output'].sub!('$format', api_options.format)

      set_option('template', 'api')
      set_option('no-yardopts')
      set_option('no-document')

      set_option('markup', config['markup']) if config['markup']
      set_option('markup-provider', config['markup_provider']) if config['markup_provider']

      if config['markup_provider'] == 'redcarpet'
        require 'yard-api/markup/redcarpet'
      end

      set_option('title', config['title'])
      set_option('output-dir', config['output'])
      set_option('one-file') if config['one_file']
      set_option('readme', config['readme']) if File.exists?(config['readme'])
      set_option('verbose') if config['verbose']
      set_option('debug') if config['debug']

      set_option('no-save') if config['no_save']
      set_option('format', api_options.format)

      get_assets(config).each_pair do |asset_id, rpath|
        asset_path = rpath

        if File.directory?(asset_path)
          set_option 'asset', [ asset_path, asset_id ].join(':')
        elsif config['strict']
          raise <<-Error
            Expected assets of type "#{asset_id}" to be found within
            "#{asset_path}", but they are not.
          Error
        end
      end

      if config['debug']
        puts "Invoking YARD with options: #{self.options.to_json}"
      end
    end

    def configure(runtime_config)
      @runtime_config = runtime_config
    end

    private

    def load_config
      path = ENV.fetch('YARD_API_CONFIG') { Rails.root.join('config', 'yard_api.yml') }

      # load defaults
      config = YAML.load_file(File.join(YARD::APIPlugin::CONFIG_PATH, 'yard_api.yml'))
      config.merge!(YAML.load_file(path)) if File.exists?(path)
      config.merge! @runtime_config if @runtime_config

      config
    end

    def set_option(k, *vals)
      self.options.concat(["--#{k}", *vals])
    end

    def get_assets(config)
      config['assets'] || {}
    end
  end
end
