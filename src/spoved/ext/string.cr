class String
  # Will retuen a pluralized string of self
  # ```
  # "wolf".pluralize => "wolves"
  # ```
  def pluralize : String
    exemptions = {
      "fez":    "fezzes",
      "gas":    "gasses",
      "photo":  "photos",
      "piano":  "pianos",
      "halo":   "halos",
      "puppy":  "puppies",
      "roof":   "roofs",
      "belief": "beliefs",
      "chef":   "chefs",
      "chief":  "chiefs",
    }
    return exemptions[self] if exemptions.has_key?(self)

    case self
    when /^metadatum$/
      "#{self[0..-5]}ata"
    when /\w{2}+us$/
      "#{self[0..-3]}i"
    when /is$/
      "#{self[0..-3]}es"
    when /(s|ss|sh|x|z|ch)$/
      "#{self}es"
    when /(a|e|i|o|u)y$/
      "#{self}s"
    when /o$/
      "#{self}es"
    when /y$/
      "#{self[0..-2]}ies"
    when /f$/
      "#{self[0..-2]}ves"
    when /fe$/
      "#{self[0..-3]}ves"
    when /on$/
      "#{self[0..-3]}a"
    else
      "#{self}s"
    end
  end

  # Converts camelcase boundaries to module/klass names.
  #
  # ```
  # "DoesWhatItSaysOnTheTin".klassify # => "Does::What::It::Says::On::The::Tin"
  # "PartyInTheUSA".klassify          # => "Party::In::The::USA"
  # "HTTP_CLIENT".klassify            # => "HTTP::CLIENT"
  # ```
  def klassify
    first = true
    last_is_downcase = false
    last_is_upcase = false
    last_is_digit = false
    last_is_colon = false

    mem = nil
    med = nil

    String.build(bytesize + 10) do |str|
      each_char do |char|
        digit = char.ascii_number?
        downcase = char.ascii_lowercase?
        upcase = char.ascii_uppercase?

        colon = char == ':'

        if first
          str << char.upcase
        elsif colon
          str << char
        elsif last_is_downcase && upcase
          if mem
            # This is the case of A2Bcd, we need to put 'mem'
            #                       ^
            # because 'mem' is digit surely
            med = mem
            mem = char
          else
            # This is the case of AbcDe, we need to put an underscore before the 'D'
            #                        ^
            str << "::"
            str << char
          end
        elsif (last_is_upcase || last_is_digit) && (upcase || digit)
          # This is the case of 1) A1Bcd, 2) A1BCd or 3) A1B_cd
          #                          ^         ^           ^
          # 1) we need to append ::
          # 2) we need to append the char, so we save this char in 'mem' and decide later
          # 3) we need to append this char as downcase and then a single underscore
          if mem
            str << mem
            med = mem
            mem = nil

            if last_is_digit && upcase
              med = mem
              mem = char
              # elsif last_is_upcase && upcase
              #   # Case 2
              #   str << char
            else
              med = mem
              mem = char
            end
          else
            if last_is_digit && upcase
              str << "::"
              str << char
            else
              med = mem
              mem = char
            end
          end
        else
          if mem
            if char == '_'
              # case 3
              char = "::"
            elsif last_is_upcase && downcase
              # case 1
              str << "::"
            end
            str << mem
            med = mem
            mem = nil
          end
          str << char
        end

        last_is_downcase = downcase
        last_is_upcase = upcase
        last_is_digit = digit
        last_is_colon = colon
        first = false
      end

      str << mem if mem
    end
  end
end
