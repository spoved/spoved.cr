macro setup_cli(options, arguments)
  setup_logging({{options}})
end

macro register_cli_commands
  {% begin %}
    {% for sub_c in Spoved::Cli::Main.all_subclasses %}
      {% for c in Object.all_subclasses %}
        {% if c.annotation(Spoved::Cli::SubCommand) %}
          register_sub_commands({{c.id}}, "cmd")
        {% end %}

        {% if c.annotation(Spoved::Cli::Command) %}
          {% puts c %}
          register_command({{c.id}}, "run", "cmd", {{ c.annotation(Spoved::Cli::Command).named_args }})
        {% end %}
      {% end %}
    {% end %}
  {% end %}
end

macro register_sub_commands(klass, cmd)
  {% c = klass.resolve %}
  {% anno = c.annotation(Spoved::Cli::SubCommand) %}
  cmd.commands.add do |%c|
    %c.use = {{anno[:name].id.gsub(/_/, "-").stringify}}

    {% if anno[:descr] %}
      %c.short = {{anno[:descr]}}
    {% end %}

    %c.run do |_, _|
      puts %c.help # => Render help screen
    end

    {% for m in c.methods %}
      {% if m.annotation(Spoved::Cli::Command) %}
      register_command({{c.id}}, {{m.name}}, %c, {{ m.annotation(Spoved::Cli::Command).named_args }})
      {% end %}
    {% end %}

    {% if anno[:flags] %}
      {% for flag in anno[:flags] %}
      register_cmd_flag({{flag}}, %cmd)
      {% end %}
    {% end %}
  end

  {% for k in c.constants %}
    {% if k.class? && k.annotation(Spoved::Cli::SubCommand) %}
    register_sub_commands({{k.id}}, %c)
    {% end %}
  {% end %}
end

macro register_command(klass, method, cmd, anno)
  {% m = klass.resolve.methods.find { |m| m.name.id == method.id } %}
  {% if m %}
    {{cmd.id}}.commands.add do |%cmd|
      %cmd.use = {{anno[:name].id.gsub(/_/, "-").stringify}}

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
        {{klass.id}}.new.{{method.id}}(%cmd, options, arguments)
      end
    end
  {% else %}
    raise "No method named {{method.id}} exits"
  {% end %}
end

macro register_cmd_flag(flag, cmd)
  cmd.flags.add do |flag|
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
