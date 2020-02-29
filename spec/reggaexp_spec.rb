# examples may contain some non-related tokens to the test
# to ensure that everything is joined properly regardless
# of argument order.

RSpec.describe Reggaexp do
  def clause(*args, **opts)
    Reggaexp.find(*args, **opts).clauses
            .map { |clause| clause[:content] }
            .flatten
  end

  def character_class(*args)
    Reggaexp.character_class clause(*args)
  end

  def non_capturing_group(*args)
    Reggaexp.non_capturing_group clause(*args)
  end

  context Reggaexp::Engine do
    context 'Argument parsing' do
      context 'Block' do
        it 'creates a sub-expression' do
          expect(Reggaexp.one_or_more(:a).or(:abc).then(:q)).to eq(/(?:a+|abc)q/)
        end
      end

      context 'Symbols' do
        it 'maps symbols to presets' do
          expect(clause(:word, :number, :letter)).to(
            contain_exactly('\w', '0'..'9', 'a'..'z', 'A'..'Z')
          )
        end

        it 'recognizes plural presets' do
          expect(clause(:words, :numbers, :letters)).to(
            contain_exactly('\w', '0'..'9', 'a'..'z', 'A'..'Z')
          )
        end

        it 'maps nested presets' do
          expect(clause(:alphanum)).to(
            contain_exactly('0'..'9', 'a'..'z', 'A'..'Z')
          )
        end

        it 'supports aliases' do
          expect(clause(:digits)).to     eq clause(:numbers)
          expect(clause(:chars)).to      eq clause(:letters)
          expect(clause(:characters)).to eq clause(:letters)
        end

        it 'correctly interpolates symbol presets that contain a backslash' do
          expect(Reggaexp.start_of_string(:whitespace, :tab)).to eq(/\A[\s\t]/)
        end
      end

      context 'Bools' do
        it 'stringifies true' do
          expect(clause(true)).to  contain_exactly 'true'
        end

        it 'stringifies false' do
          expect(clause(false)).to contain_exactly 'false'
        end
      end

      context 'Ranges' do
        it 'converts range boundary types to strings' do
          expect(clause(:b..:q, 1..4, 's'..'u')).to(
            contain_exactly('b'..'q', '1'..'4', 's'..'u')
          )
        end

        it 'removes redundant character ranges' do
          expect(clause(:a..:z, :e..:i)).to contain_exactly 'a'..'z'
          expect(clause(:a..:z, :a..:z)).to contain_exactly 'a'..'z'
          expect(clause(:a..:d, :f..:i)).to contain_exactly 'a'..'d', 'f'..'i'
        end

        it 'merges connecting character ranges' do
          expect(clause(:a..:d, :e..:i)).to contain_exactly 'a'..'i'
          expect(clause(:a..:d, :f..:i)).to contain_exactly 'a'..'d', 'f'..'i'
        end

        it 'removes redundant numeric ranges' do
          expect(clause(0..9, 3..6)).to contain_exactly '0'..'9'
          expect(clause(0..9, 0..9)).to contain_exactly '0'..'9'
          expect(clause(0..2, 4..6)).to contain_exactly '0'..'2', '4'..'6'
        end

        it 'merges connecting numeric ranges' do
          expect(clause(0..3, 4..7)).to contain_exactly '0'..'7'
          expect(clause(0..3, 5..7)).to contain_exactly '0'..'3', '5'..'7'
        end

        it 'explodes ranges with different case bounds' do
          expect(clause('a'..'Z')).to contain_exactly 'a'..'z', 'A'..'Z'
        end
      end

      context 'Numbers and floats' do
        it 'converts numbers and floats to strings' do
          expect(clause('1', 2, 3.25)).to contain_exactly '1', '2', '3\\.25'
        end

        it 'removes duplicates' do
          expect(clause('1', 2, 3, 1, 5, 1)).to contain_exactly '1', '2', '3', '5'
          expect(clause('1.25', 1, 1.25)).to    contain_exactly '1\\.25', '1'
        end
      end

      context 'Strings' do
        it 'escapes strings for use in a character-class' do
          expect(clause('$', 'h.')).to contain_exactly 'h\.', '$'
        end

        it 'escapes strings for use outside of a character-class' do
          expect(clause('the^e', 'by$')).to contain_exactly 'the\\^e', 'by\\$'
        end

        it 'removes duplicates' do
          expect(clause('a', 'b', 'c', 'b', 'a')).to contain_exactly 'a', 'b', 'c'
          expect(clause('abc', 'def', 'abc', 'ghi')).to(
            contain_exactly('abc', 'def', 'ghi')
          )
        end
      end
    end

    context 'Expression components' do
      context 'Start and end of line / string' do
        it 'creates a pattern matching the start of a line' do
          expect(Reggaexp.find('abc', prepend: '^')).to match 'abc'
          expect(Reggaexp.find('abc', prepend: '^')).not_to match 'xabc'
        end

        it 'creates a pattern matching the start of a string' do
          expect(Reggaexp.find('abc', prepend: '\A')).to match "abc"
          expect(Reggaexp.find('abc', prepend: '\A')).not_to match "\nabc"
        end

        it 'creates a pattern matching the end of a line' do
          expect(Reggaexp.find('abc', append: '$')).to match "abc"
          expect(Reggaexp.find('abc', append: '$')).not_to match "abcx"
        end

        it 'creates a pattern matching the end of a string' do
          expect(Reggaexp.find('abc', append: '\z')).to match "abc"
          expect(Reggaexp.find('abc', append: '\z')).not_to match "abc\n"
        end
      end

      context 'Character classes' do
        it 'filters single-character strings for character-class usage' do
          expect(character_class('a', 'abc', 'q', 1, :b)).to(
            contain_exactly('a', 'q', '1', 'b')
          )
        end

        it 'creates a character class with single-length strings and ranges' do
          expect(Reggaexp.find(:q, :a..:f)).to eq(/[qa-f]/)
        end

        it 'only generates a character class when needed' do
          expect(Reggaexp.find(:q)).to eq(/q/)
        end
      end

      context 'Capture groups and non capture groups' do
        it 'escapes backslashes' do
          expect(Reggaexp.find('a', '\\')).to eq(/[a\\]/)
        end

        it 'escapes closing square brackets' do
          expect(Reggaexp.find('a', ']')).to eq(/[a\]]/)
        end

        it 'escapes closing dashes' do
          expect(Reggaexp.find('a', '-')).to eq(/[a\-]/)
        end

        it 'filters multi-character strings for non-capture-group usage' do
          expect(non_capturing_group('a', 'abc', 'q', 123, :b)).to(
            contain_exactly('123', 'abc')
          )
        end

        it 'creates a capture group when capture: true is given' do
          match_data = Reggaexp.find('hello', capture: true).match('hello')
          expect(match_data[1]).to eq 'hello'
        end

        it 'does not create a capture group when capture: false' do
          match_data = Reggaexp.find('hello', capture: false).match('hello')
          expect(match_data[1]).to be_nil
        end

        it 'creates a named capture group when as: :name is given' do
          match_data = Reggaexp.find('hello', as: :name).match('hello')
          expect(match_data[:name]).to eq 'hello'
        end

        it 'creates a non-capturing group around strings when needed' do
          expect(Reggaexp.find('hello', 'goodbye')).to eq(/(?:hello|goodbye)/)
          expect(Reggaexp.find('hello', 'goodbye').then(:a)).to eq(/(?:hello|goodbye)a/)
        end
      end

      context 'Quantifiers' do
        it 'applies "one_or_more"' do
          expect(Reggaexp.find('a', quantifier: '+')).to eq(/a+/)
        end

        it 'applies "zero_or_more"' do
          expect(Reggaexp.find('a', quantifier: '*')).to eq(/a*/)
        end

        it 'applies "optional"' do
          expect(Reggaexp.find('a', quantifier: '?')).to eq(/a?/)
        end

        it 'applies "between"' do
          expect(Reggaexp.find('a', quantifier: 1..3)).to   eq(/a{1,3}/)
          expect(Reggaexp.find('a', quantifier: [1, 3])).to eq(/a{1,3}/)
        end

        it 'does not apply redundant quantifier' do
          expect(Reggaexp.find('a', quantifier: [1])).to eq(/a/)
          expect(Reggaexp.find('a', quantifier: [1, 1])).to eq(/a/)
        end

        it 'simplifies between(1, inf) to "+"' do
          expect(Reggaexp.find('a', quantifier: [1, nil])).to eq(/a+/)
        end

        it 'simplifies between(0, inf) to "*"' do
          expect(Reggaexp.find('a', quantifier: [0, nil])).to eq(/a*/)
        end

        it 'simplifies between(0, 1) to "?"' do
          expect(Reggaexp.find('a', quantifier: [0, 1])).to eq(/a?/)
        end
      end

      context 'Regular expression flags' do
        context 'Simplifies clauses' do
          it 'downcases all uppercase groups with case-insensitive flag' do
            expect(Reggaexp.add_flag(:i).find(:a..:d, :X..:Z)).to eq(/[x-za-d]/i)
          end

          it 'removes duplicate ranges with case-insensitive flag' do
            expect(Reggaexp.add_flag(:i).find(:a..:z, :A..:Z)).to eq(/[a-z]/i)
          end
        end

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

      context 'Escaping' do
        it 'escapes special characters outside character classes' do
          expect(Reggaexp.find('$|^*+.[({})]') =~ '$|^*+.[({})]').to be_truthy
        end

        it 'escapes special characters inside character classes' do
          expect(Reggaexp.find('$', ']', '-', :a..:f)).to eq(/[$\]\-a-f]/)
        end
      end
    end

    context 'Mimicks Regexp' do
      let!(:pattern) { Reggaexp::Expression.new }

      it 'responds to #match' do
        expect(pattern).to respond_to :match
      end

      it 'responds to #match?' do
        expect(pattern).to respond_to :match?
      end

      it 'responds to #!~' do
        expect(pattern).to respond_to :!~
      end

      it 'responds to #=~' do
        expect(pattern).to respond_to :=~
      end

      it 'responds to #===' do
        expect(pattern).to respond_to :===
      end

      it 'responds to #==' do
        expect(pattern).to respond_to :==
      end

      it 'responds to #!=' do
        expect(pattern).to respond_to :!=
      end

      it 'responds to #<=>' do
        expect(pattern).to respond_to :<=>
      end

      it 'responds to #~' do
        expect(pattern).to respond_to :<=>
      end

      it 'responds to #source' do
        expect(pattern).to respond_to :source
      end

      it 'responds to #options' do
        expect(pattern).to respond_to :options
      end

      it 'responds to #named_captures' do
        expect(pattern).to respond_to :named_captures
      end

      it 'responds to #names' do
        expect(pattern).to respond_to :names
      end

      it 'responds to #to_s' do
        expect(pattern).to respond_to :to_s
      end

      it 'does not respond to #to_a' do
        expect(pattern).not_to respond_to :to_a
      end
    end
  end

  context Reggaexp::Expression do
    context '#find' do
      it 'creates a pattern' do
        expect(Reggaexp.find(:a)).to eq(/a/)
      end

      it 'accepts a block' do
        expect(Reggaexp.find { maybe(:a) }).to eq(/a?/)
      end

      it 'creates a capture group' do
        expect(Reggaexp.find(:a, as: :char)).to eq(/(?<char>a)/)
      end
    end

    context '#start_to_end_of_line' do
      it 'creates a pattern matching from start to end' do
        expect(Reggaexp.start_to_end_of_line(:a)).to eq(/^a$/)
      end
    end

    context '#start_to_end_of_string' do
      it 'creates a pattern matching from start to end' do
        expect(Reggaexp.start_to_end_of_string(:a)).to eq(/\Aa\z/)
      end
    end

    context '#start_of_line' do
      it 'creates a pattern matching at start of line' do
        expect(Reggaexp.start_of_line).to eq(/^/)
        expect(Reggaexp.start_of_line(:a..:z)).to eq(/^[a-z]/)
      end
    end

    context '#start_of_string' do
      it 'creates a pattern matching at start of string' do
        expect(Reggaexp.start_of_string).to eq(/\A/)
        expect(Reggaexp.start_of_string(:a..:z)).to eq(/\A[a-z]/)
      end
    end

    context '#end_of_line' do
      it 'creates a pattern matching at end of line' do
        expect(Reggaexp.end_of_line).to eq(/$/)
        expect(Reggaexp.end_of_line(:a..:z)).to eq(/[a-z]$/)
      end
    end

    context '#end_of_string' do
      it 'creates a pattern matching at end of string' do
        expect(Reggaexp.end_of_string).to eq(/\z/)
        expect(Reggaexp.end_of_string(:a..:z)).to eq(/[a-z]\z/)
      end
    end

    context '#zero_or_one' do
      it 'creates a pattern matching zero or one occurence' do
        expect(Reggaexp.zero_or_one(:a)).to eq(/a?/)
      end

      it 'groups a clause with count correctly' do
        expect(Reggaexp.maybe(2, :letters).case_insensitive).to eq(/(?:[a-z]{2})?/i)
      end
    end

    context '#zero_or_more' do
      it 'creates a pattern matching zero or more occurences' do
        expect(Reggaexp.zero_or_more(:a)).to eq(/a*/)
      end

      it 'groups a clause with count correctly' do
        expect(Reggaexp.maybe_multiple(2, :letters).case_insensitive).to eq(/(?:[a-z]{2})*/i)
      end
    end

    context '#one_or_more' do
      it 'creates a pattern matching one or more occurences' do
        expect(Reggaexp.one_or_more(:a)).to eq(/a+/)
      end

      it 'groups a clause with count correctly' do
        expect(Reggaexp.one_or_more(2, :letters).case_insensitive).to eq(/(?:[a-z]{2})+/i)
      end
    end

    context '#between' do
      it 'creates a pattern matching between [min] and [max] occurences' do
        expect(Reggaexp.between(1..4, :a)).to eq(/a{1,4}/)
        expect(Reggaexp.between(1..4, :a, 'abc')).to eq(/(?:abc|a){1,4}/)
      end

      it 'wraps atoms in a group followed by quantifier when block given' do
        expect(Reggaexp.between(1..4) { one_or_more(:a, 'abc') }).to eq(/(?:(?:abc|a)+){1,4}/)
      end
    end

    context '#at_most' do
      it 'creates a pattern matching at most [amount] occurences' do
        expect(Reggaexp.at_most(3, :a)).to eq(/a{,3}/)
        expect(Reggaexp.at_most(3, :a, 'abc')).to eq(/(?:abc|a){,3}/)
      end

      it 'wraps atoms in a group followed by quantifier when block given' do
        expect(Reggaexp.at_most(4) { one_or_more(:a, 'abc') }).to eq(/(?:(?:abc|a)+){,4}/)
      end
    end

    context '#at_least' do
      it 'creates a pattern matching at least [amount] occurences' do
        expect(Reggaexp.at_least(3, :a)).to eq(/a{3,}/)
        expect(Reggaexp.at_least(3, :a, 'abc')).to eq(/(?:abc|a){3,}/)
      end

      it 'wraps atoms in a group followed by quantifier when block given' do
        expect(Reggaexp.at_least(4) { one_or_more(:a, 'abc') }).to eq(/(?:(?:abc|a)+){4,}/)
      end
    end

    context '#not_preceded_by' do
      let!(:pattern) { Reggaexp.start_of_line('1', :digit).not_preceded_by('0') }

      it 'does not match when preceded by found' do
        expect(pattern =~ '123').to be_truthy
        expect(pattern =~ '012').to be_falsy
      end

      it 'does not create a capture group' do
        expect(Reggaexp.not_preceded_by('a', capture: true)).to eq(/(?<!a)/)
        expect(Reggaexp.not_preceded_by('a', as: :named)).to eq(/(?<!a)/)
      end
    end

    context '#preceded_by' do
      let!(:pattern) { Reggaexp.start_of_line('1', :digit).preceded_by('0') }

      it 'matches when preceded by found' do
        expect(pattern =~ '123').to be_falsy
        expect(pattern =~ '012').to be_truthy
      end

      it 'does not create a capture group' do
        expect(Reggaexp.preceded_by('a', capture: true)).to eq(/(?<=a)/)
        expect(Reggaexp.preceded_by('a', as: :named)).to eq(/(?<=a)/)
      end
    end

    context '#or' do
      it 'creates a simple pattern using or' do
        expect(Reggaexp.at_least(3, :a).or.at_most(2, :b).then(:a)).to eq(/(?:a{3,}|b{,2})a/)
      end

      it 'does not create a non capture group if not needed' do
        expect(Reggaexp.at_least(3, :a).or.at_most(2, :b)).to eq(/a{3,}|b{,2}/)
      end

      it 'creates a capture group' do
        expect(Reggaexp.capture { at_least(3, :a).or.at_most(2, :b) }).to eq(/(a{3,}|b{,2})/)
      end

      it 'can take a count (number or numeric range) as first argument' do
        expect(Reggaexp.start_of_string(3, :a)).to eq(/\Aa{3}/)
      end

      it 'accepts a block' do
        expect(Reggaexp.at_least(3, :a).or { at_most(2, :b) }).to eq(/a{3,}|b{,2}/)
      end

      it 'groups multiple or clauses' do
        expect(
          Reggaexp
            .at_least(3, :a)
            .or.at_most(2, :b)
            .then(:a)
            .then(:b)
            .or(:c)
            .or(:d, :efg)
        ).to eq(/(?:a{3,}|b{,2})a(?:b|c|efg|d)/)
      end
    end
  end

  context 'Examples' do
    context 'Replace regex used internally with Reggaexp' do
      it 'could replace the non-digit regex' do
        expect(Reggaexp.start_to_end_of_string(:non_numeric)).to eq(/\A\D\z/)
      end

      it 'could replace the caret regex' do
        expect(Reggaexp.start_of_string('^')).to eq(/\A\^/)
      end

      it 'could replace string character split regex' do
        expect(Reggaexp.is('\\').or.not_preceded_by('\\')).to eq(/(?=\\)|(?<!\\)/)
      end

      it 'could replace start/end of string pattern regex' do
        expect(Reggaexp.not_preceded_by('\\').then('\\').then('A', 'z')).to eq(
          /(?<!\\)\\[Az]/
        )
      end

      it 'could replace flag + end of line removal regex' do
        expect(Reggaexp.maybe('$').then('/')
                       .maybe_multiple(:word)
                       .end_of_string).to eq(%r{\$?/\w*\z})
      end

      it 'could replace the plural to singular regex' do
        expect(Reggaexp.preceded_by(:any)
                       .end_of_string('s')).to eq(/(?<=.)s\z/)
      end

      it 'could replace the character range regex' do
        expect(Reggaexp.start_of_string(:any)
                       .then('-')
                       .end_of_string(:any)).to eq(/\A.-.\z/)
      end

      it 'could replace the start/end of string regex' do
        expect(Reggaexp.not_preceded_by('\\')
                       .then('\\')
                       .one_of('A', 'z')).to eq(/(?<!\\)\\[Az]/)
      end

      it 'remove expression capture group opening regex' do
        expect(Reggaexp.start_of_string
                       .maybe('^')
                       .then('(')
                       .maybe {
                         find('?')
                           .then {
                               group { maybe('<').one_of('!', '=') }
                                 .or { find('<').one_or_more(:word).then('>') }
                                 .or(':')
                           }
                       }).to eq(%r{\A\^?\((?:\?(?:<?[!=]|<\w+>|:))?})
      end
    end

    context 'Postal codes' do
      it 'matches an NL postal code' do
        pattern = Reggaexp
                  .start_of_string(2, :a..:z)
                  .maybe_multiple(:whitespace)
                  .end_of_string(4, :digits)
                  .case_insensitive

        expect(pattern =~ 'AA0000').to be_truthy
        expect(pattern =~ 'AA000O').to be_falsy
      end

      it 'matches a US postal code' do
        pattern = Reggaexp
          .start_of_string(4, :digits)
          .maybe {
            maybe_multiple(:whitespace)
              .maybe('-')
              .maybe_multiple(:whitespace)
              .maybe(5, :digits)
          }

        expect(pattern =~ '1234 - 55555').to be_truthy
        expect(pattern =~ '123A - 55555').to be_falsy
      end
    end

    context 'Phone numbers' do
      let!(:pattern) do
        Reggaexp
          .start_of_string
          .group { maybe('(').min(3, :digits).maybe(')') }
          .or {
            maybe('+')
              .maybe_multiple(:whitespace)
              .between(1..5, :digits)
              .maybe_multiple(:whitespace)
              .between(1..4, :digits)
          }
          .maybe_multiple(:whitespace)
          .then(3, :digits)
          .maybe_multiple(:whitespace)
          .maybe('-')
          .maybe_multiple(:whitespace)
          .between(4..6, :digits)
          .end_of_string
      end

      it 'matches a US phone number' do
        expect(pattern =~ '(415) 555 - 1234').to be_truthy
        expect(pattern =~ '+ 1 415 5551234').to  be_truthy
        expect(pattern =~ '+1 415 5551234').to   be_truthy
        expect(pattern =~ '+14155551234').to     be_truthy
      end

      it 'matches a UK phone number' do
        expect(pattern =~ '015 555 - 1234').to  be_truthy
        expect(pattern =~ '+ 44 15 5551234').to be_truthy
        expect(pattern =~ '+44 15 5551234').to  be_truthy
        expect(pattern =~ '+44155551234').to    be_truthy
      end

      it 'matches an NL phone number' do
        expect(pattern =~ '0031 6 12345678').to  be_truthy
        expect(pattern =~ '+31 6 12345678').to   be_truthy
        expect(pattern =~ '+31 010 12345678').to be_truthy
        expect(pattern =~ '+31612345678').to     be_truthy
      end
    end

    context 'User agent' do
      let!(:arch) do
        Reggaexp
          .capture {
            group {
              one_of('x', 'x86_', 'amd', 'wow', 'win').then('64')
            }
            .or {
              find('i').one_of('3', '6').then('86')
            }
            .or(:arm)
          }
          .case_insensitive
      end

      let!(:locale) do
        Reggaexp
          .not_preceded_by(:nintendo)
          .one_of(';', '(', :whitespace)
          .not(:nt)
          .group {
            find(2, :letters)
              .one_of('-', '_')
              .group(2, :letters).maybe
          }
          .maybe('-')
          .one_of(';', ')', '/')
          .not(:digits)
          .case_insensitive
      end

      let!(:iphone) do
        Reggaexp
          .find(:ip)
          .group { any_of(:a, :o).then(:d) }
          .or(:hone)
          .case_insensitive
      end

      let!(:http_accept) do
        Reggaexp
          .capture {
            find(2, :word)
              .group { one_of('_', '-').then(2, :word) }.maybe }
              .maybe { find(';q=').capture { one_or_more(:digits, '.') } }
              .case_insensitive
      end

      it 'can create architecture detection regex' do
        expect(arch).to eq(/((?:x86_|amd|wow|win|x)64|i[36]86|arm)/i)

        expect(arch =~ 'x86_64').to be_truthy
        expect(arch =~ 'x86_32').to be_falsy
      end

      it 'can create locale detection regex' do
        expect(locale).to eq(
           /(?<!nintendo)[;(\s](?!nt)(?:[a-z]{2}[\-_](?:[a-z]{2})?)-?[;)\/](?![0-9])/i
        )

        expect(locale =~ '(nl_NL)').to         be_truthy
        expect(locale =~ 'nintendo(nl_NL)').to be_falsy
      end

      it 'can capture locale information from http_accept header' do
        expect(http_accept).to eq(/(\w{2}(?:[_\-]\w{2})?)(?:;q=([.0-9]+))?/i)

        expect(http_accept =~ 'en-US;q=1').to be_truthy
        expect(http_accept =~ 'en*US;q=1').to be_truthy
        expect(http_accept =~ 'en-US;s=1').to be_truthy
      end

      it 'can identify iphones' do
        expect(iphone).to eq(/ip(?:[ao]d|hone)/i)

        expect(iphone =~ 'iphone').to be_truthy
        expect(iphone =~ 'iphod').to  be_falsy
      end
    end

    context 'Email address' do
      let!(:pattern) do
        Reggaexp
          .start_of_string(:word, '"')
          .zero_or_more(:word, *%w[- . + \\ $ % "])
          .not_preceded_by('.')
          .then('@')
          .then {
            find(:alphanum)
              .zero_or_more(:alphanum, '-')
              .zero_or_more { find('.').one_or_more(:letter, '-') }
              .then('.')
              .one_or_more(:letter)
          }
          .or {
            group { find(3, :digits).then('.') }
              .find(3)
              .find(3, :digits)
          }
          .end_of_string
      end

      it 'can create an email address regex' do
        expect(pattern).to eq(/\A["\w][\-.+\\$%"\w]*(?<!\.)@(?:[0-9A-Za-z][\-0-9A-Za-z]*(?:\.[\-A-Za-z]+)*\.[A-Za-z]+|(?:[0-9]{3}\.){3}[0-9]{3})\z/)
      end

      ['plainaddress', '@domain.com', 'Joe Smith <email@domain.com>',
       'email.domain.com', 'email@domain@domain.com', 'pizzaconpiña@gmail.com',
       'pizzaConpiña@gmail.COM', 'email@111.222.333.44444.555',
       'email@domain..com', 'email@domain.com (Joe Smith)', 'email@domain',
       'almedinagirón2013@hotmail.com', 'scsdfhgsdfj;ghsrf@gmail.com',
       'Fabíola.diniz37@gmail.com', 'something else@gmail.com',
       'аmazon@amazon.com', 'email@-domain.com', '#@%^%#$@#$@#.com',
       'email.@domain.com', '.email@domain.com'].each do |invalid|
        it "identifies invalid email formats: '#{invalid}'" do
          expect(pattern =~ invalid).to be_falsy
        end
      end

      ['valid@gmail.com', 'VALID@GMAIL.com', 'something_else@gmail.com',
       'something@yahoo.fr', 'hello123@gmail123.com',
       'firstname.lastname@domain.com', 'email@subdomain.domain.com',
       'firstname+lastname@domain.com', '_______@domain.com',
       'email@domain.name', 'email@domain.co.jp',
       'firstname-lastname@domain.com', '"email"@domain.com',
       'email@111.222.333.444', 'a@b.c'].each do |valid|
        it "identifies valid email formats: '#{valid}'" do
           expect(pattern =~ valid).to be_truthy
         end
      end
    end
  end
end
