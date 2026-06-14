class SolverController < ApplicationController

  # GET /
  # GET /solver/index
  def index; end

  # POST /solver/letters
  def letters
    letter1 = params[:letter1].to_s.downcase
    letter2 = params[:letter2].to_s.downcase
    letter3 = params[:letter3].to_s.downcase
    letter4 = params[:letter4].to_s.downcase
    letter5 = params[:letter5].to_s.downcase
    letter6 = params[:letter6].to_s.downcase
    unless letter1.empty? || letter2.empty? || letter3.empty? || letter4.empty? || letter5.empty? || letter6.empty?
      wl = WordList.new
      @words = wl.check_letters(letter1, letter2, letter3, letter4, letter5, letter6)
    else
      redirect_to root_path
      return
    end
  end
end
