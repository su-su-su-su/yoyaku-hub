import { application } from "../controllers/application";
import HelloController from "./hello_controller.js";
import HolidayToggleController from "./holiday_toggle_controller.js"; // 正しいファイル名を使用

application.register("hello", HelloController);
application.register("holiday-toggle", HolidayToggleController); // ハイフンを使用
