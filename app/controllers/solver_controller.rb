class SolverController < ApplicationController
  require 'words'

  # GET /
  # GET /solver/index
  def index; end

  # POST /solver/letters
  def letters
    letter1 = params[:letter1].downcase
    letter2 = params[:letter2].downcase
    letter3 = params[:letter3].downcase
    letter4 = params[:letter4].downcase
    letter5 = params[:letter5].downcase
    letter6 = params[:letter6].downcase
    if letter1.empty? || letter2.empty? || letter3.empty? || letter4.empty? || letter5.empty? || letter6.empty?
      redirect_to root_path
      nil
    else
      wl = WordList.new
      @words = wl.check_letters(letter1, letter2, letter3, letter4, letter5, letter6)
    end
  end
end
