require "test_helper"

class SolverControllerTest < ActionDispatch::IntegrationTest
  test "GET / returns 200" do
    get root_url
    assert_response :success
  end

  test "POST /solver/letters with all 6 letters returns 200 and renders words" do
    post solver_letters_url, params: {
      letter1: "c", letter2: "a", letter3: "t",
      letter4: "s", letter5: "e", letter6: "r"
    }
    assert_response :success
    assert_select "li", minimum: 1
  end

  test "POST /solver/letters with a blank letter redirects to root" do
    post solver_letters_url, params: {
      letter1: "c", letter2: "", letter3: "t",
      letter4: "s", letter5: "e", letter6: "r"
    }
    assert_redirected_to root_url
  end

  test "POST /solver/letters with a missing letter param redirects to root" do
    post solver_letters_url, params: {
      letter1: "c", letter2: "a", letter3: "t",
      letter4: "s", letter5: "e"
      # letter6 intentionally omitted
    }
    assert_redirected_to root_url
  end
end
