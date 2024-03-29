macro setup_cli(options, arguments)
  setup_logging({{options}})

  {% for method in @type.methods %}
    {% if method.annotation(Spoved::Cli::PreRun) %}
      {{method.name.id}}(options, arguments)
    {% end %}
  {% end %}
end

macro register_cli_commands
  {% for c in Object.all_subclasses %}
    {% if c.annotation(Spoved::Cli::SubCommand) %}
      register_sub_commands({{c.id}}, "cmd")
    {% end %}

    {% if c.annotation(Spoved::Cli::Command) %}
      register_command({{c.id}}, "run", "cmd", {{ c.annotation(Spoved::Cli::Command).named_args }})
    {% end %}
  {% end %}
end

macro register_sub_commands(klass, cmd, parent = nil)
  {% c = klass.resolve %}
  {% anno = c.annotation(Spoved::Cli::SubCommand) %}
  {{ name = anno[:name].id.gsub(/_/, "-").stringify }}
  cmd.commands.add do |%c|
    # logging(%c)
    %c.use = {{name}}

    {% if anno[:descr] %}
      %c.short = {{anno[:descr]}}
    {% end %}

    %c.run do |_, _|
      puts %c.help # => Render help screen
    end

    {% for m in c.methods %}
      {% if m.annotation(Spoved::Cli::Command) %}
      register_command({{c.id}}, {{m.name}}, %c, {{ m.annotation(Spoved::Cli::Command).named_args }}, {{name}})
      {% end %}
    {% end %}

    {% if anno[:flags] %}
      {% for flag in anno[:flags] %}
      register_cmd_flag({{flag}}, %c)
      {% end %}
    {% end %}

    {% for kosn in c.constants %}
      {% k = c.constant(kosn) %}
      {% if k.is_a?(TypeNode) && k.class? %}
        {% if k.annotation(Spoved::Cli::SubCommand) %}
          register_sub_commands({{k.id}}, %c, {{name}})
        {% else %}
          {% for m in k.methods %}
            {% if m.annotation(Spoved::Cli::Command) %}
            register_command({{k.id}}, "{{m.name}}", %c, {{m.annotation(Spoved::Cli::Command).named_args}}, {{name}})
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  end
end

macro register_command(klass, method, cmd, anno, parent = nil)
  {% m = klass.resolve.methods.find(&.name.id.==(method.id)) %}
  {% if m %}
    {% name = anno[:name].id.gsub(/_/, "-").stringify %}
    {% puts "+ cmd: #{name.id} method: #{method} parent: #{parent}" %}

    {{cmd.id}}.commands.add do |%cmd|
      # logging(%cmd)

      %cmd.use = {{name}}

      {% if anno[:descr] %}
        %cmd.short = {{anno[:descr]}}
      {% end %}

      {% if anno[:opts] %}
        {% for opt in anno[:opts] %}
        opt_{{opt.id}}(%cmd)
        {% end %}
      {% end %}

      {% if anno[:flags] %}
        {% for flag in anno[:flags] %}
        register_cmd_flag({{flag}}, %cmd)
        {% end %}
      {% end %}

      %cmd.run do |options, arguments|
        setup_cli(options, arguments)
        begin
          {{klass.id}}.new.{{method.id}}(%cmd, options, arguments)
        rescue ex
          Log.error { ex.message }
          raise ex
          # puts %cmd.help
          # exit 1
        end
      end
    end
  {% else %}
    raise "No method named {{method.id}} exits"
  {% end %}
end

macro register_cmd_flag(flag, cmd)
  {{cmd}}.flags.add do |flag|
    flag.name = {{flag[:name]}}
    {% if flag[:short] %}
    flag.short = {{flag[:short]}}
    {% end %}
    {% if flag[:long] %}
    flag.long = {{flag[:long]}}
    {% end %}
    {% if flag[:description] %}
    flag.description = {{flag[:description]}}
    {% end %}
    flag.default = {{flag[:default]}}
    {% if flag[:persistent] %}
    flag.persistent = {{flag[:persistent]}}
    {% end %}
  end
end
