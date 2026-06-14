require "test_helper"

# Avoids loading the 109k-word production file during tests
class TestWordList < WordList
  TEST_WORDS = %w[a ab act acts arc arcs car care card cat cats scat catch].freeze

  private

  def read_list
    @words = TEST_WORDS.dup
  end
end

class WordListTest < ActiveSupport::TestCase
  setup do
    @wl = TestWordList.new
  end

  test "returns only words constructable from given letters" do
    results = @wl.check_letters("c", "a", "t", "x", "y", "z")
    assert_includes results, "cat"
    refute_includes results, "car"   # 'r' not available
    refute_includes results, "care"  # 'r' and 'e' not available
  end

  test "respects letter counts - cannot use a letter more times than supplied" do
    # 's' appears once, so 'cats' needs exactly one 's' - ok
    # but give no 's': cats should not appear
    results = @wl.check_letters("c", "a", "t", "x", "y", "z")
    refute_includes results, "cats"
  end

  test "when a letter appears in input, words using it once are allowed" do
    results = @wl.check_letters("c", "a", "t", "s", "x", "y")
    assert_includes results, "cat"
    assert_includes results, "cats"
    assert_includes results, "acts"
  end

  test "enforces minimum word length of 3" do
    results = @wl.check_letters("a", "b", "c", "x", "y", "z")
    refute_includes results, "a"
    refute_includes results, "ab"
  end

  test "enforces maximum word length of 6 (number of letters given)" do
    results = @wl.check_letters("c", "a", "t", "c", "h", "s")
    assert results.all? { |w| w.length <= 6 },
      "Expected all words to be 6 letters or fewer, got: #{results.select { |w| w.length > 6 }}"
  end

  test "results sorted by length ascending then alphabetically within length" do
    results = @wl.check_letters("c", "a", "r", "t", "s", "e")
    lengths = results.map(&:length)
    assert_equal lengths.sort, lengths, "Expected results sorted by length"

    by_length = results.group_by(&:length)
    by_length.each do |_len, words|
      assert_equal words.sort, words, "Expected words of same length to be sorted alphabetically"
    end
  end

  test "returns empty array when no words match" do
    results = @wl.check_letters("q", "q", "q", "q", "q", "q")
    assert_equal [], results
  end
end
