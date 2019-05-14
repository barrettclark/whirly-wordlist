class WordList
  attr_reader :words

  def initialize
    @words = Array.new
    read_list
  end

  def check_letters(*letters)
    letter_counts = letters.each_with_object(Hash.new(0)) { |letter, counts| counts[letter] += 1 }
    @words.select do |word|
      word_counts = word.chars.each_with_object(Hash.new(0)) { |letter, counts| counts[letter] += 1 }
      word_counts.keys.all? { |letter| letters.include?(letter) && word_counts[letter] <= letter_counts[letter] } &&
        word.length >= 3 &&
        word.length <= letters.count
    end.sort_by { |word| [word.length, word] }
  end

  private
  def read_list
    IO.foreach(File.join(Rails.root, 'lib', 'wordsEn.txt')) { |line| @words << line.chomp }
    puts "#{@words.count} words read into memory"
  end
end

__END__

NOTE: Set logic is fun. This isn't the best answer, but I liked the proper_superset method
http://www.ruby-doc.org/stdlib-2.1.4/libdoc/set/rdoc/Set.html#method-i-3E

    def check_letters(*letters)
      require 'set'
      letter_set = letters.to_set
      @words.select do |word|
        letter_set > word.chars.to_set && word.length >= 3 && word.length <= letters.count
      end.sort_by { |word| [word.length, word] }
    end

Usage:

    $ wget http://www-01.sil.org/linguistics/wordlists/english/wordlist/wordsEn.txt
    $ irb -r ./words
    >> wl = WordList.new; nil
    109582 words read into memory
    >> wl.check_letters('s', 'h', 'c', 'p', 't', 'u')
    => ["cps", "cpu", "csp", "cst", "cts", "cup", "cut", "hts", "huh", "hup", "hut", "pct", "pts", "pup", "pus", "put", "sup", "tsp", "tup", "tut", "uhs", "ups", "cups", "cusp", "cuss", "cuts", "hush", "huts", "psst", "pups", "push", "puss", "puts", "putt", "scut", "shut", "such", "sups", "supt", "thus", "tups", "tush", "tuts", "tutu", "cusps", "cutup", "hutch", "putts", "scups", "scuts", "shush", "shuts", "tutus", "cuscus", "cutups", "pushup", "putsch", "schuss"]
