import { application } from "../controllers/application";
import HelloController from "./hello_controller.js";
import HolidayToggleController from "./holiday_toggle_controller.js";
import TimeOptionsController from "./time_options_controller";
import flash_controller from "./flash_controller.js";
import CopyClipboardController from "./copy_clipboard_controller.js";

application.register("hello", HelloController);
application.register("holiday-toggle", HolidayToggleController);
application.register("time-options", TimeOptionsController);
application.register("flash", flash_controller);
application.register("copy-clipboard", CopyClipboardController);
