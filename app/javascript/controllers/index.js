import { application } from "../controllers/application";
import HolidayToggleController from "./holiday_toggle_controller.js";
import TimeOptionsController from "./time_options_controller";
import flash_controller from "./flash_controller.js";
import CopyClipboardController from "./copy_clipboard_controller.js";

application.register("holiday-toggle", HolidayToggleController);
application.register("time-options", TimeOptionsController);
application.register("flash", flash_controller);
application.register("copy-clipboard", CopyClipboardController);
