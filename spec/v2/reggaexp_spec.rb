# examples may contain some non-related tokens to the test
# to ensure that everything is joined properly regardless
# of argument order.

RSpec.describe Reggaexp do
  def builder
    Reggaexp::V2::Base.new
  end

  def with_flags(*flags)
    builder.flags(*flags)
  end

  def clause(*args, **opts)
    builder.parse(*args, **opts).clauses.flatten
  end

  def pattern(*args, **opts)
    builder.parse(*args, **opts).pattern
  end

  def character_class(*args)
    builder.character_class clause(*args)
  end

  def non_capturing_group(*args)
    builder.non_capturing_group clause(*args)
  end

  context 'Arguments' do
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
    end

    context 'Ranges' do
      it 'converts range boundary types to strings' do
        expect(clause(1..4, :b..:q, 's'..'u')).to(
          contain_exactly('1'..'4', 'b'..'q', 's'..'u')
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
        expect(clause(1, 2, 3.25)).to contain_exactly '1', '2', '3\\.25'
      end

      it 'removes duplicates' do
        expect(clause(1, 2, 3, 1, 5, 1)).to contain_exactly '1', '2', '3', '5'
        expect(clause(1.25, 1, 1.25)).to    contain_exactly '1\\.25', '1'
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

  context 'Character classes' do
    it 'filters single-character strings for character-class usage' do
      expect(character_class('a', 'abc', 'q', 1, :b)).to(
        contain_exactly('a', 'q', '1', 'b')
      )
    end

    it 'creates a character class with single-length strings and ranges' do
      expect(builder.parse(:q, :a..:f).pattern).to eq(/[qa-f]/)
    end
  end

  context 'Groups' do
    it 'filters multi-character strings for non-capture-group usage' do
      expect(non_capturing_group('a', 'abc', 'q', 123, :b)).to(
        contain_exactly('123', 'abc')
      )
    end

    it 'creates a capture group when capture: true is given' do
      match_data = pattern('hello', capture: true).match('hello')
      expect(match_data[1]).to eq 'hello'
    end

    it 'creates a named capture group when as: :name is given' do
      match_data = pattern('hello', as: :name).match('hello')
      expect(match_data[:name]).to eq 'hello'
    end

    it 'creates a non-capturing group around strings when not capturing' do
      expect(pattern('hello', 'goodbye')).to eq(/(?:hello|goodbye)/)
    end
  end

  context 'Flags' do
    it 'sets flags on a regular expression' do
      expect(with_flags(:i, :m, :x).pattern).to eq(//mix)
    end

    it 'downcases all uppercase groups with case-insensitive regexp' do
      expect(with_flags(:i).parse(:a..:d, :X..:Z).pattern).to eq(/[x-za-d]/i)
      expect(with_flags(:i).parse(:a..:z, :A..:Z).pattern).to eq(/[a-z]/i)
    end
  end
end
