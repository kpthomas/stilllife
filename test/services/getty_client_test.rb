require "test_helper"

class GettyClientTest < ActiveSupport::TestCase
  # --- full dates ---------------------------------------------------------

  test "parses Month Day, Year" do
    assert_equal Date.new(1957, 9, 4),
                 GettyClient.infer_date("Elizabeth Eckford on September 4, 1957, in Little Rock.")
  end

  test "parses Month Day Year without comma" do
    assert_equal Date.new(1957, 9, 4), GettyClient.infer_date("Taken September 4 1957.")
  end

  test "parses Day Month Year" do
    assert_equal Date.new(1957, 9, 4),
                 GettyClient.infer_date("Photographed 4 September 1957 outside Central High.")
  end

  test "is case-insensitive on month names" do
    assert_equal Date.new(1957, 9, 4),
                 GettyClient.infer_date("LITTLE ROCK, AR - SEPTEMBER 4, 1957: Students arrive.")
  end

  test "handles single-digit days" do
    assert_equal Date.new(2023, 3, 7), GettyClient.infer_date("Traffic on March 7, 2023 near Levittown.")
  end

  test "prefers the first full date when several appear" do
    caption = "On September 4, 1957, she walked past a crowd. On September 25, 1957, troops arrived."
    assert_equal Date.new(1957, 9, 4), GettyClient.infer_date(caption)
  end

  test "allows the day to include ordinal" do
    caption = "September 6th 1957 - Elizabeth Eckford ignores the hostile screams"
    assert_equal Date.new(1957, 9, 6), GettyClient.infer_date(caption)
  end

  test "allows the date to be first" do
    caption = "Elizabeth Eckford ignores the hostile screams and stares of fellow students on her first day of school, 6th September 1957"
    assert_equal Date.new(1957, 9, 6), GettyClient.infer_date(caption)
  end

  # --- year only ----------------------------------------------------------

  test "falls back to January 1 when only a year is present" do
    assert_equal Date.new(1957, 1, 1),
                 GettyClient.infer_date("A scene from the 1957 school integration crisis.")
  end

  test "uses a bare year when the dateline has no year" do
    assert_equal Date.new(1957, 1, 1),
                 GettyClient.infer_date("LITTLE ROCK, AR - SEPTEMBER 4: Crowds gather. Circa 1957.")
  end

  test "accepts nineteenth- through twenty-first-century years" do
    assert_equal Date.new(1899, 1, 1), GettyClient.infer_date("Street scene, 1899.")
    assert_equal Date.new(2024, 1, 1), GettyClient.infer_date("Highway in 2024.")
  end

  test "returns nil for blank caption" do
    assert_nil GettyClient.infer_date(nil)
    assert_nil GettyClient.infer_date("")
    assert_nil GettyClient.infer_date("   ")
  end

  test "returns nil when no date-like text is present" do
    assert_nil GettyClient.infer_date("Heavy vehicle traffic on the highway near Levittown, New York.")
  end

  test "returns nil for a dateline with no year anywhere" do
    assert_nil GettyClient.infer_date("SEPTEMBER 4: Crowds gather outside the school.")
  end

  test "ignores four-digit numbers outside the plausible year range" do
    assert_nil GettyClient.infer_date("Route 3456 under construction.")
  end

  test "returns nil rather than raising on an impossible date" do
    assert_nil GettyClient.infer_date("Photographed February 30, 1957.")
  end
end
