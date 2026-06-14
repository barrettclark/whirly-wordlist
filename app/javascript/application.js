import { Application } from "@hotwired/stimulus"
import LetterInputController from "controllers/letter_input_controller"

const application = Application.start()
application.register("letter-input", LetterInputController)
