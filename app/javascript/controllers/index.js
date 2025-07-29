import { application } from "../controllers/application";
import HolidayToggleController from "./holiday_toggle_controller.js";
import TimeOptionsController from "./time_options_controller";
import flash_controller from "./flash_controller.js";
import CopyClipboardController from "./copy_clipboard_controller.js";
import ScheduleDatePickerController from "./schedule_date_picker_controller.js";
import AccountingController from "./accounting_controller.js";
import CustomerSearchController from "./customer_search_controller.js";

application.register("holiday-toggle", HolidayToggleController);
application.register("time-options", TimeOptionsController);
application.register("flash", flash_controller);
application.register("copy-clipboard", CopyClipboardController);
application.register("schedule-date-picker", ScheduleDatePickerController);
application.register("accounting", AccountingController);
application.register("customer-search", CustomerSearchController);
