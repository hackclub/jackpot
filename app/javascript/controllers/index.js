// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

import RsvpModalController from "controllers/rsvp_modal_controller"
application.register("rsvp-modal", RsvpModalController)
