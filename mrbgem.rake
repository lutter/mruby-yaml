MRuby::Gem::Specification.new('mruby-yaml') do |spec|
  spec.license = 'MIT'
  spec.authors = 'Andrew Belt'
  spec.version = '0.1.0'
  spec.description = 'YAML gem for mruby'
  spec.homepage = 'https://github.com/AndrewBelt/mruby-yaml'
  spec.linker.libraries << 'yaml'

  def spec.bundle_libyaml
    yaml_version = "0.1.7"
    yaml_dir = "#{build_dir}/yaml-#{yaml_version}"
    yaml_tar = "#{build_dir}/yaml-#{yaml_version}.tar.gz"
    yaml_url = "http://pyyaml.org/download/libyaml/yaml-#{yaml_version}.tar.gz"
    yaml_lib = "#{yaml_dir}/build/lib/libyaml.a"

    def run_command(env, command)
      unless system(env, command)
        fail "#{command} failed"
      end
    end

    file yaml_tar do |t|
      FileUtils.mkdir_p build_dir
      Dir.chdir(build_dir) do
        e = {}
        run_command e, "curl -s -O http://pyyaml.org/download/libyaml/yaml-#{yaml_version}.tar.gz"
      end
    end

    file yaml_dir => yaml_tar do |t|
      # We don't care about timestamps, just whether the dir exists
      unless File::directory?(yaml_dir)
        FileUtils.mkdir_p build_dir
        Dir.chdir(build_dir) do
          e = {}
          run_command e, "tar xzf #{yaml_tar}"
        end
        touch yaml_dir
      end
    end

    file yaml_lib => yaml_dir do |t|
      FileUtils.mkdir_p("#{yaml_dir}/build")
      Dir.chdir(yaml_dir) do
        e = {
          'CC' => "#{cc.command} #{cc.flags.join(' ')}",
          'CXX' => "#{cxx.command} #{cxx.flags.join(' ')}",
          'LD' => "#{build.linker.command} #{linker.flags.join(' ')}",
          'AR' => archiver.command,
          'PREFIX' => "#{yaml_dir}/build"
        }

        configure_opts = %w(--prefix=$PREFIX --enable-static --disable-shared)
        if build.kind_of?(MRuby::CrossBuild) &&
            build.host_target && build.build_target
          configure_opts += %W(--host #{build.host_target} --build #{build.build_target})
          if ['x86_64-w64-mingw32',
              'i686-w64-mingw32'].include?(build.host_target)
            e["CFLAGS"] = "-DYAML_DECLARE_STATIC"
            cc.flags << "-DYAML_DECLARE_STATIC"
            e['LD'] = "#{build.host_target}-ld #{build.linker.flags.join(' ')}"
          end
        end
        run_command e, "./configure #{configure_opts.join(" ")}"
        run_command e, "make"
        run_command e, "make install"
      end
    end

    file "#{build_dir}/src/yaml.o" => [ "#{dir}/src/yaml.c", yaml_dir ]

    build.libmruby << yaml_lib
    cc.include_paths << "#{yaml_dir}/include"
    linker.library_paths << "#{yaml_dir}/build/lib/"
  end

  spec.bundle_libyaml
end
