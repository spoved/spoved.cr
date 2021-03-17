macro opt_id(c)
  {{c}}.flags.add do |flag|
    flag.name = "id"
    flag.short = "-i"
    flag.long = "--id"
    flag.default = ""
    flag.description = "id of element"
  end
end

macro opt_uuid(c)
  {{c}}.flags.add do |flag|
    flag.name = "uuid"
    flag.short = "-u"
    flag.long = "--uuid"
    flag.default = ""
    flag.description = "uuid of element"
  end
end

macro opt_print(c)
  {{c}}.flags.add do |flag|
    flag.name = "print"
    flag.short = "-p"
    flag.long = "--print"
    flag.default = false
    flag.description = "Print to stdout"
  end
end

macro opt_all(c)
  {{c}}.flags.add do |flag|
    flag.name = "all"
    flag.short = "-a"
    flag.long = "--all"
    flag.default = false
    flag.description = "Run against all"
  end
end

macro opt_in_file(c)
  {{c}}.flags.add do |flag|
    flag.name = "in_file"
    flag.short = "-f"
    flag.long = "--file"
    flag.description = "Input file."
    flag.default = ""
  end
end

macro opt_out_file(c)
  {{c}}.flags.add do |flag|
    flag.name = "out_file"
    flag.short = "-o"
    flag.long = "--out-file"
    flag.default = ""
    flag.description = "File to save output to."
  end
end

# macro opt_group(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "group"
#     flag.short = "-g"
#     flag.long = "--group"
#     flag.default = ""
#     flag.description = "Specific usenet group."
#   end
# end

# macro opt_offset(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "offset"
#     flag.long = "--offset"
#     flag.default = 0_i64
#     flag.description = "Offset value."
#   end
# end

# macro opt_chunk_size(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "chunk-size"
#     flag.short = "-c"
#     flag.long = "--chunk-size"
#     flag.default = 1000_i64
#     flag.description = "Size of article range to search in each batch."
#     flag.persistent = true
#   end
# end

# macro opt_batch_size(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "batch_size"
#     flag.short = "-b"
#     flag.long = "--batch-size"
#     flag.default = 100_i64
#     flag.description = "Specific group to update."
#   end
# end

# macro opt_bin_name(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "bin_name"
#     flag.short = "-n"
#     flag.long = "--name"
#     flag.default = ""
#     flag.description = "Binary name to delete."
#   end
# end

# macro opt_queue(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "queue"
#     flag.short = "-q"
#     flag.long = "--queue"
#     flag.default = false
#     flag.description = "Queue the task for processing later."
#   end
# end

# macro opt_update(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "update"
#     flag.short = "-U"
#     flag.long = "--update"
#     flag.default = false
#     flag.description = "Perform an update on the element."
#   end
# end

# macro opt_status(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "status"
#     flag.short = "-S"
#     flag.long = "--status"
#     flag.default = ""
#     flag.description = "Comma seperated list of statues to filter for."
#   end
# end

# macro opt_priority(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "priority"
#     flag.short = "-P"
#     flag.long = "--priority"
#     flag.default = ""
#     flag.description = "Comma seperated list of priority to filter for."
#   end
# end

# macro opt_task(c)
#   {{c}}.flags.add do |flag|
#     flag.name = "task"
#     flag.long = "--task"
#     flag.default = ""
#     flag.description = "Specific task to filter for."
#   end
# end
