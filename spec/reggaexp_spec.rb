RSpec.describe Reggaexp do
  context Reggaexp::Engine do
    context '#map_patterns' do
      let!(:builder) { Reggaexp::BaseExpression.new }

      it 'maps :digit and :digits to [0-9]' do
        expect(builder.map_patterns(:digit)).to  include '0-9'
        expect(builder.map_patterns(:digits)).to include '0-9'
      end

      it 'maps :letter and :letters to [a-zA-Z]' do
        expect(builder.map_patterns(:letter)).to  include 'a-z', 'A-Z'
        expect(builder.map_patterns(:letters)).to include 'a-z', 'A-Z'
      end

      it 'maps :uppercase_letter and :uppercase_letters to [A-Z]' do
        expect(builder.map_patterns(:uppercase_letter)).to  include 'A-Z'
        expect(builder.map_patterns(:uppercase_letters)).to include 'A-Z'
      end

      it 'maps :lowercase_letter and :lowercase_letters to [a-z]' do
        expect(builder.map_patterns(:lowercase_letter)).to  include 'a-z'
        expect(builder.map_patterns(:lowercase_letters)).to include 'a-z'
      end

      it 'maps :space and :spaces to [ ]' do
        expect(builder.map_patterns(:space)).to  include ' '
        expect(builder.map_patterns(:spaces)).to include ' '
      end

      it 'maps :whitespace and :whitespaces to \s' do
        expect(builder.map_patterns(:whitespace)).to  include '\s'
        expect(builder.map_patterns(:whitespaces)).to include '\s'
      end

      it 'maps :non_whitespace and :non_whitespaces to \s' do
        expect(builder.map_patterns(:non_whitespace)).to  include '\S'
        expect(builder.map_patterns(:non_whitespaces)).to include '\S'
      end


      it 'maps :tab and :tabs to \t' do
        expect(builder.map_patterns(:tab)).to  include '\t'
        expect(builder.map_patterns(:tabs)).to include '\t'
      end

      it 'maps :word_character and :word_characters to \w' do
        expect(builder.map_patterns(:word_character)).to  include '\w'
        expect(builder.map_patterns(:word_characters)).to include '\w'
      end

      it 'maps :non_word_character and :non_word_characters to \W' do
        expect(builder.map_patterns(:non_word_character)).to  include '\W'
        expect(builder.map_patterns(:non_word_characters)).to include '\W'
      end

      it 'maps :alphanumeric to [a-zA-Z0-9]' do
        expect(builder.map_patterns(:alphanumeric)).to(
          include('a-z', 'A-Z', '0-9')
        )
      end

      it 'maps :uppercase_alphanumeric to [a-zA-Z0-9]' do
        expect(builder.map_patterns(:uppercase_alphanumeric)).not_to(
          include('a-z')
        )
      end

      it 'maps :lowercase_alphanumeric to [a-zA-Z0-9]' do
        expect(builder.map_patterns(:lowercase_alphanumeric)).not_to(
          include('A-Z')
        )
      end
    end

    context '#escape' do
      let!(:pattern) { Reggaexp.start_with '$|^*+.[({})]' }

      it 'escapes special characters' do
        expect(pattern).to eq(/^\$\|\^\*\+\.\[\(\{\}\)\]/)
        expect(pattern =~ '$|^*+.[({})]').to be_truthy
      end
    end

    context '#simplify' do
      let!(:pattern_zero_or_more) { Reggaexp.start_with [0, nil], :letter }
      let!(:pattern_one_or_more)  { Reggaexp.start_with [1, nil], :letter }
      let!(:pattern_zero_or_one)  { Reggaexp.start_with [0, 1],   :letter }

      it 'simplifies zero or more longhand "{0,}" to shorthand "*"' do
        expect(pattern_zero_or_more).to eq(/^[a-zA-Z]*/)
      end

      it 'simplifies one or more longhand "{1,}" to shorthand "+"' do
        expect(pattern_one_or_more).to eq(/^[a-zA-Z]+/)
      end

      it 'simplifies zero or one longhand "{0,1}" to shorthand "?"' do
        expect(pattern_zero_or_one).to eq(/^[a-zA-Z]?/)
      end

      it 'completely removes zero longhand "{0}"' do
        expect(pattern_zero_or_one).to eq(/^[a-zA-Z]?/)
      end
    end
  end

  context 'Dedeuplicating patterns' do
    context 'Numbers' do
      it 'adds them correctly in separate calls' do
        expect(Reggaexp.find(:digit).find('0', '8').find('2')).to eq(/[0-9][08]2/)
      end

      it 'do not get added when already present in a range' do
        expect(Reggaexp.find(:digit, 0, '8', '2')).to eq(/[0-9]/)
      end

      it 'do not get added when already present individually' do
        expect(Reggaexp.find('8', '8')).to eq(/8/)
      end

      it 'excludes a range that is a sub-range of another range' do
        expect(Reggaexp.find(1..8, 2..4)).to eq(/[1-8]/)
      end

      it 'excludes ranges and characters at the same time' do
        expect(Reggaexp.find(1..8, 2..4, '4', '6')).to eq(/[1-8]/)
      end
    end

    context 'Strings' do
      it 'adds them correctly in separate calls' do
        expect(Reggaexp.find(:letter).find(:letter)).to eq(/[a-zA-Z][a-zA-Z]/)
      end

      it 'do not get added when already present in a range and subject size is 1' do
        expect(Reggaexp.find(:letter, 'a', 'c', 'Z')).to eq(/[a-zA-Z]/)
      end

      it 'do not get added when present individually' do
        expect(Reggaexp.find('a', 'a')).to eq(/a/)
      end

      it 'excludes a range that is a sub-range of another range' do
        expect(Reggaexp.find('a'..'f', 'a'..'z')).to eq(/[a-z]/)
      end

      it 'exclues ranges and characters at the same time' do
        expect(Reggaexp.find('a'..'f', 'a'..'x', 'z')).to eq(/[a-xz]/)
      end
    end
  end

  context 'Regular expression flags' do
    context 'Multiple flags' do
      let!(:pattern) { Reggaexp.multi_line.case_insensitive.whitespace_insensitive }

      it 'can handle multiple flags' do
        expect(pattern).to eq(//mix)
      end

      it 'removes the correct flag when multiple are present' do
        expect(pattern.case_sensitive).to eq(//mx)
      end

      it 'does not add duplicate flags' do
        expect(pattern.case_insensitive).to eq(//mix)
      end
    end

    context 'Adding flags' do
      context '#case_insensitive' do
        let!(:pattern) { Reggaexp.case_insensitive }

        it 'adds a flag to the regular expression' do
          expect(pattern).to eq(//i)
        end
      end

      context '#whitespace_insensitive' do
        let!(:pattern) { Reggaexp.whitespace_insensitive }

        it 'adds a flag to the regular expression' do
          expect(pattern).to eq(//x)
        end
      end

      context '#multi_line' do
        let!(:pattern) { Reggaexp.multi_line }

        it 'adds a flag to the regular expression' do
          expect(pattern).to eq(//m)
        end
      end
    end

    context 'Removing flags' do
      context '#case_sensitive' do
        let!(:pattern) { Reggaexp.case_insensitive }

        it 'removes a flag to the regular expression' do
          expect(pattern).to eq(//i)
          expect(pattern.case_sensitive).to eq(//)
        end
      end

      context '#whitespace_sensitive' do
        let!(:pattern) { Reggaexp.whitespace_insensitive }

        it 'removes a flag to the regular expression' do
          expect(pattern).to eq(//x)
          expect(pattern.whitespace_sensitive).to eq(//)
        end
      end

      context '#single_line' do
        let!(:pattern) { Reggaexp.multi_line }

        it 'removes a flag to the regular expression' do
          expect(pattern).to eq(//m)
          expect(pattern.single_line).to eq(//)
        end
      end
    end
  end

  context 'Regular expression clauses' do
    context '#start_with' do
      let!(:pattern) { Reggaexp.start_with 'h' }

      it 'always prepends "^"' do
        expect(Reggaexp.start_with).to eq(/^/)
      end

      it 'matches a character at the start of a line' do
        expect(pattern =~ 'hello').to be_truthy
      end
    end

    context '#string_start_with' do
      let!(:pattern) { Reggaexp.string_start_with 'Q' }

      it 'always prepends "\\A"' do
        expect(Reggaexp.string_start_with).to eq(/\A/)
      end

      it 'matches only at the start of a string' do
        expect(pattern =~ "Q\nHello").to be_truthy
        expect(pattern =~ "\nQHello").to be_falsy
      end
    end

    context '#end_with' do
      let!(:pattern) { Reggaexp.end_with 'o' }

      it 'always appends "$"' do
        expect(Reggaexp.end_with).to eq(/$/)
      end

      it 'matches a character at the end of a line' do
        expect(pattern =~ 'hello').to be_truthy
      end
    end

    context '#string_end_with' do
      let!(:pattern) { Reggaexp.string_end_with 'o' }

      it 'always appends "\\z"' do
        expect(Reggaexp.string_end_with).to eq(/\z/)
      end

      it 'matches only at the end of a string' do
        expect(pattern =~ "Hel\nlo").to be_truthy
        expect(pattern =~ "Hello\n").to be_falsy
      end
    end

    context '#at_least' do
      let!(:pattern) { Reggaexp.start_of_line.at_least(2, 'l').end_of_line }

      it 'matches at least [N] amount of characters' do
        expect(pattern =~ 'l').to   be_falsy
        expect(pattern =~ 'lll').to be_truthy
      end
    end

    context '#at_most' do
      let!(:pattern) { Reggaexp.start_of_line.at_most(2, 'l').end_of_line }

      it 'matches at most [N] amount of characters' do
        expect(pattern =~ 'll').to  be_truthy
        expect(pattern =~ 'lll').to be_falsy
      end
    end

    context '#one_or_more' do
      let!(:pattern) { Reggaexp.start_of_line.one_or_more(:letter).end_of_line }

      it 'matches at least one of given atom' do
        expect(pattern =~ '').to    be_falsy
        expect(pattern =~ 'a').to   be_truthy
        expect(pattern =~ 'aaa').to be_truthy
      end
    end

    context '#zero_or_more' do
      let!(:pattern) { Reggaexp.start_of_line.zero_or_more(:letter).end_of_line }

      it 'matches at least one of given atom' do
        expect(pattern =~ '').to    be_truthy
        expect(pattern =~ 'a').to   be_truthy
        expect(pattern =~ 'aaa').to be_truthy
      end
    end

    context '#one_of' do
      let!(:pattern) { Reggaexp.start_of_line.one_of('dear', 'best').then(',') }

      it 'matches one of given patterns' do
        expect(pattern =~ 'dear,').to be_truthy
        expect(pattern =~ 'best,').to be_truthy
        expect(pattern =~ 'noob,').to be_falsy
      end
    end

    context '#or' do
      let!(:pattern) { Reggaexp.start_of_line(:whitespace).or { end_of_line(:whitespace) } }

      it 'generates an or clause' do
        expect(pattern).to eq(/^\s|\s$/)
        expect(pattern =~ ' a').to be_truthy
        expect(pattern =~ 'a ').to be_truthy
        expect(pattern =~ 'aa').to be_falsy
      end
    end

    context '#not' do
      let!(:pattern) { Reggaexp.start_of_line.not(2, :digits) }

      it 'does not match when found' do
        expect(pattern =~ '12hello').to be_falsy
        expect(pattern =~ 'hello').to   be_truthy
      end
    end

    context '#not_preceded_by' do
      let!(:pattern) { Reggaexp.line_start_with(1, :digit).not_preceded_by(0) }

      it 'does not match when preceded by found' do
        expect(pattern =~ '123').to be_truthy
        expect(pattern =~ '012').to be_falsy
      end
    end

    context '#preceded_by' do
      let!(:pattern) { Reggaexp.line_start_with(1, :digit).preceded_by(0) }

      it 'matches when preceded by found' do
        expect(pattern =~ '123').to be_falsy
        expect(pattern =~ '012').to be_truthy
      end
    end

    context '#capture' do
      let!(:unnamed) { Reggaexp.start_of_line.capture(1, :letter) }
      let!(:named)   { Reggaexp.start_of_line.capture(1, :letter, as: :first_char) }

      it 'captures a match' do
        expect(unnamed.match('abc')[1]).to eq 'a'
      end

      it 'creates a named capturing group when :as option is used' do
        expect(named.match('abc')[:first_char]).to eq 'a'
      end
    end

    context '#group' do
      let!(:pattern) { Reggaexp.group { find(:letters, :digits).or { find([1, 4], :whitespace) } } }

      it 'creates a non capturing group' do
        expect(pattern).to eq(/(?:[a-zA-Z0-9]|\s{1,4})/)
      end
    end
  end

  context 'Examples' do
    context 'Email address' do
      let!(:pattern) do
        Reggaexp
        .string_start_with(:word_character, '"')
        .zero_or_more(:word_character, '-', '.', '+', '"')
        .then(:word_character, '"')
        .then('@')
        .group {
          find(:alphanumeric)
            .one_or_more(:alphanumeric, '-')
            .group { find('.').one_or_more(:letter, '-') }
            .zero_or_more
            .then('.')
            .one_or_more(:letter)
            .or {
              group {
                find(3, :digits).then('.')
              }
              .repeat(3)
              .then(3, :digits)
            }
        }
        .end_of_string
        .case_insensitive
      end

      it 'can handle an email address regex' do
        expect(pattern).to eq(/\A["\w][\-.+"\w]*["\w]@(?:[a-zA-Z0-9][a-zA-Z0-9\-]+(?:\.[a-zA-Z\-]+)*\.[a-zA-Z]+|(?:[0-9]{3}\.){3}[0-9]{3})\z/i)
      end

      it 'identifies invalid email formats' do
        ['plainaddress', '@domain.com', 'Joe Smith <email@domain.com>',
         'email.domain.com', 'email@domain@domain.com', 'pizzaconpiña@gmail.com',
         'pizzaConpiña@gmail.COM', 'email@111.222.333.44444.555',
         'email@domain..com', 'email@domain.com (Joe Smith)', 'email@domain',
         'almedinagirón2013@hotmail.com', 'scsdfhgsdfj;ghsrf@gmail.com',
         'Fabíola.diniz37@gmail.com', 'something else@gmail.com',
         'аmazon@amazon.com', 'email@-domain.com', '#@%^%#$@#$@#.com',
         'email.@domain.com', '.email@domain.com'].each do |invalid|
          expect(pattern =~ invalid).to be_falsy
        end
      end

      it 'identifies valid email formats' do
        ['valid@gmail.com', 'VALID@GMAIL.com', 'something_else@gmail.com',
         'something@yahoo.fr', 'hello123@gmail123.com',
         'firstname.lastname@domain.com', 'email@subdomain.domain.com',
         'firstname+lastname@domain.com', '_______@domain.com',
         'email@domain.name', 'email@domain.co.jp',
         'firstname-lastname@domain.com', '"email"@domain.com',
         'email@111.222.333.444'].each do |valid|
           expect(pattern =~ valid).to be_truthy
         end
      end
    end
  end
end
